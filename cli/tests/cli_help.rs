//! Integration tests for CLI argument parsing and top-level help surfaces.

use std::process::Command;

#[test]
fn cli_should_print_top_level_help() {
    let output = Command::new(env!("CARGO_BIN_EXE_diy_typeless_cli"))
        .arg("--help")
        .output()
        .expect("help command should run");
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("CLI for DIY Typeless"));
    assert!(stdout.contains("record"));
    assert!(stdout.contains("diagnose"));
}

#[test]
fn cli_should_print_diagnose_help() {
    let output = Command::new(env!("CARGO_BIN_EXE_diy_typeless_cli"))
        .args(["diagnose", "--help"])
        .output()
        .expect("diagnose help command should run");
    assert!(output.status.success());
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("env"));
    assert!(stdout.contains("audio"));
    assert!(stdout.contains("pipeline"));
}

#[test]
fn cli_should_fail_for_unknown_subcommand() {
    let output = Command::new(env!("CARGO_BIN_EXE_diy_typeless_cli"))
        .arg("unknown")
        .output()
        .expect("unknown command should run");
    assert!(!output.status.success());
    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(stderr.contains("unrecognized subcommand"));
}
