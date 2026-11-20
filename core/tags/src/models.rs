use std::fmt;
use std::str::FromStr;
use serde::{Deserialize, Serialize};
use crate::tags::Tags;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum MemberRef {
    Relation(String),
    Object(String),
    Photo(String),
}

impl MemberRef {
    pub fn to_member_string(&self) -> String {
        match self {
            MemberRef::Relation(id) => format!("r:{}", id),
            MemberRef::Object(id) => format!("o:{}", id),
            MemberRef::Photo(id) => format!("p:{}", id),
        }
    }
}

impl fmt::Display for MemberRef {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_member_string())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum ParseMemberRefError {
    #[error("Invalid member ref prefix, must be r:, o:, or p:")]
    InvalidPrefix,
    #[error("Empty member id")]
    EmptyId,
}

impl FromStr for MemberRef {
    type Err = ParseMemberRefError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        let mut parts = s.splitn(2, ':');
        let prefix = parts.next().ok_or(ParseMemberRefError::InvalidPrefix)?;
        let id = parts.next().ok_or(ParseMemberRefError::EmptyId)?;
        if id.is_empty() {
            return Err(ParseMemberRefError::EmptyId);
        }
        match prefix {
            "r" => Ok(MemberRef::Relation(id.to_string())),
            "o" => Ok(MemberRef::Object(id.to_string())),
            "p" => Ok(MemberRef::Photo(id.to_string())),
            _ => Err(ParseMemberRefError::InvalidPrefix),
        }
    }
}

pub fn parse_members_list(s: &str) -> Vec<MemberRef> {
    s.split(';')
        .filter(|item| !item.is_empty())
        .filter_map(|item| item.parse().ok())
        .collect()
}

pub fn format_members_list(members: &[MemberRef]) -> String {
    members
        .iter()
        .map(|m| m.to_member_string())
        .collect::<Vec<_>>()
        .join(";")
}

/// Store reference representation:
/// - `w:{way}`: OSM Way ID
/// - `n:{node}`: OSM Node ID
/// - `r:{relation}`: OSM Relation ID
/// - `u:{url}`: URL
/// - `{store_object_id}`: Custom store object ID in database
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum StoreRef {
    OsmWay(String),
    OsmNode(String),
    OsmRelation(String),
    Url(String),
    StoreObject(String),
}

impl StoreRef {
    pub fn to_store_string(&self) -> String {
        match self {
            StoreRef::OsmWay(id) => format!("w:{}", id),
            StoreRef::OsmNode(id) => format!("n:{}", id),
            StoreRef::OsmRelation(id) => format!("r:{}", id),
            StoreRef::Url(url) => format!("u:{}", url),
            StoreRef::StoreObject(id) => id.clone(),
        }
    }
}

impl fmt::Display for StoreRef {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.to_store_string())
    }
}

impl FromStr for StoreRef {
    type Err = std::convert::Infallible;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        if let Some(way_id) = s.strip_prefix("w:") {
            Ok(StoreRef::OsmWay(way_id.to_string()))
        } else if let Some(node_id) = s.strip_prefix("n:") {
            Ok(StoreRef::OsmNode(node_id.to_string()))
        } else if let Some(rel_id) = s.strip_prefix("r:") {
            Ok(StoreRef::OsmRelation(rel_id.to_string()))
        } else if let Some(url) = s.strip_prefix("u:") {
            Ok(StoreRef::Url(url.to_string()))
        } else {
            Ok(StoreRef::StoreObject(s.to_string()))
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Object {
    pub id: String,
    pub r#type: String,
    pub tags: Tags,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Relation {
    pub id: String,
    pub r#type: String,
    pub tags: Tags,
    pub members: Vec<MemberRef>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Photo {
    pub id: String,
    pub hash: String,
    pub format: String,
    pub size: i64,
    pub path: String,
    pub is_local: bool,
}
