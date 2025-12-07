use chrono::NaiveDateTime;

#[flutter_rust_bridge::frb(sync)] // Synchronous mode for simplicity of the demo
pub fn greet(name: String) -> String {
    format!("Hello, {name}!")
}

#[derive(Clone, Debug)]
pub enum Store {
    Biedronka,
    Lidl,
    Other(String),
}

#[derive(Clone, Debug)]
pub struct Item {
    pub name: String,
    pub unit_price: f32,
    pub count: f32,
    pub price: f32,
}

#[derive(Clone, Debug)]
pub struct Receipt {
    pub nip: Option<String>,
    pub store: Store,
    pub items: Vec<Item>,
    pub total: f32,
    pub date: NaiveDateTime,
}

#[flutter_rust_bridge::frb(sync)]
pub fn fetch_receipts() -> Vec<Receipt> {
    vec![
        Receipt {
            nip: Some("123-456-789".to_string()),
            store: Store::Biedronka,
            items: vec![
                Item {
                    name: "Bread".to_string(),
                    unit_price: 2.50,
                    count: 1.0,
                    price: 2.50,
                },
                Item {
                    name: "Milk".to_string(),
                    unit_price: 3.00,
                    count: 2.0,
                    price: 6.00,
                },
            ],
            total: 8.50,
            date: NaiveDateTime::from_timestamp_opt(1678886400, 0).unwrap(), // March 15, 2023 12:00:00 AM UTC
        },
        Receipt {
            nip: None,
            store: Store::Lidl,
            items: vec![
                Item {
                    name: "Apples".to_string(),
                    unit_price: 1.20,
                    count: 3.0,
                    price: 3.60,
                },
                Item {
                    name: "Cheese".to_string(),
                    unit_price: 5.00,
                    count: 1.0,
                    price: 5.00,
                },
            ],
            total: 8.60,
            date: NaiveDateTime::from_timestamp_opt(1678972800, 0).unwrap(), // March 16, 2023 12:00:00 AM UTC
        },
    ]
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    // Default utilities - feel free to customize
    flutter_rust_bridge::setup_default_user_utils();
}
