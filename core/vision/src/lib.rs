pub mod corners;
pub mod ml;
pub mod transform;

pub use corners::{detect_receipt_corners, Point2D, Quad};
pub use ml::{detect_corners_hybrid, CornerDetectionResult};
pub use transform::{encode_jpeg, warp_perspective};
