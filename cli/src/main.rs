use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use diy_typeless_core::{start_recording, stop_recording};
use std::fs;
use std::path::PathBuf;
use std::thread::sleep;
use std::time::Duration;

mod commands;
use commands::diagnose::{run_diagnose_audio, run_diagnose_env, run_diagnose_pipeline};
use commands::utils::{
    copy_to_clipboard, read_stdin, resolve_gemini_key, resolve_groq_key, resolve_output_dir,
    timestamp, wait_for_enter,
};

#[derive(Parser)]
#[command(name = "diy-typeless")]
#[command(about = "CLI for DIY Typeless", long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Commands,
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
        gemini_key: Option<String>,
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
        gemini_key: Option<String>,
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
    Pipeline {
        file: PathBuf,
        #[arg(long)]
        output_dir: Option<PathBuf>,
        #[arg(long)]
        groq_key: Option<String>,
        #[arg(long)]
        gemini_key: Option<String>,
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
            gemini_key,
            text,
            context,
        } => cmd_polish(gemini_key, text, context),
        Commands::Full {
            output_dir,
            groq_key,
            gemini_key,
            language,
            duration_seconds,
            context,
        } => cmd_full(
            output_dir,
            groq_key,
            gemini_key,
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
            DiagnoseCommands::Pipeline {
                file,
                output_dir,
                groq_key,
                gemini_key,
                language,
                transcribe_only,
                context,
            } => run_diagnose_pipeline(
                file,
                output_dir,
                groq_key,
                gemini_key,
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

    let wav_data = stop_recording().context("Failed to stop recording")?;
    let wav_path = output_dir.join(format!("recording_{}.wav", timestamp()));
    fs::write(&wav_path, wav_data.bytes)?;

    println!(
        "Saved WAV to {} (duration {:.2}s)",
        wav_path.display(),
        wav_data.duration_seconds
    );

    Ok(())
}

fn cmd_transcribe(file: PathBuf, groq_key: Option<String>, language: Option<String>) -> Result<()> {
    let api_key = resolve_groq_key(groq_key)?;
    let wav_bytes = fs::read(&file).context("Failed to read WAV file")?;
    use secrecy::ExposeSecret;
    let text = diy_typeless_core::transcribe_audio_bytes(
        api_key.expose_secret().to_string(),
        wav_bytes,
        language,
    )?;
    println!("{text}");
    Ok(())
}

fn cmd_polish(
    gemini_key: Option<String>,
    text: Option<String>,
    context: Option<String>,
) -> Result<()> {
    let api_key = resolve_gemini_key(gemini_key)?;
    let raw_text = match text {
        Some(text) => text,
        None => read_stdin()?,
    };
    use secrecy::ExposeSecret;
    let polished = diy_typeless_core::polish_text(
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
    gemini_key: Option<String>,
    language: Option<String>,
    duration_seconds: Option<u64>,
    context: Option<String>,
) -> Result<()> {
    let gemini_key = resolve_gemini_key(gemini_key)?;
    let output_dir = resolve_output_dir(output_dir)?;
    fs::create_dir_all(&output_dir)?;

    let raw_text = run_groq_full(&output_dir, duration_seconds, groq_key, language.clone())?;

    println!("Polishing...");
    use secrecy::ExposeSecret;
    let polished_text = diy_typeless_core::polish_text(
        gemini_key.expose_secret().to_string(),
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

    let wav_data = stop_recording().context("Failed to stop recording")?;
    let base = format!("recording_{}", timestamp());
    let wav_path = output_dir.join(format!("{base}.wav"));
    fs::write(&wav_path, &wav_data.bytes)?;

    println!("Transcribing with Groq API...");
    use secrecy::ExposeSecret;
    let text = diy_typeless_core::transcribe_audio_bytes(
        groq_key.expose_secret().to_string(),
        wav_data.bytes,
        language,
    )?;
    let raw_path = output_dir.join(format!("{base}_raw.txt"));
    fs::write(&raw_path, &text)?;

    Ok(text)
}
