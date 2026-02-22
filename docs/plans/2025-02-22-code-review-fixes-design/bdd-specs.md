# BDD Specifications - Code Review Fixes

## Feature: Architecture Compliance Fixes

### Scenario 1: CapsuleView uses constructor injection for AudioLevelMonitor

```gherkin
Given CapsuleView requires an AudioLevelProviding instance
When the view is initialized
Then AudioLevelMonitor should be injected via constructor
And not created directly with @State
```

### Scenario 2: Color system supports dark/light mode

```gherkin
Given the app runs on macOS
When system appearance changes between light and dark mode
Then appBackground should adapt using semantic colors
And brandPrimary can remain hardcoded as it's brand-specific
And glassBackground should use .ultraThinMaterial
```

### Scenario 3: WaveformView logs audio engine errors

```gherkin
Given WaveformView attempts to start audio engine
When an error occurs during start
Then the error should be logged using Logger
And isMonitoring should be set to false
```

### Scenario 4: AudioLevelMonitor Timer uses common runloop mode

```gherkin
Given AudioLevelMonitor starts monitoring
When a Timer is created
Then it should be added to RunLoop with .common mode
So it continues to fire during UI interactions
```

### Scenario 5: AudioLevelProviding protocol is in Domain layer

```gherkin
Given AudioLevelProviding is a protocol
When examining the project structure
Then it should be located in Domain/Protocols/
And not in Presentation/Protocols/
```

### Scenario 6: MockAudioLevelProvider is separated from production code

```gherkin
Given MockAudioLevelProvider is a test helper
When building for production
Then it should not be included in the main target
And should be located in PreviewSupport/ directory
```

## Verification Commands

```bash
# Build verification
./scripts/dev-loop.sh --testing

# Check protocol location exists
ls app/DIYTypeless/DIYTypeless/Domain/Protocols/AudioLevelProviding.swift

# Check PreviewSupport directory exists
ls app/DIYTypeless/DIYTypeless/PreviewSupport/
```
