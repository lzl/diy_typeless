//! Utility functions for CLI

use anyhow::{Context, Result};
use secrecy::SecretString;
use std::io::{self, Read};
use std::path::{Path, PathBuf};
use std::time::Duration;

/// Generate a timestamp string for file naming
pub(crate) fn timestamp() -> String {
    chrono::Local::now().format("%Y%m%d_%H%M%S").to_string()
}

/// Format a duration as a human-readable string
pub(crate) fn format_duration(duration: Duration) -> String {
    format!("{:.2}s", duration.as_secs_f64())
}

/// Mask a secret string, showing only first and last 4 characters
pub(crate) fn mask_secret(secret: &str) -> String {
    if secret.len() <= 8 {
        return "***".to_string();
    }
    format!("{}...{}", &secret[..4], &secret[secret.len() - 4..])
}

/// Find a binary in the system PATH
pub(crate) fn find_binary(binary: &str) -> Option<PathBuf> {
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
pub(crate) fn resolve_output_dir(output_dir: Option<PathBuf>) -> Result<PathBuf> {
    if let Some(dir) = output_dir {
        return Ok(dir);
    }
    let home = dirs::home_dir().context("Failed to resolve home directory")?;
    Ok(home.join("diy_typeless_recordings"))
}

/// Resolve Groq API key from argument or environment
pub(crate) fn resolve_groq_key(provided: Option<String>) -> Result<SecretString> {
    let key = if let Some(key) = provided {
        key
    } else {
        std::env::var("GROQ_API_KEY").context("GROQ_API_KEY not set")?
    };
    Ok(SecretString::from(key))
}

/// Resolve Gemini API key from argument or environment
pub(crate) fn resolve_gemini_key(provided: Option<String>) -> Result<SecretString> {
    let key = if let Some(key) = provided {
        key
    } else {
        std::env::var("GEMINI_API_KEY").context("GEMINI_API_KEY not set")?
    };
    Ok(SecretString::from(key))
}

/// Wait for user to press Enter
pub(crate) fn wait_for_enter() -> Result<()> {
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(())
}

/// Read all text from stdin
pub(crate) fn read_stdin() -> Result<String> {
    let mut buffer = String::new();
    io::stdin().read_to_string(&mut buffer)?;
    Ok(buffer.trim().to_string())
}

/// Validate that bytes start with the FLAC stream marker.
pub(crate) fn ensure_flac_bytes(bytes: &[u8], path: &Path) -> Result<()> {
    const FLAC_MAGIC: &[u8; 4] = b"fLaC";
    if bytes.len() < FLAC_MAGIC.len() || &bytes[..FLAC_MAGIC.len()] != FLAC_MAGIC {
        anyhow::bail!(
            "Input file is not FLAC: {} (expected 'fLaC' header)",
            path.display()
        );
    }
    Ok(())
}

/// Copy text to clipboard (macOS only)
pub(crate) fn copy_to_clipboard(text: &str) {
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
pub(crate) fn print_key_status(key_name: &str) {
    match std::env::var(key_name) {
        Ok(value) if !value.trim().is_empty() => {
            println!("- {key_name}: set ({})", mask_secret(&value));
        }
        _ => println!("- {key_name}: not set"),
    }
}

/// Print status of a binary in PATH
pub(crate) fn print_binary_status(binary: &str) {
    match find_binary(binary) {
        Some(path) => println!("- {binary}: {}", path.display()),
        None => println!("- {binary}: not found in PATH"),
    }
}

#[cfg(test)]
mod tests {
    use super::{ensure_flac_bytes, format_duration, mask_secret, resolve_output_dir};
    use std::path::{Path, PathBuf};
    use std::time::Duration;

    #[test]
    fn ensure_flac_bytes_accepts_valid_flac_header() {
        let bytes = b"fLaC\x00\x00\x00\x22";
        let result = ensure_flac_bytes(bytes, Path::new("audio.flac"));
        assert!(result.is_ok());
    }

    #[test]
    fn ensure_flac_bytes_rejects_invalid_header() {
        let bytes = b"RIFF";
        let result = ensure_flac_bytes(bytes, Path::new("audio.bin"));
        assert!(result.is_err());
        assert_eq!(
            result.expect_err("must be error").to_string(),
            "Input file is not FLAC: audio.bin (expected 'fLaC' header)"
        );
    }

    #[test]
    fn ensure_flac_bytes_rejects_too_short_input() {
        let bytes = b"fL";
        let result = ensure_flac_bytes(bytes, Path::new("audio.flac"));
        assert!(result.is_err());
    }

    #[test]
    fn mask_secret_should_hide_short_values() {
        assert_eq!(mask_secret("12345678"), "***");
        assert_eq!(mask_secret("123"), "***");
    }

    #[test]
    fn mask_secret_should_keep_prefix_and_suffix_for_long_values() {
        assert_eq!(mask_secret("abcdefghijk"), "abcd...hijk");
    }

    #[test]
    fn format_duration_should_show_two_decimal_places() {
        let value = format_duration(Duration::from_millis(1234));
        assert_eq!(value, "1.23s");
    }

    #[test]
    fn resolve_output_dir_should_return_provided_path() {
        let path = PathBuf::from("/tmp/custom-output");
        let resolved = resolve_output_dir(Some(path.clone())).expect("path should resolve");
        assert_eq!(resolved, path);
    }
}
