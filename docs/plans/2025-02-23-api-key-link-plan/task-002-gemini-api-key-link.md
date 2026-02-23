# Task 002: Implement Gemini API Key Link

**ref**: Scenario "Gemini API Key link display" from bdd-specs.md

## Goal

Add "Get API Key" link to GeminiKeyStepView that opens aistudio.google.com/app/apikey in default browser.

## Files to Modify

- `/Users/lzl/conductor/workspaces/diy_typeless/asuncion/app/DIYTypeless/DIYTypeless/Onboarding/Steps/GeminiKeyStepView.swift`

## Implementation Requirements

1. Add a Button below the description text and above the SecureField
2. The button should display: "Don't have an API key? Get one here"
   - "Don't have an API key?" - use `.foregroundColor(.secondary)`
   - "Get one here" - use `.foregroundColor(.accentColor)` and `.underline()`
   - Font size: `.font(.system(size: 13))`
3. On tap: open `https://aistudio.google.com/app/apikey` using `NSWorkspace.shared.open()`
4. Use optional binding for URL creation to prevent crashes
5. Apply `.buttonStyle(PlainButtonStyle())` to remove default button appearance
6. Add cursor `.pointingHand` on hover

## BDD Scenario

```gherkin
Scenario: Display get link
  Given the user is viewing the Gemini API Key step
  Then should see the text "Don't have an API key? Get one here"
  And "Get one here" should be displayed as link style (with underline and accent color)

Scenario: Click link to open browser
  Given the user is viewing the Gemini API Key step
  When the user clicks "Get one here" link
  Then the system should call NSWorkspace.shared.open()
  And open URL "https://aistudio.google.com/app/apikey"
  And using the default browser
```

## Verification Steps

1. Build the project: `./scripts/dev-loop.sh --testing`
2. Run the app and navigate to Gemini API Key step
3. Verify the link text is displayed correctly
4. Verify the link has correct styling (underlined, accent color)
5. Verify clicking the link opens https://aistudio.google.com/app/apikey in default browser

## depends-on

None (can be done in parallel with Task 001)
