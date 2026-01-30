# Agent Guidance

## Closing the Loop (Primary Rule)

This project prioritizes closing the loop. Any core logic changes must be verified through an executable path that the agent can run end-to-end without opening the macOS app UI.

Required workflow:

1. Implement Rust core logic first.
2. Expose the same code paths through the Rust CLI.
3. Build and run the CLI to validate behavior.
4. Only after CLI validation, integrate the Rust core into the macOS app.
5. If the app changes break the CLI or the core logic, fix the core and CLI first.

If there is uncertainty, extend the CLI with additional flags or diagnostics so the agent can re-run and confirm fixes.
