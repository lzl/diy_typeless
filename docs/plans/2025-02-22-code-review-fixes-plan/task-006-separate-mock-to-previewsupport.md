# Task 006: Separate MockAudioLevelProvider to PreviewSupport

**BDD Scenario**: Scenario 6 - MockAudioLevelProvider is separated from production code

## Goal

Extract MockAudioLevelProvider from WaveformView.swift into a separate PreviewSupport directory to keep production code clean.

## Acceptance Criteria

- [ ] Create directory `PreviewSupport/` if it doesn't exist
- [ ] Create `PreviewSupport/MockAudioLevelProvider.swift`
- [ ] Move `MockAudioLevelProvider` class to new file
- [ ] Wrap in `#if DEBUG` / `#endif` for debug-only compilation
- [ ] Remove MockAudioLevelProvider from WaveformView.swift
- [ ] Update Xcode project to include new file in Debug configuration only
- [ ] Verify previews still work correctly

## Files to Modify

- Create: `app/DIYTypeless/DIYTypeless/PreviewSupport/MockAudioLevelProvider.swift`
- Modify: `app/DIYTypeless/DIYTypeless/Capsule/WaveformView.swift` (remove MockAudioLevelProvider)

## Verification

```bash
./scripts/dev-loop-build.sh --testing
```

Build should pass. Preview canvas should show mock waveform correctly.

## Dependencies

- Task 001 (CapsuleView Constructor Injection) - Mock may need to be updated if constructor changes

## Commit Boundary

Single commit for this task:
```
refactor(preview): extract MockAudioLevelProvider to PreviewSupport directory
```
