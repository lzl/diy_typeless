 use anyhow::{Context, Result};
 use clap::{Parser, Subcommand};
 use diy_typeless_core::{process_wav_bytes, start_recording, stop_recording};
 use std::fs;
 use std::io::{self, Read};
use std::path::PathBuf;
 use std::process::Command;
use std::thread::sleep;
use std::time::Duration;
 
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
     },
 }
 
 fn main() -> Result<()> {
    dotenvy::dotenv().ok();
     let cli = Cli::parse();
 
     match cli.command {
        Commands::Record {
            output_dir,
            duration_seconds,
        } => {
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
         }
         Commands::Transcribe {
             file,
             groq_key,
             language,
         } => {
             let api_key = resolve_groq_key(groq_key)?;
             let wav_bytes = fs::read(&file).context("Failed to read WAV file")?;
             let text =
                 diy_typeless_core::transcribe_wav_bytes(api_key, wav_bytes, language)?;
             println!("{text}");
         }
         Commands::Polish { gemini_key, text } => {
             let api_key = resolve_gemini_key(gemini_key)?;
             let raw_text = match text {
                 Some(text) => text,
                 None => read_stdin()?,
             };
             let polished = diy_typeless_core::polish_text(api_key, raw_text)?;
             println!("{polished}");
             copy_to_clipboard(&polished);
         }
         Commands::Full {
             output_dir,
             groq_key,
             gemini_key,
             language,
            duration_seconds,
         } => {
             let groq_key = resolve_groq_key(groq_key)?;
             let gemini_key = resolve_gemini_key(gemini_key)?;
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
             let base = format!("recording_{}", timestamp());
             let wav_path = output_dir.join(format!("{base}.wav"));
             fs::write(&wav_path, &wav_data.bytes)?;
 
             println!("Transcribing...");
             let result =
                 process_wav_bytes(groq_key, gemini_key, wav_data.bytes, language)?;
 
             let raw_path = output_dir.join(format!("{base}.txt"));
             fs::write(&raw_path, &result.raw_text)?;
 
             let polished_path = output_dir.join(format!("{base}_polished.txt"));
             fs::write(&polished_path, &result.polished_text)?;
 
             println!("Polished text:\n{}", result.polished_text);
             copy_to_clipboard(&result.polished_text);
 
             println!(
                 "Saved:\n- {}\n- {}\n- {}",
                 wav_path.display(),
                 raw_path.display(),
                 polished_path.display()
             );
         }
     }
 
     Ok(())
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
         let _ = Command::new("pbcopy").stdin(std::process::Stdio::piped()).spawn().and_then(
             |mut child| {
                 use std::io::Write;
                 if let Some(stdin) = child.stdin.as_mut() {
                     stdin.write_all(text.as_bytes())?;
                 }
                 child.wait()?;
                 Ok(())
             },
         );
     }
 }
 
 fn timestamp() -> String {
     chrono::Local::now().format("%Y%m%d_%H%M%S").to_string()
 }
 
