# DIYTypeless macOS App UI/UX Enhancement Plan

## Architecture Compliance Notice

This plan strictly adheres to Clean Architecture principles:
- **ViewModels** manage business state only (no animation state)
- **Views** manage visual presentation and animation state via `@State`
- **Design System** is pure presentation layer with no business logic
- All dependencies point inward toward Domain layer

---

## Current Issues

1. **Primitive Color Scheme**: Hard-coded colors (`Color(white: 0.12)`) with no unified design system
2. **Basic Animations**: Only simple fade transitions (`easeInOut(duration: 0.2)`), lacking micro-interactions
3. **Plain Capsule Window**: Solid black background without texture, looks like a prototype
4. **Lifeless Waveform**: Simple bar chart without color variation or fluid transitions
5. **Abrupt Onboarding**: Step transitions lack visual guidance and smooth animations
6. **Weak State Feedback**: Recording/transcribing/polishing/completed states lack visual impact

---

## Key Insights Beyond Your Current Thinking

### 1. Breathing Animation for Voice Assistants
Your capsule window is static. Excellent voice assistants (Siri, ChatGPT Voice) have **breathing animations**—subtle rhythmic effects that let users feel "it's listening." This isn't decoration; it's a core **visibility of system status** design principle.

### 2. Narrative Design with Progressive Disclosure
Your Onboarding is a 6-step linear flow. Consider the "Horizontal Scroll Journey" pattern—wrap steps into a coherent narrative with unique theme colors per step (microphone=blue, API Key=brand colors), using background gradients to convey progress.

### 3. Proper Glassmorphism
macOS native design language centers on depth and materials. Your capsule should use `Material` + `blur` effects with system light/dark mode adaptation, not hard-coded black.

### 4. Advanced Audio Visualization
Current waveform uses 20 static bars. Upgrade to:
- **Fluid waveform**: Smooth flow using `AnimatableData`
- **Spectrum colors**: Map audio frequency to color (low=warm, high=cool)
- **Particle effects**: Tiny light points dancing with audio

---

## Design System

### Color Palette (OLED Dark Mode)

| Role | Hex | SwiftUI |
|------|-----|---------|
| Background Deep | #0A0A0F | `Color.appBackground` |
| Background Secondary | #141419 | `Color.appBackgroundSecondary` |
| Primary | #0D9488 | `Color.brandPrimary` |
| Accent | #F97316 | `Color.brandAccent` |
| Success | #10B981 | `Color.success` |
| Text Primary | #F8FAFC | `.primary` |
| Text Secondary | #94A3B8 | `.secondary` |
| Glass Background | rgba(20,20,25,0.85) | `Material` + opacity |

### Typography System

Use system font (SF Pro) with weight/size hierarchy:

| Level | Size | Weight | Usage |
|-------|------|--------|-------|
| Title | 28pt | .bold | Onboarding titles |
| Subtitle | 20pt | .semibold | Step titles |
| Body | 16pt | .regular | Descriptions |
| Small | 13pt | .medium | Labels, status |
| Tiny | 11pt | .regular | Auxiliary info |

### Spacing System

| Token | Value | Usage |
|-------|-------|-------|
| xs | 4pt | Icon padding |
| sm | 8pt | Compact spacing |
| md | 16pt | Standard spacing |
| lg | 24pt | Section spacing |
| xl | 32pt | Large section spacing |

### Corner Radius System

| Token | Value | Usage |
|-------|-------|-------|
| sm | 6pt | Small buttons |
| md | 8pt | Standard buttons |
| lg | 12pt | Cards |
| full | 9999pt | Pill shapes |

---

## Animation System

### Timing Curves

| Scenario | Duration | Curve |
|----------|----------|-------|
| Micro-interaction | 150ms | `.easeOut` |
| State change | 250ms | `.easeInOut` |
| Page transition | 350ms | `.spring()` |
| Breathing animation | 2000ms | `.easeInOut` (loop) |

### Core Animation Specs

```swift
// Capsule appearance
.animation(.spring(response: 0.35, dampingFraction: 0.8), value: isVisible)

// State transition
.animation(.easeInOut(duration: 0.25), value: capsuleState)

// Waveform bars
.animation(.linear(duration: 0.05), value: audioLevels)
```

---

## Implementation Tasks

### Phase 1: Design System Infrastructure

