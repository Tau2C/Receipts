use chrono::{DateTime, FixedOffset};
use serde::{Deserialize, Serialize};
use tags::Tags;

/// PDS collection / entity type constants
pub const ENTITY_TYPE_RECEIPTS: &str = "receipts";
pub const ENTITY_TYPE_RECEIPT_ITEMS: &str = "receipt_items";
pub const ENTITY_TYPE_DAG_DIVERGENCE: &str = "dag_divergence_nodes";

/// Shared Unencrypted Receipt Entry stored in PDS
/// Conforms to 06-pds-data-usage.md and PDS-Client-API
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReceiptRecord {
    pub id: String,
    pub store: String,
    pub timestamp: String,
    pub total: f64,
    pub currency: String,
    pub image_blob_hash: Option<String>,
    pub items_ref: Option<String>,
    pub tags: Tags,
}

impl ReceiptRecord {
    pub fn new(
        id: String,
        store: String,
        timestamp: String,
        total: f64,
        currency: String,
    ) -> Result<Self, String> {
        // Verify RFC 3339 timestamp with timezone
        DateTime::parse_from_rfc3339(&timestamp)
            .map_err(|e| format!("Invalid timezone-aware RFC 3339 timestamp: {}", e))?;

        let mut tags = Tags::new();
        tags.set_tag("store", &store);
        tags.set_tag("currency", &currency);
        tags.set_tag("total", format!("{:.2}", total));
        tags.set_tag("date", &timestamp);

        Ok(Self {
            id,
            store,
            timestamp,
            total,
            currency,
            image_blob_hash: None,
            items_ref: None,
            tags,
        })
    }

    pub fn set_image_blob_hash(&mut self, hash: String) {
        self.tags.set_tag("image:blob", &hash);
        self.image_blob_hash = Some(hash);
    }

    pub fn parse_datetime(&self) -> Result<DateTime<FixedOffset>, chrono::ParseError> {
        DateTime::parse_from_rfc3339(&self.timestamp)
    }
}

/// Linked Receipt Item Record in PDS
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ReceiptItemRecord {
    pub id: String,
    pub receipt_id: String,
    pub name: String,
    pub variant_ref: Option<String>,
    pub quantity: f64,
    pub unit: String,
    pub unit_price: f64,
    pub total_price: f64,
    pub tags: Tags,
}

impl ReceiptItemRecord {
    pub fn new(
        id: String,
        receipt_id: String,
        name: String,
        quantity: f64,
        unit: String,
        unit_price: f64,
    ) -> Self {
        let total_price = (quantity * unit_price * 100.0).round() / 100.0;
        let mut tags = Tags::new();
        tags.set_tag("name", &name);
        tags.set_tag("quantity", quantity.to_string());
        tags.set_tag("unit", &unit);
        tags.set_tag("price:unit", format!("{:.2}", unit_price));
        tags.set_tag("price:total", format!("{:.2}", total_price));
        tags.set_tag("receipt_id", &receipt_id);

        Self {
            id,
            receipt_id,
            name,
            variant_ref: None,
            quantity,
            unit,
            unit_price,
            total_price,
            tags,
        }
    }

    pub fn set_variant_ref(&mut self, variant_ref: String) {
        self.tags.set_tag("ref", &variant_ref);
        self.variant_ref = Some(variant_ref);
    }
}

/// DAG Divergence Node for conflict resolution
/// Conforms to 06-pds-data-usage.md
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct DagDivergenceNode {
    pub node_id: String,
    pub branch_a_hash: String,
    pub branch_b_hash: String,
    pub common_ancestor_hash: String,
    pub status: String,
    pub resolution_event_id: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use ulid::Ulid;

    #[test]
    fn test_create_receipt_record_valid_rfc3339() {
        let id = Ulid::new().to_string();
        let receipt = ReceiptRecord::new(
            id.clone(),
            "Lidl".to_string(),
            "2026-11-20T00:15:00+01:00".to_string(),
            45.99,
            "PLN".to_string(),
        )
        .unwrap();

        assert_eq!(receipt.store, "Lidl");
        assert_eq!(receipt.total, 45.99);
        assert_eq!(receipt.currency, "PLN");
        assert_eq!(receipt.tags.get_tag("store"), Some("Lidl"));
    }

    #[test]
    fn test_create_receipt_record_invalid_timestamp() {
        let id = Ulid::new().to_string();
        let res = ReceiptRecord::new(
            id,
            "Lidl".to_string(),
            "not-a-timestamp".to_string(),
            10.0,
            "PLN".to_string(),
        );
        assert!(res.is_err());
    }

    #[test]
    fn test_receipt_item_calculation() {
        let id = Ulid::new().to_string();
        let receipt_id = Ulid::new().to_string();
        let item = ReceiptItemRecord::new(
            id,
            receipt_id.clone(),
            "Milk 3.2%".to_string(),
            2.0,
            "l".to_string(),
            3.49,
        );

        assert_eq!(item.total_price, 6.98);
        assert_eq!(item.tags.get_tag("unit"), Some("l"));
    }
}
