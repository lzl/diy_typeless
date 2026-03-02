use reqwest::StatusCode;
use std::thread::sleep;
use std::time::Duration;

const CANCELLED_MESSAGE: &str = "Operation cancelled";
const RETRY_CANCELLATION_POLL_INTERVAL: Duration = Duration::from_millis(50);

/// The result of an HTTP request that includes the response status information.
/// This allows the retry logic to distinguish between success, retryable errors,
/// and non-retryable errors.
pub(crate) enum HttpResult<T> {
    /// Successful response with the result value
    Success(T),
    /// Retryable error - will retry with exponential backoff
    Retryable,
    /// Non-retryable error - will fail immediately
    NonRetryable(String),
}

/// Executes an HTTP operation with exponential backoff retry logic.
///
/// Retries up to `max_attempts` times with exponential backoff (2^attempt seconds)
/// for retryable conditions (server errors, rate limiting, network errors).
///
/// # Arguments
/// * `max_attempts` - Maximum number of attempts (must be >= 1)
/// * `operation` - Function that performs the HTTP request and returns an HttpResult
/// * `error_message` - Base error message for when all retries are exhausted
///
/// # Returns
/// * `Ok(T)` - The successful result from the operation
/// * `Err(String)` - Error message if all retries are exhausted or a non-retryable error occurs
///
/// # Example
/// ```ignore
/// use diy_typeless_core::retry::{with_retry, HttpResult};
///
/// let result = with_retry(3, || {
///     match make_http_request() {
///         Ok(resp) if resp.status().is_success() => {
///             HttpResult::Success(parse_response(resp))
///         }
///         Ok(resp) if is_retryable_status(resp.status()) => {
///             HttpResult::Retryable
///         }
///         Ok(resp) => {
///             HttpResult::NonRetryable(format!("HTTP error: {}", resp.status()))
///         }
///         Err(_) => HttpResult::Retryable,
///     }
/// }, "API request failed");
/// ```
pub(crate) fn with_retry<T>(
    max_attempts: u32,
    operation: impl FnMut() -> HttpResult<T>,
    error_message: &str,
) -> Result<T, String> {
    with_retry_impl(max_attempts, operation, error_message, |seconds| {
        sleep(Duration::from_secs(seconds));
    })
}

pub(crate) fn with_retry_cancellable<T>(
    max_attempts: u32,
    operation: impl FnMut() -> HttpResult<T>,
    error_message: &str,
    is_cancelled: impl FnMut() -> bool,
) -> Result<T, String> {
    with_retry_cancellable_impl(
        max_attempts,
        operation,
        error_message,
        is_cancelled,
        RETRY_CANCELLATION_POLL_INTERVAL,
        sleep,
    )
}

fn with_retry_impl<T>(
    max_attempts: u32,
    mut operation: impl FnMut() -> HttpResult<T>,
    error_message: &str,
    mut sleep_fn: impl FnMut(u64),
) -> Result<T, String> {
    if max_attempts == 0 {
        return Err("max_attempts must be at least 1".to_string());
    }

    for attempt in 0..max_attempts {
        match operation() {
            HttpResult::Success(value) => return Ok(value),
            HttpResult::NonRetryable(msg) => return Err(msg),
            HttpResult::Retryable => {
                // Only sleep if we're going to retry
                if attempt < max_attempts - 1 {
                    let backoff = 2u64.pow(attempt);
                    sleep_fn(backoff);
                }
            }
        }
    }

    Err(format!("{}: retries exceeded", error_message))
}

