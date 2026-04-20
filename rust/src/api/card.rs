use flutter_rust_bridge::frb;
use sqlx::FromRow;

use crate::api::retailers::FetchError;

#[frb(opaque)]
#[derive(Debug, Clone, FromRow)]
pub struct Card {
    pub id: Option<i64>,
    pub name: String,
    pub number: String,
    #[sqlx(default)]
    pub enabled: bool,
}

impl Card {
    #[frb(sync)]
    pub fn new(id: Option<i64>, name: String, number: String, enabled: bool) -> Self {
        Self {
            id,
            name,
            number,
            enabled,
        }
    }
}

pub trait CardProvider {
    #[allow(async_fn_in_trait)]
    async fn fetch_card(&mut self) -> Result<Card, FetchError>;
}
