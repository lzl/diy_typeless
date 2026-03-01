//! Diagnostic commands for CLI

use anyhow::{anyhow, Context, Result};
use diy_typeless_core::{start_recording, stop_recording};
use std::fs;
use std::path::PathBuf;
use std::thread::sleep;
use std::time::{Duration, Instant};

use crate::commands::utils::{
    ensure_flac_bytes, format_duration, print_binary_status, print_key_status, resolve_gemini_key,
    resolve_groq_key, resolve_output_dir, timestamp,
};

/// Run environment diagnostics
pub(crate) fn run_diagnose_env() -> Result<()> {
    println!("CLI diagnostics (environment)");
    println!(
        "- OS: {} ({})",
        std::env::consts::OS,
        std::env::consts::ARCH
    );
    println!("- cwd: {}", std::env::current_dir()?.display());
    println!("- executable: {}", std::env::current_exe()?.display());
    println!(
        "- default output dir: {}",
        resolve_output_dir(None)?.display()
    );

    print_key_status("GROQ_API_KEY");
    print_key_status("GEMINI_API_KEY");

    print_binary_status("pbcopy");
    print_binary_status("tccutil");

    Ok(())
}

/// Run audio diagnostics
pub(crate) fn run_diagnose_audio(duration_seconds: u64, output: Option<PathBuf>) -> Result<()> {
    if duration_seconds == 0 {
        return Err(anyhow!("--duration-seconds must be greater than 0"));
    }

    let output_path = match output {
        Some(path) => path,
        None => {
            let output_dir = resolve_output_dir(None)?;
            fs::create_dir_all(&output_dir)?;
            output_dir.join(format!("diag_recording_{}.flac", timestamp()))
        }
    };

    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }

    println!("CLI diagnostics (audio)");
    println!("- recording duration: {duration_seconds}s");

    let start = Instant::now();
    start_recording().context("Failed to start recording")?;
    sleep(Duration::from_secs(duration_seconds));
    let audio_data = stop_recording().context("Failed to stop recording")?;
    let elapsed = start.elapsed();

    fs::write(&output_path, &audio_data.bytes)
        .with_context(|| format!("Failed to write {}", output_path.display()))?;
    println!("- capture wall time: {}", format_duration(elapsed));
    println!("- reported duration: {:.2}s", audio_data.duration_seconds);
    println!("- format: FLAC (header verified)");
    println!("- bytes: {}", audio_data.bytes.len());
    println!("- output: {}", output_path.display());

    Ok(())
}

/// Run pipeline diagnostics
#[allow(clippy::too_many_arguments)]
pub(crate) fn run_diagnose_pipeline(
    file: PathBuf,
    output_dir: Option<PathBuf>,
    groq_key: Option<String>,
    gemini_key: Option<String>,
    language: Option<String>,
    transcribe_only: bool,
    context: Option<String>,
) -> Result<()> {
    let audio_bytes = fs::read(&file).context("Failed to read audio file")?;
    ensure_flac_bytes(&audio_bytes, &file)?;

    let output_dir = resolve_output_dir(output_dir)?;
    fs::create_dir_all(&output_dir)?;

    let stem = file.file_stem().and_then(|s| s.to_str()).unwrap_or("input");
    let base = format!("{}_diag_{}", stem, timestamp());

    println!("CLI diagnostics (pipeline)");
    println!("- input: {}", file.display());
    println!("- format: FLAC (header verified)");
    println!("- bytes: {}", audio_bytes.len());

    let groq_key = resolve_groq_key(groq_key)?;
    let transcribe_start = Instant::now();
    // SecretString is passed by reference to core functions
    use secrecy::ExposeSecret;
    let raw_text = diy_typeless_core::transcribe_audio_bytes(
        groq_key.expose_secret().to_string(),
        audio_bytes,
        language,
    )
    .context("Transcribe step failed")?;
    let transcribe_elapsed = transcribe_start.elapsed();
    let raw_path = output_dir.join(format!("{}_raw.txt", base));
    fs::write(&raw_path, &raw_text)?;

    println!(
        "- transcribe: {} | {} chars",
        format_duration(transcribe_elapsed),
        raw_text.chars().count()
    );
    println!("- raw text: {}", raw_path.display());

    if transcribe_only {
        return Ok(());
    }

    let gemini_key = resolve_gemini_key(gemini_key)?;
    let polish_start = Instant::now();
    let polished_text =
        diy_typeless_core::polish_text(gemini_key.expose_secret().to_string(), raw_text, context)
            .context("Polish step failed")?;
    let polish_elapsed = polish_start.elapsed();
    let polished_path = output_dir.join(format!("{}_polished.txt", base));
    fs::write(&polished_path, &polished_text)?;

    println!(
        "- polish: {} | {} chars",
        format_duration(polish_elapsed),
        polished_text.chars().count()
    );
    println!("- polished text: {}", polished_path.display());

    Ok(())
}
