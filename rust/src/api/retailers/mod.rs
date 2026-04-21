use crate::api::receipts::Receipt;
use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use reqwest::StatusCode;
use thiserror::Error;

pub mod biedronka;
pub mod lidl;
pub mod spolem;

#[derive(Debug, Error)]
pub enum FetchError {
    #[error("ClientError {file:?}:{line:?}")]
    ClientError { file: String, line: u32 },
    #[error("ServerError {file:?}:{line:?}")]
    ServerError { file: String, line: u32 },
    #[error("InavlidLogin {file:?}:{line:?}")]
    InavlidLogin { file: String, line: u32 },
    #[error("BadRequest {message:?} {file:?}:{line:?}")]
    BadRequest {
        message: String,
        file: String,
        line: u32,
    },
    #[error("UnexpectedStatus {status:?} {file:?}: {line:?}")]
    UnexpectedStatus {
        status: StatusCode,
        file: String,
        line: u32,
    },
}

pub trait ReceiptProvider {
    #[frb(sync, getter)]
    fn get_last_fetch(&self) -> Option<DateTime<Utc>>;
    #[frb(sync, setter)]
    fn set_last_fetch(&mut self, value: Option<DateTime<Utc>>);

    #[allow(async_fn_in_trait)]
    async fn fetch_receipts(&mut self) -> anyhow::Result<Vec<Receipt>>;

    #[allow(async_fn_in_trait)]
    async fn fetch_receipts_after(&mut self, date: DateTime<Utc>) -> anyhow::Result<Vec<Receipt>>;
}
