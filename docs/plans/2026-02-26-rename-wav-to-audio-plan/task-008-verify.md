# Task 008: Final Verification

## Objective

Run comprehensive verification to ensure all renames are complete and the system works end-to-end.

## Files to Verify (Not Modify)

All previously modified files.

## BDD Scenario Reference

All scenarios: 1, 2, 3, 4, 5, 6, 7

## Verification Steps

### 1. Rust Core Build
```bash
cargo build -p diy_typeless_core --release
echo "Exit code: $?"
```
Expected: Exit code 0

### 2. Rust Tests
```bash
cargo test -p diy_typeless_core
echo "Exit code: $?"
```
Expected: All tests pass

### 3. CLI Build
```bash
cargo build -p diy-typeless-cli --release
echo "Exit code: $?"
```
Expected: Exit code 0

### 4. Xcode Build
```bash
./scripts/dev-loop-build.sh --testing 2>&1 | tail -20
```
Expected: ** BUILD SUCCEEDED **

### 5. Check for Remaining "Wav" References
```bash
# Search for remaining WavData in Swift (excluding generated comments)
grep -r "WavData" app/DIYTypeless --include="*.swift" | grep -v "//"

# Search for transcribeWavBytes in Swift
grep -r "transcribeWavBytes" app/DIYTypeless --include="*.swift"

# Search in Rust (should only be in comments or actual WAV handling)
grep -r "WavData" core/src --include="*.rs" | grep -v "//"
grep -r "transcribe_wav_bytes" core/src --include="*.rs" | grep -v "//"
```
Expected: No matches (or only in CLI wav.rs for actual WAV handling)

### 6. Verify New Names Exist
```bash
# Check AudioData in Swift
grep -r "AudioData" app/DIYTypeless --include="*.swift" | head -5

# Check transcribeAudioBytes in Swift
grep -r "transcribeAudioBytes" app/DIYTypeless --include="*.swift"

# Check in Rust
grep -r "AudioData" core/src --include="*.rs" | head -5
grep -r "transcribe_audio_bytes" core/src --include="*.rs"
```
Expected: Multiple matches showing new names are in use

## Dependencies

- **depends-on**: All previous tasks (001-007)

## Success Criteria

- [ ] Rust core builds without errors
- [ ] Rust tests pass
- [ ] CLI builds without errors
- [ ] Xcode build succeeds
- [ ] No `WavData` references remain in Swift code
- [ ] No `transcribeWavBytes` references remain in Swift code
- [ ] `AudioData` is used in Swift code
- [ ] `transcribeAudioBytes` is used in Swift code

## Rollback Trigger

If any verification step fails:
1. Identify the failing task
2. Fix the issue or revert to previous state
3. Re-run verification
