use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;

#[frb(opaque)]
#[derive(Debug)]
pub struct Lidl {}

impl Lidl {
    const CLIENT_ID: &str = "";
    const CLIENT_SECRET: &str = "";
    const OPENIDCONNECT_CONFIG_URL: &str =
        "https://accounts.lidl.com/.well-known/openid-configuration";

    // #[frb(sync)]
    pub fn new(last_fetch: Option<DateTime<Utc>>) -> Self {
        todo!()
    }

    // #[frb(sync)]
    pub fn from_token(token: String, last_fetch: Option<DateTime<Utc>>) -> Self {
        todo!()
    }
}
