# Task 007: Remove Legacy Button Styles from ViewModifiers

**Priority**: P2 (Medium)
**Scope**: `/Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ViewModifiers.swift`
**Estimated Time**: 30 minutes

## Objective

Remove deprecated button style implementations from `ViewModifiers.swift`, keeping only non-button modifiers.

## Cleanup Steps

### Step 1: Remove Button Style Structs

Delete the following structs from `ViewModifiers.swift`:

1. `PrimaryButtonStyle` (lines 64-94)
2. `SecondaryButtonStyle` (lines 96-151)
3. `GhostButtonStyle` (lines 153-179)
4. `IconButtonStyle` (lines 181-211)

### Step 2: Remove Button Style View Extensions

Delete the following extension methods from `View` extension:

```swift
// DELETE these:
func primaryButton() -> some View
func secondaryButton() -> some View
func ghostButton() -> some View
func iconButton(size: CGFloat = 20) -> some View
```

### Step 3: Keep Non-Button Modifiers

Preserve these modifiers (they are not being migrated):

```swift
// KEEP these:
struct Glassmorphism: ViewModifier
struct CardContainer: ViewModifier
struct AnimatedProgressBar: ViewModifier

func glassmorphism(...) -> some View
func cardContainer(...) -> some View
```

## Final ViewModifiers.swift Structure

```swift
import SwiftUI

// MARK: - Glassmorphism Modifier
struct Glassmorphism: ViewModifier { ... }

// MARK: - Card Container Modifier
struct CardContainer: ViewModifier { ... }

// MARK: - Progress Bar Modifier
struct AnimatedProgressBar: ViewModifier { ... }

// MARK: - View Extensions
extension View {
    func glassmorphism(...) -> some View { ... }
    func cardContainer(...) -> some View { ... }
    // Note: Button style extensions removed - use ButtonStyles.swift
}
```

## Verification

1. Build the project:
   ```bash
   ./scripts/dev-loop-build.sh --testing
   ```

2. Verify no compilation errors

3. Verify no broken imports or references

4. Final grep to confirm no legacy button code remains:
   ```bash
   grep -n "PrimaryButtonStyle\|SecondaryButtonStyle\|GhostButtonStyle\|IconButtonStyle" \
     /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless/DIYTypeless/Presentation/DesignSystem/ViewModifiers.swift
   ```
   Expected: No matches (or only in comments if documenting the change)

## Dependencies

- **Depends on**: Task 006 (all call sites must be migrated first)
- **Blocks**: None (final task)

## Notes

- This is a destructive change - ensure Task 006 is fully complete
- If any issues arise, the old code can be recovered from git history
- Consider adding a file-level comment explaining that button styles have moved to `ButtonStyles.swift`
