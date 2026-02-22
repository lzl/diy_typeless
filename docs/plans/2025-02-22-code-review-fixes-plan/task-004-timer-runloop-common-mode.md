# Task 004: Timer RunLoop Common Mode

**BDD Scenario**: Scenario 4 - AudioLevelMonitor Timer uses common runloop mode

## Goal

Fix AudioLevelMonitor's Timer to continue firing during UI interactions by adding it to RunLoop with .common mode.

## Acceptance Criteria

- [ ] In `AudioLevelMonitor.start()`, after creating the Timer
- [ ] Add timer to RunLoop.current with mode `.common`
- [ ] Waveform animation continues smoothly during mouse tracking/resizing
- [ ] No duplicate timers are created on repeated start/stop calls

## Files to Modify

- `app/DIYTypeless/DIYTypeless/Capsule/WaveformView.swift`

## Verification

```bash
./scripts/dev-loop.sh --testing
```

Build should pass. Manual test: show capsule, start recording, move mouse rapidly over window - waveform should continue animating smoothly.

## Dependencies

None

## Commit Boundary

Single commit for this task:
```
fix(capsule): add timer to common runloop mode for smooth animation
```
