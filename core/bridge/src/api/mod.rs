use analytics::{
    CategorySpendAggregator, PriceObservation, PriceTrend, StandardUnit, UnitPriceNormalizer,
};
use catalog::CatalogDeriver;
use pds_types::ReceiptItemRecord;
use tags::Tags;

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgeReceiptItem {
    pub id: String,
    pub receipt_id: String,
    pub name: String,
    pub quantity: f64,
    pub unit: String,
    pub unit_price: f64,
    pub total_price: f64,
    pub tags_json: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgeNormalizedItem {
    pub id: String,
    pub receipt_id: String,
    pub name: String,
    pub brand: Option<String>,
    pub cleaned_name: String,
    pub quantity: f64,
    pub unit: String,
    pub unit_price: f64,
    pub total_price: f64,
    pub tags_json: String,
    pub unit_price_normalized: Option<f64>,
    pub standard_unit: Option<String>,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgeCategorySpend {
    pub category: String,
    pub total_amount: f64,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgePricePoint {
    pub date: String,
    pub store: String,
    pub unit_price: f64,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgePriceTrendResult {
    pub variant_ref: String,
    pub min_price: f64,
    pub max_price: f64,
    pub avg_price: f64,
    pub latest_price: f64,
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn normalize_receipt_items(items: Vec<BridgeReceiptItem>) -> Vec<BridgeNormalizedItem> {
    items
        .into_iter()
        .map(|item| {
            let (brand, cleaned_name) = CatalogDeriver::extract_brand_and_name(&item.name);
            let normalized =
                UnitPriceNormalizer::normalize(item.quantity, &item.unit, item.total_price);

            let (norm_price, norm_unit) = match normalized {
                Some((price, unit)) => {
                    let u_str = match unit {
                        StandardUnit::Kilogram => "kg",
                        StandardUnit::Liter => "l",
                        StandardUnit::Piece => "pcs",
                    };
                    (
                        Some((price * 100.0).round() / 100.0),
                        Some(u_str.to_string()),
                    )
                }
                None => (None, None),
            };

            BridgeNormalizedItem {
                id: item.id,
                receipt_id: item.receipt_id,
                name: item.name,
                brand,
                cleaned_name,
                quantity: item.quantity,
                unit: item.unit,
                unit_price: item.unit_price,
                total_price: item.total_price,
                tags_json: item.tags_json,
                unit_price_normalized: norm_price,
                standard_unit: norm_unit,
            }
        })
        .collect()
}

pub fn calculate_category_spend(items: Vec<BridgeReceiptItem>) -> Vec<BridgeCategorySpend> {
    let mut aggregator = CategorySpendAggregator::new();
    for item in items {
        let tags = Tags::from_json(&item.tags_json).unwrap_or_default();
        let record = ReceiptItemRecord {
            id: item.id,
            receipt_id: item.receipt_id,
            name: item.name,
            variant_ref: None,
            quantity: item.quantity,
            unit: item.unit,
            unit_price: item.unit_price,
            total_price: item.total_price,
            tags,
        };
        aggregator.add_item(&record, None);
    }

    aggregator
        .spend_by_category
        .into_iter()
        .map(|(category, total_amount)| BridgeCategorySpend {
            category,
            total_amount,
        })
        .collect()
}

pub fn calculate_price_trend(
    variant_ref: String,
    points: Vec<BridgePricePoint>,
) -> Option<BridgePriceTrendResult> {
    let observations = points
        .into_iter()
        .map(|p| PriceObservation {
            date: p.date,
            store: p.store,
            unit_price: p.unit_price,
            normalized_price: None,
            standard_unit: None,
        })
        .collect();

    PriceTrend::compute(variant_ref, observations).map(|trend| BridgePriceTrendResult {
        variant_ref: trend.variant_ref,
        min_price: trend.min_price,
        max_price: trend.max_price,
        avg_price: trend.avg_price,
        latest_price: trend.latest_price,
    })
}

pub fn parse_tag_json(json: String) -> Vec<String> {
    Tags::from_json(&json)
        .map(|tags| tags.into_iter().map(|(k, v)| format!("{k}={v}")).collect())
        .unwrap_or_default()
}
