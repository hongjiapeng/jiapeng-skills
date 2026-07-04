# WPF Feature Spec: [Feature Name]

## Problem

[User or engineering problem.]

## Goals

- [Goal]

## Non-goals

- [Non-goal]

## Target Repository

- May modify: [repo]
- Read-only references: [repos]

## WPF Application Structure

- App startup path: [App.xaml/MainWindow/etc.]
- Views: [view files]
- ViewModels: [view model files]
- Models: [model files]
- Services: [service files]
- Existing MVVM framework or pattern: [CommunityToolkit.Mvvm/custom/none]

## Functional Requirements

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-1 | [Requirement] | AC-1 |

## XAML Layout and UX Behavior

- Layout: [Grid/DockPanel/etc.]
- Visual states: loading, empty, error, success
- Responsive behavior: [window size behavior]
- Accessibility: names, keyboard path, focus behavior, contrast

## MVVM and Binding

- Use `ICommand` or project command pattern for actions.
- Use `INotifyPropertyChanged` for mutable view state.
- Keep view logic minimal; place business logic in services.
- Use dependency properties only when creating reusable controls or when binding requires them.
- Define validation behavior for user input.

## Resources and Styling

- Resource dictionaries: [existing dictionaries]
- Styles/templates: [reuse or new scoped style]
- Do not introduce unrelated UI frameworks.
- Do not use WinUI-specific APIs.
- Do not assume Windows App SDK.

## Dialogs, Navigation, and OS Integration

- Dialogs/message boxes: [behavior]
- Navigation: [if applicable]
- File/folder picker behavior: [if applicable]
- System tray behavior: [if applicable]
- Startup behavior: [if applicable]

## WebView2 Integration

- Required: [yes/no]
- Source/content policy: [local/remote]
- Navigation restrictions: [if any]
- Host-object or message passing: [if any]

## Threading and Background Work

- UI updates must use WPF `Dispatcher` when crossing threads.
- Background work must not block the UI thread.
- Cancellation and progress behavior: [if applicable]

## Logging and Error States

- Logging: [where and what]
- User-facing errors: [message and recovery]
- Empty/loading states: [expected behavior]

## Risks and Assumptions

- [Risk or assumption]

## Acceptance Criteria

| ID | Criteria | Verification |
|---|---|---|
| AC-1 | [Observable behavior] | [test/manual step] |

## Manual Verification Steps

1. [Launch app]
2. [Perform workflow]
3. [Expected result]

## Rules

- Keep implementation aligned with the existing WPF architecture.
- Prefer minimal vertical slices over large UI rewrites.
- Do not use WinUI-specific APIs.
- Do not introduce unrelated UI frameworks.
