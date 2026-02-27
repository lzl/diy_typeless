# Task 006: Migrate All Call Sites

**Priority**: P2 (Medium)
**Scope**: All Swift files using button styles
**Estimated Time**: 60 minutes

## Objective

Update all view files to use the unified button styles instead of deprecated legacy styles.

## Migration Process

### Step 1: Identify Call Sites from Task 002

Using the audit results from Task 002, create a checklist of files to update.

### Step 2: Update Each File

For each file using deprecated styles:

1. Open the file
2. Check import statements (ensure `DesignSystem` is imported if needed)
3. Replace style modifiers:
   - `.primaryButton()` → `.primaryButton()` (same API, new implementation)
   - `.secondaryButton()` → `.secondaryButton()` (same API, new implementation)
   - `.ghostButton()` → `.ghostButton()` (same API, new implementation)
   - `.iconButton()` → `.iconButton()` (verify `size` parameter if used)

4. Build and verify no deprecation warnings remain for this file

### Step 3: Handle Special Cases

#### Icon Button Size Parameter

Legacy: `iconButton(size: 20)`
Enhanced: `enhancedIconButton(size: 20)`

Unified API should support: `iconButton(size: 20)`

If sizes differ between implementations:
- Legacy default: 32pt frame, 20pt icon
- Enhanced default: 36pt frame, 20pt icon

Decision: Keep enhanced defaults (36pt) as they provide better touch targets.

#### Enhanced Style Direct Usage

If any file uses the style structs directly:

```swift
// Old
.buttonStyle(EnhancedSecondaryButtonStyle())

// New
.buttonStyle(UnifiedSecondaryButtonStyle())
```

## Verification

1. Build the project with strict warnings:
   ```bash
   ./scripts/dev-loop-build.sh --testing
   ```

2. Verify zero deprecation warnings related to button styles

3. Grep for any remaining usages:
   ```bash
   grep -r "PrimaryButtonStyle\|SecondaryButtonStyle\|GhostButtonStyle\|IconButtonStyle" \
     --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless | \
     grep -v "Unified\|deprecated"
   ```

4. Visual regression testing:
   - [ ] All buttons render correctly in Light Mode
   - [ ] All buttons render correctly in Dark Mode
   - [ ] No visual regressions in onboarding flow
   - [ ] No visual regressions in main app UI
   - [ ] No visual regressions in settings/menu

## Dependencies

- **Depends on**: Task 002 (audit results), Task 004 (unified styles), Task 005 (deprecation markers)
- **Blocks**: Task 007 (cannot remove legacy until all usages migrated)

## Rollback Plan

If issues are found:
1. Revert the specific file changes
2. Document the issue for later fix
3. Continue with other files

## Notes

- This is a mechanical refactoring - no behavior changes expected
- If any visual differences are found, document them for review
- Consider taking screenshots before/after for critical UI paths
