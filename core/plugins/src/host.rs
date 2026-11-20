use std::sync::Arc;
use wasmi::{
    Caller, Config, Engine, Instance, Linker, Memory, Module, Store, TypedFunc,
};

use crate::dto::{FetchReceiptsRequest, PluginAuthPayload, PluginManifest, PluginReceipt};
use crate::error::PluginError;

pub type HttpCallback =
    Arc<dyn Fn(&str, &str, &[(String, String)], &[u8]) -> Result<(u16, Vec<u8>), String> + Send + Sync>;

#[derive(Default, Clone)]
pub struct PluginHostConfig {
    pub http_callback: Option<HttpCallback>,
}

use wasmi_wasi::{WasiCtx, WasiCtxBuilder};

pub struct HostState {
    pub wasi: WasiCtx,
    pub http_callback: Option<HttpCallback>,
    pub memory: Option<Memory>,
}

pub struct PluginHost {
    engine: Engine,
    module: Module,
    config: PluginHostConfig,
}

impl PluginHost {
    pub fn new(wasm_bytes: &[u8], config: PluginHostConfig) -> Result<Self, PluginError> {
        let mut wasm_config = Config::default();
        wasm_config.wasm_mutable_global(true);

        let engine = Engine::new(&wasm_config);
        let module = Module::new(&engine, wasm_bytes)?;

        Ok(Self {
            engine,
            module,
            config,
        })
    }

    fn init_store_and_instance(
        &self,
    ) -> Result<(Store<HostState>, Instance), PluginError> {
        let wasi = WasiCtxBuilder::new().inherit_stdout().inherit_stderr().build();

        let mut store = Store::new(
            &self.engine,
            HostState {
                wasi,
                http_callback: self.config.http_callback.clone(),
                memory: None,
            },
        );

        let mut linker = Linker::new(&self.engine);
        wasmi_wasi::add_to_linker(&mut linker, |state: &mut HostState| &mut state.wasi)?;

        // Host import: host_http_request
        linker.func_wrap(
            "env",
            "host_http_request",
            |mut caller: Caller<'_, HostState>,
             method_ptr: i32,
             method_len: i32,
             url_ptr: i32,
             url_len: i32,
             body_ptr: i32,
             body_len: i32,
             out_buf_ptr: i32,
             out_buf_len: i32|
             -> i32 {
                // Host callback hook for sandboxed HTTP requests
                let memory = match caller.data().memory {
                    Some(m) => m,
                    None => return -1,
                };

                let http_cb = match &caller.data().http_callback {
                    Some(cb) => cb.clone(),
                    None => return -2,
                };

                let mem_data = memory.data(&caller);

                let method = match std::str::from_utf8(
                    &mem_data[method_ptr as usize..(method_ptr + method_len) as usize],
                ) {
                    Ok(m) => m,
                    Err(_) => return -3,
                };

                let url = match std::str::from_utf8(
                    &mem_data[url_ptr as usize..(url_ptr + url_len) as usize],
                ) {
                    Ok(u) => u,
                    Err(_) => return -3,
                };

                let body = mem_data[body_ptr as usize..(body_ptr + body_len) as usize].to_vec();

                match http_cb(method, url, &[], &body) {
                    Ok((status, resp_data)) => {
                        if resp_data.len() > out_buf_len as usize {
                            return -(resp_data.len() as i32);
                        }
                        if !resp_data.is_empty() {
                            let mem_mut = memory.data_mut(&mut caller);
                            let start = out_buf_ptr as usize;
                            let end = start + resp_data.len();
                            mem_mut[start..end].copy_from_slice(&resp_data);
                        }
                        status as i32
                    }
                    Err(_) => -4,
                }
            },
        )?;

        let instance = linker
            .instantiate_and_start(&mut store, &self.module)?;

        let memory = instance
            .get_memory(&store, "memory")
            .ok_or_else(|| PluginError::MemoryAccess("Export 'memory' not found".to_string()))?;

        store.data_mut().memory = Some(memory);

        Ok((store, instance))
    }

