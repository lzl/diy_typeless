# Task 001: Rust LLM Processor Module

## Goal
Create a generic LLM text processing module in Rust that can be called via FFI from Swift.

## Reference BDD Scenario
- Scenario: LLM API 调用失败 (Error handling)
- Scenario: LLM API 返回空响应
- Scenario: LLM API 请求超时

## Implementation Steps

### 1. Create File
Create `core/src/llm_processor.rs`

### 2. Implementation Requirements
- Implement `process_text_with_llm` function
- Support configurable temperature
- Support optional system instruction
- Implement retry logic with exponential backoff (max 3 attempts)
- Set maxOutputTokens to 4096
- Handle API errors appropriately

### 3. Code Structure
```rust
use crate::config::{GEMINI_API_URL, GEMINI_MODEL};
use crate::error::CoreError;
use crate::http_client::get_http_client;
use reqwest::StatusCode;
use serde::Deserialize;
use std::thread::sleep;
use std::time::Duration;

#[derive(Deserialize)]
struct GeminiResponse {
    candidates: Vec<GeminiCandidate>,
}

#[derive(Deserialize)]
struct GeminiCandidate {
    content: GeminiContent,
}

#[derive(Deserialize)]
struct GeminiContent {
    parts: Vec<GeminiPart>,
}

#[derive(Deserialize)]
struct GeminiPart {
    text: Option<String>,
}

pub fn process_text_with_llm(
    api_key: &str,
    prompt: &str,
    system_instruction: Option<&str>,
    temperature: Option<f32>,
) -> Result<String, CoreError> {
    // Implementation here
}
```

## Verification

### Build Test
```bash
cargo build -p diy_typeless_core --release
```

### Unit Test
Add tests in `core/src/llm_processor.rs`:
```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_prompt_building() {
        // Test that prompt is correctly formatted
    }

    #[test]
    fn test_retry_logic() {
        // Test exponential backoff calculation
    }
}
```

Run tests:
```bash
cargo test -p diy_typeless_core llm_processor
```

## Dependencies
- None (uses existing config, error, http_client modules)

## Commit Message
```
feat(core): add llm_processor module for generic text processing

- Add process_text_with_llm function with retry logic
- Support temperature and system_instruction parameters
- Implement exponential backoff for retries
- Add maxOutputTokens limit (4096)

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
