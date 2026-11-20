use thiserror::Error;

#[derive(Error, Debug)]
pub enum PluginError {
    #[error("Engine error: {0}")]
    Engine(#[from] wasmi::Error),

    #[error("Linker error: {0}")]
    Linker(#[from] wasmi::errors::LinkerError),

    #[error("WASI error: {0}")]
    Wasi(#[from] wasmi_wasi::Error),

    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    #[error("Function not found: {0}")]
    FunctionNotFound(String),

    #[error("Memory access error: {0}")]
    MemoryAccess(String),

    #[error("Plugin returned failure: {0}")]
    PluginExecutionFailed(String),

    #[error("Invalid DTO conversion: {0}")]
    DtoConversion(String),

    #[error("Http callback error: {0}")]
    HttpError(String),
}
