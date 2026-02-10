# Evaluation Criteria

Score the polished output (B2) against the expected output (B1) on 5 dimensions, each 0-2 points. Total: 10 points.

**Core principle**: Scores are directional signals. The real question is: "Would a human accept B2 as a replacement for B1?"

## Dimensions

### 1. Language Fidelity (0-2)

Does B2 preserve the original language and not translate?

- **0**: Wrong language or significant translation
- **1**: Correct language but with unnatural phrasing or inappropriate register
- **2**: Natural, native-quality text in the correct language

### 2. Content Completeness (0-2)

Does B2 retain all substantive information from the input?

- **0**: Missing key information or added fabricated content
- **1**: Minor information loss or slight additions, but core message intact
- **2**: All substantive content preserved, only filler words removed

### 3. Structure Quality (0-2)

Is B2 well-organized as written text?

- **0**: No improvement over raw transcript, or structure makes text harder to read
- **1**: Some organization but could be better (e.g., missing paragraph breaks, inconsistent formatting)
- **2**: Clear logical structure, appropriate paragraph breaks, lists where warranted

### 4. Style & Tone (0-2)

Does B2 match the appropriate written register?

- **0**: Tone completely wrong (e.g., overly formal when casual is needed, or vice versa)
- **1**: Generally appropriate but some mismatch (e.g., too formal for a chat message)
- **2**: Tone and style match the intended context perfectly

When a context parameter is provided, weigh this dimension more heavily — the output must adapt to the specified context.

### 5. Accuracy (0-2)

Are transcription errors corrected without introducing new ones?

- **0**: New errors introduced or existing errors made worse
- **1**: Some errors fixed but others remain, or minor new issues
- **2**: Transcription errors appropriately corrected, no new errors

## Scoring Notes

- Score B2 independently, then compare with B1's expected quality
- A total of 7+ generally means human-acceptable
- A total of 5-6 means significant issues but partially usable
- A total below 5 means unacceptable
- Score fluctuations of 1 point across runs (due to LLM variance) are normal and NOT regressions
- A drop of 2+ points on the same case, or any drop that makes output human-unacceptable, IS a regression
