use flutter_rust_bridge::frb;
use reqwest::Url;

use crate::api::receipts::{Price, Quantity};

pub mod card;
pub mod database;
pub mod receipts;
pub mod retailers;

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}

#[frb(rust2dart(dart_type = "Uri", dart_code = "Uri.parse({})"))]
pub fn encode_url(raw: Url) -> String {
    raw.to_string()
}

#[frb(dart2rust(dart_type = "Uri", dart_code = "{}.toString()"))]
pub fn decode_url(raw: String) -> Url {
    Url::parse(&raw).unwrap()
}

#[frb(rust2dart(dart_type = "double", dart_code = "{}"))]
pub fn encode_price(raw: Price) -> f32 {
    raw.into()
}

#[frb(dart2rust(dart_type = "double", dart_code = "{}"))]
pub fn decode_price(raw: f32) -> Price {
    raw.into()
}

#[frb(rust2dart(dart_type = "double", dart_code = "{}"))]
pub fn encode_quantity(raw: Quantity) -> f32 {
    raw.into()
}

#[frb(dart2rust(dart_type = "double", dart_code = "{}"))]
pub fn decode_quantity(raw: f32) -> Quantity {
    raw.into()
}
