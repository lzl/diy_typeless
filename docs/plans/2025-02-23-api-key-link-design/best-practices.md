# Best Practices

## Implementation Guidelines

### 1. URL Handling

**Correct Approach**:
```swift
if let url = URL(string: "https://console.groq.com/keys") {
    NSWorkspace.shared.open(url)
}
```

**Avoid**:
```swift
// Do not force unwrap
NSWorkspace.shared.open(URL(string: "...")!)
```

### 2. Cursor Style

Use `.onHover` to modify cursor:
```swift
.onHover { hovering in
    if hovering {
        NSCursor.pointingHand.push()
    } else {
        NSCursor.pop()
    }
}
```

Or use View extension:
```swift
.cursor(.pointingHand)
```

### 3. Text Style Consistency

- Use system font: `.font(.system(size: 13))`
- Secondary text uses: `.foregroundColor(.secondary)`
- Link text uses: `.foregroundColor(.accentColor)` + `.underline()`

### 4. Button Style

Use `PlainButtonStyle()` to avoid default button appearance:
```swift
.buttonStyle(PlainButtonStyle())
```

## Accessibility

### VoiceOver Support

Add accessibility labels for links:
```swift
.accessibilityLabel("Open Groq API key page in browser")
.accessibilityHint("Opens the Groq console website where you can create an API key")
```

### Keyboard Navigation

Ensure links are accessible via keyboard:
- Tab key can focus on links
- Space or Enter key can activate links

## Performance Considerations

### NSWorkspace Calls

`NSWorkspace.shared.open()` is asynchronous, does not block the main thread, no additional handling needed.

### Memory Impact

This feature has almost no memory overhead, just adds two lightweight Button components.

## Security Considerations

### URL Validation

Although URLs are hardcoded, optional binding is still recommended:
```swift
if let url = URL(string: "https://console.groq.com/keys"),
   url.scheme == "https" {
    NSWorkspace.shared.open(url)
}
```

### Preventing Injection

Since URLs are hardcoded constants, there is no user input injection risk.

## Testing Strategy

### Manual Testing Points

1. **Link Display**: Confirm text and style are correct
2. **Link Click**: Confirm correct URL is opened
3. **Cursor Feedback**: Confirm pointing hand cursor appears on hover
4. **No Crashes**: Confirm app does not crash in various scenarios

### Build Verification

```bash
./scripts/dev-loop.sh --testing
```

## Future Considerations

### Multi-Provider Support

If more API providers need to be supported in the future, consider creating a reusable component:

```swift
struct APIKeyStepView: View {
    let provider: Provider
    let description: String
    let apiKeyURL: URL
    // ...
}
```

### Localization

If multilingual support is needed in the future, extract text to Localizable.strings:
```swift
Text(NSLocalizedString("api_key_link_prefix", comment: ""))
```

### Analytics Tracking

Consider adding analytics events:
```swift
Button(action: {
    Analytics.track(.apiKeyLinkTapped, provider: "groq")
    NSWorkspace.shared.open(url)
}) { ... }
```
