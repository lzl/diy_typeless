use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tokio::sync::watch;

/// Cooperative cancellation token shared between Swift and Rust.
#[derive(uniffi::Object)]
pub struct CoreCancellationToken {
    cancelled: AtomicBool,
    notifier: watch::Sender<bool>,
}

#[uniffi::export]
impl CoreCancellationToken {
    /// Create a fresh token in the active (not-cancelled) state.
    #[uniffi::constructor]
    pub fn new() -> Arc<Self> {
        let (notifier, _receiver) = watch::channel(false);
        Arc::new(Self {
            cancelled: AtomicBool::new(false),
            notifier,
        })
    }

    /// Mark this token as cancelled and wake any blocked waiters.
    pub fn cancel(&self) {
        self.cancelled.store(true, Ordering::SeqCst);
        let _ = self.notifier.send(true);
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

        let mut receiver = self.notifier.subscribe();
        if self.is_cancelled() || *receiver.borrow() {
            return;
        }

        while receiver.changed().await.is_ok() {
            if *receiver.borrow() {
                return;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::CoreCancellationToken;
    use std::time::Duration;

    #[test]
    fn cancelled_should_return_immediately_when_already_cancelled() {
        let token = CoreCancellationToken::new();
        token.cancel();

        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime should build")
            .block_on(async {
                tokio::time::timeout(Duration::from_millis(50), token.cancelled())
                    .await
                    .expect("cancelled() should not block");
            });
    }

    #[test]
    fn cancelled_should_wake_after_cancel_request() {
        let token = CoreCancellationToken::new();
        let wait_token = token.clone();

        tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .expect("runtime should build")
            .block_on(async move {
                let waiter = tokio::spawn(async move {
                    wait_token.cancelled().await;
                });
                tokio::time::sleep(Duration::from_millis(10)).await;
                token.cancel();

                tokio::time::timeout(Duration::from_millis(200), waiter)
                    .await
                    .expect("waiter should be awakened after cancellation")
                    .expect("waiter task should finish");
            });
    }
}
