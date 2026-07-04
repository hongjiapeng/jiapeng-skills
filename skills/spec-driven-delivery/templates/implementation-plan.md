# Implementation Plan: [Feature Name]

## Target Repository

- May modify: [repo path/name]
- Read-only references: [repo path/name or none]

## Affected Modules

- [Module/project/file area]
- [Module/project/file area]

## Proposed Approach

[Short technical approach. Explain why this fits the existing architecture.]

## Engineering Guidelines

- If the target repository is a .NET project, apply `templates/dotnet-engineering-guidelines.md`.
- Do not repeat the common .NET rules here.
- List only project-specific deviations, tradeoffs, or explicit architecture decisions.

## Requirement Traceability

| Requirement | Implementation Task | Verification |
|---|---|---|
| FR-1 | TASK-1 | AC-1 / check |

## Vertical Slice

The first safe slice is:

1. [Smallest user-visible or behavior-visible change]
2. [Minimal supporting code]
3. [Test or manual check proving the slice works]

## File-level Plan

| File/Area | Change | Requirement |
|---|---|---|
| [path] | [expected edit] | FR-1 |

## Task Plan

- [ ] TASK-1: [Task]
  - Requirement: [FR-*]
  - Verify: [command or manual check]

## Test/Build Plan

- Build: `[command]`
- Tests: `[command]`
- Lint/format: `[command or not applicable]`
- Manual verification: [short steps]

## Rollback Considerations

- [How to revert or disable safely]

## Risks

- [Risk]: [mitigation]
