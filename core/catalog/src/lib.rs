use serde::{Deserialize, Serialize};
use tags::Tags;

/// Master Item: canonical identity of a product (brand, standard name, category hierarchy)
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MasterItem {
    pub id: String,
    pub name: String,
    pub brand: Option<String>,
    pub category: String,
    pub tags: Tags,
}

impl MasterItem {
    pub fn new(id: String, name: String, brand: Option<String>, category: String) -> Self {
        let mut tags = Tags::new();
        tags.set_tag("name", &name);
        if let Some(ref b) = brand {
            tags.set_tag("brand", b);
        }
        tags.set_tag("category", &category);

        Self {
            id,
            name,
            brand,
            category,
            tags,
        }
    }
}

/// Product Variant: specific packaging, size, or barcode form of a Master Item
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ProductVariant {
    pub id: String,
    pub master_item_id: String,
    pub size: Option<String>,
    pub barcode: Option<String>,
    pub packaging: Option<String>,
    pub tags: Tags,
}

impl ProductVariant {
    pub fn new(id: String, master_item_id: String, size: Option<String>, barcode: Option<String>) -> Self {
        let mut tags = Tags::new();
        tags.set_tag("ref", &master_item_id);
        if let Some(ref s) = size {
            tags.set_tag("size", s);
        }
        if let Some(ref b) = barcode {
            tags.set_tag("barcode", b);
        }

        Self {
            id,
            master_item_id,
            size,
            barcode,
            packaging: None,
            tags,
        }
    }

    /// Resolves effective tags by inheriting from Master Item with priority shadowing
    pub fn resolve_effective_tags(&self, master: &MasterItem) -> Tags {
        let mut resolved = master.tags.clone();
        for (key, val) in &self.tags {
            resolved.set_tag(key, val);
        }
        resolved
    }
}

/// Automated derivation and normalization helper
pub struct CatalogDeriver;

impl CatalogDeriver {
    /// Normalizes raw product text into candidate name and brand
    pub fn extract_brand_and_name(raw_name: &str) -> (Option<String>, String) {
        let known_brands = [
            "Coca-Cola", "Pepsi", "Milka", "Pilos", "Mlekovita", "Łaciate",
            "Kubuś", "Lipton", "Nescafe", "Danone", "Barilla",
        ];

        for brand in known_brands {
            if raw_name.to_lowercase().contains(&brand.to_lowercase()) {
                let cleaned_name = raw_name
                    .replace(brand, "")
                    .replace(&brand.to_lowercase(), "")
                    .replace(&brand.to_uppercase(), "")
                    .trim()
                    .to_string();
                return (Some(brand.to_string()), cleaned_name);
            }
        }

        (None, raw_name.trim().to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ulid::Ulid;

    #[test]
    fn test_master_item_and_variant_tag_shadowing() {
        let master_id = Ulid::new().to_string();
        let master = MasterItem::new(
            master_id.clone(),
            "Cola Original".to_string(),
            Some("Coca-Cola".to_string()),
            "drink:fizzy:cola".to_string(),
        );

        let variant_id = Ulid::new().to_string();
        let mut variant = ProductVariant::new(
            variant_id,
            master_id,
            Some("1.5 L".to_string()),
            Some("5449000000996".to_string()),
        );
        variant.tags.set_tag("category", "drink:fizzy:special");

        let effective = variant.resolve_effective_tags(&master);
        // Variant category shadows Master category
        assert_eq!(effective.get_tag("category"), Some("drink:fizzy:special"));
        // Inherits brand from Master
        assert_eq!(effective.get_tag("brand"), Some("Coca-Cola"));
        // Has variant size
        assert_eq!(effective.get_tag("size"), Some("1.5 L"));
    }

    #[test]
    fn test_catalog_deriver_brand_extraction() {
        let (brand, name) = CatalogDeriver::extract_brand_and_name("Coca-Cola Zero Cukru 1.5L");
        assert_eq!(brand, Some("Coca-Cola".to_string()));
        assert!(name.contains("Zero Cukru"));
    }
}
