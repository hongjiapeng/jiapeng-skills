# Example: AI-generated Workflow Asset Validation Loop

## Requirement

Create a lightweight validation loop for AI-generated workflow assets: generate a draft, validate it against its specification, run available checks, collect failures, repair issues, and repeat until the acceptance criteria pass.

## Problem Statement

AI-generated workflow assets can look plausible while missing required sections, contradicting their own spec, or failing simple repository checks. A lightweight validation loop makes the asset reviewable and repairable without introducing a complex orchestration framework.

## Scope

In scope:
- A Markdown-based workflow for draft, validate, collect failures, repair, and repeat.
- Generic asset types such as AI agent workflow instructions, markdown-based skills, prompt packages, and reusable automation recipes.
- A validation checklist that can be run by a human or coding agent.

Out of scope:
- Multi-agent orchestration.
- Runtime services.
- Proprietary execution frameworks.
- Private repository names or product-specific modules.
- Automated claims without actual checks.

## Non-goals

- Creating a new framework.
- Adding dependencies.
- Replacing code review.
- Guaranteeing correctness without human review.

## Workflow Assumptions

- The generated asset has a written specification.
- The repository has at least basic checks such as Markdown review, schema validation, tests, or manual inspection.
- The loop should stop when acceptance criteria pass or when a blocker requires human input.

## Architecture Constraints

- Keep the loop as Markdown instructions and checklists.
- Do not assume a specific AI coding tool.
- Do not require a background service, plugin, database, or queue.
- Keep failure records concise and actionable.

## Implementation Plan

### Target Repository

- May modify: the repository containing the workflow asset.
- Read-only references: source specs, examples, and external documentation.

### Proposed Approach

Create a reusable Markdown workflow with explicit phases:

1. Draft the asset from the spec.
2. Validate against the spec.
3. Run available repository checks.
4. Collect failures with file, section, requirement, and evidence.
5. Repair the smallest necessary part.
6. Repeat until checks pass or a blocker is declared.

### File-level Plan

| File/Area | Change | Requirement |
|---|---|---|
| Workflow instruction file | Add validation loop phases | FR-1 |
| Checklist/template file | Add failure collection and repair checklist | FR-2 |
| Example file | Show one complete generic loop | FR-3 |

### Failure Collection and Repair Loop

Use this failure record:

| Failure | Evidence | Requirement | Repair |
|---|---|---|---|
| [What failed] | [check output or section mismatch] | [spec item] | [smallest repair] |

Repair rules:
- Fix the cause, not only the symptom.
- Keep the repair scoped to the failed requirement.
- Re-run the failed check first, then the full checklist.
- Stop and ask when the spec conflicts with available checks.

## Validation Strategy

- Spec coverage: every required section exists.
- Traceability: each requirement maps to acceptance criteria.
- Consistency: terms, scope, and non-goals do not conflict.
- Check execution: available commands or manual checks are run and recorded.
- Repair loop: failures produce targeted edits and a repeated check.

## Functional Requirements

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-1 | The workflow defines draft, validate, check, failure collection, repair, and repeat phases. | AC-1 |
| FR-2 | The workflow records failures with evidence and mapped requirements. | AC-2 |
| FR-3 | The loop stops only when criteria pass or a blocker is declared. | AC-3 |
| FR-4 | The workflow remains generic and open-source terminology only. | AC-4 |

## Acceptance Criteria

| ID | Criteria | Verification |
|---|---|---|
| AC-1 | All loop phases are present and ordered. | Markdown review. |
| AC-2 | Failure records include evidence, requirement, and repair. | Checklist review. |
| AC-3 | Stop conditions include pass and blocker paths. | Workflow review. |
| AC-4 | No company products, private runtimes, private repositories, or proprietary framework names appear. | Text search and review. |

## Final Coding-agent Prompt

You are implementing a lightweight validation loop for generic AI-generated workflow assets.

Target repository, may modify: `[target repo path]`
Skill repository, read-only: `[skill repo path]`
Reference repositories, read-only: `[reference repo paths or none]`

Allowed modifications:
- Markdown workflow instruction files.
- Markdown templates/checklists directly related to validation.
- Generic examples.

Disallowed modifications:
- Do not add dependencies.
- Do not create runtime services, plugins, queues, dashboards, or multi-agent orchestration.
- Do not mention company products, internal runtimes, private module names, proprietary execution frameworks, or private repository names.

Requirement:
Create a lightweight validation loop for AI-generated workflow assets: generate a draft, validate it against its specification, run available checks, collect failures, repair issues, and repeat until acceptance criteria pass.

Implementation plan:
1. Inspect existing workflow asset structure.
2. Add or update a Markdown validation loop with draft, validate, check, collect, repair, repeat, and stop phases.
3. Add a concise failure record format.
4. Add acceptance criteria and manual verification.
5. Search the result for prohibited proprietary terms.

Acceptance criteria:
- The phases are complete and ordered.
- Failures map to evidence, requirement, and repair.
- The loop has clear pass and blocker stop conditions.
- The example uses only generic open-source terminology.

Final summary:
Return files changed, requirement coverage, checks run, failure cases considered, and remaining risks.
