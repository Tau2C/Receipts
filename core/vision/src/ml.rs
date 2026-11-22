use crate::corners::{detect_receipt_corners, Point2D, Quad};
use std::sync::OnceLock;
use thiserror::Error;
use tract_onnx::prelude::*;

#[derive(Error, Debug)]
pub enum MlVisionError {
    #[error("Tract error: {0}")]
    Tract(String),

    #[error("Image error: {0}")]
    Image(#[from] image::ImageError),

    #[error("Invalid image dimensions: {0}x{1}")]
    InvalidDimensions(u32, u32),
}

/// Embedded ONNX weights for MobileViT document/card corner regression
static MODEL_BYTES: &[u8] = include_bytes!("../models/cornelius.onnx");

type RunnableModel = SimplePlan<TypedFact, Box<dyn TypedOp>, Graph<TypedFact, Box<dyn TypedOp>>>;

static RUNNABLE_MODEL: OnceLock<RunnableModel> = OnceLock::new();

fn get_or_init_model() -> Result<&'static RunnableModel, MlVisionError> {
    if let Some(model) = RUNNABLE_MODEL.get() {
        return Ok(model);
    }

    let mut reader = std::io::Cursor::new(MODEL_BYTES);
    let runnable = tract_onnx::onnx()
        .model_for_read(&mut reader)
        .map_err(|e| MlVisionError::Tract(e.to_string()))?
        .with_input_fact(
            0,
            InferenceFact::dt_shape(f32::datum_type(), tvec!(1, 3, 384, 384)),
        )
        .map_err(|e| MlVisionError::Tract(e.to_string()))?
        .into_optimized()
        .map_err(|e| MlVisionError::Tract(e.to_string()))?
        .into_runnable()
        .map_err(|e| MlVisionError::Tract(e.to_string()))?;

    let _ = RUNNABLE_MODEL.set(runnable);
    Ok(RUNNABLE_MODEL.get().expect("Model initialized"))
}

/// Result of ML corner detection containing corner quad, confidence (0.0 to 1.0), and whether ML was used.
#[derive(Debug, Clone, PartialEq, serde::Serialize, serde::Deserialize)]
pub struct CornerDetectionResult {
    pub quad: Quad,
    pub confidence: f32,
    pub is_ml: bool,
}

/// Preprocesses RGBA image into normalized (1, 3, 384, 384) NCHW tensor with ImageNet mean/std.
fn preprocess_image_tensor(
    rgba_bytes: &[u8],
    width: u32,
    height: u32,
) -> Result<Tensor, MlVisionError> {
    if width == 0 || height == 0 || rgba_bytes.len() != (width * height * 4) as usize {
        return Err(MlVisionError::InvalidDimensions(width, height));
    }

    // Bilinear downsampling to 384x384 RGB
    let target_w = 384usize;
    let target_h = 384usize;
    let mut tensor = tract_ndarray::Array4::<f32>::zeros((1, 3, target_h, target_w));

    let mean = [0.485f32, 0.456, 0.406];
    let std = [0.229f32, 0.224, 0.225];

    let x_scale = width as f32 / target_w as f32;
    let y_scale = height as f32 / target_h as f32;

    for ty in 0..target_h {
        let sy = (ty as f32 * y_scale).clamp(0.0, (height - 1) as f32);
        let y0 = sy.floor() as usize;
        let y1 = (y0 + 1).min((height - 1) as usize);
        let fy = sy - y0 as f32;
        let fy1 = 1.0 - fy;

        for tx in 0..target_w {
            let sx = (tx as f32 * x_scale).clamp(0.0, (width - 1) as f32);
            let x0 = sx.floor() as usize;
            let x1 = (x0 + 1).min((width - 1) as usize);
            let fx = sx - x0 as f32;
            let fx1 = 1.0 - fx;

            let idx00 = (y0 * width as usize + x0) * 4;
            let idx10 = (y0 * width as usize + x1) * 4;
            let idx01 = (y1 * width as usize + x0) * 4;
            let idx11 = (y1 * width as usize + x1) * 4;

            for c in 0..3 {
                let c00 = rgba_bytes[idx00 + c] as f32 / 255.0;
                let c10 = rgba_bytes[idx10 + c] as f32 / 255.0;
                let c01 = rgba_bytes[idx01 + c] as f32 / 255.0;
                let c11 = rgba_bytes[idx11 + c] as f32 / 255.0;

                let top = c00 * fx1 + c10 * fx;
                let bot = c01 * fx1 + c11 * fx;
                let val = top * fy1 + bot * fy;

                let norm = (val - mean[c]) / std[c];
                tensor[[0, c, ty, tx]] = norm;
            }
        }
    }

    Ok(tensor.into())
}

