//! Command-line interface for local recording, transcription, and polishing.

use anyhow::{Context, Result};
use clap::{Parser, Subcommand, ValueEnum};
use diy_typeless_core::{start_recording, stop_recording, LlmProvider};
use std::fs;
use std::path::PathBuf;
use std::thread::sleep;
use std::time::Duration;

mod commands;
use commands::diagnose::{
    run_diagnose_audio, run_diagnose_env, run_diagnose_llm, run_diagnose_pipeline,
};
use commands::utils::{
    copy_to_clipboard, ensure_flac_bytes, read_stdin, resolve_groq_key, resolve_llm_key,
    resolve_output_dir, timestamp, wait_for_enter,
};

#[derive(Parser)]
#[command(name = "diy-typeless")]
#[command(about = "CLI for DIY Typeless", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, ValueEnum)]
enum CliLlmProvider {
    #[value(name = "google-ai-studio")]
    GoogleAiStudio,
    #[value(name = "openai")]
    Openai,
}

impl From<CliLlmProvider> for LlmProvider {
    fn from(value: CliLlmProvider) -> Self {
        match value {
            CliLlmProvider::GoogleAiStudio => LlmProvider::GoogleAiStudio,
            CliLlmProvider::Openai => LlmProvider::Openai,
        }
    }
}

#[derive(Subcommand)]
enum Commands {
    Record {
        #[arg(long)]
        output_dir: Option<PathBuf>,
        #[arg(long)]
        duration_seconds: Option<u64>,
    },
    Transcribe {
        file: PathBuf,
        #[arg(long)]
        groq_key: Option<String>,
        #[arg(long)]
        language: Option<String>,
    },
    Polish {
        #[arg(long)]
        llm_key: Option<String>,
        #[arg(long, value_enum, default_value = "google-ai-studio")]
        provider: CliLlmProvider,
        #[arg(long)]
        text: Option<String>,
        #[arg(long)]
        context: Option<String>,
    },
    Full {
        #[arg(long)]
        output_dir: Option<PathBuf>,
        #[arg(long)]
        groq_key: Option<String>,
        #[arg(long)]
        llm_key: Option<String>,
        #[arg(long, value_enum, default_value = "google-ai-studio")]
        provider: CliLlmProvider,
        #[arg(long)]
        language: Option<String>,
        #[arg(long)]
        duration_seconds: Option<u64>,
        #[arg(long)]
        context: Option<String>,
    },
    Diagnose {
        #[command(subcommand)]
        command: DiagnoseCommands,
    },
}

#[derive(Subcommand)]
enum DiagnoseCommands {
    Env,
    Audio {
        #[arg(long, default_value_t = 3)]
        duration_seconds: u64,
        #[arg(long)]
        output: Option<PathBuf>,
    },
    Llm {
        #[arg(long)]
        llm_key: Option<String>,
        #[arg(long, value_enum, default_value = "google-ai-studio")]
        provider: CliLlmProvider,
        #[arg(long)]
        prompt: String,
        #[arg(long)]
        system_instruction: Option<String>,
        #[arg(long)]
        temperature: Option<f32>,
        #[arg(long)]
        cancel_immediately: bool,
    },
    Pipeline {
        file: PathBuf,
        #[arg(long)]
        output_dir: Option<PathBuf>,
        #[arg(long)]
        groq_key: Option<String>,
        #[arg(long)]
        llm_key: Option<String>,
        #[arg(long, value_enum, default_value = "google-ai-studio")]
        provider: CliLlmProvider,
        #[arg(long)]
        language: Option<String>,
        #[arg(long)]
        transcribe_only: bool,
        #[arg(long)]
        context: Option<String>,
    },
}

fn main() -> Result<()> {
    dotenvy::dotenv().ok();
    let cli = Cli::parse();

    match cli.command {
        Commands::Record {
            output_dir,
            duration_seconds,
        } => cmd_record(output_dir, duration_seconds),
        Commands::Transcribe {
            file,
            groq_key,
            language,
        } => cmd_transcribe(file, groq_key, language),
        Commands::Polish {
            llm_key,
            provider,
            text,
            context,
        } => cmd_polish(provider.into(), llm_key, text, context),
        Commands::Full {
            output_dir,
            groq_key,
            llm_key,
            provider,
            language,
            duration_seconds,
            context,
        } => cmd_full(
            output_dir,
            groq_key,
            provider.into(),
            llm_key,
            language,
            duration_seconds,
            context,
        ),
        Commands::Diagnose { command } => match command {
            DiagnoseCommands::Env => run_diagnose_env(),
            DiagnoseCommands::Audio {
                duration_seconds,
                output,
            } => run_diagnose_audio(duration_seconds, output),
            DiagnoseCommands::Llm {
                llm_key,
                provider,
                prompt,
                system_instruction,
                temperature,
                cancel_immediately,
            } => run_diagnose_llm(
                prompt,
                provider.into(),
                llm_key,
                system_instruction,
                temperature,
                cancel_immediately,
            ),
            DiagnoseCommands::Pipeline {
                file,
                output_dir,
                groq_key,
                llm_key,
                provider,
                language,
                transcribe_only,
                context,
            } => run_diagnose_pipeline(
                file,
                output_dir,
                groq_key,
                provider.into(),
                llm_key,
                language,
                transcribe_only,
                context,
            ),
        },
    }
}

