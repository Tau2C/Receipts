use crate::api::{
    card::Card,
    database::{ItemIdEanMap, SqlExecutionResult},
    receipts::{
        Date, Price, Quantity, Receipt, ReceiptItem, ReceiptItemDiscount, ReceiptItemSummary,
        ReceiptPayment, ReceiptPaymentType, ReceiptTaxSummary, Store,
    },
};
use anyhow::Result; // Added this line
use chrono::{DateTime, Utc};
use sqlx::{query_as, Column, Row, SqlitePool}; // Removed Result from here

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
    let mut cards =
        sqlx::query_as::<_, Card>(r#"SELECT id, name, number, 1 AS enabled FROM cards"#)
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
            SELECT id as "id!: u32", store as "store!: Store", receipt_id, issued_at, total as "total!: Price", tax_total as "tax_total!: Price"
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

    let mut receipts = Vec::new();
    for record in records {
        let id = record.id as i64;
        let issued_at = match DateTime::parse_from_rfc3339(&record.issued_at) {
            Ok(date) => date.to_utc(),
            Err(e) => {
                log::error!("Date parse error for receipt {}: {}", id, e);
                continue;
            }
        };

        let item_records = match sqlx::query!(
            r#"
            SELECT id, item_id, ean, name, price as "price!: Price", count as "count!: Quantity", total as "total!: Price", tax_group, tax_rate as "tax_rate: Price"
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

        let mut items = Vec::new();
        for item_record in item_records {
            let discounts = match sqlx::query!(
                "SELECT type, value FROM receipt_item_discounts WHERE receipt_item_id = ?",
                item_record.id
            )
            .fetch_all(pool)
            .await
            {
                Ok(discounts) => discounts
                    .into_iter()
                    .map(|d| {
                        if d.r#type == "value" {
                            ReceiptItemDiscount::Value(d.value as f32)
                        } else {
                            ReceiptItemDiscount::Percent(d.value as f32)
                        }
                    })
                    .collect(),
                Err(e) => {
                    log::error!(
                        "Failed to fetch discounts for item {}: {:?}",
                        item_record.id,
                        e
                    );
                    Vec::new()
                }
            };

            items.push(ReceiptItem::new(
                item_record.item_id,
                item_record.ean,
                item_record.name,
                item_record.price,
                item_record.count,
                discounts,
                item_record.total,
                item_record.tax_group,
                item_record.tax_rate,
            ));
        }

        let payments = match sqlx::query!(
            r#"
            SELECT payment_type as "payment_type!: ReceiptPaymentType", value as "value!: Price"
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

        let tax_summaries = match sqlx::query!(
            r#"
            SELECT tax_group, tax_rate as "tax_rate!: Price", sales_value as "sales_value!: Price", tax_value as "tax_value!: Price"
            FROM receipt_tax_summaries WHERE receipt_id = ?
            "#,
            id
        )
        .fetch_all(pool)
        .await
        {
            Ok(summaries) => summaries,
            Err(e) => {
                log::error!("Failed to fetch tax summaries for receipt {}: {:?}", id, e);
                Vec::new()
            }
        };

        receipts.push(Receipt::new(
            Some(record.id),
            record.store,
            record.receipt_id.into(),
            issued_at,
            items,
            record.total,
            Vec::new(), // Receipt-level discounts not implemented yet
            tax_summaries
                .into_iter()
                .map(|s| {
                    ReceiptTaxSummary::new(s.tax_group, s.tax_rate, s.sales_value, s.tax_value)
                })
                .collect(),
            record.tax_total,
            payments
                .into_iter()
                .map(|p| ReceiptPayment::new(p.payment_type, p.value))
                .collect(),
        ));
    }

    Ok(receipts)
}

pub async fn insert_receipt(pool: &SqlitePool, mut receipt: Receipt) -> Result<i64> {
    log::debug!("Starting receipt insertion transaction");
    let mut tx = pool.begin().await.map_err(|e| {
        log::error!("Failed to begin transaction: {:?}", e);
        e
    })?;

    let receipt_id = sqlx::query!(
        r#"
        INSERT INTO receipts (store, receipt_id, issued_at, total, tax_total)
        VALUES (?, ?, ?, ?, ?)
        "#,
        receipt.store,
        receipt.receipt_id,
        receipt.issued_at,
        receipt.total,
        receipt.tax_total
    )
    .execute(&mut *tx)
    .await
    .map_err(|e| {
        log::error!("Failed to insert receipt header: {:?}", e);
        e
    })?
    .last_insert_rowid();

    log::debug!("Inserted receipt header ID: {}", receipt_id);

    for item in receipt.items {
        let item_record_id = sqlx::query!(
            r#"
            INSERT INTO receipt_items (receipt_id, item_id, ean, name, price, count, total, tax_group, tax_rate)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            "#,
            receipt_id,
            item.id,
            item.ean,
            item.name,
            item.price,
            item.count,
            item.total,
            item.tax_group,
            item.tax_rate
        )
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            log::error!("Failed to insert receipt item '{}': {:?}", item.name, e);
            e
        })?
        .last_insert_rowid();

        for discount in item.discounts {
            let (discount_type, value) = match discount {
                crate::api::receipts::ReceiptItemDiscount::Value(v) => ("value", v),
                crate::api::receipts::ReceiptItemDiscount::Percent(v) => ("percent", v),
            };

            sqlx::query!(
                r#"
                INSERT INTO receipt_item_discounts (receipt_item_id, type, value)
                VALUES (?, ?, ?)
                "#,
                item_record_id,
                discount_type,
                value
            )
            .execute(&mut *tx)
            .await
            .map_err(|e| {
                log::error!(
                    "Failed to insert receipt item discount for item {}: {:?}",
                    item_record_id,
                    e
                );
                e
            })?;
        }
    }

    for summary in receipt.tax_summary {
        sqlx::query!(
            r#"
            INSERT INTO receipt_tax_summaries (receipt_id, tax_group, tax_rate, sales_value, tax_value)
            VALUES (?, ?, ?, ?, ?)
            "#,
            receipt_id,
            summary.tax_group,
            summary.tax_rate,
            summary.sales_value,
            summary.tax_value
        )
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            log::error!(
                "Failed to insert tax summary for receipt {}: {:?}",
                receipt_id,
                e
            );
            e
        })?;
    }

    for payment in &receipt.payments {
        sqlx::query!(
            r#"
            INSERT INTO receipt_payments (receipt_id, payment_type, value)
            VALUES (?, ?, ?)
            "#,
            receipt_id,
            payment.payment_type,
            payment.value
        )
        .execute(&mut *tx)
        .await
        .map_err(|e| {
            log::error!("Failed to insert payment {}: {:?}", payment.payment_type, e);
            e
        })?;
    }

    tx.commit().await.map_err(|e| {
        log::error!("Failed to commit receipt transaction: {:?}", e);
        e
    })?;

    log::debug!("Receipt {} transaction committed successfully", receipt_id);
    receipt.id = Some(receipt_id as u32);
    Ok(receipt_id)
}

