# AI-Ready Codebase Improvement

## Background

This initiative is inspired by the video ["Your codebase is NOT ready for AI (here's how to fix it)"](https://www.youtube.com/watch?v=uC44zFz7JSM). The core thesis is:

> **AI is a newcomer to your codebase** — it has no memory of your mental model. To make AI effective, the file system must reflect the natural grouping of modules with **deep modules** (simple interfaces, complex implementations) and **graybox modules** (implementation can be delegated to AI, controlled by tests).

## Current Status

### Already Good (No Action Needed)

The codebase is already well-structured for AI collaboration. Most improvements are about **documenting the existing architecture** rather than refactoring.

| Aspect | Status |
|--------|--------|
| Clean Architecture | ✅ Domain/Data/Presentation/State/Infrastructure separation |
| Deep Modules | ✅ Protocols in Domain, implementations in Data |
| Repository Pattern | ✅ Protocol in Domain, implementation in Data |
| Dependency Injection | ✅ Constructor injection, no singletons |
| State Management | ✅ @Observable (modern Swift) |
| CLI for Validation | ✅ Core logic exposed via Rust CLI |
| Test Coverage | ✅ RecordingState has 12+ comprehensive tests |
| AGENTS.md | ✅ Already exists with agent guidance |

### Improvement Opportunities (Revised)

> **Important**: P2 (Entity Grouping) has been removed. The current role-based grouping (Entity/UseCase/Repository) is already correct. Do NOT reorganize by domain.

| Priority | Item | Impact | Notes |
|----------|------|--------|-------|
| P0 | Add module-level READMEs | High | Document existing architecture |
| P1 | Add INDEX.md to key directories | High | List all protocols/use cases |
| P1 | Document naming conventions | Medium | Help AI name new files correctly |
| P2 | Expand UseCase test coverage | Medium | Faster feedback loops |

## Principles

### Deep Modules
- **Interface**: Simple protocols in Domain layer (what)
- **Implementation**: Complex logic in Data layer (how)
- AI should be able to understand the "what" without reading the "how"

### Graybox Modules
- Well-tested modules where AI can safely modify implementation
- Tests lock down behavior; AI can improve internals

### Progressive Disclosure
- Start with interface documentation
- Only dive into implementation when needed

### Role-Based Grouping (Do NOT change)
- Current grouping by role (Entity/UseCase/Repository) is **correct**
- Do NOT reorganize by domain (Api/, Transcription/, etc.)
- This would break Clean Architecture principles

### Naming Conventions (Document existing patterns)
- `XXXRepository.swift` - Protocol in Domain, Implementation in Data
- `XXXUseCase.swift` - Business logic protocol
- `XXXUseCaseImpl.swift` - Implementation in Data layer
- `XXXState.swift` - @Observable ViewModel (in State/, not Presentation/)
- `XXXEntities.swift` - Domain entities

## Implementation Notes

- All changes must maintain **backward compatibility**
- Test changes should be verified via `./scripts/dev-loop.sh --testing`
- Follow commit conventions: `refactor(ai-ready): ...`
- No new dependencies or runtime behavior changes