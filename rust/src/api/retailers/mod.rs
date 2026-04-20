use crate::api::receipts::Receipt;
use chrono::{DateTime, Utc};
use reqwest::StatusCode;

pub mod biedronka;
pub mod lidl;
pub mod spolem;

#[derive(Debug)]
pub enum FetchError {
    ClientError {
        file: String,
        line: u32,
    },
    ServerError {
        file: String,
        line: u32,
    },
    InavlidLogin {
        file: String,
        line: u32,
    },
    BadRequest {
        message: String,
        file: String,
        line: u32,
    },
    UnexpectedStatus {
        status: StatusCode,
        file: String,
        line: u32,
    },
}

pub trait ReceiptProvider {
    #[allow(async_fn_in_trait)]
    async fn fetch_receipts(&mut self) -> Result<Vec<Receipt>, FetchError>;

    #[allow(async_fn_in_trait)]
    async fn fetch_receipts_older_than(
        &mut self,
        date: DateTime<Utc>,
    ) -> Result<Vec<Receipt>, FetchError>;
}
