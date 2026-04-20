use flutter_rust_bridge::frb;
use reqwest::Url;

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
pub fn encode_fancy_type(raw: Url) -> String {
    raw.to_string()
}

#[frb(dart2rust(dart_type = "Uri", dart_code = "{}.toString()"))]
pub fn decode_fancy_type(raw: String) -> Url {
    Url::parse(&raw).unwrap()
}
