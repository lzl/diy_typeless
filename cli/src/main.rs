use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use diy_typeless_core::{start_recording, stop_recording};
use std::fs;
use std::io::{self, Cursor, Read};
use std::path::PathBuf;
use std::process::Command;
use std::thread::sleep;
use std::time::{Duration, Instant};

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
        #[arg(long)]
        language: Option<String>,
        /// Use local ASR model for real-time transcription
        #[arg(long)]
        local_asr: Option<PathBuf>,
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
        /// Use local ASR model instead of Groq API (model directory path)
        #[arg(long)]
        local_asr: Option<PathBuf>,
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

struct WavMetrics {
    sample_rate: u32,
    channels: u16,
    bits_per_sample: u16,
    duration_seconds: f64,
    rms_dbfs: f64,
    peak_dbfs: f64,
    sample_count: usize,
}

fn main() -> Result<()> {
    dotenvy::dotenv().ok();
    let cli = Cli::parse();

    match cli.command {
        Commands::Record {
            output_dir,
            duration_seconds,
            language,
            local_asr,
        } => {
            let output_dir = resolve_output_dir(output_dir)?;
            fs::create_dir_all(&output_dir)?;

            if let Some(model_dir) = local_asr {
                // Local ASR flow
                if !model_dir.exists() {
                    return Err(anyhow!("Model directory does not exist: {}", model_dir.display()));
                }

                let model_dir_str = model_dir.to_string_lossy().to_string();

                println!("Initializing local ASR...");
                diy_typeless_core::init_local_asr(model_dir_str.clone())
                    .context("Failed to initialize local ASR")?;

                let session_id = diy_typeless_core::start_streaming_session(model_dir_str, language)
                    .context("Failed to start streaming session")?;

                if let Some(duration) = duration_seconds {
                    println!("Recording for {duration}s (auto-start)...");
                    sleep(Duration::from_secs(duration));
                } else {
                    println!("Recording... Press Enter to stop.");
                    wait_for_enter()?;
                }

                let text = diy_typeless_core::stop_streaming_session(session_id)
                    .context("Failed to stop streaming session")?;

                let txt_path = output_dir.join(format!("recording_{}.txt", timestamp()));
                fs::write(&txt_path, &text)?;

                println!("Transcription:\n{text}");
                println!("Saved to {}", txt_path.display());
            } else {
                // Traditional recording flow
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
            }
        }
        Commands::Transcribe {
            file,
            groq_key,
            language,
        } => {
            let api_key = resolve_groq_key(groq_key)?;
            let wav_bytes = fs::read(&file).context("Failed to read WAV file")?;
            let text = diy_typeless_core::transcribe_wav_bytes(api_key, wav_bytes, language)?;
            println!("{text}");
        }
        Commands::Polish {
            gemini_key,
            text,
            context,
        } => {
            let api_key = resolve_gemini_key(gemini_key)?;
            let raw_text = match text {
                Some(text) => text,
                None => read_stdin()?,
            };
            let polished = diy_typeless_core::polish_text(api_key, raw_text, context)?;
            println!("{polished}");
            copy_to_clipboard(&polished);
        }
        Commands::Full {
            output_dir,
            groq_key,
            gemini_key,
            language,
            duration_seconds,
            context,
            local_asr,
        } => {
            let gemini_key = resolve_gemini_key(gemini_key)?;
            let output_dir = resolve_output_dir(output_dir)?;
            fs::create_dir_all(&output_dir)?;

            let raw_text = if let Some(model_dir) = local_asr {
                // Local ASR flow - real-time streaming transcription
                if !model_dir.exists() {
                    return Err(anyhow!("Model directory does not exist: {}", model_dir.display()));
                }

                let model_dir_str = model_dir.to_string_lossy().to_string();

                // Initialize local ASR
                println!("Initializing local ASR...");
                diy_typeless_core::init_local_asr(model_dir_str.clone())
                    .context("Failed to initialize local ASR")?;

                // Start streaming session
                let session_id = diy_typeless_core::start_streaming_session(model_dir_str, language)
                    .context("Failed to start streaming session")?;

                if let Some(duration) = duration_seconds {
                    println!("Using local ASR... Recording for {duration}s (auto-start)...");
                    sleep(Duration::from_secs(duration));
                } else {
                    println!("Using local ASR... Press Enter to stop recording.");
                    wait_for_enter()?;
                }

                // Stop and get final text
                let text = diy_typeless_core::stop_streaming_session(session_id)
                    .context("Failed to stop streaming session")?;
                println!("Transcription completed.");
                text
            } else {
                // Groq API flow - traditional recording then transcription
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
                let text = diy_typeless_core::transcribe_wav_bytes(groq_key, wav_data.bytes, language)?;
                let raw_path = output_dir.join(format!("{base}_raw.txt"));
                fs::write(&raw_path, &text)?;
                text
            };

            println!("Polishing...");
            let polished_text = diy_typeless_core::polish_text(gemini_key, raw_text, context)?;

            let polished_path = output_dir.join(format!("recording_{}_polished.txt", timestamp()));
            fs::write(&polished_path, &polished_text)?;

            println!("Polished text:\n{}", polished_text);
            copy_to_clipboard(&polished_text);

            println!("Saved: {}", polished_path.display());
        }
        Commands::Diagnose { command } => match command {
            DiagnoseCommands::Env => run_diagnose_env()?,
            DiagnoseCommands::Audio {
                duration_seconds,
                output,
            } => run_diagnose_audio(duration_seconds, output)?,
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
            )?,
        },
    }

    Ok(())
}

