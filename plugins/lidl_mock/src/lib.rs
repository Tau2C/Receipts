use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct PluginManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub retailer: String,
    pub description: String,
}

#[derive(Serialize, Deserialize)]
pub struct PluginReceiptItem {
    pub name: String,
    pub quantity: f64,
    pub unit: String,
    pub unit_price: f64,
    pub total_price: f64,
}

#[derive(Serialize, Deserialize)]
pub struct PluginReceipt {
    pub external_id: String,
    pub store: String,
    pub timestamp: String,
    pub total: f64,
    pub currency: String,
    pub items: Vec<PluginReceiptItem>,
}

#[derive(Serialize, Deserialize)]
pub struct PluginAuthPayload {
    pub access_token: String,
}

#[derive(Serialize, Deserialize)]
pub struct FetchReceiptsRequest {
    pub since: Option<String>,
    pub limit: Option<u32>,
}

#[no_mangle]
pub extern "C" fn alloc(size: i32) -> *mut u8 {
    let mut buf = Vec::with_capacity(size as usize);
    let ptr = buf.as_mut_ptr();
    std::mem::forget(buf);
    ptr
}

/// Deallocates memory buffer previously allocated with `alloc`.
///
/// # Safety
/// Caller must ensure `ptr` points to valid buffer allocated with capacity `size`.
#[no_mangle]
pub unsafe extern "C" fn dealloc(ptr: *mut u8, size: i32) {
    if !ptr.is_null() {
        drop(Vec::from_raw_parts(ptr, size as usize, size as usize));
    }
}

fn pack_ptr_len(slice: &[u8]) -> u64 {
    let ptr = slice.as_ptr() as usize as u64;
    let len = slice.len() as u64;
    (ptr << 32) | (len & 0xFFFF_FFFF)
}

#[no_mangle]
pub extern "C" fn get_manifest() -> u64 {
    let manifest = PluginManifest {
        id: "lidl_plus_mock".to_string(),
        name: "Lidl Plus Mock Plugin".to_string(),
        version: "0.1.0".to_string(),
        retailer: "Lidl".to_string(),
        description: "Mock retailer plugin generating sample Lidl Plus receipts".to_string(),
    };

    let json = serde_json::to_vec(&manifest).unwrap_or_default();
    let boxed = json.into_boxed_slice();
    let packed = pack_ptr_len(&boxed);
    std::mem::forget(boxed);
    packed
}

/// Fetches sample receipts for mock Lidl Plus integration.
///
/// # Safety
/// Caller must ensure `auth_ptr` and `req_ptr` point to readable memory buffers of respective lengths.
#[no_mangle]
pub unsafe extern "C" fn fetch_receipts(
    auth_ptr: *const u8,
    auth_len: i32,
    _req_ptr: *const u8,
    _req_len: i32,
) -> u64 {
    let _auth_slice = std::slice::from_raw_parts(auth_ptr, auth_len as usize);

    let receipts = vec![
        PluginReceipt {
            external_id: "lidl-rec-2026-001".to_string(),
            store: "Lidl".to_string(),
            timestamp: "2026-11-20T09:30:00+01:00".to_string(),
            total: 28.47,
            currency: "PLN".to_string(),
            items: vec![
                PluginReceiptItem {
                    name: "Pilos Mleko UHT 3.2% 1l".to_string(),
                    quantity: 2.0,
                    unit: "l".to_string(),
                    unit_price: 3.49,
                    total_price: 6.98,
                },
                PluginReceiptItem {
                    name: "Chleb pszenno-żytni 500g".to_string(),
                    quantity: 1.0,
                    unit: "pcs".to_string(),
                    unit_price: 4.29,
                    total_price: 4.29,
                },
                PluginReceiptItem {
                    name: "Pikok Szynka z piersi kurczaka 100g".to_string(),
                    quantity: 3.0,
                    unit: "pcs".to_string(),
                    unit_price: 5.40,
                    total_price: 16.20,
                },
            ],
        },
        PluginReceipt {
            external_id: "lidl-rec-2026-002".to_string(),
            store: "Lidl".to_string(),
            timestamp: "2026-11-19T17:15:00+01:00".to_string(),
            total: 12.50,
            currency: "PLN".to_string(),
            items: vec![
                PluginReceiptItem {
                    name: "Banany bio na wagę".to_string(),
                    quantity: 1.5,
                    unit: "kg".to_string(),
                    unit_price: 6.99,
                    total_price: 10.49,
                },
                PluginReceiptItem {
                    name: "Woda źródlana Saguaro 1.5l".to_string(),
                    quantity: 1.0,
                    unit: "pcs".to_string(),
                    unit_price: 2.01,
                    total_price: 2.01,
                },
            ],
        },
    ];

    let json = serde_json::to_vec(&receipts).unwrap_or_default();
    let boxed = json.into_boxed_slice();
    let packed = pack_ptr_len(&boxed);
    std::mem::forget(boxed);
    packed
}
