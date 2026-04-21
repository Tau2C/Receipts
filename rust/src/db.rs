use crate::api::{
    card::Card,
    receipts::{
        Receipt, ReceiptItem, ReceiptItemSummary, ReceiptPayment, ReceiptPaymentType, ReceiptStore,
    },
};
use chrono::{DateTime, Utc};
use futures::StreamExt;
use sqlx::{Result, SqlitePool};
use std::{panic, str::FromStr};

pub async fn run_migrations(pool: &SqlitePool) -> Result<()> {
    log::debug!("Running database migrations");
    sqlx::migrate!("./migrations")
        .run(pool)
        .await
        .map_err(|e| {
            log::error!("Failed to run migrations: {:?}", e);
            e
        })?;
    log::debug!("Migrations completed successfully");
    Ok(())
}

pub async fn get_cards(pool: &SqlitePool) -> Result<Vec<Card>> {
    log::debug!("Fetching cards from database");
    let mut cards = sqlx::query_as::<_, Card>("SELECT id, name, number FROM cards")
        .fetch_all(pool)
        .await
        .map_err(|e| {
            log::error!("Failed to fetch cards: {:?}", e);
            e
        })?;

    for card in &mut cards {
        card.enabled = true;
    }
    log::debug!("Retrieved {} cards", cards.len());
    Ok(cards)
}

pub async fn insert_card(pool: &SqlitePool, card: Card) -> Result<Card> {
    log::debug!("Inserting card: name={}, number={}", card.name, card.number);
    let id = sqlx::query!(
        "INSERT INTO cards (name, number) VALUES (?, ?)",
        card.name,
        card.number
    )
    .execute(pool)
    .await
    .map_err(|e| {
        log::error!("Failed to insert card: {:?}", e);
        e
    })?
    .last_insert_rowid();

    log::debug!("Card inserted with ID: {}", id);
    Ok(Card {
        id: Some(id),
        ..card
    })
}

pub async fn update_card(pool: &SqlitePool, card: Card) -> Result<()> {
    log::debug!("Updating card ID: {}", card.id.unwrap_or(-1));
    sqlx::query!(
        "UPDATE cards SET name = ?, number = ? WHERE id = ?",
        card.name,
        card.number,
        card.id
    )
    .execute(pool)
    .await
    .map_err(|e| {
        log::error!("Failed to update card {}: {:?}", card.id.unwrap_or(-1), e);
        e
    })?;
    Ok(())
}

pub async fn delete_card(pool: &SqlitePool, id: i64) -> Result<()> {
    log::debug!("Deleting card ID: {}", id);
    sqlx::query!("DELETE FROM cards WHERE id = ?", id)
        .execute(pool)
        .await
        .map_err(|e| {
            log::error!("Failed to delete card {}: {:?}", id, e);
            e
        })?;
    Ok(())
}

pub async fn get_receipts(pool: &SqlitePool) -> Result<Vec<Receipt>> {
    log::debug!("Fetching receipts summary");
    let records = sqlx::query!(
        r#"
            SELECT id, store_type, store_value, issued_at, total, tax_total
            FROM receipts
            ORDER BY issued_at DESC
            "#,
    )
    .fetch_all(pool)
    .await
    .map_err(|e| {
        log::error!("Failed to fetch receipts summary: {:?}", e);
        e
    })?;

    log::debug!("Processing details for {} receipts", records.len());

    // Use buffer_ordered to maintain the 'ORDER BY issued_at DESC'
    // while processing sub-queries concurrently.
    let receipts: Vec<Receipt> = futures::stream::iter(records.into_iter())
        .map(|record| async move {
            let id = record.id as i64;

            let items = match sqlx::query!(
                r#"
                SELECT ean, name, price, count, total, tax_group, tax_rate
                FROM receipt_items WHERE receipt_id = ?
                "#,
                id
            )
            .fetch_all(pool)
            .await
            {
                Ok(items) => items,
                Err(e) => {
                    log::error!("Failed to fetch items for receipt {}: {:?}", id, e);
                    Vec::new()
                }
            };

            let payments = match sqlx::query!(
                r#"
                SELECT payment_type, value
                FROM receipt_payments WHERE receipt_id = ?
                "#,
                id
            )
            .fetch_all(pool)
            .await
            {
                Ok(payments) => payments,
                Err(e) => {
                    log::error!("Failed to fetch payments for receipt {}: {:?}", id, e);
                    Vec::new()
                }
            };

            Receipt::new(
                Some(record.id as u32),
                if record.store_type.is_some() && record.store_value.is_some() {
                    unsafe {
                        ReceiptStore::from_parts(
                            &record.store_type.unwrap(),
                            record.store_value.unwrap(),
                        )
                    }
                } else {
                    ReceiptStore::Other("".to_string())
                },
                DateTime::parse_from_rfc3339(&record.issued_at)
                    .unwrap_or_else(|_| {
                        log::error!("Date parse error for receipt {}", id);
                        panic!("Date parse error for receipt {}", id);
                    })
                    .to_utc(),
                items
                    .into_iter()
                    .map(|i| {
                        ReceiptItem::new(
                            i.ean,
                            i.name,
                            i.price as f32,
                            i.count as f32,
                            Vec::new(),
                            i.total as f32,
                            i.tax_group,
                            i.tax_rate.map(|f| f as f32),
                        )
                    })
                    .collect(),
                record.total as f32,
                Vec::new(),
                Vec::new(),
                record.tax_total.map(|f| f as f32).unwrap_or(0.0),
                payments
                    .iter()
                    .map(|p| {
                        ReceiptPayment::new(
                            ReceiptPaymentType::from_str(&p.payment_type)
                                .unwrap_or(ReceiptPaymentType::Cash),
                            p.value as f32,
                        )
                    })
                    .collect(),
            )
        })
        .buffered(20)
        .collect()
        .await;

    Ok(receipts)
}

