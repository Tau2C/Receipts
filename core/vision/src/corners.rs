use serde::{Deserialize, Serialize};

/// 2D floating-point coordinate point.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Point2D {
    pub x: f32,
    pub y: f32,
}

impl Point2D {
    pub fn new(x: f32, y: f32) -> Self {
        Self { x, y }
    }

    pub fn distance_squared(&self, other: &Point2D) -> f32 {
        let dx = self.x - other.x;
        let dy = self.y - other.y;
        dx * dx + dy * dy
    }

    pub fn distance(&self, other: &Point2D) -> f32 {
        self.distance_squared(other).sqrt()
    }
}

/// A quadrilateral defined by 4 corner points in clockwise order:
/// top-left, top-right, bottom-right, bottom-left.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Quad {
    pub top_left: Point2D,
    pub top_right: Point2D,
    pub bottom_right: Point2D,
    pub bottom_left: Point2D,
}

impl Quad {
    pub fn new(
        top_left: Point2D,
        top_right: Point2D,
        bottom_right: Point2D,
        bottom_left: Point2D,
    ) -> Self {
        Self {
            top_left,
            top_right,
            bottom_right,
            bottom_left,
        }
    }

    /// Calculates ideal rectified destination width and height.
    pub fn dimensions(&self) -> (u32, u32) {
        let width_top = self.top_left.distance(&self.top_right);
        let width_bottom = self.bottom_left.distance(&self.bottom_right);
        let max_width = width_top.max(width_bottom).round() as u32;

        let height_left = self.top_left.distance(&self.bottom_left);
        let height_right = self.top_right.distance(&self.bottom_right);
        let max_height = height_left.max(height_right).round() as u32;

        (max_width.max(1), max_height.max(1))
    }
}

/// Detects the 4 corner points of a receipt on a contrasting background.
/// Uses edge gradient and convex bounding quad heuristics.
pub fn detect_receipt_corners(grayscale_bytes: &[u8], width: u32, height: u32) -> Option<Quad> {
    if width < 10 || height < 10 || grayscale_bytes.len() < (width * height) as usize {
        return None;
    }

    // 1. Calculate luminance statistics (Otsu-like thresholding)
    let total_pixels = (width * height) as usize;
    let sum: u64 = grayscale_bytes.iter().map(|&b| b as u64).sum();
    let mean = (sum / total_pixels as u64) as u8;

    // 2. Sample bright pixels representing the receipt paper
    // A receipt on a dark or neutral background is typically brighter than the mean
    let threshold = mean.saturating_add(20);

    let mut min_sum = f32::MAX; // top-left (x + y is minimum)
    let mut max_sum = f32::MIN; // bottom-right (x + y is maximum)
    let mut min_diff = f32::MAX; // top-right (y - x is minimum)
    let mut max_diff = f32::MIN; // bottom-left (y - x is maximum)

    let mut tl = Point2D::new(0.0, 0.0);
    let mut tr = Point2D::new(width as f32, 0.0);
    let mut br = Point2D::new(width as f32, height as f32);
    let mut bl = Point2D::new(0.0, height as f32);

    let mut found_bright = false;

    // Scan with step for speed and noise rejection
    let step = (width.min(height) / 100).max(1);
    for y in (0..height).step_by(step as usize) {
        let row_offset = (y * width) as usize;
        for x in (0..width).step_by(step as usize) {
            let val = grayscale_bytes[row_offset + x as usize];
            if val >= threshold {
                found_bright = true;
                let xf = x as f32;
                let yf = y as f32;

                let s = xf + yf;
                let d = yf - xf;

                if s < min_sum {
                    min_sum = s;
                    tl = Point2D::new(xf, yf);
                }
                if s > max_sum {
                    max_sum = s;
                    br = Point2D::new(xf, yf);
                }
                if d < min_diff {
                    min_diff = d;
                    tr = Point2D::new(xf, yf);
                }
                if d > max_diff {
                    max_diff = d;
                    bl = Point2D::new(xf, yf);
                }
            }
        }
    }

    if !found_bright {
        // Fallback to image boundaries if no receipt could be isolated
        return Some(Quad::new(
            Point2D::new(0.0, 0.0),
            Point2D::new((width - 1) as f32, 0.0),
            Point2D::new((width - 1) as f32, (height - 1) as f32),
            Point2D::new(0.0, (height - 1) as f32),
        ));
    }

    Some(Quad::new(tl, tr, br, bl))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_quad_dimensions() {
        let quad = Quad::new(
            Point2D::new(10.0, 10.0),
            Point2D::new(110.0, 10.0),
            Point2D::new(110.0, 210.0),
            Point2D::new(10.0, 210.0),
        );
        let (w, h) = quad.dimensions();
        assert_eq!(w, 100);
        assert_eq!(h, 200);
    }

    #[test]
    fn test_detect_receipt_corners_synthetic() {
        let width = 100u32;
        let height = 100u32;
        let mut img = vec![30u8; (width * height) as usize]; // dark background

        // Draw a bright receipt rectangle inside [20, 20] to [80, 80]
        for y in 20..=80 {
            for x in 20..=80 {
                img[(y * width + x) as usize] = 230;
            }
        }

        let quad = detect_receipt_corners(&img, width, height).expect("Corners detection failed");
        assert_eq!(quad.top_left, Point2D::new(20.0, 20.0));
        assert_eq!(quad.bottom_right, Point2D::new(80.0, 80.0));
    }
}
