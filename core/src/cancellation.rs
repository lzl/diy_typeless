use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tokio::sync::Notify;

/// Cooperative cancellation token shared between Swift and Rust.
#[derive(uniffi::Object)]
pub struct CoreCancellationToken {
    cancelled: AtomicBool,
    notify: Notify,
}

#[uniffi::export]
impl CoreCancellationToken {
    /// Create a fresh token in the active (not-cancelled) state.
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        Arc::new(Self {
            cancelled: AtomicBool::new(false),
            notify: Notify::new(),
        })
    }

    /// Mark this token as cancelled and wake any blocked waiters.
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::SeqCst);
        self.notify.notify_waiters();
    }

    /// Returns true if cancellation has been requested.
    pub fn is_cancelled(&self) -> bool {
        self.cancelled.load(Ordering::SeqCst)
    }
}

impl CoreCancellationToken {
    pub(crate) async fn cancelled(&self) {
        if self.is_cancelled() {
            return;
        }
        self.notify.notified().await;
    }
}
