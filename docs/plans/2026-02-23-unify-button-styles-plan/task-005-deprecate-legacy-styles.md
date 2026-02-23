# Task 005: Deprecate Legacy Button Styles

**Priority**: P1 (High)
**Scope**: `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ViewModifiers.swift`
**Estimated Time**: 30 minutes

## Objective

Mark legacy button styles as deprecated to guide migration to the unified system.

## Implementation Steps

### Step 1: Add Deprecation Annotations

In `ViewModifiers.swift`, add `@available` deprecation to legacy button styles:

```swift
// MARK: - Primary Button Style (Deprecated)
@available(*, deprecated, renamed: "UnifiedPrimaryButtonStyle",
           message: "Use .primaryButton() from ButtonStyles.swift instead")
struct PrimaryButtonStyle: ButtonStyle {
    // ... existing implementation
}

// MARK: - Secondary Button Style (Deprecated)
@available(*, deprecated, renamed: "UnifiedSecondaryButtonStyle",
           message: "Use .secondaryButton() from ButtonStyles.swift instead")
struct SecondaryButtonStyle: ButtonStyle {
    // ... existing implementation
}

// MARK: - Ghost Button Style (Deprecated)
@available(*, deprecated, renamed: "UnifiedGhostButtonStyle",
           message: "Use .ghostButton() from ButtonStyles.swift instead")
struct GhostButtonStyle: ButtonStyle {
    // ... existing implementation
}

// MARK: - Icon Button Style (Deprecated)
@available(*, deprecated, renamed: "UnifiedIconButtonStyle",
           message: "Use .iconButton() from ButtonStyles.swift instead")
struct IconButtonStyle: ButtonStyle {
    // ... existing implementation
}
```

### Step 2: Add Deprecation to View Extensions

```swift
extension View {
    @available(*, deprecated, renamed: "primaryButton",
               message: "Use .primaryButton() from ButtonStyles.swift")
    func primaryButton() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    @available(*, deprecated, renamed: "secondaryButton",
               message: "Use .secondaryButton() from ButtonStyles.swift")
    func secondaryButton() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }

    // ... etc for ghostButton, iconButton
}
```

## Deprecation Strategy

| Old Style | New Style | Migration Effort |
|-----------|-----------|------------------|
| `PrimaryButtonStyle` | `UnifiedPrimaryButtonStyle` | Drop-in replacement |
| `SecondaryButtonStyle` | `UnifiedSecondaryButtonStyle` | Drop-in replacement |
| `GhostButtonStyle` | `UnifiedGhostButtonStyle` | Drop-in replacement |
| `IconButtonStyle` | `UnifiedIconButtonStyle` | Check iconSize parameter |

## Verification

1. Build the project:
   ```bash
   ./scripts/dev-loop.sh --testing
   ```

2. Expected: Compiler warnings for any usages of deprecated styles

3. Verify deprecation messages are helpful and actionable

## Dependencies

- **Depends on**: Task 004 (unified styles must exist first)
- **Blocks**: Task 006 (migration uses deprecation warnings as guide)

## Notes

- Do NOT remove the legacy implementations yet - just mark them deprecated
- The deprecation warnings will help identify all call sites that need migration
- Keep non-button modifiers (Glassmorphism, CardContainer) without deprecation
