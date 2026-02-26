# Task 001: Add SelectedTextContext.empty

## Description

Add a static `.empty` property to `SelectedTextContext` for use when no text is selected or prefetch was cancelled.

## BDD Scenario

N/A - Infrastructure task

## Acceptance Criteria

- [ ] `SelectedTextContext.empty` returns a context with:
  - `text: nil`
  - `isEditable: false`
  - `isSecure: false`
  - `applicationName: ""`

## Implementation Notes

Add extension to `SelectedTextContext.swift` or create new file `SelectedTextContext+Empty.swift`:

```swift
extension SelectedTextContext {
    static var empty: SelectedTextContext {
        SelectedTextContext(
            text: nil,
            isEditable: false,
            isSecure: false,
            applicationName: ""
        )
    }
}
```

## Location

File: `app/DIYTypeless/DIYTypeless/Domain/Entities/SelectedTextContext.swift`

Or create: `app/DIYTypeless/DIYTypeless/Domain/Extensions/SelectedTextContext+Empty.swift`

## depends-on

None

## Estimated Effort

5 minutes