pub async fn insert_receipt(pool: &SqlitePool, mut receipt: Receipt) -> Result<Receipt> {
    log::debug!("Starting receipt insertion transaction");
    let mut tx = pool.begin().await.map_err(|e| {
        log::error!("Failed to begin transaction: {:?}", e);
        e
    })?;

    let (store_type, store_value) = match &receipt.store {
        ReceiptStore::Biedronka(val) => (Some("biedronka".to_string()), Some(val.clone())),
        ReceiptStore::Lidl(val) => (Some("lidl".to_string()), Some(val.clone())),
        ReceiptStore::Spolem(val) => (Some("spolem".to_string()), Some(val.clone())),
        ReceiptStore::Other(val) => (Some("other".to_string()), Some(val.clone())),
    };

    let issued_at_str = receipt.issued_at.to_rfc3339();
    let total = receipt.total();
    let tax_total = receipt.tax_total() as f64;

    let receipt_id = sqlx::query!(
        r#"
        INSERT INTO receipts (store_type, store_value, issued_at, total, tax_total)
        VALUES (?, ?, ?, ?, ?)
        "#,
        store_type,
        store_value,
        issued_at_str,
        total,
        tax_total
    )
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        log::error!("Failed to insert receipt header: {:?}", e);
        e
    })?
    .last_insert_rowid();

    log::debug!("Inserted receipt header ID: {}", receipt_id);

    for item in &receipt.items {
        let price = item.get_price();
        let count = item.get_count();
        let item_total = item.get_total();
        let tax_group = item.get_tax_group();
        let tax_rate = item.get_tax_rate();
        let ean = item.get_ean();
        let name = item.get_name();

        sqlx::query!(
            r#"
            INSERT INTO receipt_items (receipt_id, ean, name, price, count, total, tax_group, tax_rate)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            "#,
            receipt_id, ean, name, price, count, item_total, tax_group, tax_rate
        )
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            log::error!("Failed to insert receipt item '{}': {:?}", name, e);
            e
        })?;
    }

    for payment in &receipt.payments {
        let payment_type_str: &str = payment.payment_type().into();
        let payment_type = payment_type_str.to_string();
        let value = payment.value() as f64;

        sqlx::query!(
            r#"
            INSERT INTO receipt_payments (receipt_id, payment_type, value)
            VALUES (?, ?, ?)
            "#,
            receipt_id,
            payment_type,
            value
        )
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            log::error!("Failed to insert payment {}: {:?}", payment_type, e);
            e
        })?;
    }

    tx.commit().await.map_err(|e| {
        log::error!("Failed to commit receipt transaction: {:?}", e);
        e
    })?;

    log::debug!("Receipt {} transaction committed successfully", receipt_id);
    receipt.id = Some(receipt_id as u32);
    Ok(receipt)
}

pub async fn insert_receipts(pool: &SqlitePool, receipts: Vec<Receipt>) -> Result<Vec<Receipt>> {
    log::debug!("Batch inserting {} receipts", receipts.len());
    let mut inserted_receipts = Vec::with_capacity(receipts.len());

    for (i, receipt) in receipts.into_iter().enumerate() {
        let inserted = insert_receipt(pool, receipt).await?;
        inserted_receipts.push(inserted);
        if i % 10 == 0 && i > 0 {
            log::debug!("Batch progress: {}/{}", i, inserted_receipts.capacity());
        }
    }

    log::debug!("Batch insertion completed");
    Ok(inserted_receipts)
}

