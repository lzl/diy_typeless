# Task 002: Audit Button Style Usage

**Priority**: P1 (High)
**Scope**: Entire codebase
**Estimated Time**: 45 minutes

## Objective

Identify all usages of button styles across the codebase to plan migration strategy.

## Audit Checklist

### Step 1: Find All Button Style Usages

Search for usages of button style modifiers:

```bash
grep -r "\.primaryButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.secondaryButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.ghostButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.iconButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.enhancedPrimaryButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.enhancedSecondaryButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.destructiveButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.enhancedIconButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
grep -r "\.menuBarButton()" --include="*.swift" /Users/lzl/conductor/workspaces/diy_typeless/mogadishu/app/DIYTypeless
```

### Step 2: Categorize Usage Patterns

Create a mapping of:
- File path
- Style used
- Context (what the button does)
- Priority for migration

### Step 3: Identify Feature Gaps

Compare features between old and new systems:

| Feature | ViewModifiers (Old) | ButtonStyles (New) | Needed? |
|---------|---------------------|--------------------|---------|
| Hover effects | Basic | Enhanced with animations | Yes |
| Pressed scale | 0.96 | 0.96 | Keep |
| Disabled opacity | Hardcoded | Hardcoded | Unify |
| Border overlay | Yes | Yes | Keep |
| isEnabled support | Partial | Full | Yes |

## Expected Output

Create a migration matrix document listing:
1. All files using button styles
2. Recommended migration path for each
3. Styles that can be directly replaced vs. need custom handling

## Verification

- [ ] All button style usages identified
- [ ] Migration matrix created
- [ ] No usages missed (double-check with broader grep patterns)

## Dependencies

- **Depends on**: Task 001 (understand the fixed style API)
- **Blocks**: Task 004 (need usage data to design unified API)
