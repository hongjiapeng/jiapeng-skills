# Windows Worker Service Spec: [Feature Name]

## Problem

[Operational or background-processing problem.]

## Goals

- [Goal]

## Non-goals

- [Non-goal]

## Target Repository

- May modify: [repo]
- Read-only references: [repos]
- Engineering guidelines: Apply `templates/dotnet-engineering-guidelines.md`; do not repeat common .NET rules here.

## Service Behavior

- Service name: [name]
- Startup behavior: [automatic/manual/delayed]
- Install/uninstall path: [sc.exe/MSIX/installer/PowerShell/other]
- Permissions/account: [LocalSystem/NetworkService/custom user]
- Recovery behavior: [restart policy or none]

## Functional Requirements

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-1 | [Requirement] | AC-1 |

## Scheduling and Work Loop

- Trigger: [timer/file change/network event/manual]
- Interval: [if scheduled]
- Cancellation: [expected behavior]
- Concurrency: [single instance/parallel limits]

## File/Network IO

- Inputs: [paths/endpoints]
- Outputs: [paths/endpoints]
- Retry behavior: [policy]
- Offline behavior: [policy]

## Logging and Diagnostics

- Log sink: [Event Log/file/structured logs]
- Log levels: [info/warn/error]
- Do not log secrets or sensitive file contents.

## Update Flow

- Update mechanism: [manual/installer/winget/none]
- Backward compatibility: [config/data compatibility]

## Failure Handling

- Startup failure: [behavior]
- Runtime failure: [behavior]
- Permission failure: [behavior]
- Partial work recovery: [behavior]

## Build/Test Commands

- Build: `[command]`
- Tests: `[command]`
- Manual service verification: `[command or steps]`

## Risks and Assumptions

- [Risk or assumption]

## Acceptance Criteria

| ID | Criteria | Verification |
|---|---|---|
| AC-1 | [Observable behavior] | [test/manual step] |
