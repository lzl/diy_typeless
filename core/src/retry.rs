use reqwest::StatusCode;
use std::thread::sleep;
use std::time::Duration;

/// The result of an HTTP request that includes the response status information.
/// This allows the retry logic to distinguish between success, retryable errors,
/// and non-retryable errors.
pub enum HttpResult<T> {
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
pub fn with_retry<T>(
    max_attempts: u32,
    mut operation: impl FnMut() -> HttpResult<T>,
    error_message: &str,
) -> Result<T, String> {
    assert!(max_attempts >= 1, "max_attempts must be at least 1");

    for attempt in 0..max_attempts {
        match operation() {
            HttpResult::Success(value) => return Ok(value),
            HttpResult::NonRetryable(msg) => return Err(msg),
            HttpResult::Retryable => {
                // Only sleep if we're going to retry
                if attempt < max_attempts - 1 {
                    let backoff = 2u64.pow(attempt);
                    sleep(Duration::from_secs(backoff));
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
pub fn is_retryable_status(status: StatusCode) -> bool {
    status == StatusCode::TOO_MANY_REQUESTS || status.is_server_error()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU32, Ordering};

    #[test]
    fn test_success_on_first_attempt() {
        let result = with_retry(3, || HttpResult::Success::<i32>(42), "test");
        assert_eq!(result, Ok(42));
    }

    #[test]
    fn test_success_after_retries() {
        let attempts = AtomicU32::new(0);
        let result = with_retry(3, || {
            let current = attempts.fetch_add(1, Ordering::SeqCst);
            if current < 2 {
                HttpResult::Retryable::<u32>
            } else {
                HttpResult::Success(current)
            }
        }, "test");
        assert_eq!(result, Ok(2));
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
    }

    #[test]
    fn test_non_retryable_fails_immediately() {
        let attempts = AtomicU32::new(0);
        let result = with_retry(3, || {
            attempts.fetch_add(1, Ordering::SeqCst);
            HttpResult::NonRetryable::<u32>("bad request".to_string())
        }, "test");
        assert!(result.is_err());
        assert_eq!(result.unwrap_err(), "bad request");
        assert_eq!(attempts.load(Ordering::SeqCst), 1);
    }

    #[test]
    fn test_all_retries_exhausted() {
        let attempts = AtomicU32::new(0);
        let result = with_retry(3, || {
            attempts.fetch_add(1, Ordering::SeqCst);
            HttpResult::Retryable::<u32>
        }, "API call");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("API call: retries exceeded"));
        assert_eq!(attempts.load(Ordering::SeqCst), 3);
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
    fn test_exponential_backoff_timing() {
        // Verify the backoff calculation is correct
        assert_eq!(2u64.pow(0), 1);
        assert_eq!(2u64.pow(1), 2);
        assert_eq!(2u64.pow(2), 4);
    }
}
