# Task 005: Move AudioLevelProviding to Domain Layer

**BDD Scenario**: Scenario 5 - AudioLevelProviding protocol is in Domain layer

## Goal

Move AudioLevelProviding protocol from Presentation/Protocols to Domain/Protocols to comply with Clean Architecture dependency direction.

## Acceptance Criteria

- [ ] Create directory `Domain/Protocols/` if it doesn't exist
- [ ] Move `AudioLevelProviding.swift` from `Presentation/Protocols/` to `Domain/Protocols/`
- [ ] Update all imports in files that reference the protocol
- [ ] Verify no circular dependencies are created
- [ ] Delete empty `Presentation/Protocols/` directory if it becomes empty
- [ ] Update Xcode project file references if necessary

## Files to Modify

- Create: `app/DIYTypeless/DIYTypeless/Domain/Protocols/AudioLevelProviding.swift`
- Delete: `app/DIYTypeless/DIYTypeless/Presentation/Protocols/AudioLevelProviding.swift`
- Update imports in: `WaveformView.swift`, `CapsuleView.swift`

## Verification

```bash
./scripts/dev-loop-build.sh --testing
```

Build should pass. Check that Domain layer has no external dependencies.

## Dependencies

None

## Commit Boundary

Single commit for this task:
```
refactor(domain): move AudioLevelProviding protocol to Domain layer
```
