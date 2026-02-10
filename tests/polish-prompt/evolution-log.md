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
