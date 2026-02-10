---
name: prompt-evolution
description: Test-driven prompt optimization for polish.rs. Use this skill when you want to add test cases, run regression tests, optimize the polish prompt, or review prompt evolution history.
---

# Prompt Evolution

Test-driven iterative optimization of the polish prompt in `core/src/polish.rs`. Maintains a regression test suite to ensure quality monotonically improves.

## Key Paths

- **Prompt source**: `core/src/polish.rs` (the `prompt` variable in `polish_text()`)
- **Test suite**: `tests/polish-prompt/suite.json`
- **Test cases**: `tests/polish-prompt/cases/NNN-slug/`
- **Evolution log**: `tests/polish-prompt/evolution-log.md`
- **Evaluation criteria**: Load `references/evaluation-criteria.md` before scoring

## Workflow 1: Add Test Case

When the user wants to add a new regression test case.

### Steps

1. Read `tests/polish-prompt/suite.json` to determine the next case number
2. Ask the user for:
   - The raw speech transcript (input)
   - The expected polished output
   - Optional: context parameter
3. Create the case directory `tests/polish-prompt/cases/NNN-slug/` with:
   - `input.txt` — raw transcript
   - `expected.txt` — expected output
   - `context.txt` — context parameter (only if provided)
4. Add the case entry to `suite.json`:
   ```json
   {
     "id": "NNN-slug",
     "description": "Brief description of what this case tests",
     "has_context": true/false,
     "scores": []
   }
   ```
5. Run the new case through CLI to establish a baseline score:
   ```bash
   cat tests/polish-prompt/cases/NNN-slug/input.txt | cargo run -p diy_typeless_cli -- polish
   ```
   If the case has context:
   ```bash
   cat tests/polish-prompt/cases/NNN-slug/input.txt | cargo run -p diy_typeless_cli -- polish --context "$(cat tests/polish-prompt/cases/NNN-slug/context.txt)"
   ```
6. Score the output against `expected.txt` using `references/evaluation-criteria.md`
7. Record the baseline score in `suite.json`

## Workflow 2: Run Regression Tests

Run all test cases against the current prompt and report results.

### Steps

1. Read `tests/polish-prompt/suite.json` to get all cases
2. Load `references/evaluation-criteria.md` for scoring criteria
3. For each case:
   a. Read `input.txt` (and `context.txt` if `has_context` is true)
   b. Run through CLI:
      ```bash
      cat tests/polish-prompt/cases/{id}/input.txt | cargo run -p diy_typeless_cli -- polish
      ```
      Or with context:
      ```bash
      cat tests/polish-prompt/cases/{id}/input.txt | cargo run -p diy_typeless_cli -- polish --context "$(cat tests/polish-prompt/cases/{id}/context.txt)"
      ```
   c. Read `expected.txt`
   d. Score the actual output against expected using evaluation criteria
   e. Compare with the last score in the case's `scores` array
4. Report results as a table:
   ```
   | Case | Description | Score | Previous | Delta |
   |------|-------------|-------|----------|-------|
   | 001  | ...         | 8/10  | 7/10     | +1    |
   ```
5. Flag any regressions (score dropped by 2+ or human-unacceptable quality change)

## Workflow 3: Optimize Prompt

The core iterative loop. Modify the polish prompt to improve quality.

### Steps

1. **Identify target**: Ask the user what to improve, or run Workflow 2 to find weak spots
2. **Diagnose**: Analyze why the current prompt produces suboptimal results for the target cases. Read the current prompt in `core/src/polish.rs`
3. **Propose changes**: Draft specific prompt modifications. Explain the rationale. Present to user for approval — do NOT modify without confirmation
4. **Apply**: After user approval, edit `core/src/polish.rs` with the prompt changes
5. **Verify**: Run Workflow 2 (full regression suite)
6. **Evaluate results**:
   - If any case regresses significantly (score drop 2+ or human-unacceptable): **rollback** the change via `git checkout core/src/polish.rs` and report failure
   - If target cases improve without regression: proceed
7. **Record**: Append to `tests/polish-prompt/evolution-log.md`:
   ```markdown
   ## [Date] — Brief title

   **Target**: What we tried to improve
   **Change**: What was modified in the prompt
   **Result**: Score changes summary
   **Constraint discovered**: Any new insight about what the prompt must preserve
   ```
8. Update `suite.json` with new scores for all cases

### Rollback Protocol

If regression is detected:
1. Immediately rollback: `git checkout core/src/polish.rs`
2. Report which cases regressed and by how much
3. Analyze why the change caused regression
4. Suggest alternative approaches that might avoid the regression

## Workflow 4: View History

Review the prompt evolution trajectory.

### Steps

1. Read and display `tests/polish-prompt/evolution-log.md`
2. Optionally read `suite.json` to show score trends per case
3. Summarize:
   - Total iterations
   - Overall score trajectory
   - Key constraints discovered
   - Current weak spots

## Important Notes

- **LLM output variance**: Score fluctuations of 1 point that remain human-acceptable are NOT regressions. Only flag drops of 2+ or quality changes a human would reject.
- **Human in the loop**: Always get user confirmation before modifying `core/src/polish.rs`.
- **Close the loop**: Always verify via CLI, never assume a prompt change works based on reasoning alone.