    /// Read plugin manifest metadata.
    pub fn get_manifest(&self) -> Result<PluginManifest, PluginError> {
        let (mut store, instance) = self.init_store_and_instance()?;
        let memory = store.data().memory.unwrap();

        let get_manifest_func: TypedFunc<(), u64> = instance
            .get_typed_func(&store, "get_manifest")
            .map_err(|_| PluginError::FunctionNotFound("get_manifest".to_string()))?;

        let ptr_and_len = get_manifest_func.call(&mut store, ())?;
        let (ptr, len) = unpack_ptr_len(ptr_and_len);

        let data = memory.data(&store);
        let slice = &data[ptr as usize..(ptr + len) as usize];
        let manifest: PluginManifest = serde_json::from_slice(slice)?;

        Ok(manifest)
    }

    /// Fetches receipts using the plugin logic.
    pub fn fetch_receipts(
        &self,
        auth: &PluginAuthPayload,
        req: &FetchReceiptsRequest,
    ) -> Result<Vec<PluginReceipt>, PluginError> {
        let (mut store, instance) = self.init_store_and_instance()?;
        let memory = store.data().memory.unwrap();

        let alloc_func: TypedFunc<i32, i32> = instance
            .get_typed_func(&store, "alloc")
            .map_err(|_| PluginError::FunctionNotFound("alloc".to_string()))?;

        let dealloc_func: TypedFunc<(i32, i32), ()> = instance
            .get_typed_func(&store, "dealloc")
            .map_err(|_| PluginError::FunctionNotFound("dealloc".to_string()))?;

        let fetch_func: TypedFunc<(i32, i32, i32, i32), u64> = instance
            .get_typed_func(&store, "fetch_receipts")
            .map_err(|_| PluginError::FunctionNotFound("fetch_receipts".to_string()))?;

        let auth_json = serde_json::to_vec(auth)?;
        let req_json = serde_json::to_vec(req)?;

        let auth_ptr = alloc_func.call(&mut store, auth_json.len() as i32)?;
        memory.write(&mut store, auth_ptr as usize, &auth_json)
            .map_err(|e| PluginError::MemoryAccess(e.to_string()))?;

        let req_ptr = alloc_func.call(&mut store, req_json.len() as i32)?;
        memory.write(&mut store, req_ptr as usize, &req_json)
            .map_err(|e| PluginError::MemoryAccess(e.to_string()))?;

        let result_packed = fetch_func.call(
            &mut store,
            (auth_ptr, auth_json.len() as i32, req_ptr, req_json.len() as i32),
        )?;

        // Free input buffers
        let _ = dealloc_func.call(&mut store, (auth_ptr, auth_json.len() as i32));
        let _ = dealloc_func.call(&mut store, (req_ptr, req_json.len() as i32));

        let (res_ptr, res_len) = unpack_ptr_len(result_packed);
        let data = memory.data(&store);
        let result_bytes = &data[res_ptr as usize..(res_ptr + res_len) as usize];

        let receipts: Vec<PluginReceipt> = serde_json::from_slice(result_bytes)?;
        let _ = dealloc_func.call(&mut store, (res_ptr, res_len));

        Ok(receipts)
    }
}