fn with_retry_cancellable_impl<T>(
    max_attempts: u32,
    mut operation: impl FnMut() -> HttpResult<T>,
    error_message: &str,
    mut is_cancelled: impl FnMut() -> bool,
    poll_interval: Duration,
    mut sleep_fn: impl FnMut(Duration),
) -> Result<T, String> {
    if max_attempts == 0 {
        return Err("max_attempts must be at least 1".to_string());
    }

    for attempt in 0..max_attempts {
        if is_cancelled() {
            return Err(CANCELLED_MESSAGE.to_string());
        }

        match operation() {
            HttpResult::Success(value) => return Ok(value),
            HttpResult::NonRetryable(msg) => return Err(msg),
            HttpResult::Retryable => {
                if attempt < max_attempts - 1 {
                    let mut remaining = Duration::from_secs(2u64.pow(attempt));

                    while remaining > Duration::ZERO {
                        if is_cancelled() {
                            return Err(CANCELLED_MESSAGE.to_string());
                        }

                        let sleep_for = remaining.min(poll_interval);
                        sleep_fn(sleep_for);
                        remaining -= sleep_for;
                    }
                }
            }
        }
    }

    Err(format!("{}: retries exceeded", error_message))
}

/// Checks if an HTTP status code indicates a retryable error.
///
/// Retryable status codes:
/// - 429 (Too Many Requests) - Rate limiting
/// - 5xx (Server Errors) - Temporary server issues
pub(crate) fn is_retryable_status(status: StatusCode) -> bool {
    status == StatusCode::TOO_MANY_REQUESTS || status.is_server_error()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicBool, AtomicU32, Ordering};
    use std::sync::Arc;
    use std::thread;
    use std::time::Instant;

    #[test]
    fn test_success_on_first_attempt() {
        let result = with_retry(3, || HttpResult::Success::<i32>(42), "test");
        assert_eq!(result, Ok(42));
    }

    #[test]
    fn test_success_after_retries() {
        let attempts = AtomicU32::new(0);
        let mut backoff_calls = Vec::new();
        let result = with_retry_impl(
            3,
            || {
                let current = attempts.fetch_add(1, Ordering::SeqCst);
                if current < 2 {
                    HttpResult::Retryable::<u32>
                } else {
                    HttpResult::Success(current)
                }
            },
            "test",
            |seconds| backoff_calls.push(seconds),
        );
        assert_eq!(result, Ok(2));
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
        assert_eq!(backoff_calls, vec![1, 2]);
    }

    #[test]
    fn test_non_retryable_fails_immediately() {
        let attempts = AtomicU32::new(0);
        let mut sleeper_called = false;
        let result = with_retry_impl(
            3,
            || {
                attempts.fetch_add(1, Ordering::SeqCst);
                HttpResult::NonRetryable::<u32>("bad request".to_string())
            },
            "test",
            |_| sleeper_called = true,
        );
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "bad request");
        assert_eq!(attempts.load(Ordering::SeqCst), 1);
        assert!(!sleeper_called);
    }

    #[test]
    fn test_all_retries_exhausted() {
        let attempts = AtomicU32::new(0);
        let mut backoff_calls = Vec::new();
        let result = with_retry_impl(
            3,
            || {
                attempts.fetch_add(1, Ordering::SeqCst);
                HttpResult::Retryable::<u32>
            },
            "API call",
            |seconds| backoff_calls.push(seconds),
        );
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("API call: retries exceeded"));
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
        assert_eq!(backoff_calls, vec![1, 2]);
    }

    #[test]
    fn test_is_retryable_status() {
        assert!(is_retryable_status(StatusCode::TOO_MANY_REQUESTS));
        assert!(is_retryable_status(StatusCode::INTERNAL_SERVER_ERROR));
        assert!(is_retryable_status(StatusCode::BAD_GATEWAY));
        assert!(is_retryable_status(StatusCode::SERVICE_UNAVAILABLE));
        assert!(is_retryable_status(StatusCode::GATEWAY_TIMEOUT));

        assert!(!is_retryable_status(StatusCode::OK));
        assert!(!is_retryable_status(StatusCode::BAD_REQUEST));
        assert!(!is_retryable_status(StatusCode::UNAUTHORIZED));
        assert!(!is_retryable_status(StatusCode::NOT_FOUND));
    }

    #[test]
    fn test_max_attempts_zero_returns_validation_error() {
        let result = with_retry(0, || HttpResult::Success::<i32>(42), "test");
        assert_eq!(result, Err("max_attempts must be at least 1".to_string()));
    }

    #[test]
    fn test_exponential_backoff_sequence_for_four_attempts() {
        let mut backoff_calls = Vec::new();
        let _ = with_retry_impl(
            4,
            || HttpResult::Retryable::<u32>,
            "API call",
            |seconds| backoff_calls.push(seconds),
        );
        assert_eq!(backoff_calls, vec![1, 2, 4]);
    }

    #[test]
    fn test_no_sleep_after_final_attempt() {
        let mut backoff_calls = Vec::new();
        let _ = with_retry_impl(
            1,
            || HttpResult::Retryable::<u32>,
            "API call",
            |seconds| backoff_calls.push(seconds),
        );
        assert!(backoff_calls.is_empty());
    }

    #[test]
    fn test_success_on_last_attempt_returns_value() {
        let attempts = AtomicU32::new(0);
        let mut backoff_calls = Vec::new();
        let result = with_retry_impl(
            4,
            || {
                let current = attempts.fetch_add(1, Ordering::SeqCst);
                if current == 3 {
                    HttpResult::Success("ok")
                } else {
                    HttpResult::Retryable
                }
            },
            "API call",
            |seconds| backoff_calls.push(seconds),
        );
        assert_eq!(result, Ok("ok"));
        assert_eq!(attempts.load(Ordering::SeqCst), 4);
        assert_eq!(backoff_calls, vec![1, 2, 4]);
    }

    #[test]
    fn test_with_retry_cancellable_aborts_before_first_attempt_when_cancelled() {
        let cancelled = AtomicBool::new(true);
        let attempts = AtomicU32::new(0);
        let result = with_retry_cancellable(
            3,
            || {
                attempts.fetch_add(1, Ordering::SeqCst);
                HttpResult::Success::<u32>(1)
            },
            "API call",
            || cancelled.load(Ordering::SeqCst),
        );

        assert_eq!(result, Err("Operation cancelled".to_string()));
        assert_eq!(attempts.load(Ordering::SeqCst), 0);
    }

    #[test]
    fn test_with_retry_cancellable_aborts_during_backoff() {
        let cancelled = Arc::new(AtomicBool::new(false));
        let cancelled_for_thread = Arc::clone(&cancelled);
        let attempts = AtomicU32::new(0);
        let canceller = thread::spawn(move || {
            thread::sleep(Duration::from_millis(20));
            cancelled_for_thread.store(true, Ordering::SeqCst);
        });

        let start = Instant::now();
        let result = with_retry_cancellable(
            3,
            || {
                attempts.fetch_add(1, Ordering::SeqCst);
                HttpResult::Retryable::<u32>
            },
            "API call",
            || cancelled.load(Ordering::SeqCst),
        );
        let elapsed = start.elapsed();
        canceller
            .join()
            .expect("canceller thread should join cleanly");

        assert_eq!(result, Err("Operation cancelled".to_string()));
        assert_eq!(attempts.load(Ordering::SeqCst), 1);
        assert!(elapsed < Duration::from_millis(500));
    }

    #[test]
    fn test_with_retry_cancellable_impl_honors_custom_sleep_without_delay() {
        let cancelled = AtomicBool::new(false);
        let attempts = AtomicU32::new(0);
        let mut sleeps = 0_u32;

        let result = with_retry_cancellable_impl(
            3,
            || {
                let current = attempts.fetch_add(1, Ordering::SeqCst);
                if current == 1 {
                    HttpResult::Success("ok")
                } else {
                    HttpResult::Retryable
                }
            },
            "API call",
            || cancelled.load(Ordering::SeqCst),
            Duration::from_millis(10),
            |_| {
                sleeps += 1;
            },
        );

        assert_eq!(result, Ok("ok"));
        assert_eq!(attempts.load(Ordering::SeqCst), 2);
        assert!(sleeps > 0);
    }
}
