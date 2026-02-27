# API Key Link Implementation Plan

## Goal

Add "Get API Key" links to Groq and Gemini onboarding steps, directing users to provider console pages to create API keys.

## Design Reference

- Design Document: `docs/plans/2025-02-23-api-key-link-design/`
- BDD Specifications: `docs/plans/2025-02-23-api-key-link-design/bdd-specs.md`

## Architecture

This implementation is purely in the Presentation Layer:

```
Presentation Layer (SwiftUI Views)
├── GroqKeyStepView.swift [MODIFY]
│   └── Add: Button opening https://console.groq.com/keys
└── GeminiKeyStepView.swift [MODIFY]
    └── Add: Button opening https://aistudio.google.com/app/apikey
```

No changes needed to Domain, Data, or Infrastructure layers.

## Constraints

1. Use `NSWorkspace.shared.open()` for opening URLs
2. Use optional binding for URL creation (safety)
3. Apply `.buttonStyle(PlainButtonStyle())` for link appearance
4. Match existing design system (font size 13, secondary/accent colors)
5. Keep spacing consistent with existing VStack (spacing: 16)

## Execution Plan

### Phase 1: Implementation

| Task | Description | BDD Scenario | Files Modified |
|------|-------------|--------------|----------------|
| [Task 001](./task-001-groq-api-key-link.md) | Add link to Groq step | Groq API Key link display | GroqKeyStepView.swift |
| [Task 002](./task-002-gemini-api-key-link.md) | Add link to Gemini step | Gemini API Key link display | GeminiKeyStepView.swift |

### Phase 2: Verification

| Task | Description | BDD Scenario | Depends On |
|------|-------------|--------------|------------|
| [Task 003](./task-003-build-verification.md) | Build verification and regression testing | Existing Functionality Protection, Edge Case Handling | Task 001, Task 002 |

## Implementation Order

Tasks 001 and 002 are **independent** and can be executed in parallel.
Task 003 depends on both 001 and 002.

```
Task 001 ──┐
           ├──→ Task 003
Task 002 ──┘
```

## Success Criteria

- [ ] Groq step displays "Get API Key" link with correct styling
- [ ] Gemini step displays "Get API Key" link with correct styling
- [ ] Clicking Groq link opens https://console.groq.com/keys
- [ ] Clicking Gemini link opens https://aistudio.google.com/app/apikey
- [ ] Build passes: `./scripts/dev-loop-build.sh --testing`
- [ ] Existing validation functionality remains intact
- [ ] No crashes when opening links

## Commit Strategy

Single commit for all changes:
```
feat(onboarding): add API key links to Groq and Gemini steps

Add "Get one here" link to GroqKeyStepView and GeminiKeyStepView.
Links open provider console pages in default browser.

- Groq: https://console.groq.com/keys
- Gemini: https://aistudio.google.com/app/apikey

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```
