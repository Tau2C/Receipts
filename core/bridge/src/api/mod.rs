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

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgePoint2D {
    pub x: f32,
    pub y: f32,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgeQuad {
    pub top_left: BridgePoint2D,
    pub top_right: BridgePoint2D,
    pub bottom_right: BridgePoint2D,
    pub bottom_left: BridgePoint2D,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgeWarpResult {
    pub rgba_bytes: Vec<u8>,
    pub width: u32,
    pub height: u32,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgePluginManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub retailer: String,
    pub description: String,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgePluginReceiptItem {
    pub name: String,
    pub quantity: f64,
    pub unit: String,
    pub unit_price: f64,
    pub total_price: f64,
}

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgePluginReceipt {
    pub external_id: String,
    pub store: String,
    pub timestamp: String,
    pub total: f64,
    pub currency: String,
    pub items: Vec<BridgePluginReceiptItem>,
}

#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
}

pub fn get_plugin_manifest(wasm_bytes: Vec<u8>) -> Result<BridgePluginManifest, String> {
    let host = plugins::PluginHost::new(&wasm_bytes, plugins::PluginHostConfig::default())
        .map_err(|e| format!("Plugin initialization error: {e}"))?;

    let manifest = host
        .get_manifest()
        .map_err(|e| format!("Failed to read plugin manifest: {e}"))?;

    Ok(BridgePluginManifest {
        id: manifest.id,
        name: manifest.name,
        version: manifest.version,
        retailer: manifest.retailer,
        description: manifest.description,
    })
}

pub fn execute_plugin_fetch_receipts(
    wasm_bytes: Vec<u8>,
    access_token: String,
    since: Option<String>,
    limit: Option<u32>,
) -> Result<Vec<BridgePluginReceipt>, String> {
    let host = plugins::PluginHost::new(&wasm_bytes, plugins::PluginHostConfig::default())
        .map_err(|e| format!("Plugin initialization error: {e}"))?;

    let auth = plugins::PluginAuthPayload {
        access_token,
        refresh_token: None,
        expires_at: None,
        custom_headers: None,
    };

    let req = plugins::FetchReceiptsRequest { since, limit };

    let receipts = host
        .fetch_receipts(&auth, &req)
        .map_err(|e| format!("Failed to fetch receipts from plugin: {e}"))?;

    Ok(receipts
        .into_iter()
        .map(|r| BridgePluginReceipt {
            external_id: r.external_id,
            store: r.store,
            timestamp: r.timestamp,
            total: r.total,
            currency: r.currency,
            items: r
                .items
                .into_iter()
                .map(|item| BridgePluginReceiptItem {
                    name: item.name,
                    quantity: item.quantity,
                    unit: item.unit,
                    unit_price: item.unit_price,
                    total_price: item.total_price,
                })
                .collect(),
        })
        .collect())
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

#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct BridgeCornerDetectionResult {
    pub quad: BridgeQuad,
    pub confidence: f32,
    pub is_ml: bool,
}

pub fn detect_receipt_corners(
    grayscale_bytes: Vec<u8>,
    width: u32,
    height: u32,
) -> Option<BridgeQuad> {
    vision::detect_receipt_corners(&grayscale_bytes, width, height).map(|q| BridgeQuad {
        top_left: BridgePoint2D {
            x: q.top_left.x,
            y: q.top_left.y,
        },
        top_right: BridgePoint2D {
            x: q.top_right.x,
            y: q.top_right.y,
        },
        bottom_right: BridgePoint2D {
            x: q.bottom_right.x,
            y: q.bottom_right.y,
        },
        bottom_left: BridgePoint2D {
            x: q.bottom_left.x,
            y: q.bottom_left.y,
        },
    })
}

pub fn detect_receipt_corners_ml(
    rgba_bytes: Vec<u8>,
    width: u32,
    height: u32,
) -> Option<BridgeCornerDetectionResult> {
    vision::detect_corners_hybrid(&rgba_bytes, width, height).map(|res| {
        BridgeCornerDetectionResult {
            quad: BridgeQuad {
                top_left: BridgePoint2D {
                    x: res.quad.top_left.x,
                    y: res.quad.top_left.y,
                },
                top_right: BridgePoint2D {
                    x: res.quad.top_right.x,
                    y: res.quad.top_right.y,
                },
                bottom_right: BridgePoint2D {
                    x: res.quad.bottom_right.x,
                    y: res.quad.bottom_right.y,
                },
                bottom_left: BridgePoint2D {
                    x: res.quad.bottom_left.x,
                    y: res.quad.bottom_left.y,
                },
            },
            confidence: res.confidence,
            is_ml: res.is_ml,
        }
    })
}

pub fn warp_receipt_perspective(
    rgba_bytes: Vec<u8>,
    width: u32,
    height: u32,
    corners: BridgeQuad,
) -> Result<BridgeWarpResult, String> {
    let quad = vision::Quad::new(
        vision::Point2D::new(corners.top_left.x, corners.top_left.y),
        vision::Point2D::new(corners.top_right.x, corners.top_right.y),
        vision::Point2D::new(corners.bottom_right.x, corners.bottom_right.y),
        vision::Point2D::new(corners.bottom_left.x, corners.bottom_left.y),
    );

    let (out_rgba, out_w, out_h) = vision::warp_perspective(&rgba_bytes, width, height, &quad)
        .map_err(|e| format!("Perspective warp failed: {e}"))?;

    Ok(BridgeWarpResult {
        rgba_bytes: out_rgba,
        width: out_w,
        height: out_h,
    })
}

pub fn encode_receipt_jpeg(
    rgba_bytes: Vec<u8>,
    width: u32,
    height: u32,
    quality: u8,
) -> Result<Vec<u8>, String> {
    vision::encode_jpeg(&rgba_bytes, width, height, quality)
        .map_err(|e| format!("JPEG encoding failed: {e}"))
}
