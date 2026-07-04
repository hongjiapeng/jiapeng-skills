---
name: spec-driven-delivery
description: Create lightweight implementation-ready specs, plans, acceptance criteria, verification checklists, and final coding-agent prompts from vague product or engineering requests. Use when Codex, Claude Code, GitHub Copilot CLI, Cursor, or another AI coding agent should implement a feature only after requirements, scope, repository boundaries, risks, and checks are explicit.
---

# Spec-Driven Delivery

## Purpose

Turn a vague coding request into a clear delivery packet:

1. Feature spec
2. Implementation plan
3. Acceptance criteria
4. Verification checklist
5. Final coding-agent prompt

This skill does not implement code directly. It prepares the instructions that make coding agents implement code more reliably.

## When to Use

Use this skill when the request is ambiguous, touches multiple files, changes user-facing behavior, affects architecture, adds a workflow, or needs a coding agent handoff.

Use it for C#, .NET 8/.NET 10, WPF, WebView2, WinUI, ASP.NET Core, Windows Worker Service, local AI features, GitHub Actions, NuGet packaging, winget packaging, small independent software products, internal tools, and Windows desktop applications.

## When Not to Use

Do not use this skill for typo fixes, single-line changes, mechanical renames, direct debugging where the user already provided a failing command and expected fix, or emergency repairs where writing a spec would delay an obvious safe patch.

## Required Workflow

Follow these steps in order:

1. Understand the real problem.
   - Restate the user-visible outcome.
   - Identify who benefits and what must become true.
   - Separate product intent from technical guesses.

2. Identify target repository and repository role.
   - State the repository that may be modified.
   - State the skill repository, if relevant.
   - State read-only reference repositories.
   - Never let a coding-agent prompt leave repository boundaries implicit.

3. Clarify scope and non-goals.
   - Define the smallest safe vertical slice.
   - List non-goals explicitly.
   - Mark unknowns as assumptions or open questions.

4. Generate the feature spec.
   - Use `templates/feature-spec.md` by default.
   - Use `templates/wpf-feature-spec.md`, `templates/winui-feature-spec.md`, `templates/aspnet-api-spec.md`, or `templates/windows-service-spec.md` when the target stack matches.

5. Generate the implementation plan.
   - Use `templates/implementation-plan.md`.
   - Every task must map back to a requirement.
   - Prefer a small vertical slice over a broad rewrite.

6. Generate acceptance criteria.
   - Every requirement must have at least one acceptance criterion.
   - Every acceptance criterion must be observable or testable.
   - Avoid "improved", "polished", "fast", or "robust" unless converted into concrete checks.

7. Generate the verification checklist.
   - Use `templates/acceptance-checklist.md`.
   - Include build, test, UI/manual, error handling, and regression checks.
   - Include exact commands when they are known.

8. Generate the final coding-agent prompt.
   - Use `templates/coding-agent-prompt.md`.
   - Include allowed modifications, disallowed modifications, read-only references, requirements, plan, acceptance criteria, build/test commands, and final summary format.

9. Optionally review implementation against the spec.
   - Compare completed work to requirements, acceptance criteria, and verification checklist.
   - Report gaps before suggesting new work.

## Output Contract

When producing a delivery packet, include these sections:

1. Assumptions
2. Non-goals
3. Feature spec
4. Implementation plan
5. Acceptance criteria
6. Verification checklist
7. Final coding-agent prompt
8. Risks and review notes

If the user asks for files, save the artifacts as Markdown. If the user asks for an inline packet, keep it concise but complete.

## Rules

- Do not jump directly to code.
- Do not create a framework, runtime, orchestration layer, or dependency unless the user explicitly asks.
- Prefer the smallest safe vertical slice.
- Separate product requirements from implementation details.
- Keep requirements traceable to acceptance criteria.
- Keep implementation tasks traceable to requirements.
- State assumptions, risks, and non-goals every time.
- Use exact repository boundaries in agent prompts.
- Make build and test commands concrete when discoverable.
- If a check cannot be run, say why and provide a manual fallback.
- Preserve existing project architecture unless the spec explicitly approves a change.
- For UI work, require loading, empty, error, accessibility, and responsive behavior when applicable.
- For Windows desktop work, account for UI thread dispatching, app lifecycle, packaging constraints, and OS integration only when relevant.

## Quality Gates

Before handing off to a coding agent, confirm:

- The target repository is named.
- Read-only repositories are named.
- Product goals and technical approach are separated.
- Each requirement maps to acceptance criteria.
- Each acceptance criterion is testable.
- Each implementation task maps to a requirement.
- Non-goals prevent obvious scope creep.
- Risks are specific enough to guide review.
- Verification includes automated and manual checks where appropriate.
- The prompt tells the coding agent what not to modify.

## Final Response Format

Use this structure after creating or updating artifacts:

```markdown
Created/updated:
- [file paths]

Key decisions:
- [short design choices]

Influences:
- [source patterns used]

How to use:
- [one short instruction]

Example prompt:
[direct prompt the user can give to a coding agent]
```

## Safety and Scope Boundaries

Coding-agent prompts produced by this skill must include:

- Target repository: the only repository that may be modified.
- Skill repository: read-only unless the task is to edit the skill.
- Reference repositories: read-only by default.
- Allowed modifications: files, modules, tests, docs, or packaging assets in scope.
- Disallowed modifications: unrelated refactors, dependency upgrades, formatting churn, generated artifacts, secrets, CI changes, or packaging changes outside scope.
- Approval triggers: schema migrations, public API breaks, data deletion, dependency additions, installer changes, signing changes, or release automation changes.
