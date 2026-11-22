use chrono::DateTime;
use pds_types::{ReceiptItemRecord, ReceiptRecord};
use serde::{Deserialize, Serialize};
use ulid::Ulid;

/// Plugin manifest describing the retailer integration.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PluginManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub retailer: String,
    pub description: String,
}

/// Raw line item extracted by a retailer plugin.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PluginReceiptItem {
    pub name: String,
    pub quantity: f64,
    pub unit: String,
    pub unit_price: f64,
    pub total_price: f64,
}

/// Raw receipt data extracted by a retailer plugin.
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PluginReceipt {
    pub external_id: String,
    pub store: String,
    pub timestamp: String,
    pub total: f64,
    pub currency: String,
    pub items: Vec<PluginReceiptItem>,
}

impl PluginReceipt {
    /// Converts a plugin receipt into PDS records (`ReceiptRecord`, `Vec<ReceiptItemRecord>`).
    pub fn to_pds_records(self) -> Result<(ReceiptRecord, Vec<ReceiptItemRecord>), String> {
        // Validate timestamp
        DateTime::parse_from_rfc3339(&self.timestamp)
            .map_err(|e| format!("Invalid RFC 3339 timestamp '{}': {}", self.timestamp, e))?;

        let receipt_id = Ulid::new().to_string();
        let mut receipt = ReceiptRecord::new(
            receipt_id.clone(),
            self.store,
            self.timestamp,
            self.total,
            self.currency,
        )?;

        receipt.tags.set_tag("source", "plugin");
        receipt.tags.set_tag("external_id", &self.external_id);

        let items = self
            .items
            .into_iter()
            .map(|item| {
                let item_id = Ulid::new().to_string();
                let mut record = ReceiptItemRecord::new(
                    item_id,
                    receipt_id.clone(),
                    item.name,
                    item.quantity,
                    item.unit,
                    item.unit_price,
                );
                record.total_price = item.total_price;
                record
            })
            .collect();

        Ok((receipt, items))
    }
}

/// Authentication payload forwarded to a retailer plugin.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PluginAuthPayload {
    pub access_token: String,
    pub refresh_token: Option<String>,
    pub expires_at: Option<String>,
    pub custom_headers: Option<std::collections::HashMap<String, String>>,
}

/// Fetch request parameters passed to a retailer plugin.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FetchReceiptsRequest {
    pub since: Option<String>,
    pub limit: Option<u32>,
}
