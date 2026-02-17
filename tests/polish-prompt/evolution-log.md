# Polish Prompt Evolution Log

Record of all prompt modifications, their rationale, and outcomes.

---

## 2026-02-10 — Strengthen list formatting directive

**Target**: Fix structure quality issues in cases 001 and 002 — output should use lists to organize parallel points instead of continuous paragraphs

**Change**:
1. Promoted list formatting directive from Rule 3 sub-bullet to standalone Rule 4
2. Added BAD/GOOD few-shot example to reinforce the instruction
3. Used "NEVER as separate paragraphs" negative constraint

Before (Rule 3):
```
3. Reorganize content logically:
   - Group related information together
   - Separate different topics into paragraphs with blank lines
   - Use numbered lists when content describes steps, features, or multiple points
```

After (Rule 3-4):
```
3. Reorganize content logically:
   - Group related information together
   - Separate different topics into paragraphs with blank lines
4. When content contains multiple parallel points, requirements, or items, ALWAYS format them as a numbered or bulleted list — NEVER as separate paragraphs. Example:
   BAD: "First issue is performance. Second issue is UI complexity."
   GOOD: "Issues encountered:\n1. Performance bottlenecks\n2. UI complexity"
```

**Result**:
| Case | Before | After | Delta |
|------|--------|-------|-------|
| 001-chinese-casual | 9/10 | 10/10 | +1 |
| 002-english-filler | 8/10 | 8/10 | 0 |
| 003-english-with-context | 9/10 | 9/10 | 0 |

- **001 improved**: Output changed from continuous paragraphs to structured text with lists, structure quality improved from 1 to 2 points
- **002 unchanged**: Gemini still interprets content as progressive narrative rather than parallel points, no list generated. Two runs produced consistent results, indicating this is not random variance
- **003 maintained**: Already had lists, continues to maintain

**Constraint discovered**:
- Few-shot examples significantly improve Gemini's format compliance, but remain limited by LLM's semantic understanding of input content
- When input text's parallel structure is not obvious (e.g., 002's progressive narrative), even strong directives and examples may not trigger list generation
- Further optimization may require more fundamental prompt restructuring (e.g., two-step processing: extract points first, then format), but this increases complexity and token consumption

**Remaining issues**:
- Cases 002 and 003 still exhibit over-formalization (Rule 2's "Transform colloquial expressions into formal written style" is too strong)
- Case 003's Slack context fails to sufficiently suppress formal tone

---

## 2026-02-17 — Fix over-formalization and add email context support

**Target**: Fix over-formalization across all context-aware cases; add Gmail email formatting support (case 004)

**Change**:
1. Rule 2: Replaced `"Transform colloquial expressions into formal written style"` with `"Clean up spoken-language patterns into polished written text while preserving the speaker's original tone and formality level"`
2. Context section: Replaced generic one-liner with structured per-application guidance (Chat, Email, Code editors, Social media) and added `"IMPORTANT: Match the speaker's original level of formality — do NOT make casual speech overly formal."`

Before (Rule 2 sub-bullet):
```
- Transform colloquial expressions into formal written style
```

After:
```
- Clean up spoken-language patterns into polished written text while preserving the speaker's original tone and formality level
```

Before (context section):
```
Adapt the tone, format and style to match the target application. For example: chat/messaging apps should be casual and concise; email should use appropriate email tone; code editors should preserve technical terms; social media should follow platform conventions.
```

After:
```
Adapt the tone, format and style to match the target application.
- Chat/messaging apps (Slack, Teams, iMessage): keep it casual and concise
- Email (Gmail, Outlook): use standard email structure (greeting line, body, sign-off), format phone numbers and addresses properly, preserve the sender's greeting style (e.g., "Hi" stays casual, don't upgrade to "Dear")
- Code editors: preserve technical terms and formatting
- Social media: follow platform conventions
IMPORTANT: Match the speaker's original level of formality — do NOT make casual speech overly formal.
```

**Result**:
| Case | Before | After | Delta |
|------|--------|-------|-------|
| 001-chinese-casual | 10/10 | 9/10 | -1 (normal LLM variance) |
| 002-english-filler | 8/10 | 9/10 | +1 |
| 003-english-with-context | 9/10 | 10/10 | +1 |
| 004-email-gmail-format | 8/10 | 8/10 | 0 (qualitatively better) |

- **003 significantly improved**: Tone shifted from overly formal ("I have pushed... Please review it when you have a moment") to natural Slack style ("Hey, I just pushed... Can you review it when you get a chance?")
- **002 improved**: Less formal phrasing ("We need to" vs "We must ensure"), though list formatting still missing
- **004 qualitatively better**: Greeting fixed ("Hi Anna," vs "Dear Anna,"), sign-off casual ("Thanks, Jack" vs "Thank you, Jack"), but content slightly trimmed (dropped "just wanted to let you know") and phone format still not (408) style
- **001 within variance**: 9-10 range, no regression

**Constraint discovered**:
- Removing the "formal written style" directive dramatically improves context-aware cases without harming no-context cases
- Email-specific guidance helps with structure but phone number formatting may need explicit format examples (e.g., "(XXX) XXX-XXXX") to achieve consistent results
- Content preservation tension: removing "formal" encourages brevity, which can over-trim friendly softeners like "just wanted to let you know"

**Remaining issues**:
- Case 004: Phone number not formatted as (408) 123-4567; email body too terse (lost conversational warmth)
- Cases 001/002: List formatting still inconsistently applied (pre-existing issue from previous iteration)
