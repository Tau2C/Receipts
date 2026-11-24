use crate::corners::Quad;
use thiserror::Error;

#[derive(Error, Debug)]
pub enum TransformError {
    #[error("Invalid source or destination dimensions")]
    InvalidDimensions,

    #[error("Singular homography matrix")]
    SingularMatrix,

    #[error("Image buffer error: {0}")]
    ImageError(String),
}

/// 3x3 Homography Matrix representing a 2D projective transformation.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct Homography {
    pub m: [f64; 9],
}

impl Homography {
    /// Solves for the 3x3 projective transformation matrix mapping `src` quad to `dst` quad.
    /// Uses the Direct Linear Transformation (DLT) algorithm.
    pub fn find(src: &Quad, dst_width: f64, dst_height: f64) -> Option<Self> {
        let src_pts = [
            (src.top_left.x as f64, src.top_left.y as f64),
            (src.top_right.x as f64, src.top_right.y as f64),
            (src.bottom_right.x as f64, src.bottom_right.y as f64),
            (src.bottom_left.x as f64, src.bottom_left.y as f64),
        ];

        let dst_pts = [
            (0.0, 0.0),
            (dst_width, 0.0),
            (dst_width, dst_height),
            (0.0, dst_height),
        ];

        // 8x8 system for finding H mapping dst -> src (inverse mapping for backward sampling)
        let mut a = [[0.0f64; 8]; 8];
        let mut b = [0.0f64; 8];

        for i in 0..4 {
            let (dx, dy) = dst_pts[i];
            let (sx, sy) = src_pts[i];

            a[i * 2] = [dx, dy, 1.0, 0.0, 0.0, 0.0, -dx * sx, -dy * sx];
            b[i * 2] = sx;

            a[i * 2 + 1] = [0.0, 0.0, 0.0, dx, dy, 1.0, -dx * sy, -dy * sy];
            b[i * 2 + 1] = sy;
        }

        let h = solve_8x8(&mut a, &mut b)?;

        Some(Self {
            m: [h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1.0],
        })
    }

    /// Maps point (x, y) from destination plane back to source plane.
    #[inline(always)]
    pub fn transform_point(&self, x: f64, y: f64) -> (f64, f64) {
        let denom = self.m[6] * x + self.m[7] * y + self.m[8];
        let inv_denom = if denom.abs() < 1e-10 {
            1.0
        } else {
            1.0 / denom
        };
        let sx = (self.m[0] * x + self.m[1] * y + self.m[2]) * inv_denom;
        let sy = (self.m[3] * x + self.m[4] * y + self.m[5]) * inv_denom;
        (sx, sy)
    }
}

/// Warps image perspective so the quad region becomes a rectified rectangular image.
/// Operates on 8-bit RGBA input buffer.
pub fn warp_perspective(
    rgba_bytes: &[u8],
    src_width: u32,
    src_height: u32,
    corners: &Quad,
) -> Result<(Vec<u8>, u32, u32), TransformError> {
    if src_width == 0
        || src_height == 0
        || rgba_bytes.len() != (src_width * src_height * 4) as usize
    {
        return Err(TransformError::InvalidDimensions);
    }

    let (dst_w, dst_h) = corners.dimensions();
    if dst_w == 0 || dst_h == 0 {
        return Err(TransformError::InvalidDimensions);
    }

    let homography = Homography::find(corners, dst_w as f64, dst_h as f64)
        .ok_or(TransformError::SingularMatrix)?;

    let mut out_bytes = vec![0u8; (dst_w * dst_h * 4) as usize];

    for dy in 0..dst_h {
        let dy_f = dy as f64;
        let row_idx = (dy * dst_w * 4) as usize;

        for dx in 0..dst_w {
            let dx_f = dx as f64;
            let (sx_f, sy_f) = homography.transform_point(dx_f, dy_f);

            // Bilinear interpolation
            let pixel_idx = row_idx + (dx * 4) as usize;
            if sx_f >= 0.0
                && sx_f < (src_width - 1) as f64
                && sy_f >= 0.0
                && sy_f < (src_height - 1) as f64
            {
                let x0 = sx_f.floor() as u32;
                let y0 = sy_f.floor() as u32;
                let x1 = x0 + 1;
                let y1 = y0 + 1;

                let fx = (sx_f - x0 as f64) as f32;
                let fy = (sy_f - y0 as f64) as f32;
                let fx1 = 1.0 - fx;
                let fy1 = 1.0 - fy;

                let p00_idx = ((y0 * src_width + x0) * 4) as usize;
                let p10_idx = ((y0 * src_width + x1) * 4) as usize;
                let p01_idx = ((y1 * src_width + x0) * 4) as usize;
                let p11_idx = ((y1 * src_width + x1) * 4) as usize;

                for c in 0..4 {
                    let c00 = rgba_bytes[p00_idx + c] as f32;
                    let c10 = rgba_bytes[p10_idx + c] as f32;
                    let c01 = rgba_bytes[p01_idx + c] as f32;
                    let c11 = rgba_bytes[p11_idx + c] as f32;

                    let top = c00 * fx1 + c10 * fx;
                    let bot = c01 * fx1 + c11 * fx;
                    let val = top * fy1 + bot * fy;

                    out_bytes[pixel_idx + c] = val.round().clamp(0.0, 255.0) as u8;
                }
            } else if sx_f >= 0.0
                && sx_f < src_width as f64
                && sy_f >= 0.0
                && sy_f < src_height as f64
            {
                // Nearest neighbor for border edges
                let sx = sx_f.round().clamp(0.0, (src_width - 1) as f64) as u32;
                let sy = sy_f.round().clamp(0.0, (src_height - 1) as f64) as u32;
                let p_idx = ((sy * src_width + sx) * 4) as usize;
                out_bytes[pixel_idx..pixel_idx + 4].copy_from_slice(&rgba_bytes[p_idx..p_idx + 4]);
            }
        }
    }

    Ok((out_bytes, dst_w, dst_h))
}

