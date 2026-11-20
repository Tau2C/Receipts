use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

/// Standard tag key suggestions for autocompletion
pub const STANDARD_KEYS: &[&str] = &[
    "store",
    "category",
    "total",
    "payment",
    "currency",
    "date",
    "tax",
    "receipt_id",
    "brand",
    "barcode",
    "size",
    "unit",
    "price:unit",
    "price:total",
    "discount",
    "ref",
];

#[derive(Debug, Serialize, Deserialize, Clone, PartialEq, Eq)]
pub struct Tags(pub BTreeMap<String, String>);

impl Default for Tags {
    fn default() -> Self {
        Self::new()
    }
}

impl Tags {
    pub fn new() -> Self {
        Self(BTreeMap::new())
    }

    pub fn len(&self) -> usize {
        self.0.len()
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    pub fn contains(&self, tag: &str) -> bool {
        self.0.contains_key(tag)
    }

    pub fn set_tag<S: Into<String>>(&mut self, tag: &str, value: S) -> Option<String> {
        self.0.insert(tag.to_string(), value.into())
    }

    pub fn remove_tag(&mut self, tag: &str) -> Option<String> {
        self.0.remove(tag)
    }

    pub fn set_tag_to_vec(&mut self, tag: &str, value: Vec<String>) -> Option<String> {
        self.set_tag_to_vec_separated_with(tag, value, ";")
    }

    pub fn set_tag_to_vec_separated_with(
        &mut self,
        tag: &str,
        value: Vec<String>,
        separator: &str,
    ) -> Option<String> {
        let prev = self.0.remove(tag);
        self.0.insert(tag.to_string(), value.join(separator));
        prev
    }

    pub fn get_tag(&self, tag: &str) -> Option<&str> {
        self.0.get(tag).map(|v| v.as_str())
    }

    pub fn get_tag_vec(&self, tag: &str) -> Option<Vec<&str>> {
        self.get_tag_vec_separated_with(tag, ";")
    }

    pub fn get_tag_vec_separated_with(&self, tag: &str, separator: &str) -> Option<Vec<&str>> {
        self.0
            .get(tag)
            .map(|s| s.split(separator).filter(|v| !v.is_empty()).collect())
    }

    pub fn to_json_minified(&self) -> String {
        serde_json::to_string(&self.0).unwrap_or_else(|_| "{}".to_string())
    }

    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        let map: BTreeMap<String, String> = serde_json::from_str(json)?;
        Ok(Self(map))
    }

    pub fn autocompletions(query: &str) -> Vec<&'static str> {
        STANDARD_KEYS
            .iter()
            .copied()
            .filter(|key| key.starts_with(query))
            .collect()
    }
}

impl<'a> IntoIterator for &'a Tags {
    type Item = (&'a String, &'a String);
    type IntoIter = std::collections::btree_map::Iter<'a, String, String>;

    fn into_iter(self) -> Self::IntoIter {
        self.0.iter()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tags_operations() {
        let mut tags = Tags::new();
        tags.set_tag("store", "Target");
        tags.set_tag_to_vec(
            "category",
            vec!["food".to_string(), "groceries".to_string()],
        );

        assert_eq!(tags.get_tag("store"), Some("Target"));
        assert_eq!(
            tags.get_tag_vec("category"),
            Some(vec!["food", "groceries"])
        );
        assert_eq!(
            tags.to_json_minified(),
            r#"{"category":"food;groceries","store":"Target"}"#
        );
    }
}