fn unpack_ptr_len(packed: u64) -> (i32, i32) {
    let ptr = (packed >> 32) as i32;
    let len = (packed & 0xFFFF_FFFF) as i32;
    (ptr, len)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_unpack_ptr_len() {
        let ptr: i32 = 1024;
        let len: i32 = 42;
        let packed = ((ptr as u64) << 32) | (len as u32 as u64);
        assert_eq!(unpack_ptr_len(packed), (1024, 42));
    }

    #[test]
    fn test_plugin_host_wat_manifest_and_fetch() {
        let manifest_json = "{\"id\":\"mock_lidl\",\"name\":\"Lidl Mock\",\"version\":\"0.1.0\",\"retailer\":\"Lidl\",\"description\":\"Mock plugin\"}";
        let receipt_json = "[{\"external_id\":\"rec_1\",\"store\":\"Lidl\",\"timestamp\":\"2026-11-20T10:00:00+01:00\",\"total\":15.50,\"currency\":\"PLN\",\"items\":[{\"name\":\"Butter\",\"quantity\":1.0,\"unit\":\"pc\",\"unit_price\":7.50,\"total_price\":7.50},{\"name\":\"Bread\",\"quantity\":1.0,\"unit\":\"pc\",\"unit_price\":8.00,\"total_price\":8.00}]}]";

        let manifest_len = manifest_json.len() as u64;
        let receipt_len = receipt_json.len() as u64;

        let manifest_packed = ((100u64) << 32) | manifest_len;
        let receipt_packed = ((500u64) << 32) | receipt_len;

        let manifest_wat_escaped = manifest_json.replace('"', "\\\"");
        let receipt_wat_escaped = receipt_json.replace('"', "\\\"");

        let wat = format!(
            r#"
        (module
            (memory (export "memory") 1)
            (data (i32.const 100) "{manifest_wat_escaped}")
            (data (i32.const 500) "{receipt_wat_escaped}")

            (func (export "alloc") (param i32) (result i32)
                (i32.const 1000)
            )

            (func (export "dealloc") (param i32 i32)
            )

            (func (export "get_manifest") (result i64)
                (i64.const {manifest_packed})
            )

            (func (export "fetch_receipts") (param i32 i32 i32 i32) (result i64)
                (i64.const {receipt_packed})
            )
        )
        "#
        );

        let wasm_bytes = wat::parse_str(wat).expect("WAT parsing failed");
        let host = PluginHost::new(&wasm_bytes, PluginHostConfig::default()).expect("Host creation failed");

        let manifest = host.get_manifest().expect("Manifest failed");
        assert_eq!(manifest.retailer, "Lidl");
        assert_eq!(manifest.id, "mock_lidl");

        let receipts = host
            .fetch_receipts(
                &PluginAuthPayload {
                    access_token: "test_token".to_string(),
                    refresh_token: None,
                    expires_at: None,
                    custom_headers: None,
                },
                &FetchReceiptsRequest {
                    since: None,
                    limit: Some(10),
                },
            )
            .expect("Fetch receipts failed");

        assert_eq!(receipts.len(), 1);
        assert_eq!(receipts[0].store, "Lidl");
        assert_eq!(receipts[0].items.len(), 2);

        let (pds_receipt, pds_items) = receipts[0].clone().to_pds_records().expect("PDS conversion failed");
        assert_eq!(pds_receipt.store, "Lidl");
        assert_eq!(pds_items.len(), 2);
        assert_eq!(pds_items[0].name, "Butter");
    }

    #[test]
    fn test_lidl_mock_compiled_wasm() {
        let wasm_path = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../target/wasm32-wasip1/release/lidl_mock.wasm"
        );
        let wasm_bytes = match std::fs::read(wasm_path) {
            Ok(b) => b,
            Err(_) => return, // Skip test if wasm binary hasn't been built yet
        };

        let host = PluginHost::new(&wasm_bytes, PluginHostConfig::default())
            .expect("Host creation failed for lidl_mock.wasm");

        let manifest = host.get_manifest().expect("Manifest read failed");
        assert_eq!(manifest.retailer, "Lidl");
        assert_eq!(manifest.id, "lidl_plus_mock");

        let receipts = host
            .fetch_receipts(
                &PluginAuthPayload {
                    access_token: "test_token".to_string(),
                    refresh_token: None,
                    expires_at: None,
                    custom_headers: None,
                },
                &FetchReceiptsRequest {
                    since: None,
                    limit: Some(10),
                },
            )
            .expect("Fetch receipts failed");

        assert_eq!(receipts.len(), 2);
        assert_eq!(receipts[0].store, "Lidl");
        assert_eq!(receipts[0].total, 28.47);
        assert_eq!(receipts[0].items.len(), 3);

        let (pds_receipt, pds_items) = receipts[0].clone().to_pds_records().expect("PDS conversion failed");
        assert_eq!(pds_receipt.store, "Lidl");
        assert_eq!(pds_items.len(), 3);
        assert_eq!(pds_items[0].name, "Pilos Mleko UHT 3.2% 1l");
    }
}