pub async fn insert_receipts(pool: &SqlitePool, receipts: Vec<Receipt>) -> Result<usize> {
    let i = receipts.len();
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
    Ok(i)
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

pub async fn delete_receipts_by_retailer(pool: &SqlitePool, retailer: &str) -> Result<u32> {
    log::debug!("Deleting receipts from {}", &retailer);
    let result = sqlx::query!("DELETE FROM receipts WHERE store = ?", retailer)
        .execute(pool)
        .await
        .map_err(|e| {
            log::error!("Failed to delete receipts from {}: {:?}", retailer, e);
            e
        })?;

    Ok(result.rows_affected() as u32)
}

pub async fn get_item(
    pool: &SqlitePool,
    ean: Option<&str>,
    store: Option<Store>,
    item_id: Option<&str>,
) -> Result<Vec<ReceiptItemSummary>> {
    log::debug!(
        "Fetching items with ean: {:?}, store: {:?}, item_id: {:?}",
        ean,
        store,
        item_id
    );

    let mut effective_ean: Option<String> = ean.map(|s| s.to_string());

    if let (Some(store_val), Some(item_id_val)) = (&store, item_id) {
        let store_str = match store_val {
            Store::Biedronka => "biedronka",
            Store::Lidl => "lidl",
            Store::Spolem => "spolem",
            Store::Other(s) => s,
        };
        if let Ok(Some(ean_from_map)) = get_ean_by_item_id(pool, store_str, item_id_val).await {
            effective_ean = Some(ean_from_map);
        }
    }

    #[derive(Debug)]
    struct Record {
        id: i64,
        item_id: Option<String>,
        ean: Option<String>,
        name: String,
        price: Price,
        count: Quantity,
        total: Price,
        tax_group: Option<String>,
        tax_rate: Option<Price>,
        issued_at: Date,
        store: Store,
    }

    let records = if let Some(ean_val) = &effective_ean {
        query_as!(
            Record,
            r#"
            SELECT
                ri.id, ri.item_id, ri.ean, ri.name, ri.price as "price: Price", ri.count as "count: Quantity", ri.total as "total: Price", ri.tax_group, ri.tax_rate as "tax_rate?: Price", r.issued_at as "issued_at: Date",
                r.store as "store!: Store"
            FROM receipt_items ri
            JOIN receipts r ON r.id = ri.receipt_id
            WHERE ri.ean = ?
            ORDER BY r.issued_at DESC
            "#,
            ean_val
        )
        .fetch_all(pool)
        .await?
    } else if let (Some(store), Some(item_id)) = (store, item_id) {
        query_as!(
            Record,
            r#"
            SELECT
                ri.id, ri.item_id, ri.ean, ri.name, ri.price as "price: Price", ri.count as "count: Quantity", ri.total as "total: Price", ri.tax_group, ri.tax_rate as "tax_rate?: Price", r.issued_at as "issued_at: Date",
                r.store as "store!: Store"
            FROM receipt_items ri
            JOIN receipts r ON r.id = ri.receipt_id
            WHERE r.store = ? AND ri.item_id = ?
            ORDER BY r.issued_at DESC
            "#,
            store,
            item_id
        )
        .fetch_all(pool)
        .await?
    } else {
        return Ok(Vec::new());
    };

    let mut item_summaries = Vec::new();
    for record in records {
        let discounts = match sqlx::query!(
            "SELECT type, value FROM receipt_item_discounts WHERE receipt_item_id = ?",
            record.id
        )
        .fetch_all(pool)
        .await
        {
            Ok(discounts) => discounts
                .into_iter()
                .map(|d| {
                    if d.r#type == "value" {
                        ReceiptItemDiscount::Value(d.value as f32)
                    } else {
                        ReceiptItemDiscount::Percent(d.value as f32)
                    }
                })
                .collect(),
            Err(e) => {
                log::error!("Failed to fetch discounts for item {}: {:?}", record.id, e);
                Vec::new()
            }
        };

        item_summaries.push(ReceiptItemSummary::new(
            ReceiptItem::new(
                record.item_id,
                record.ean,
                record.name,
                record.price.into(),
                record.count.into(),
                discounts,
                record.total.into(),
                record.tax_group,
                record.tax_rate,
            ),
            record.issued_at.0,
            record.store,
        ));
    }

    Ok(item_summaries)
}