**Task 1.1: Create DesignSystem/Colors.swift**
```swift
// Presentation/DesignSystem/Colors.swift
// Pure color values, no business logic

extension Color {
    static let appBackground = Color(hex: "#0A0A0F")
    static let appBackgroundSecondary = Color(hex: "#141419")
    static let brandPrimary = Color(hex: "#0D9488")
    static let brandAccent = Color(hex: "#F97316")
    static let success = Color(hex: "#10B981")

    static var glassBackground: Color {
        Color(nsColor: .windowBackgroundColor).opacity(0.85)
    }
}
```

**Task 1.2: Create DesignSystem/Animations.swift**
```swift
// Presentation/DesignSystem/Animations.swift
// Animation curves and ViewModifiers

enum AppAnimation {
    static let micro = Animation.easeOut(duration: 0.15)
    static let stateChange = Animation.easeInOut(duration: 0.25)
    static let pageTransition = Animation.spring(response: 0.35, dampingFraction: 0.8)

    static func breathing(duration: Double = 2.0) -> Animation {
        .easeInOut(duration: duration).repeatForever(autoreverses: true)
    }
}

struct BreathingEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let intensity: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 + phase * intensity)
            .animation(AppAnimation.breathing(), value: phase)
            .onAppear { phase = 1 }
    }
}
```

**Task 1.3: Create DesignSystem/ViewModifiers.swift**
```swift
// Presentation/DesignSystem/ViewModifiers.swift
// Reusable view modifiers

struct Glassmorphism: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

struct AppButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

**Architecture Note**: Design System components are pure presentation layer. They contain no business logic and don't depend on ViewModels.

---

### Phase 2: Capsule Window Refactoring

**Task 2.1: Refactor CapsuleView Visual Design**
```swift
// Presentation/Views/Capsule/CapsuleView.swift

struct CapsuleView: View {
    @Bindable var state: RecordingState
    // Animation state stays in View, NOT in ViewModel
    @State private var glowIntensity: CGFloat = 0

    var body: some View {
        ZStack {
            glassBackground
            content
        }
        .modifier(Glassmorphism())
        .onChange(of: state.capsuleState) { updateGlow(for: $0) }
    }

    private var glassBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}
```

**Task 2.2: Enhance WaveformView with Protocol Abstraction**
```swift
// Presentation/Protocols/AudioLevelProviding.swift
protocol AudioLevelProviding: AnyObject {
    var levels: [CGFloat] { get }
    func start()
    func stop()
}

// Presentation/Views/Capsule/WaveformView.swift
struct WaveformView: View {
    @Bindable var state: RecordingState
    let audioProvider: AudioLevelProviding

    init(state: RecordingState,
         audioProvider: AudioLevelProviding = AudioLevelMonitor()) {
        self.state = state
        self.audioProvider = audioProvider
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                WaveformBar(
                    level: audioProvider.levels[safe: index] ?? 0,
                    color: barColor(for: index)
                )
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        // Color mapping based on position and audio intensity
        let intensity = audioProvider.levels[safe: index] ?? 0
        return intensity > 0.7 ? .brandAccent : .brandPrimary
    }
}
```

**Architecture Note**: `AudioLevelProviding` protocol enables testing with mock data. ViewModel (`RecordingState`) remains unchanged.

**Task 2.3: Add State Transition Animations**
```swift
// Presentation/Views/Capsule/CapsuleView.swift

private var statusIcon: some View {
    Group {
        switch state.capsuleState {
        case .recording:
            RecordingIndicator()  // Red pulsing dot
        case .transcribing:
            WaveIcon()  // Animated wave
        case .polishing:
            SparkleIcon()  // Animated sparkle
        case .completed:
            CheckmarkIcon()  // Animated checkmark
        default:
            EmptyView()
        }
    }
    .transition(.scale.combined(with: .opacity))
    .animation(AppAnimation.stateChange, value: state.capsuleState)
}
```

**Task 2.4: Implement Breathing Animation System (View Layer Only)**
```swift
// Presentation/Views/Capsule/CapsuleView.swift

struct CapsuleView: View {
    @Bindable var state: RecordingState
    @State private var breathPhase: CGFloat = 0  // View's own state

    var body: some View {
        ZStack {
            backgroundView
            content
        }
        .scaleEffect(breathScale)
        .animation(breathAnimation, value: breathPhase)
        .onChange(of: state.capsuleState) { updateBreathing(for: $0) }
    }

    private var breathScale: CGFloat {
        guard case .recording = state.capsuleState else { return 1.0 }
        return 1.0 + (breathPhase * 0.02)  // Subtle 2% breathing
    }