fn cmd_record(output_dir: Option<PathBuf>, duration_seconds: Option<u64>) -> Result<()> {
    let output_dir = resolve_output_dir(output_dir)?;
    fs::create_dir_all(&output_dir)?;

    if let Some(duration) = duration_seconds {
        start_recording().context("Failed to start recording")?;
        println!("Recording for {duration}s (auto-start)...");
        sleep(Duration::from_secs(duration));
    } else {
        println!("Press Enter to start recording...");
        wait_for_enter()?;
        start_recording().context("Failed to start recording")?;
        println!("Recording... Press Enter to stop.");
        wait_for_enter()?;
    }

    let audio_data = stop_recording().context("Failed to stop recording")?;
    let flac_path = output_dir.join(format!("recording_{}.flac", timestamp()));
    fs::write(&flac_path, audio_data.bytes)?;

    println!(
        "Saved FLAC to {} (duration {:.2}s)",
        flac_path.display(),
        audio_data.duration_seconds
    );

    Ok(())
}

fn cmd_transcribe(file: PathBuf, groq_key: Option<String>, language: Option<String>) -> Result<()> {
    let audio_bytes = fs::read(&file).context("Failed to read audio file")?;
    ensure_flac_bytes(&audio_bytes, &file)?;
    let api_key = resolve_groq_key(groq_key)?;
    use secrecy::ExposeSecret;
    let text = diy_typeless_core::transcribe_audio_bytes(
        api_key.expose_secret().to_string(),
        audio_bytes,
        language,
    )?;
    println!("{text}");
    Ok(())
}

fn cmd_polish(
    provider: LlmProvider,
    llm_key: Option<String>,
    text: Option<String>,
    context: Option<String>,
) -> Result<()> {
    let api_key = resolve_llm_key(provider, llm_key)?;
    let raw_text = match text {
        Some(text) => text,
        None => read_stdin()?,
    };
    use secrecy::ExposeSecret;
    let polished = diy_typeless_core::polish_text(
        provider,
        api_key.expose_secret().to_string(),
        raw_text,
        context,
    )?;
    println!("{polished}");
    copy_to_clipboard(&polished);
    Ok(())
}

#[allow(clippy::too_many_arguments)]
fn cmd_full(
    output_dir: Option<PathBuf>,
    groq_key: Option<String>,
    provider: LlmProvider,
    llm_key: Option<String>,
    language: Option<String>,
    duration_seconds: Option<u64>,
    context: Option<String>,
) -> Result<()> {
    let llm_key = resolve_llm_key(provider, llm_key)?;
    let output_dir = resolve_output_dir(output_dir)?;
    fs::create_dir_all(&output_dir)?;

    let raw_text = run_groq_full(&output_dir, duration_seconds, groq_key, language)?;

    println!("Polishing...");
    use secrecy::ExposeSecret;
    let polished_text = diy_typeless_core::polish_text(
        provider,
        llm_key.expose_secret().to_string(),
        raw_text,
        context,
    )?;

    let polished_path = output_dir.join(format!("recording_{}_polished.txt", timestamp()));
    fs::write(&polished_path, &polished_text)?;

    println!("Polished text:\n{}", polished_text);
    copy_to_clipboard(&polished_text);

    println!("Saved: {}", polished_path.display());

    Ok(())
}

fn run_groq_full(
    output_dir: &std::path::Path,
    duration_seconds: Option<u64>,
    groq_key: Option<String>,
    language: Option<String>,
) -> Result<String> {
    let groq_key = resolve_groq_key(groq_key)?;

    if let Some(duration) = duration_seconds {
        start_recording().context("Failed to start recording")?;
        println!("Recording for {duration}s (auto-start)...");
        sleep(Duration::from_secs(duration));
    } else {
        println!("Press Enter to start recording...");
        wait_for_enter()?;
        start_recording().context("Failed to start recording")?;
        println!("Recording... Press Enter to stop.");
        wait_for_enter()?;
    }

    let audio_data = stop_recording().context("Failed to stop recording")?;
    let base = format!("recording_{}", timestamp());
    let flac_path = output_dir.join(format!("{base}.flac"));
    fs::write(&flac_path, &audio_data.bytes)?;

    println!("Transcribing with Groq API...");
    use secrecy::ExposeSecret;
    let text = diy_typeless_core::transcribe_audio_bytes(
        groq_key.expose_secret().to_string(),
        audio_data.bytes,
        language,
    )?;
    let raw_path = output_dir.join(format!("{base}_raw.txt"));
    fs::write(&raw_path, &text)?;

    Ok(text)
}

#[cfg(test)]
mod tests {
    use super::{Cli, CliLlmProvider, Commands};
    use clap::Parser;

    #[test]
    fn polish_command_should_accept_openai_provider() {
        let cli = Cli::try_parse_from([
            "diy-typeless",
            "polish",
            "--provider",
            "openai",
            "--text",
            "hello",
        ])
        .expect("cli should parse");

        match cli.command {
            Commands::Polish { provider, .. } => assert_eq!(provider, CliLlmProvider::Openai),
            _ => panic!("expected polish command"),
        }
    }

    #[test]
    fn full_command_should_accept_openai_provider() {
        let cli = Cli::try_parse_from([
            "diy-typeless",
            "full",
            "--provider",
            "openai",
            "--duration-seconds",
            "1",
        ])
        .expect("cli should parse");

        match cli.command {
            Commands::Full { provider, .. } => assert_eq!(provider, CliLlmProvider::Openai),
            _ => panic!("expected full command"),
        }
    }
}