pub async fn get_ean_by_item_id(
    pool: &SqlitePool,
    store: &str,
    item_id: &str,
) -> Result<Option<String>> {
    log::debug!("Fetching EAN for store: {}, item_id: {}", store, item_id);

    let result = sqlx::query!(
        r#"
        SELECT ean
        FROM item_id_ean_map
        WHERE store = ? AND item_id = ?
        "#,
        store,
        item_id
    )
    .fetch_optional(pool)
    .await?;

    Ok(result.map(|row| row.ean))
}

pub async fn insert_item_id_ean_map(
    pool: &SqlitePool,
    store: &Store,
    item_id: &str,
    ean: &str,
) -> Result<()> {
    log::debug!(
        "Inserting item_id_ean_map for store: {:?}, item_id: {}, ean: {}",
        store,
        item_id,
        ean
    );

    sqlx::query!(
        r#"
        INSERT INTO item_id_ean_map (store, item_id, ean)
        VALUES (?, ?, ?)
        ON CONFLICT (store, item_id) DO UPDATE SET ean = EXCLUDED.ean
        "#,
        store,
        item_id,
        ean
    )
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn get_all_mappings(pool: &SqlitePool) -> Result<Vec<ItemIdEanMap>> {
    log::debug!("Fetching all item_id_ean_map mappings");
    let mappings = sqlx::query_as!(
        ItemIdEanMap,
        r#"SELECT store as "store: Store", item_id, ean FROM item_id_ean_map"#
    )
    .fetch_all(pool)
    .await?
    .into_iter()
    .map(|f| ItemIdEanMap {
        store: f.store,
        item_id: f.item_id,
        ean: f.ean,
    })
    .collect();
    Ok(mappings)
}

pub async fn delete_item_id_ean_map(pool: &SqlitePool, store: &Store, item_id: &str) -> Result<()> {
    log::debug!(
        "Deleting item_id_ean_map for store: {}, item_id: {}",
        store,
        item_id
    );

    sqlx::query!(
        "DELETE FROM item_id_ean_map
        WHERE
        store = ? AND item_id = ?",
        store,
        item_id
    )
    .execute(pool)
    .await?;

    Ok(())
}

pub async fn get_stores(pool: &SqlitePool) -> Result<Vec<Store>> {
    log::debug!("Get stores");
    let result = sqlx::query!(r#"SELECT DISTINCT store as "store: Store" FROM receipts"#)
        .fetch_all(pool)
        .await
        .map_err(|e| {
            log::error!("Failed to get list of stores: {:?}", e);
            e
        })?
        .into_iter()
        .map(|f| f.store)
        .collect();

    Ok(result)
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
    log::debug!(
        "Upserting last fetch date for {}: {:?}",
        retailer,
        date_time
    );
    let date_time_str = date_time.map(|v| v.to_rfc3339());
    let result = sqlx::query!(
        r#"
        INSERT INTO retailers (name, last_fetch_date_time)
        VALUES (?, ?)
        ON CONFLICT(name)
        DO UPDATE SET last_fetch_date_time = excluded.last_fetch_date_time
        "#,
        retailer,
        date_time_str
    )
    .execute(pool)
    .await
    .map_err(|e| {
        log::error!("Failed to upsert fetch date for {}: {:?}", retailer, e);
        e
    })?;

    Ok(result.rows_affected() as i64)
}

pub async fn execute_custom_sql(pool: &SqlitePool, sql: String) -> Result<SqlExecutionResult> {
    log::debug!("Executing custom SQL: {}", sql);

    let sql_lower = sql.to_lowercase().trim().to_string();

    if sql_lower.starts_with("select") {
        let rows = sqlx::query(&sql).fetch_all(pool).await.map_err(|e| {
            log::error!("Failed to execute SELECT query: {:?}", e);
            e
        })?;

        if rows.is_empty() {
            return Ok(SqlExecutionResult::Select(Vec::new(), Vec::new()));
        }

        let mut result_rows: Vec<Vec<String>> = Vec::new();
        let mut column_names: Vec<String> = Vec::new();

        // Get column names from the first row
        if let Some(first_row) = rows.first() {
            for column in first_row.columns() {
                column_names.push(column.name().to_string());
            }
        }

        for row in rows {
            let mut current_row: Vec<String> = Vec::new();

            for (i, _) in row.columns().iter().enumerate() {
                let value_str = if let Ok(v) = row.try_get::<String, _>(i) {
                    v
                } else if let Ok(v) = row.try_get::<i64, _>(i) {
                    v.to_string()
                } else if let Ok(v) = row.try_get::<f64, _>(i) {
                    v.to_string()
                } else if let Ok(v) = row.try_get::<Vec<u8>, _>(i) {
                    format!("<{} bytes blob>", v.len())
                } else {
                    // covers NULL and anything else
                    "NULL".to_string()
                };

                current_row.push(value_str);
            }

            result_rows.push(current_row);
        }
        Ok(SqlExecutionResult::Select(result_rows, column_names))
    } else {
        // DML statements
        let result = sqlx::query(&sql).execute(pool).await.map_err(|e| {
            log::error!("Failed to execute DML query: {:?}", e);
            e
        })?;
        Ok(SqlExecutionResult::RowsAffected(result.rows_affected()))
    }
}

pub async fn export_database(db_path: String, destination_dir: String) -> Result<String> {
    use chrono::Local;
    use std::fs;
    use std::path::PathBuf;

    log::debug!("Exporting database from {} to {}", db_path, destination_dir);

    let result = flutter_rust_bridge::spawn_blocking_with(
        move || {
            let src_path = PathBuf::from(db_path);
            let now = Local::now();
            let timestamp = now.format("%Y%m%d_%H%M%S").to_string();
            let export_file_name = format!("receipts_app_{}.db", timestamp);

            let dest_dir_path = PathBuf::from(&destination_dir);
            let dest_path = dest_dir_path.join(export_file_name);

            if !dest_dir_path.exists() {
                fs::create_dir_all(&dest_dir_path)?;
            }

            fs::copy(&src_path, &dest_path)?;

            log::debug!("Database exported to {}", dest_path.to_string_lossy());
            Ok(dest_path.to_string_lossy().to_string())
        },
        crate::frb_generated::FLUTTER_RUST_BRIDGE_HANDLER.thread_pool(),
    )
    .await?;

    result
}
