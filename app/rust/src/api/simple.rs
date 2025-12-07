use rust_decimal::Decimal;
use chrono::NaiveDateTime;

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

pub enum Store {
    Biedronka,
    Lidl,
    Other(String),
}

pub struct Item {
    pub name: String,
    pub unit_price: Decimal,
    pub count: Decimal,
    pub price: Decimal,
}

pub struct Receipt {
    pub nip: Option<String>,
    pub store: Store,
    pub items: Vec<Item>,
    pub total: Decimal,
    pub date: NaiveDateTime,
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
