# Task 003: WaveformView Error Logging

**BDD Scenario**: Scenario 3 - WaveformView logs audio engine errors

## Goal

Add proper error logging to WaveformView when audio engine fails to start.

## Acceptance Criteria

- [ ] Import `os.log` or use `Logger` for logging
- [ ] When `audioEngine.start()` throws, log the error with description
- [ ] Log level should be `.error`
- [ ] Error message includes context: "Failed to start audio engine"
- [ ] `isMonitoring` is still set to false on error (existing behavior preserved)

## Files to Modify

- `app/DIYTypeless/DIYTypeless/Capsule/WaveformView.swift`

## Verification

```bash
./scripts/dev-loop.sh --testing
```

Build should pass. Errors will be visible in Console.app when they occur.

## Dependencies

None

## Commit Boundary

Single commit for this task:
```
fix(capsule): add error logging for audio engine startup failures
```
