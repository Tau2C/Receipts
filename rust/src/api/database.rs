use crate::api::receipts::{Receipt, ReceiptItemSummary, ReceiptStore};
use crate::db;
use crate::{api::card::Card, db::LastFetchDateTimeErrors};
use anyhow::Result;
use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use sqlx::SqlitePool;

#[frb(opaque)]
pub struct DatabaseService {
    receipts_cache: Option<Vec<Receipt>>,
    pool: SqlitePool,
}

impl DatabaseService {
    #[frb(sync)]
    pub fn new(path: String) -> Result<Self> {
        log::debug!("Attempting to initialize database pool with path: {}", path);

        let pool = SqlitePool::connect_lazy(&path);

        match pool {
            Ok(pool) => {
                log::debug!("Successfully created database pool lazy connection.");

                Ok(Self {
                    receipts_cache: None,
                    pool,
                })
            }
            Err(err) => {
                log::error!(
                    "Failed to create self.pool for path '{}'. Error: {}",
                    path,
                    err
                );

                Err(anyhow::format_err!("Failed to create self.pool: {}", err))
            }
        }
    }

    pub async fn get_last_fetch_date_time(&self, retailer: &str) -> Result<Option<DateTime<Utc>>> {
        log::debug!("Fetching last fetch date time for retailer: {}", retailer);
        match db::get_last_fetch_date_time(&self.pool, retailer).await {
            Err(LastFetchDateTimeErrors::SqlxError(sqlx::Error::RowNotFound)) => Ok(None),
            Err(e) => Err(anyhow::format_err!("{:?}", e)),
            Ok(a) => Ok(Some(a)),
        }
    }

    pub async fn update_last_fetch_date_time(
        &mut self,
        retailer: &str,
        date_time: Option<DateTime<Utc>>,
    ) -> Result<i64> {
        log::debug!("Updating last fetch date time for retailer: {}", retailer);
        db::update_last_fetch_date_time(&mut self.pool, retailer, date_time)
            .await
            .map_err(|e| e.into())
    }

    pub async fn get_cards(&mut self) -> Result<Vec<Card>> {
        log::debug!("Fetching all cards");
        db::get_cards(&self.pool).await.map_err(|e| e.into())
    }

    pub async fn insert_card(&mut self, card: Card) -> Result<Card> {
        log::debug!("Inserting new card");
        db::insert_card(&self.pool, card)
            .await
            .map_err(|e| e.into())
    }

    pub async fn update_card(&mut self, card: Card) -> Result<()> {
        log::debug!("Updating card");
        db::update_card(&self.pool, card)
            .await
            .map_err(|e| e.into())
    }

    pub async fn delete_card(&mut self, id: i64) -> Result<()> {
        log::debug!("Deleting card with id: {}", id);
        db::delete_card(&self.pool, id).await.map_err(|e| e.into())
    }

    #[frb(getter)]
    pub async fn get_receipts(&mut self) -> Result<Vec<Receipt>> {
        log::debug!("Fetching all receipts (checking cache)");
        if let Some(cached_receipts) = &self.receipts_cache {
            return Ok(cached_receipts.clone());
        }

        let receipts = db::get_receipts(&self.pool).await?;
        self.receipts_cache = Some(receipts.clone());
        Ok(receipts)
    }

    pub async fn insert_receipt(&mut self, receipt: Receipt) -> Result<Receipt> {
        log::debug!("Inserting new receipt");
        self.receipts_cache = None;
        db::insert_receipt(&self.pool, receipt)
            .await
            .map_err(|e| e.into())
    }

    pub async fn insert_receipts(&mut self, receipts: Vec<Receipt>) -> Result<Vec<Receipt>> {
        log::debug!("Inserting multiple receipts (count: {})", receipts.len());
        self.receipts_cache = None;
        db::insert_receipts(&self.pool, receipts)
            .await
            .map_err(|e| e.into())
    }

    pub async fn update_receipt(&mut self, _receipt: Receipt) -> Result<()> {
        log::debug!("Updating receipt (currently unimplemented)");
        self.receipts_cache = None;
        // db::update_receipt(&self.pool, receipt).await.map_err(|e| e.into())
        todo!("Implement update_receipt logic")
    }

    pub async fn delete_receipt(&mut self, id: i64) -> Result<()> {
        log::debug!("Deleting receipt with id: {}", id);
        self.receipts_cache = None;
        db::delete_receipt(&self.pool, id)
            .await
            .map_err(|e| e.into())
    }

    pub async fn delete_receipts_by_retailer(&mut self, retailer: String) -> Result<u32> {
        log::debug!("Deleting receipt from {}", &retailer);
        self.receipts_cache = None;
        db::delete_receipts_by_retailer(&self.pool, &retailer)
            .await
            .map_err(|e| e.into())
    }

    pub async fn get_item(
        &mut self,
        ean: Option<String>,
        store: Option<ReceiptStore>,
        item_id: Option<String>,
    ) -> Result<Vec<ReceiptItemSummary>> {
        log::debug!(
            "Fetching items with ean: {:?}/{:?}:{:?}",
            ean,
            store,
            item_id
        );
        db::get_item(&self.pool, ean, store, item_id)
            .await
            .map_err(|e| e.into())
    }

    pub async fn run_db_migrations(&mut self) -> Result<()> {
        log::debug!("Running database migrations");
        db::run_migrations(&self.pool)
            .await
            .map_err(anyhow::Error::from)
    }
}
