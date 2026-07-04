# Coding Agent Prompt: [Feature Name]

You are implementing a scoped change from an approved spec. Do not start by rewriting the plan. First inspect the target repository, confirm the affected files, then implement the smallest safe vertical slice that satisfies the acceptance criteria.

## Repositories

- Target repository, may modify: `[path/name]`
- Skill repository, read-only unless explicitly stated: `[path/name]`
- Reference repositories, read-only: `[path/name or none]`

## Allowed Modifications

- [Allowed file/module/project area]
- [Tests/docs directly related to this change]

## Disallowed Modifications

- Do not modify unrelated repositories.
- Do not perform broad refactors.
- Do not add dependencies unless explicitly approved.
- Do not change CI, packaging, signing, or release automation unless listed in scope.
- Do not remove tests, suppress errors, or change public contracts to make checks pass.

## Requirement

[Plain-language requirement.]

## Spec Summary

- Problem: [problem]
- Goals: [goals]
- Non-goals: [non-goals]
- Assumptions: [assumptions]
- Risks: [risks]
- Engineering guidelines: [For .NET projects, apply `templates/dotnet-engineering-guidelines.md`; list only project-specific deviations.]

## Implementation Plan

1. [Task]
2. [Task]
3. [Task]

## Acceptance Criteria

- [AC-1]
- [AC-2]

## Build/Test Commands

- Build: `[command]`
- Test: `[command]`
- Manual: [manual checks]

## Required Agent Behavior

- Keep changes scoped to the target repository.
- Preserve existing architecture and style.
- Map every implementation task to a requirement.
- Run the listed checks when possible.
- If a check cannot run, state why and provide the closest manual verification.
- Stop and ask before schema migrations, new dependencies, public API breaks, installer/signing changes, or destructive data changes.

## Final Summary Format

Return:

1. Files changed
2. Requirement coverage
3. Verification run and results
4. Risks or follow-up work
