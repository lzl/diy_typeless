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
    find_binary_in_path(binary, &path_var)
}

fn find_binary_in_path(binary: &str, path_var: &std::ffi::OsStr) -> Option<PathBuf> {
    for dir in std::env::split_paths(path_var) {
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
    default_output_dir(dirs::home_dir())
}

fn default_output_dir(home_dir: Option<PathBuf>) -> Result<PathBuf> {
    let home = home_dir.context("Failed to resolve home directory")?;
    Ok(home.join("diy_typeless_recordings"))
}

/// Resolve Groq API key from argument or environment
pub(crate) fn resolve_groq_key(provided: Option<String>) -> Result<SecretString> {
    resolve_api_key_value(provided, std::env::var("GROQ_API_KEY").ok(), "GROQ_API_KEY")
}

/// Resolve Gemini API key from argument or environment
pub(crate) fn resolve_gemini_key(provided: Option<String>) -> Result<SecretString> {
    resolve_api_key_value(
        provided,
        std::env::var("GEMINI_API_KEY").ok(),
        "GEMINI_API_KEY",
    )
}

fn resolve_api_key_value(
    provided: Option<String>,
    env_value: Option<String>,
    env_name: &str,
) -> Result<SecretString> {
    if let Some(key) = provided {
        let trimmed = key.trim();
        if trimmed.is_empty() {
            anyhow::bail!("Provided API key is empty");
        }
        return Ok(SecretString::from(trimmed.to_string()));
    }

    let env_key = env_value.with_context(|| format!("{env_name} not set"))?;
    let trimmed = env_key.trim();
    if trimmed.is_empty() {
        anyhow::bail!("{env_name} is set but empty");
    }

    Ok(SecretString::from(trimmed.to_string()))
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
    use super::{
        default_output_dir, ensure_flac_bytes, find_binary_in_path, format_duration, mask_secret,
        resolve_api_key_value, resolve_gemini_key, resolve_groq_key, resolve_output_dir,
    };
    use secrecy::ExposeSecret;
    use std::ffi::OsString;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::sync::{LazyLock, Mutex};
    use std::time::Duration;
    use std::time::{SystemTime, UNIX_EPOCH};

    static PATH_TEST_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));
    static HOME_TEST_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));
    static API_KEY_TEST_LOCK: LazyLock<Mutex<()>> = LazyLock::new(|| Mutex::new(()));

    struct PathEnvGuard {
        original: Option<OsString>,
    }

    impl Drop for PathEnvGuard {
        fn drop(&mut self) {
            if let Some(value) = &self.original {
                std::env::set_var("PATH", value);
            } else {
                std::env::remove_var("PATH");
            }
        }
    }

    fn set_path_for_test(path: &std::ffi::OsStr) -> PathEnvGuard {
        let original = std::env::var_os("PATH");
        std::env::set_var("PATH", path);
        PathEnvGuard { original }
    }

    struct HomeEnvGuard {
        original_home: Option<OsString>,
        original_user_profile: Option<OsString>,
    }

    impl Drop for HomeEnvGuard {
        fn drop(&mut self) {
            if let Some(value) = &self.original_home {
                std::env::set_var("HOME", value);
            } else {
                std::env::remove_var("HOME");
            }

            if let Some(value) = &self.original_user_profile {
                std::env::set_var("USERPROFILE", value);
            } else {
                std::env::remove_var("USERPROFILE");
            }
        }
    }

    fn set_home_for_test(path: &std::ffi::OsStr) -> HomeEnvGuard {
        let original_home = std::env::var_os("HOME");
        let original_user_profile = std::env::var_os("USERPROFILE");
        std::env::set_var("HOME", path);
        std::env::set_var("USERPROFILE", path);
        HomeEnvGuard {
            original_home,
            original_user_profile,
        }
    }

    struct ApiKeyEnvGuard {
        original_groq: Option<OsString>,
        original_gemini: Option<OsString>,
    }

    impl Drop for ApiKeyEnvGuard {
        fn drop(&mut self) {
            if let Some(value) = &self.original_groq {
                std::env::set_var("GROQ_API_KEY", value);
            } else {
                std::env::remove_var("GROQ_API_KEY");
            }

            if let Some(value) = &self.original_gemini {
                std::env::set_var("GEMINI_API_KEY", value);
            } else {
                std::env::remove_var("GEMINI_API_KEY");
            }
        }
    }

    fn set_api_keys_for_test(groq: Option<&str>, gemini: Option<&str>) -> ApiKeyEnvGuard {
        let original_groq = std::env::var_os("GROQ_API_KEY");
        let original_gemini = std::env::var_os("GEMINI_API_KEY");

        if let Some(value) = groq {
            std::env::set_var("GROQ_API_KEY", value);
        } else {
            std::env::remove_var("GROQ_API_KEY");
        }

        if let Some(value) = gemini {
            std::env::set_var("GEMINI_API_KEY", value);
        } else {
            std::env::remove_var("GEMINI_API_KEY");
        }

        ApiKeyEnvGuard {
            original_groq,
            original_gemini,
        }
    }

    fn make_temp_dir(label: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .expect("system time should be after unix epoch")
            .as_nanos();
        let path = std::env::temp_dir().join(format!(
            "diy_typeless_cli_utils_{label}_{}_{}",
            std::process::id(),
            nanos
        ));
        fs::create_dir_all(&path).expect("temp directory should be created");
        path
    }

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

    #[test]
    fn default_output_dir_should_append_recordings_suffix_to_home() {
        let resolved = default_output_dir(Some(PathBuf::from("/tmp/test-home")))
            .expect("default output dir should resolve");
        assert_eq!(
            resolved,
            PathBuf::from("/tmp/test-home/diy_typeless_recordings")
        );
    }

    #[test]
    fn default_output_dir_should_fail_when_home_is_missing() {
        let result = default_output_dir(None);
        assert_eq!(
            result.expect_err("missing home should fail").to_string(),
            "Failed to resolve home directory"
        );
    }

    #[test]
    fn resolve_output_dir_should_use_home_environment_when_not_provided() {
        let _lock = HOME_TEST_LOCK
            .lock()
            .expect("home test lock should be acquired");
        let fake_home = make_temp_dir("home_env");
        let _guard = set_home_for_test(fake_home.as_os_str());

        let resolved = resolve_output_dir(None).expect("default output dir should resolve");
        assert_eq!(resolved, fake_home.join("diy_typeless_recordings"));

        let _ = fs::remove_dir_all(fake_home);
    }

    #[test]
    fn find_binary_in_path_should_return_first_match_by_path_order() {
        let dir_one = make_temp_dir("path_first_one");
        let dir_two = make_temp_dir("path_first_two");
        let bin_name = "tool";
        let first = dir_one.join(bin_name);
        let second = dir_two.join(bin_name);
        fs::write(&first, b"one").expect("first binary file should be created");
        fs::write(&second, b"two").expect("second binary file should be created");

        let path = std::env::join_paths([dir_one.clone(), dir_two.clone()])
            .expect("path join should succeed");
        let found = find_binary_in_path(bin_name, path.as_os_str());

        assert_eq!(found, Some(first));

        let _ = fs::remove_dir_all(dir_one);
        let _ = fs::remove_dir_all(dir_two);
    }

    #[test]
    fn find_binary_in_path_should_find_match_in_later_path_segment() {
        let dir_one = make_temp_dir("path_later_one");
        let dir_two = make_temp_dir("path_later_two");
        let bin_name = "late_tool";
        let expected = dir_two.join(bin_name);
        fs::write(&expected, b"late").expect("later binary file should be created");

        let path = std::env::join_paths([dir_one.clone(), dir_two.clone()])
            .expect("path join should succeed");
        let found = find_binary_in_path(bin_name, path.as_os_str());

        assert_eq!(found, Some(expected));

        let _ = fs::remove_dir_all(dir_one);
        let _ = fs::remove_dir_all(dir_two);
    }

    #[test]
    fn find_binary_in_path_should_return_none_when_binary_absent() {
        let dir = make_temp_dir("path_none");
        let path = OsString::from(dir.as_os_str());
        let found = find_binary_in_path("missing_bin", path.as_os_str());

        assert!(found.is_none());

        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn find_binary_should_use_current_process_path_environment() {
        let _lock = PATH_TEST_LOCK
            .lock()
            .expect("path test lock should be acquired");
        let dir = make_temp_dir("path_env");
        let bin_name = "env_tool";
        let expected = dir.join(bin_name);
        fs::write(&expected, b"env").expect("env binary file should be created");

        let path = std::env::join_paths([dir.clone()]).expect("path join should succeed");
        let _guard = set_path_for_test(path.as_os_str());
        let found = super::find_binary(bin_name);

        assert_eq!(found, Some(expected));

        let _ = fs::remove_dir_all(dir);
    }

    #[test]
    fn resolve_api_key_value_should_use_trimmed_provided_key() {
        let key = resolve_api_key_value(Some("  abc123  ".to_string()), None, "GROQ_API_KEY")
            .expect("provided key should resolve");
        assert_eq!(key.expose_secret(), "abc123");
    }

    #[test]
    fn resolve_api_key_value_should_reject_blank_provided_key() {
        let result = resolve_api_key_value(Some("   ".to_string()), None, "GROQ_API_KEY");
        assert_eq!(
            result
                .expect_err("blank provided key should fail")
                .to_string(),
            "Provided API key is empty"
        );
    }

    #[test]
    fn resolve_api_key_value_should_use_trimmed_env_key_when_provided_missing() {
        let key = resolve_api_key_value(None, Some("  env-secret  ".to_string()), "GROQ_API_KEY")
            .expect("env key should resolve");
        assert_eq!(key.expose_secret(), "env-secret");
    }

    #[test]
    fn resolve_api_key_value_should_fail_when_env_missing() {
        let result = resolve_api_key_value(None, None, "GROQ_API_KEY");
        assert_eq!(
            result.expect_err("missing env should fail").to_string(),
            "GROQ_API_KEY not set"
        );
    }

    #[test]
    fn resolve_api_key_value_should_fail_when_env_empty() {
        let result = resolve_api_key_value(None, Some("   ".to_string()), "GROQ_API_KEY");
        assert_eq!(
            result.expect_err("empty env key should fail").to_string(),
            "GROQ_API_KEY is set but empty"
        );
    }

    #[test]
    fn resolve_groq_key_should_read_groq_env_variable() {
        let _lock = API_KEY_TEST_LOCK
            .lock()
            .expect("api key test lock should be acquired");
        let _guard = set_api_keys_for_test(Some("groq-env"), Some("gemini-env"));

        let key = resolve_groq_key(None).expect("groq env key should resolve");
        assert_eq!(key.expose_secret(), "groq-env");
    }

    #[test]
    fn resolve_gemini_key_should_read_gemini_env_variable() {
        let _lock = API_KEY_TEST_LOCK
            .lock()
            .expect("api key test lock should be acquired");
        let _guard = set_api_keys_for_test(Some("groq-env"), Some("gemini-env"));

        let key = resolve_gemini_key(None).expect("gemini env key should resolve");
        assert_eq!(key.expose_secret(), "gemini-env");
    }

    #[test]
    fn resolve_groq_key_should_prefer_provided_value_over_env() {
        let _lock = API_KEY_TEST_LOCK
            .lock()
            .expect("api key test lock should be acquired");
        let _guard = set_api_keys_for_test(Some("groq-env"), Some("gemini-env"));

        let key = resolve_groq_key(Some("provided-groq".to_string()))
            .expect("provided groq key should resolve");
        assert_eq!(key.expose_secret(), "provided-groq");
    }
}