pub async fn update_receipt(_pool: &SqlitePool, _receipt: Receipt) -> Result<Receipt> {
    log::error!("update_receipt called but not implemented");
    todo!("Implement update_receipt")
}

pub async fn delete_receipt(pool: &SqlitePool, id: i64) -> Result<()> {
    log::debug!("Deleting receipt ID: {}", id);
    sqlx::query!("DELETE FROM receipts WHERE id = ?", id)
        .execute(pool)
        .await
        .map_err(|e| {
            log::error!("Failed to delete receipt {}: {:?}", id, e);
            e
        })?;
    Ok(())
}

pub async fn get_item(pool: &SqlitePool, ean: &str) -> Result<Vec<ReceiptItemSummary>> {
    log::debug!("Fetching items with ean: {}", ean);
    let items = sqlx::query!(
        r#"
        SELECT ri.ean, ri.name, ri.price, ri.count, ri.total, ri.tax_group, ri.tax_rate, r.issued_at, r.store_type, r.store_value
        FROM receipt_items ri JOIN receipts r ON r.id = ri.receipt_id WHERE ean = ?
        "#,
        ean
    )
    .fetch_all(pool)
    .await
    .map_err(|e| {
        log::error!("Failed to fetch items for ean {}: {:?}", ean, e);
        e
    })?;

    Ok(items
        .into_iter()
        .map(|i| {
            ReceiptItemSummary::new(
                ReceiptItem::new(
                    i.ean,
                    i.name,
                    i.price as f32,
                    i.count as f32,
                    Vec::new(),
                    i.total as f32,
                    i.tax_group,
                    i.tax_rate.map(|f| f as f32),
                ),
                DateTime::parse_from_rfc3339(&i.issued_at).unwrap().to_utc(),
                if i.store_type.is_some() && i.store_value.is_some() {
                    unsafe {
                        ReceiptStore::from_parts(&i.store_type.unwrap(), i.store_value.unwrap())
                    }
                } else {
                    ReceiptStore::Other("".to_string())
                },
            )
        })
        .collect())
}

#[derive(Debug)]
pub enum LastFetchDateTimeErrors {
    DateTimeParseError(String),
    MissingValue,
    SqlxError(sqlx::Error),
}

pub async fn get_last_fetch_date_time(
    pool: &SqlitePool,
    retailer: &str,
) -> Result<DateTime<Utc>, LastFetchDateTimeErrors> {
    log::debug!("Getting last fetch date for retailer: {}", retailer);
    let record = sqlx::query!(
        "SELECT last_fetch_date_time FROM retailers WHERE name = ?",
        retailer
    )
    .fetch_one(pool)
    .await
    .map_err(|e| {
        log::error!(
            "Database error fetching last fetch date for {}: {:?}",
            retailer,
            e
        );
        LastFetchDateTimeErrors::SqlxError(e)
    })?;

    let s = match record.last_fetch_date_time {
        Some(it) => it,
        None => {
            log::debug!("No last fetch date found for {}", retailer);
            return Err(LastFetchDateTimeErrors::MissingValue);
        }
    };

    let dt = DateTime::parse_from_rfc3339(&s).map_err(|e| {
        log::error!(
            "Failed to parse fetch date '{}' for {}: {:?}",
            s,
            retailer,
            e
        );
        LastFetchDateTimeErrors::DateTimeParseError(format!("{} {}", s, e))
    })?;

    log::debug!("Last fetch date for {}: {}", retailer, dt);
    Ok(dt.to_utc())
}

pub async fn update_last_fetch_date_time(
    pool: &SqlitePool,
    retailer: &str,
    date_time: Option<DateTime<Utc>>,
) -> Result<i64> {
    log::debug!("Updating last fetch date for {}: {:?}", retailer, date_time);
    let date_time_str = date_time.map(|v| v.to_rfc3339());
    let result = sqlx::query!(
        "UPDATE retailers SET last_fetch_date_time = ? WHERE name = ?",
        date_time_str,
        retailer
    )
    .execute(pool)
    .await
    .map_err(|e| {
        log::error!("Failed to update fetch date for {}: {:?}", retailer, e);
        e
    })?;

    Ok(result.rows_affected() as i64)
}