fn run_diagnose_env() -> Result<()> {
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

fn run_diagnose_audio(duration_seconds: u64, output: Option<PathBuf>) -> Result<()> {
    if duration_seconds == 0 {
        return Err(anyhow!("--duration-seconds must be greater than 0"));
    }

    let output_path = match output {
        Some(path) => path,
        None => {
            let output_dir = resolve_output_dir(None)?;
            fs::create_dir_all(&output_dir)?;
            output_dir.join(format!("diag_recording_{}.wav", timestamp()))
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
    let wav_data = stop_recording().context("Failed to stop recording")?;
    let elapsed = start.elapsed();

    fs::write(&output_path, &wav_data.bytes)
        .with_context(|| format!("Failed to write {}", output_path.display()))?;

    let metrics = inspect_wav_bytes(&wav_data.bytes)?;
    println!("- capture wall time: {}", format_duration(elapsed));
    println!(
        "- reported duration: {:.2}s | analyzed duration: {:.2}s",
        wav_data.duration_seconds, metrics.duration_seconds
    );
    println!(
        "- WAV spec: {} Hz, {} channel(s), {} bit",
        metrics.sample_rate, metrics.channels, metrics.bits_per_sample
    );
    println!(
        "- levels: RMS {:.1} dBFS, peak {:.1} dBFS",
        metrics.rms_dbfs, metrics.peak_dbfs
    );
    println!("- samples: {}", metrics.sample_count);
    println!("- output: {}", output_path.display());

    Ok(())
}

fn run_diagnose_pipeline(
    file: PathBuf,
    output_dir: Option<PathBuf>,
    groq_key: Option<String>,
    gemini_key: Option<String>,
    language: Option<String>,
    transcribe_only: bool,
    context: Option<String>,
) -> Result<()> {
    let wav_bytes = fs::read(&file).context("Failed to read WAV file")?;
    let metrics = inspect_wav_bytes(&wav_bytes)
        .with_context(|| format!("Failed to parse WAV: {}", file.display()))?;

    let output_dir = resolve_output_dir(output_dir)?;
    fs::create_dir_all(&output_dir)?;

    let stem = file.file_stem().and_then(|s| s.to_str()).unwrap_or("input");
    let base = format!("{}_diag_{}", stem, timestamp());

    println!("CLI diagnostics (pipeline)");
    println!("- input: {}", file.display());
    println!(
        "- WAV spec: {} Hz, {} channel(s), {} bit, {:.2}s",
        metrics.sample_rate, metrics.channels, metrics.bits_per_sample, metrics.duration_seconds
    );

    let groq_key = resolve_groq_key(groq_key)?;
    let transcribe_start = Instant::now();
    let raw_text = diy_typeless_core::transcribe_wav_bytes(groq_key, wav_bytes, language)
        .context("Transcribe step failed")?;
    let transcribe_elapsed = transcribe_start.elapsed();
    let raw_path = output_dir.join(format!("{base}_raw.txt"));
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
        diy_typeless_core::polish_text(gemini_key, raw_text, context).context("Polish step failed")?;
    let polish_elapsed = polish_start.elapsed();
    let polished_path = output_dir.join(format!("{base}_polished.txt"));
    fs::write(&polished_path, &polished_text)?;

    println!(
        "- polish: {} | {} chars",
        format_duration(polish_elapsed),
        polished_text.chars().count()
    );
    println!("- polished text: {}", polished_path.display());

    Ok(())
}

fn inspect_wav_bytes(bytes: &[u8]) -> Result<WavMetrics> {
    let mut reader = hound::WavReader::new(Cursor::new(bytes))?;
    let spec = reader.spec();

    if spec.channels == 0 || spec.sample_rate == 0 {
        return Err(anyhow!("Invalid WAV header"));
    }

    let mut sample_count = 0usize;
    let mut sum_square = 0.0f64;
    let mut peak = 0.0f64;

    match spec.sample_format {
        hound::SampleFormat::Float => {
            for sample in reader.samples::<f32>() {
                let normalized = sample.context("Failed to read WAV sample")? as f64;
                sum_square += normalized * normalized;
                peak = peak.max(normalized.abs());
                sample_count += 1;
            }
        }
        hound::SampleFormat::Int => {
            let bits = spec.bits_per_sample;
            if bits <= 16 {
                let denom = max_int_amplitude(bits);
                for sample in reader.samples::<i16>() {
                    let normalized = sample.context("Failed to read WAV sample")? as f64 / denom;
                    sum_square += normalized * normalized;
                    peak = peak.max(normalized.abs());
                    sample_count += 1;
                }
            } else {
                let denom = max_int_amplitude(bits);
                for sample in reader.samples::<i32>() {
                    let normalized = sample.context("Failed to read WAV sample")? as f64 / denom;
                    sum_square += normalized * normalized;
                    peak = peak.max(normalized.abs());
                    sample_count += 1;
                }
            }
        }
    }

    if sample_count == 0 {
        return Err(anyhow!("WAV contains no samples"));
    }

    let channels = spec.channels as usize;
    let frames = sample_count / channels;
    let duration_seconds = frames as f64 / spec.sample_rate as f64;

    let rms = (sum_square / sample_count as f64).sqrt();
    let rms_dbfs = to_dbfs(rms);
    let peak_dbfs = to_dbfs(peak.max(1e-12));

    Ok(WavMetrics {
        sample_rate: spec.sample_rate,
        channels: spec.channels,
        bits_per_sample: spec.bits_per_sample,
        duration_seconds,
        rms_dbfs,
        peak_dbfs,
        sample_count,
    })
}

fn max_int_amplitude(bits_per_sample: u16) -> f64 {
    if bits_per_sample <= 1 {
        return 1.0;
    }

    // Keep diagnostic normalization valid for 24/32-bit PCM and avoid shift overflow.
    let shift = (bits_per_sample - 1).min(62) as u32;
    ((1i64 << shift) - 1) as f64
}

fn to_dbfs(value: f64) -> f64 {
    if value <= 1e-12 {
        return f64::NEG_INFINITY;
    }
    20.0 * value.log10()
}

fn format_duration(duration: Duration) -> String {
    format!("{:.2}s", duration.as_secs_f64())
}

fn print_key_status(key_name: &str) {
    match std::env::var(key_name) {
        Ok(value) if !value.trim().is_empty() => {
            println!("- {key_name}: set ({})", mask_secret(&value));
        }
        _ => println!("- {key_name}: not set"),
    }
}

fn mask_secret(secret: &str) -> String {
    let chars: Vec<char> = secret.chars().collect();
    if chars.len() <= 8 {
        return "***".to_string();
    }

    let head: String = chars.iter().take(4).collect();
    let tail: String = chars
        .iter()
        .rev()
        .take(4)
        .copied()
        .collect::<Vec<char>>()
        .into_iter()
        .rev()
        .collect();

    format!("{head}...{tail}")
}

fn print_binary_status(binary: &str) {
    match find_binary(binary) {
        Some(path) => println!("- {binary}: {}", path.display()),
        None => println!("- {binary}: not found in PATH"),
    }
}

fn find_binary(binary: &str) -> Option<PathBuf> {
    let path_var = std::env::var_os("PATH")?;
    for dir in std::env::split_paths(&path_var) {
        let candidate = dir.join(binary);
        if candidate.is_file() {
            return Some(candidate);
        }
    }
    None
}

fn resolve_output_dir(output_dir: Option<PathBuf>) -> Result<PathBuf> {
    if let Some(dir) = output_dir {
        return Ok(dir);
    }
    let home = dirs::home_dir().context("Failed to resolve home directory")?;
    Ok(home.join("diy_typeless_recordings"))
}

fn resolve_groq_key(provided: Option<String>) -> Result<String> {
    if let Some(key) = provided {
        return Ok(key);
    }
    std::env::var("GROQ_API_KEY").context("GROQ_API_KEY not set")
}

fn resolve_gemini_key(provided: Option<String>) -> Result<String> {
    if let Some(key) = provided {
        return Ok(key);
    }
    std::env::var("GEMINI_API_KEY").context("GEMINI_API_KEY not set")
}

fn wait_for_enter() -> Result<()> {
    let mut input = String::new();
    io::stdin().read_line(&mut input)?;
    Ok(())
}

fn read_stdin() -> Result<String> {
    let mut buffer = String::new();
    io::stdin().read_to_string(&mut buffer)?;
    Ok(buffer.trim().to_string())
}

fn copy_to_clipboard(text: &str) {
    if cfg!(target_os = "macos") {
        let _ = Command::new("pbcopy")
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

fn timestamp() -> String {
    chrono::Local::now().format("%Y%m%d_%H%M%S").to_string()
}

#[cfg(test)]
mod tests {
    use super::max_int_amplitude;

    #[test]
    fn max_int_amplitude_handles_16_bit_pcm() {
        assert!((max_int_amplitude(16) - 32767.0).abs() < f64::EPSILON);
    }

    #[test]
    fn max_int_amplitude_handles_32_bit_pcm() {
        assert!((max_int_amplitude(32) - 2_147_483_647.0).abs() < f64::EPSILON);
    }
}
