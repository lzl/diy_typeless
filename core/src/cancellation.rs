use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc::{sync_channel, RecvTimeoutError};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

const CANCELLATION_POLL_INTERVAL: Duration = Duration::from_millis(50);
const WORKER_DISCONNECTED_MESSAGE: &str = "Worker thread disconnected";

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

pub(crate) fn cancellation_requested(cancellation_token: Option<&CancellationToken>) -> bool {
    cancellation_token.is_some_and(CancellationToken::is_cancelled)
}

#[derive(Debug, Eq, PartialEq)]
pub(crate) enum CancellableOperationError {
    Cancelled,
    WorkerDisconnected,
}

pub(crate) fn run_with_cancellation<T>(
    cancellation_token: Option<&CancellationToken>,
    operation: impl FnOnce() -> T + Send + 'static,
) -> Result<T, CancellableOperationError>
where
    T: Send + 'static,
{
    if cancellation_token.is_none() {
        return Ok(operation());
    }

    let (sender, receiver) = sync_channel(1);
    thread::spawn(move || {
        let result = operation();
        let _ = sender.send(result);
    });

    loop {
        if cancellation_requested(cancellation_token) {
            return Err(CancellableOperationError::Cancelled);
        }

        match receiver.recv_timeout(CANCELLATION_POLL_INTERVAL) {
            Ok(result) => return Ok(result),
            Err(RecvTimeoutError::Timeout) => {}
            Err(RecvTimeoutError::Disconnected) => {
                return Err(CancellableOperationError::WorkerDisconnected);
            }
        }
    }
}

pub(crate) fn worker_disconnected_message() -> &'static str {
    WORKER_DISCONNECTED_MESSAGE
}

#[cfg(test)]
mod tests {
    use super::{
        cancellation_requested, run_with_cancellation, CancellableOperationError, CancellationToken,
    };
    use std::sync::Arc;
    use std::thread;
    use std::time::{Duration, Instant};

    #[test]
    fn cancellation_requested_should_be_false_when_token_absent() {
        assert!(!cancellation_requested(None));
    }

    #[test]
    fn cancellation_requested_should_reflect_token_state() {
        let token = CancellationToken::new();
        assert!(!cancellation_requested(Some(token.as_ref())));
        token.cancel();
        assert!(cancellation_requested(Some(token.as_ref())));
    }

    #[test]
    fn run_with_cancellation_should_return_worker_result_when_not_cancelled() {
        let token = CancellationToken::new();
        let result = run_with_cancellation(Some(token.as_ref()), || 42_u32);
        assert_eq!(result, Ok(42));
    }

    #[test]
    fn run_with_cancellation_should_return_cancelled_while_worker_blocks() {
        let token = CancellationToken::new();
        let cancel_token = Arc::clone(&token);
        let canceller = thread::spawn(move || {
            thread::sleep(Duration::from_millis(20));
            cancel_token.cancel();
        });

        let start = Instant::now();
        let result = run_with_cancellation(Some(token.as_ref()), || {
            thread::sleep(Duration::from_secs(1));
            7_u32
        });
        let elapsed = start.elapsed();
        canceller
            .join()
            .expect("canceller thread should join cleanly");

        assert_eq!(result, Err(CancellableOperationError::Cancelled));
        assert!(elapsed < Duration::from_millis(500));
    }
}
