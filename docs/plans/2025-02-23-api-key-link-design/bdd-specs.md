# BDD Specifications

## Feature: API Key Link in Onboarding

### Background

```gherkin
Given the user is using the macOS application
And the user is in the onboarding flow
```

---

## Scenario: Groq API Key Link Display

```gherkin
Feature: Groq API Key Link
  As a new user
  I want to see a get API key link on the Groq API Key input page
  So that I can quickly obtain an API key

  Scenario: Display get link
    Given the user is viewing the Groq API Key step
    Then the user should see the text "Don't have an API key? Get one here"
    And "Get one here" should be displayed as link style (with underline and accent color)

  Scenario: Click link to open browser
    Given the user is viewing the Groq API Key step
    When the user clicks "Get one here" link
    Then the system should call NSWorkspace.shared.open()
    And open URL "https://console.groq.com/keys"
    And use the default browser
```

---

## Scenario: Gemini API Key Link Display

```gherkin
Feature: Gemini API Key Link
  As a new user
  I want to see a get API key link on the Gemini API Key input page
  So that I can quickly obtain an API key

  Scenario: Display get link
    Given the user is viewing the Gemini API Key step
    Then the user should see the text "Don't have an API key? Get one here"
    And "Get one here" should be displayed as link style (with underline and accent color)

  Scenario: Click link to open browser
    Given the user is viewing the Gemini API Key step
    When the user clicks "Get one here" link
    Then the system should call NSWorkspace.shared.open()
    And open URL "https://aistudio.google.com/app/apikey"
    And use the default browser
```

---

## Scenario: Existing Functionality Protection

```gherkin
Feature: Existing Functionality Protection
  As a developer
  I want to add links without affecting the existing validation flow
  To ensure functional integrity

  Scenario: Validate button still works
    Given the user is viewing the API Key step (Groq or Gemini)
    When the user enters text in the SecureField
    Then the validate button should be enabled/disabled based on input state
    And clicking the validate button should trigger the validation flow

  Scenario: Link does not interfere with input
    Given the user is viewing the API Key step
    When the user enters text in the SecureField
    Then the link should remain visible
    And should not capture input focus
```

---

## Scenario: Edge Case Handling

```gherkin
Feature: Edge Case Handling
  As a developer
  I want the system to gracefully handle exceptional cases

  Scenario: Browser open fails
    Given the user clicked the API Key link
    And the system cannot open the browser (e.g., no default browser)
    Then the application should not crash
    And can fail silently (macOS will handle the error)

  Scenario: Invalid URL
    Given the application attempts to open URL
    And URL format is invalid
    Then the application should not crash
    And silently skip the open operation
```

---

## Test Strategy

### Manual Test Checklist

1. **UI Verification**
   - [ ] Groq step displays link text
   - [ ] Gemini step displays link text
   - [ ] Link style correct (underline + accent color)
   - [ ] Hover shows pointing hand cursor

2. **Functional Verification**
   - [ ] Clicking Groq link opens console.groq.com/keys
   - [ ] Clicking Gemini link opens aistudio.google.com/app/apikey
   - [ ] Opens using the default browser

3. **Regression Verification**
   - [ ] API key input field works normally
   - [ ] Validate button works normally
   - [ ] Validation status displays normally

### Automated Testing

- Since this involves `NSWorkspace.shared.open()` system calls, this feature is suitable for manual testing
- Ensure build passes: `./scripts/dev-loop-build.sh --testing`
