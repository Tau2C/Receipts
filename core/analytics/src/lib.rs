use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use pds_types::ReceiptItemRecord;

/// Standard base units for price normalization
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum StandardUnit {
    Kilogram,
    Liter,
    Piece,
}

pub struct UnitPriceNormalizer;

impl UnitPriceNormalizer {
    /// Normalizes quantity and unit price into standard price per kg, liter, or piece
    pub fn normalize(quantity: f64, unit: &str, total_price: f64) -> Option<(f64, StandardUnit)> {
        if quantity <= 0.0 || total_price <= 0.0 {
            return None;
        }

        let u = unit.trim().to_lowercase();
        match u.as_str() {
            "kg" | "kilogram" | "kilograms" => Some((total_price / quantity, StandardUnit::Kilogram)),
            "g" | "gram" | "grams" => {
                let kg = quantity / 1000.0;
                Some((total_price / kg, StandardUnit::Kilogram))
            }
            "l" | "liter" | "liters" | "litre" | "litres" => {
                Some((total_price / quantity, StandardUnit::Liter))
            }
            "ml" | "milliliter" | "milliliters" => {
                let l = quantity / 1000.0;
                Some((total_price / l, StandardUnit::Liter))
            }
            "pcs" | "piece" | "pieces" | "szt" | "sztuka" | "sztuki" => {
                Some((total_price / quantity, StandardUnit::Piece))
            }
            _ => None,
        }
    }
}

/// Price observation point
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PriceObservation {
    pub date: String,
    pub store: String,
    pub unit_price: f64,
    pub normalized_price: Option<f64>,
    pub standard_unit: Option<StandardUnit>,
}

/// Price trend summary for a product variant
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PriceTrend {
    pub variant_ref: String,
    pub observations: Vec<PriceObservation>,
    pub min_price: f64,
    pub max_price: f64,
    pub avg_price: f64,
    pub latest_price: f64,
}

impl PriceTrend {
    pub fn compute(variant_ref: String, observations: Vec<PriceObservation>) -> Option<Self> {
        if observations.is_empty() {
            return None;
        }

        let mut min_price = f64::MAX;
        let mut max_price = f64::MIN;
        let mut sum_price = 0.0;
        let latest_price = observations.last().map(|o| o.unit_price).unwrap_or(0.0);

        for obs in &observations {
            if obs.unit_price < min_price {
                min_price = obs.unit_price;
            }
            if obs.unit_price > max_price {
                max_price = obs.unit_price;
            }
            sum_price += obs.unit_price;
        }

        let avg_price = sum_price / observations.len() as f64;

        Some(Self {
            variant_ref,
            observations,
            min_price: (min_price * 100.0).round() / 100.0,
            max_price: (max_price * 100.0).round() / 100.0,
            avg_price: (avg_price * 100.0).round() / 100.0,
            latest_price,
        })
    }
}

/// Aggregates category spending
#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct CategorySpendAggregator {
    pub spend_by_category: BTreeMap<String, f64>,
}

impl CategorySpendAggregator {
    pub fn new() -> Self {
        Self {
            spend_by_category: BTreeMap::new(),
        }
    }

    pub fn add_item(&mut self, item: &ReceiptItemRecord, category: Option<&str>) {
        let cat = category
            .or_else(|| item.tags.get_tag("category"))
            .unwrap_or("uncategorized");

        let current = self.spend_by_category.entry(cat.to_string()).or_insert(0.0);
        *current = ((*current + item.total_price) * 100.0).round() / 100.0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unit_price_normalization_grams_to_kg() {
        // 500g for 7.50 PLN -> 15.00 PLN/kg
        let (norm_price, unit) = UnitPriceNormalizer::normalize(500.0, "g", 7.50).unwrap();
        assert_eq!(unit, StandardUnit::Kilogram);
        assert!((norm_price - 15.0).abs() < 0.001);
    }

    #[test]
    fn test_unit_price_normalization_ml_to_liter() {
        // 250ml for 3.00 PLN -> 12.00 PLN/l
        let (norm_price, unit) = UnitPriceNormalizer::normalize(250.0, "ml", 3.00).unwrap();
        assert_eq!(unit, StandardUnit::Liter);
        assert!((norm_price - 12.0).abs() < 0.001);
    }

    #[test]
    fn test_price_trend_calculation() {
        let obs = vec![
            PriceObservation {
                date: "2026-11-01T10:00:00+01:00".to_string(),
                store: "Lidl".to_string(),
                unit_price: 4.50,
                normalized_price: Some(4.50),
                standard_unit: Some(StandardUnit::Liter),
            },
            PriceObservation {
                date: "2026-11-10T12:00:00+01:00".to_string(),
                store: "Biedronka".to_string(),
                unit_price: 4.20,
                normalized_price: Some(4.20),
                standard_unit: Some(StandardUnit::Liter),
            },
        ];

        let trend = PriceTrend::compute("variant_1".to_string(), obs).unwrap();
        assert_eq!(trend.min_price, 4.20);
        assert_eq!(trend.max_price, 4.50);
        assert_eq!(trend.avg_price, 4.35);
        assert_eq!(trend.latest_price, 4.20);
    }

    #[test]
    fn test_category_spend_aggregator() {
        let mut agg = CategorySpendAggregator::new();
        let mut item1 = ReceiptItemRecord::new("1".into(), "r1".into(), "Cola".into(), 1.0, "pcs".into(), 5.00);
        item1.tags.set_tag("category", "drink:fizzy");
        agg.add_item(&item1, None);

        let mut item2 = ReceiptItemRecord::new("2".into(), "r1".into(), "Pepsi".into(), 1.0, "pcs".into(), 4.50);
        item2.tags.set_tag("category", "drink:fizzy");
        agg.add_item(&item2, None);

        assert_eq!(agg.spend_by_category.get("drink:fizzy"), Some(&9.50));
    }
}
