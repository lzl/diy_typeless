//! Utility functions for CLI

use anyhow::{Context, Result};
use std::io::{self, Read};
use std::path::PathBuf;
use std::time::Duration;

/// Generate a timestamp string for file naming
pub fn timestamp() -> String {
    chrono::Local::now().format("%Y%m%d_%H%M%S").to_string()
}

/// Format a duration as a human-readable string
pub fn format_duration(duration: Duration) -> String {
    format!("{:.2}s", duration.as_secs_f64())
}

/// Mask a secret string, showing only first and last 4 characters
pub fn mask_secret(secret: &str) -> String {
    if secret.len() <= 8 {
        return "***".to_string();
    }
    format!("{}...{}", &secret[..4], &secret[secret.len() - 4..])
}

/// Find a binary in the system PATH
pub fn find_binary(binary: &str) -> Option<PathBuf> {
    let path_var = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path_var) {
        let candidate = dir.join(binary);
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}

/// Resolve the output directory, defaulting to ~/diy_typeless_recordings
pub fn resolve_output_dir(output_dir: Option<PathBuf>) -> Result<PathBuf> {
    if let Some(dir) = output_dir {
        return Ok(dir);
    }
    let home = dirs::home_dir().context("Failed to resolve home directory")?;
    Ok(home.join("diy_typeless_recordings"))
}

/// Resolve Groq API key from argument or environment
pub fn resolve_groq_key(provided: Option<String>) -> Result<String> {
    if let Some(key) = provided {
        return Ok(key);
    }
    std::env::var("GROQ_API_KEY").context("GROQ_API_KEY not set")
}

/// Resolve Gemini API key from argument or environment
pub fn resolve_gemini_key(provided: Option<String>) -> Result<String> {
    if let Some(key) = provided {
        return Ok(key);
    }
    std::env::var("GEMINI_API_KEY").context("GEMINI_API_KEY not set")
}

/// Wait for user to press Enter
pub fn wait_for_enter() -> Result<()> {
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(())
}

/// Read all text from stdin
pub fn read_stdin() -> Result<String> {
    let mut buffer = String::new();
    io::stdin().read_to_string(&mut buffer)?;
    Ok(buffer.trim().to_string())
}

/// Copy text to clipboard (macOS only)
pub fn copy_to_clipboard(text: &str) {
    if cfg!(target_os = "macos") {
        let _ = std::process::Command::new("pbcopy")
            .stdin(std::process::Stdio::piped())
            .spawn()
            .and_then(|mut child| {
                use std::io::Write;
                if let Some(stdin) = child.stdin.as_mut() {
                    stdin.write_all(text.as_bytes())?;
                }
                child.wait()?;
                Ok(())
            });
    }
}

/// Print status of an environment variable (set/masked or not set)
pub fn print_key_status(key_name: &str) {
    match std::env::var(key_name) {
        Ok(value) if !value.trim().is_empty() => {
            println!("- {key_name}: set ({})", mask_secret(&value));
        }
        _ => println!("- {key_name}: not set"),
    }
}

/// Print status of a binary in PATH
pub fn print_binary_status(binary: &str) {
    match find_binary(binary) {
        Some(path) => println!("- {binary}: {}", path.display()),
        None => println!("- {binary}: not found in PATH"),
    }
}