    private var breathAnimation: Animation {
        .easeInOut(duration: 2).repeatForever(autoreverses: true)
    }

    private func updateBreathing(for state: CapsuleState) {
        breathPhase = (state == .recording) ? 1 : 0
    }
}
```

**Critical Architecture Rule**: Breathing animation state (`breathPhase`) stays in View via `@State`. `RecordingState` (ViewModel) only tracks business state (`capsuleState`).

---

### Phase 3: Onboarding Experience Upgrade

**Task 3.1: Step Transition Animations (Direction in View, Not ViewModel)**
```swift
// Presentation/Views/Onboarding/OnboardingContainerView.swift

struct OnboardingContainerView: View {
    @Bindable var state: OnboardingState
    @State private var previousStep: OnboardingStep = .welcome  // View state

    var body: some View {
        currentStepView
            .transition(asymmetricTransition)
            .animation(AppAnimation.pageTransition, value: state.step)
            .onChange(of: state.step) { oldValue, _ in
                previousStep = oldValue  // Track for direction calculation
            }
    }

    private var asymmetricTransition: AnyTransition {
        // View calculates direction, NOT ViewModel
        let isForward = state.step.rawValue > previousStep.rawValue
        return .asymmetric(
            insertion: .move(edge: isForward ? .trailing : .leading),
            removal: .move(edge: isForward ? .leading : .trailing)
        )
    }
}
```

**Critical Architecture Rule**: Direction calculation happens in View using `@State`. `OnboardingState` tracks current step only, not transition direction.

**Task 3.2: Visual Optimization for Each Step**
```swift
// Presentation/Views/Onboarding/Steps/WelcomeStepView.swift

struct WelcomeStepView: View {
    @Bindable var state: OnboardingState

    var body: some View {
        ZStack {
            // Dynamic gradient background
            MeshGradientBackground()

            VStack(spacing: .lg) {
                appIcon
                title
                featureList
            }
        }
    }
}

// Presentation/Views/Onboarding/Steps/MicrophoneStepView.swift

struct MicrophoneStepView: View {
    @Bindable var state: OnboardingState
    @State private var pulseScale: CGFloat = 1.0  // Animation in View

    var body: some View {
        VStack {
            Image(systemName: "mic.fill")
                .font(.system(size: 48))
                .foregroundStyle(.brandPrimary)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: pulseScale
                )
                .onAppear { pulseScale = 1.1 }
        }
    }
}
```

**Task 3.3: Enhanced ValidationStatusView**
```swift
// Presentation/Views/Onboarding/Components/ValidationStatusView.swift

struct ValidationStatusView: View {
    let status: ValidationState

    var body: some View {
        Group {
            switch status {
            case .validating:
                ProgressView()
                    .scaleEffect(0.8)
            case .success:
                CheckmarkAnimation()  // Stroke animation
            case .failure:
                ErrorShakeAnimation() // Shake + fade
            }
        }
    }
}

struct ErrorShakeAnimation: ViewModifier {
    @State private var shakeOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onAppear {
                withAnimation(.spring(response: 0.1, dampingFraction: 0.2)) {
                    shakeOffset = 5
                }
            }
    }
}
```

---

### Phase 4: Micro-interactions and Feedback

**Task 4.1: Button Interaction System**
```swift
// Presentation/DesignSystem/ButtonStyles.swift

struct PrimaryButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, .md)
            .padding(.vertical, .sm)
            .background(backgroundColor(for: configuration))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: .md))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(for configuration: Configuration) -> Color {
        if configuration.isPressed { return .brandPrimary.opacity(0.8) }
        if isHovered { return .brandPrimary.opacity(0.9) }
        return .brandPrimary
    }
}
```

**Task 4.2: Enhanced Status Feedback**
```swift
// Presentation/Views/Capsule/CapsuleView.swift

private var statusText: some View {
    Text(statusLabel)
        .contentTransition(.opacity)  // Smooth text transitions
        .animation(AppAnimation.stateChange, value: state.capsuleState)
}

private var statusLabel: String {
    switch state.capsuleState {
    case .recording: return "Listening..."
    case .transcribing: return "Transcribing..."
    case .polishing: return "Polishing..."
    case .completed: return "Done!"
    default: return ""
    }
}
```

**Task 4.3: Menu Bar Icon States**
```swift
// MenuBar/MenuBarView.swift

struct MenuBarIcon: View {
    @Bindable var state: AppState

