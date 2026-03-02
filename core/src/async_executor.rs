use crate::error::CoreError;
use std::future::Future;

pub(crate) fn run_blocking<F, T>(future: F) -> Result<T, CoreError>
where
    F: Future<Output = Result<T, CoreError>>,
{
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .map_err(|e| CoreError::Config(format!("Failed to build async runtime: {e}")))?
        .block_on(future)
}