/// Detects receipt corners using the ML model.
/// If the confidence is below 0.35 or ML fails, falls back to heuristic contour detector.
pub fn detect_corners_hybrid(
    rgba_bytes: &[u8],
    width: u32,
    height: u32,
) -> Option<CornerDetectionResult> {
    if width < 10 || height < 10 || rgba_bytes.len() != (width * height * 4) as usize {
        return None;
    }

    // Try ML inference first
    if let Ok(model) = get_or_init_model() {
        if let Ok(input_tensor) = preprocess_image_tensor(rgba_bytes, width, height) {
            if let Ok(outputs) = model.run(tvec!(input_tensor.into())) {
                if outputs.len() >= 3 {
                    // Extract corners: [1, 8]
                    if let Ok(corners_view) = outputs[0].to_array_view::<f32>() {
                        // Extract presence logit and sharpness
                        let presence_logit = outputs[1].to_scalar::<f32>().copied().unwrap_or(0.0);
                        let sharpness = outputs[2].to_scalar::<f32>().copied().unwrap_or(0.0);

                        let sigmoid = 1.0 / (1.0 + (-presence_logit).exp());
                        // Confidence combined from presence sigmoid and sharpness
                        let confidence =
                            (sigmoid * 0.5 + (sharpness * 5.0).clamp(0.0, 0.5)).clamp(0.0, 1.0);

                        if corners_view.len() == 8 && confidence >= 0.35 {
                            let w_f = width as f32;
                            let h_f = height as f32;

                            let tl = Point2D::new(
                                (corners_view[[0, 0]] * w_f).clamp(0.0, w_f),
                                (corners_view[[0, 1]] * h_f).clamp(0.0, h_f),
                            );
                            let tr = Point2D::new(
                                (corners_view[[0, 2]] * w_f).clamp(0.0, w_f),
                                (corners_view[[0, 3]] * h_f).clamp(0.0, h_f),
                            );
                            let br = Point2D::new(
                                (corners_view[[0, 4]] * w_f).clamp(0.0, w_f),
                                (corners_view[[0, 5]] * h_f).clamp(0.0, h_f),
                            );
                            let bl = Point2D::new(
                                (corners_view[[0, 6]] * w_f).clamp(0.0, w_f),
                                (corners_view[[0, 7]] * h_f).clamp(0.0, h_f),
                            );

                            return Some(CornerDetectionResult {
                                quad: Quad::new(tl, tr, br, bl),
                                confidence,
                                is_ml: true,
                            });
                        }
                    }
                }
            }
        }
    }

    // Fallback: heuristic detection on grayscale luminance
    let total_pixels = (width * height) as usize;
    let mut grayscale = Vec::with_capacity(total_pixels);
    for i in 0..total_pixels {
        let idx = i * 4;
        let r = rgba_bytes[idx] as u16;
        let g = rgba_bytes[idx + 1] as u16;
        let b = rgba_bytes[idx + 2] as u16;
        let gray = ((r * 299 + g * 587 + b * 114) / 1000) as u8;
        grayscale.push(gray);
    }

    detect_receipt_corners(&grayscale, width, height).map(|quad| CornerDetectionResult {
        quad,
        confidence: 0.5,
        is_ml: false,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_ml_model_initialization_and_inference() {
        let w = 200u32;
        let h = 300u32;
        let mut rgba = vec![200u8; (w * h * 4) as usize];
        // draw a dark card inside
        for y in 50..250 {
            for x in 40..160 {
                let idx = ((y * w + x) * 4) as usize;
                rgba[idx] = 20;
                rgba[idx + 1] = 20;
                rgba[idx + 2] = 20;
            }
        }

        let res = detect_corners_hybrid(&rgba, w, h);
        assert!(res.is_some());
        let res = res.unwrap();
        assert!(res.confidence >= 0.0 && res.confidence <= 1.0);
    }
}