    var body: some View {
        Image(systemName: iconName)
            .symbolEffect(.pulse, options: .repeating, value: isRecording)
    }

    private var iconName: String {
        state.recordingState.capsuleState == .recording
            ? "mic.fill"
            : "mic"
    }

    private var isRecording: Bool {
        state.recordingState.capsuleState == .recording
    }
}
```

---

## Directory Structure

```
app/DIYTypeless/DIYTypeless/
├── Presentation/
│   ├── DesignSystem/              ✅ NEW
│   │   ├── Colors.swift
│   │   ├── Animations.swift
│   │   ├── Typography.swift
│   │   └── ViewModifiers.swift
│   ├── Protocols/                 ✅ NEW
│   │   └── AudioLevelProviding.swift
│   ├── Views/
│   │   ├── Capsule/
│   │   │   ├── CapsuleView.swift
│   │   │   ├── WaveformView.swift
│   │   │   └── WaveformBar.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingWindow.swift
│   │   │   ├── OnboardingContainerView.swift
│   │   │   └── Steps/
│   │   │       ├── WelcomeStepView.swift
│   │   │       ├── MicrophoneStepView.swift
│   │   │       ├── GroqKeyStepView.swift
│   │   │       ├── GeminiKeyStepView.swift
│   │   │       └── CompletionStepView.swift
│   │   └── Components/
│   │       └── ValidationStatusView.swift
│   └── State/
│       ├── AppState.swift          (unchanged)
│       ├── RecordingState.swift    (unchanged - no animation state)
│       └── OnboardingState.swift   (unchanged - no direction state)
```

---

## BDD Test Scenarios

### Feature: Capsule Window Visual Experience

```gherkin
Scenario: Capsule window appearance animation
  Given the user presses the Fn key
  When the capsule window appears
  Then it should animate from bottom with spring curve
  And fade in with opacity transition

Scenario: Recording state breathing animation
  Given the capsule is in recording state
  When the user holds the Fn key
  Then the capsule should have subtle scale breathing
  And the waveform should respond to audio in real-time
  And the glow should pulse rhythmically

Scenario: State transition animation
  Given the capsule is in recording state
  When the user releases the Fn key
  Then the status icon should morph to transcribing icon
  And the progress bar should fill from left to right
  And the status text should crossfade
```

### Feature: Onboarding Experience

```gherkin
Scenario: Step transition animation
  Given the user is in the onboarding flow
  When they click the "Next" button
  Then the current step should slide out left
  And the new step should slide in from right
  And the step indicator should animate

Scenario: API Key validation feedback
  Given the user enters an API key
  When they click "Validate"
  Then the button should show loading state
  And on success, display checkmark stroke animation
  And the input field should show success border
```

---

## Architecture Compliance Checklist

### Layer Separation
- [ ] ViewModels contain NO animation state (@State for business logic only)
- [ ] Views manage visual state via @State
- [ ] Design System has no dependencies on ViewModels
- [ ] Domain layer unchanged by UI enhancements

### State Management
- [ ] `RecordingState.capsuleState` is pure business state
- [ ] Breathing animation state stays in `CapsuleView` via `@State`
- [ ] `OnboardingState.step` has no direction information
- [ ] Transition direction calculated in View layer

### Testability
- [ ] `AudioLevelProviding` protocol enables mock testing
- [ ] ViewModels testable without UI components
- [ ] Animation logic doesn't affect business logic tests

### Dependencies
- [ ] Design System → no dependencies (pure values)
- [ ] Views → depend on Design System + ViewModels
- [ ] ViewModels → depend on Domain UseCases
- [ ] All arrows point inward toward Domain

---

## Verification Checklist

### Visual Quality
- [ ] Capsule window has glassmorphism texture
- [ ] Waveform animates at 60fps
- [ ] Light/dark mode adaptation works
- [ ] No hardcoded colors, all from Design System

### Interaction Experience
- [ ] All buttons have clear hover/pressed states
- [ ] State transitions are smooth and natural
- [ ] Breathing animation doesn't interfere with content
- [ ] Respects `prefersReducedMotion` setting

### Code Quality
- [ ] Design System components are reusable
- [ ] Animation logic is cleanly encapsulated
- [ ] No performance issues (Instruments verified)
- [ ] Supports macOS 13.0+

### Architecture Compliance
- [ ] ViewModels remain free of animation state
- [ ] Views properly manage their @State
- [ ] Dependencies flow inward only
- [ ] All layers independently testable
