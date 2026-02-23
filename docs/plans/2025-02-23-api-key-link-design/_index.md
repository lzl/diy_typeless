# API Key Link Design

## Context

The current onboarding flow includes two API Key input steps (Groq and Gemini), but lacks guidance for users to obtain API keys. New users may not know how to get these keys, causing the onboarding flow to be interrupted.

## Requirements

### Functional Requirements

1. **FR-1: Groq API Key link**
   - Add a link to obtain API key in GroqKeyStepView
   - URL: `https://console.groq.com/keys`
   - Open in default browser when clicked

2. **FR-2: Gemini API Key link**
   - Add a link to obtain API key in GeminiKeyStepView
   - URL: `https://aistudio.google.com/app/apikey`
   - Open in default browser when clicked

3. **FR-3: Link Opening Method**
   - Use `NSWorkspace.shared.open()` method
   - Execute asynchronously without blocking the main thread
   - Fail silently when errors occur

### UI/UX Requirements

1. **UX-1: Layout Position**
   - Add link below description text and above SecureField
   - Maintain existing VStack structure with spacing 16

2. **UX-2: Visual Style**
   - Use combined text: "Don't have an API key? Get one here"
   - "Don't have an API key?" - `.secondary` color
   - "Get one here" - `.accentColor` + underline
   - Font size: 13pt

3. **UX-3: Interaction Feedback**
   - Show pointing hand cursor on hover
   - Use Button component (macOS design convention)

### Success Criteria

| ID | Criteria | Verification Method |
|------|------|----------|
| SC-1 | Groq step displays link | Visual inspection |
| SC-2 | Gemini step displays link | Visual inspection |
| SC-3 | Clicking link opens correct URL | Functional testing |
| SC-4 | Link style matches macOS | UI review |
| SC-5 | Does not affect existing validation | Regression testing |
| SC-6 | Code compiles with xcodebuild | Build Verification |

## Design Decisions

### Use Button Instead of Link

Although SwiftUI provides a `Link` component, macOS apps are more accustomed to using the combination of `Button` + `NSWorkspace.shared.open()` for better control over opening behavior.

### Text Link Style

Choose a simple text link instead of a standalone button because:
1. Does not interfere with primary actions (Validate)
2. Consistent with link style in macOS System Preferences
3. Keeps the interface clean

### Hardcoded URLs

URLs are hardcoded directly in View files because:
1. These URLs are provided by third-party services, the app cannot control them
2. Low probability of changes in the short term
3. Avoids over-engineering a configuration system

## Implementation Notes

### Code Location

- `/Users/lzl/conductor/workspaces/diy_typeless/asuncion/app/DIYTypeless/DIYTypeless/Onboarding/Steps/GroqKeyStepView.swift`
- `/Users/lzl/conductor/workspaces/diy_typeless/asuncion/app/DIYTypeless/DIYTypeless/Onboarding/Steps/GeminiKeyStepView.swift`

### Suggested Code Structure

```swift
Button(action: {
    if let url = URL(string: "https://console.groq.com/keys") {
        NSWorkspace.shared.open(url)
    }
}) {
    HStack(spacing: 0) {
        Text("Don't have an API key? ")
            .foregroundColor(.secondary)
        Text("Get one here")
            .foregroundColor(.accentColor)
            .underline()
    }
    .font(.system(size: 13))
}
.buttonStyle(PlainButtonStyle())
.cursor(.pointingHand)
```

## Design Documents

- [BDD Specifications](./bdd-specs.md) - Behavior scenarios and testing strategy
- [Architecture](./architecture.md) - System architecture and component details
- [Best Practices](./best-practices.md) - Implementation guidelines and considerations
