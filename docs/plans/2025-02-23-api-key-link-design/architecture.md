# Architecture

## Component Overview

```
┌─────────────────────────────────────────┐
│         GroqKeyStepView                 │
│  ┌─────────────────────────────────┐    │
│  │  Description Text               │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  [NEW] Get API Key Link         │    │
│  │  "Don't have an API key?        │    │
│  │   Get one here"                 │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  SecureField (API Key Input)    │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │  [Validate] [Status]            │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
                     │
                     ▼
        NSWorkspace.shared.open()
                     │
                     ▼
            Default Browser
                     │
                     ▼
         https://console.groq.com/keys
```

## Modified Files

### 1. GroqKeyStepView.swift

**Location**: `/Users/lzl/conductor/workspaces/diy_typeless/asuncion/app/DIYTypeless/DIYTypeless/Onboarding/Steps/GroqKeyStepView.swift`

**Change**: Add link button between description and SecureField

**URL**: `https://console.groq.com/keys`

### 2. GeminiKeyStepView.swift

**Location**: `/Users/lzl/conductor/workspaces/diy_typeless/asuncion/app/DIYTypeless/DIYTypeless/Onboarding/Steps/GeminiKeyStepView.swift`

**Change**: Add link button between description and SecureField

**URL**: `https://aistudio.google.com/app/apikey`

## Implementation Pattern

### macOS Link Button Pattern

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
```

### Design Decisions

| Option | Pros | Cons | Choice |
|------|------|------|------|
| SwiftUI Link | Declarative, simple | Less flexible behavior on macOS | ❌ |
| Button + NSWorkspace | macOS convention, controllable | Slightly more code | ✅ |
| Custom View | Reusable | Over-engineered | ❌ |

## No Layer Changes

This feature is entirely in the **Presentation Layer**, no changes needed to:
- Domain Layer (UseCases, Entities)
- Data Layer (Repositories)
- Infrastructure Layer (FFI)

## URL Configuration

| Provider | URL | Status |
|----------|-----|--------|
| Groq | `https://console.groq.com/keys` | Stable, use directly |
| Gemini | `https://aistudio.google.com/app/apikey` | Stable, use directly |

### URL Stability Assessment

- **Groq**: Console URL structure has remained consistent since launch, unlikely to change in the short term
- **Gemini**: Google AI Studio is a newer structure (2024-2025), but is already the standard entry point

## Error Handling

```swift
// Use optional binding to avoid force unwrap crashes
if let url = URL(string: "https://console.groq.com/keys") {
    NSWorkspace.shared.open(url)
}
// Fail silently when errors occur, macOS will handle cases where it cannot open
```
