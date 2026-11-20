use tags::{
    format_members_list, parse_members_list, MemberRef, Object, StoreRef, Tags,
};
use ulid::Ulid;

#[test]
fn test_ulid_generation_for_ids() {
    let id1 = Ulid::new().to_string();
    let id2 = Ulid::new().to_string();
    assert_eq!(id1.len(), 26);
    assert_eq!(id2.len(), 26);
    assert_ne!(id1, id2);
}

#[test]
fn test_object_serialization_minified_json() {
    let mut tags = Tags::new();
    tags.set_tag("store", "Supermarket");
    tags.set_tag_to_vec("category", vec!["food".to_string(), "groceries".to_string()]);

    let obj = Object {
        id: Ulid::new().to_string(),
        r#type: "receipt".to_string(),
        tags,
    };

    let json = serde_json::to_string(&obj).unwrap();
    assert!(json.contains(r#""store":"Supermarket""#));
    assert!(json.contains(r#""category":"food;groceries""#));
}

#[test]
fn test_relation_members_prefix_formatting() {
    let obj_id = Ulid::new().to_string();
    let rel_id = Ulid::new().to_string();
    let pic_id = Ulid::new().to_string();

    let members = vec![
        MemberRef::Object(obj_id.clone()),
        MemberRef::Relation(rel_id.clone()),
        MemberRef::Photo(pic_id.clone()),
    ];

    let formatted = format_members_list(&members);
    assert_eq!(formatted, format!("o:{};r:{};p:{}", obj_id, rel_id, pic_id));

    let parsed = parse_members_list(&formatted);
    assert_eq!(parsed, members);
}

#[test]
fn test_store_ref_parsing() {
    let way: StoreRef = "w:12345".parse().unwrap();
    assert_eq!(way, StoreRef::OsmWay("12345".to_string()));
    assert_eq!(way.to_store_string(), "w:12345");

    let url: StoreRef = "u:https://example.com/store".parse().unwrap();
    assert_eq!(url, StoreRef::Url("https://example.com/store".to_string()));
    assert_eq!(url.to_store_string(), "u:https://example.com/store");
}
