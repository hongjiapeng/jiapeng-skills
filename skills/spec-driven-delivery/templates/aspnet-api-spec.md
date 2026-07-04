# ASP.NET Core API Spec: [Feature Name]

## Problem

[API problem or product capability.]

## Goals

- [Goal]

## Non-goals

- [Non-goal]

## Target Repository

- May modify: [repo]
- Read-only references: [repos]
- Engineering guidelines: Apply `templates/dotnet-engineering-guidelines.md`; do not repeat common .NET rules here.

## API Contract

| Method | Route | Purpose | Auth |
|---|---|---|---|
| [GET/POST/etc.] | `/api/...` | [purpose] | [required/none] |

## Request Contract

```json
{
  "field": "value"
}
```

Validation:
- [Rule]

## Response Contract

Success:

```json
{
  "field": "value"
}
```

Errors:

| Status | Condition | Body |
|---|---|---|
| 400 | [invalid input] | [shape] |

## Functional Requirements

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-1 | [Requirement] | AC-1 |

## Persistence

- Data model changes: [none/entities]
- Migrations: [none/required]
- Concurrency/idempotency: [behavior]

## Authentication and Authorization

- Authentication: [scheme]
- Authorization rules: [roles/policies]

## Logging and Observability

- Log events: [events]
- Do not log: secrets, tokens, personal data beyond existing policy.

## Integration Testing

- Test project/location: [path]
- Cases: success, validation failure, auth failure, persistence behavior

## Build/Test Commands

- Build: `[command]`
- Tests: `[command]`

## Risks and Assumptions

- [Risk or assumption]

## Acceptance Criteria

| ID | Criteria | Verification |
|---|---|---|
| AC-1 | [Observable behavior] | [test/manual step] |
