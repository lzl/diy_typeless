//! CLI for testing core library functionality
//!
//! This CLI provides commands to validate core logic changes before macOS app integration,
//! following the "Closing the Loop" rule from AGENTS.md.

use std::path::PathBuf;
use std::time::Duration;

use diy_typeless_core::{init_local_asr, is_local_asr_available, start_streaming_session, get_streaming_text, is_streaming_session_active, stop_streaming_session};

fn print_usage() {
    println!("DIY Typeless Core CLI");
    println!("=====================");
    println!();
    println!("Commands:");
    println!("  validate [MODEL_DIR]  - Validate streaming ASR functionality");
    println!("  check                 - Check if local ASR is available");
    println!();
    println!("Examples:");
    println!("  cargo run --bin cli -- validate /path/to/model");
    println!("  cargo run --bin cli -- check");
}

fn main() {
    let args: Vec<String> = std::env::args().collect();

    if args.len() < 2 {
        print_usage();
        std::process::exit(1);
    }

    match args[1].as_str() {
        "validate" => {
            if args.len() < 3 {
                eprintln!("Error: MODEL_DIR required");
                println!("Usage: cargo run --bin cli -- validate /path/to/model");
                std::process::exit(1);
            }
            validate_streaming(&args[2]);
        }
        "check" => {
            check_availability();
        }
        _ => {
            eprintln!("Unknown command: {}", args[1]);
            print_usage();
            std::process::exit(1);
        }
    }
}

fn check_availability() {
    println!("Checking local ASR availability...");
    if is_local_asr_available() {
        println!("  Local ASR: AVAILABLE");
    } else {
        println!("  Local ASR: NOT AVAILABLE");
    }
}

fn validate_streaming(model_dir: &str) {
    println!("Validating streaming ASR...");
    println!("  Model directory: {}", model_dir);

    let path = PathBuf::from(model_dir);
    if !path.exists() {
        eprintln!("Error: Model directory does not exist: {}", model_dir);
        std::process::exit(1);
    }

    // Initialize local ASR
    println!("  Initializing local ASR...");
    if let Err(e) = init_local_asr(model_dir.to_string()) {
        eprintln!("  Failed to initialize local ASR: {:?}", e);
        std::process::exit(1);
    }
    println!("  Local ASR initialized successfully");

    // Start streaming session
    println!("  Starting streaming session...");
    let session_id = match start_streaming_session(model_dir.to_string(), None) {
        Ok(id) => {
            println!("  Streaming session started: ID = {}", id);
            id
        }
        Err(e) => {
            eprintln!("  Failed to start streaming session: {:?}", e);
            std::process::exit(1);
        }
    };

    // Poll for 5 seconds
    println!("  Recording for 5 seconds...");
    let start = std::time::Instant::now();
    while start.elapsed() < Duration::from_secs(5) {
        if !is_streaming_session_active(session_id) {
            println!("  Session ended early");
            break;
        }
        std::thread::sleep(Duration::from_millis(500));
        let text = get_streaming_text(session_id);
        if !text.is_empty() {
            println!("  Partial text: {}", text);
        }
    }

    // Stop streaming session
    println!("  Stopping streaming session...");
    match stop_streaming_session(session_id) {
        Ok(text) => {
            println!("  Final transcription: {}", text);
            println!();
            println!("Streaming ASR validation: SUCCESS");
        }
        Err(e) => {
            eprintln!("  Failed to stop streaming session: {:?}", e);
            std::process::exit(1);
        }
    }
}
