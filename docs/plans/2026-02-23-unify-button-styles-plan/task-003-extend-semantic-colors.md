# Task 003: Extend Semantic Color System

**Priority**: P1 (High)
**Scope**: `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/Colors.swift`
**Estimated Time**: 45 minutes

## Objective

Add button-specific semantic colors to `Colors.swift` to support unified button styles without hardcoded values.

## Current State Analysis

Existing semantic colors in `Colors.swift`:
- `appBackground`, `appBackgroundSecondary`, `appSurface` - Background colors
- `textPrimary`, `textSecondary`, `textMuted` - Text colors
- `brandPrimary`, `brandAccent`, etc. - Brand colors

Missing: Button state colors that adapt to Light/Dark mode.

## Implementation Steps

### Step 1: Add Button Background Colors

Add the following to `Colors.swift`:

```swift
// MARK: - Button Colors
extension Color {
    /// Secondary button background (neutral, adaptive)
    static var buttonSecondaryBackground: Color {
        Color(nsColor: .quaternarySystemFill)
    }

    /// Secondary button background when hovered
    static var buttonSecondaryBackgroundHover: Color {
        Color(nsColor: .tertiarySystemFill)
    }

    /// Secondary button background when pressed
    static var buttonSecondaryBackgroundPressed: Color {
        Color(nsColor: .secondarySystemFill)
    }

    /// Secondary button border
    static var buttonSecondaryBorder: Color {
        Color(nsColor: .separatorColor)
    }

    /// Secondary button border when hovered
    static var buttonSecondaryBorderHover: Color {
        Color(nsColor: .separatorColor).opacity(0.8)
    }

    /// Secondary button border when pressed
    static var buttonSecondaryBorderPressed: Color {
        Color(nsColor: .separatorColor).opacity(0.6)
    }
}
```

### Step 2: Add Icon Button Colors

```swift
extension Color {
    /// Icon button background when hovered
    static var buttonIconBackgroundHover: Color {
        Color(nsColor: .quaternarySystemFill)
    }

    /// Icon button background when pressed
    static var buttonIconBackgroundPressed: Color {
        Color(nsColor: .tertiarySystemFill)
    }
}
```

### Step 3: Add Menu Button Colors

```swift
extension Color {
    /// Menu bar button background when hovered
    static var buttonMenuBackgroundHover: Color {
        Color(nsColor: .quaternarySystemFill)
    }

    /// Menu bar button background when pressed
    static var buttonMenuBackgroundPressed: Color {
        Color(nsColor: .tertiarySystemFill)
    }
}
```

## NSColor Semantic Reference

| NSColor | Light Mode | Dark Mode | Use Case |
|---------|------------|-----------|----------|
| `.quaternarySystemFill` | Light gray | Dark gray | Default button background |
| `.tertiarySystemFill` | Medium gray | Medium dark | Hover state |
| `.secondarySystemFill` | Darker gray | Lighter gray | Pressed state |
| `.separatorColor` | Light border | Dark border | Borders |

## Verification

1. Build the project:
   ```bash
   ./scripts/dev-loop-build.sh --testing
   ```

2. Verify new colors compile and are accessible

3. Test in both Light and Dark mode preview

## Dependencies

- **Depends on**: Task 001 (understand what colors are needed)
- **Blocks**: Task 004 (unified button styles need these colors)

## Notes

- Use `@available` if needed for macOS version compatibility
- Document any macOS version requirements
- Keep colors lazy/computed (not stored) to respond to mode changes
