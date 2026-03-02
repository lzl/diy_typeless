use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

/// Cooperative cancellation token for long-running operations.
#[derive(Debug, uniffi::Object)]
pub struct CancellationToken {
    cancelled: AtomicBool,
}

impl Default for CancellationToken {
    fn default() -> Self {
        Self {
            cancelled: AtomicBool::new(false),
        }
    }
}

#[uniffi::export]
impl CancellationToken {
    /// Create a new token in non-cancelled state.
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self::default())
    }

    /// Request cancellation.
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::SeqCst);
    }

    /// Check whether cancellation has been requested.
    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::SeqCst)
    }
}