/// Encodes RGBA buffer to JPEG bytes with specified quality (1..=100).
pub fn encode_jpeg(
    rgba_bytes: &[u8],
    width: u32,
    height: u32,
    quality: u8,
) -> Result<Vec<u8>, TransformError> {
    if width == 0 || height == 0 || rgba_bytes.len() != (width * height * 4) as usize {
        return Err(TransformError::InvalidDimensions);
    }

    let img_buffer =
        image::RgbaImage::from_raw(width, height, rgba_bytes.to_vec()).ok_or_else(|| {
            TransformError::ImageError("Failed to build RgbaImage buffer".to_string())
        })?;

    let rgb_img = image::DynamicImage::ImageRgba8(img_buffer).to_rgb8();

    let mut output = std::io::Cursor::new(Vec::new());
    let mut encoder = image::codecs::jpeg::JpegEncoder::new_with_quality(&mut output, quality);
    encoder
        .encode(
            rgb_img.as_raw(),
            width,
            height,
            image::ExtendedColorType::Rgb8,
        )
        .map_err(|e| TransformError::ImageError(e.to_string()))?;

    Ok(output.into_inner())
}

/// Solves 8x8 linear equation system Ax = B using Gaussian elimination with partial pivoting.
#[allow(clippy::needless_range_loop)]
fn solve_8x8(a: &mut [[f64; 8]; 8], b: &mut [f64; 8]) -> Option<[f64; 8]> {
    for col in 0..8 {
        // Find pivot
        let mut max_row = col;
        let mut max_val = a[col][col].abs();
        for row in col + 1..8 {
            let val = a[row][col].abs();
            if val > max_val {
                max_val = val;
                max_row = row;
            }
        }

        if max_val < 1e-12 {
            return None; // Singular matrix
        }

        // Swap rows
        if max_row != col {
            a.swap(col, max_row);
            b.swap(col, max_row);
        }

        let pivot = a[col][col];
        for row in col + 1..8 {
            let factor = a[row][col] / pivot;
            a[row][col] = 0.0;
            for j in col + 1..8 {
                a[row][j] -= factor * a[col][j];
            }
            b[row] -= factor * b[col];
        }
    }

    // Back-substitution
    let mut x = [0.0f64; 8];
    for row in (0..8).rev() {
        let mut sum = b[row];
        for col in row + 1..8 {
            sum -= a[row][col] * x[col];
        }
        x[row] = sum / a[row][row];
    }

    Some(x)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::corners::Point2D;

    #[test]
    fn test_homography_identity() {
        let quad = Quad::new(
            Point2D::new(0.0, 0.0),
            Point2D::new(100.0, 0.0),
            Point2D::new(100.0, 100.0),
            Point2D::new(0.0, 100.0),
        );

        let h = Homography::find(&quad, 100.0, 100.0).expect("Homography failed");
        let (x, y) = h.transform_point(50.0, 50.0);
        assert!((x - 50.0).abs() < 1e-3);
        assert!((y - 50.0).abs() < 1e-3);
    }

    #[test]
    fn test_warp_perspective_dimensions() {
        let w = 200u32;
        let h = 200u32;
        let rgba = vec![255u8; (w * h * 4) as usize];

        let quad = Quad::new(
            Point2D::new(20.0, 20.0),
            Point2D::new(180.0, 20.0),
            Point2D::new(180.0, 180.0),
            Point2D::new(20.0, 180.0),
        );

        let (out, out_w, out_h) = warp_perspective(&rgba, w, h, &quad).expect("Warp failed");
        assert_eq!(out_w, 160);
        assert_eq!(out_h, 160);
        assert_eq!(out.len(), (160 * 160 * 4) as usize);
    }
}
