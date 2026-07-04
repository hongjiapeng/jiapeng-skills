# WinUI Feature Spec: [Feature Name]

## Problem

[User or engineering problem.]

## Goals

- [Goal]

## Non-goals

- [Non-goal]

## Target Repository

- May modify: [repo]
- Read-only references: [repos]

## WinUI / Windows App SDK Structure

- App startup path: [App.xaml/MainWindow/etc.]
- Pages: [page files]
- Controls: [control files]
- ViewModels: [view model files, if used]
- Models: [model files]
- Services: [service files]
- Windows App SDK version constraints: [version]
- Packaged/unpackaged mode: [mode]
- Engineering guidelines: Apply `templates/dotnet-engineering-guidelines.md`; do not repeat common .NET rules here.

## Functional Requirements

| ID | Requirement | Acceptance Criteria |
|---|---|---|
| FR-1 | [Requirement] | AC-1 |

## XAML Layout and UX Behavior

- Layout: [Grid/StackPanel/etc.]
- Visual states: loading, empty, error, success
- Responsive behavior: [window size behavior]
- Accessibility: names, keyboard path, focus behavior, contrast

## Binding, Commands, and Events

- Use `x:Bind` when compile-time binding is appropriate.
- Use `Binding` when runtime DataContext behavior is required.
- Follow the project's MVVM pattern if one exists.
- Keep event handlers thin and route business logic to services/view models.

## Resources and Styling

- Resource dictionaries: [existing dictionaries]
- Styles/control templates: [reuse or new scoped style]
- Do not use WPF-specific APIs.
- Do not assume WPF `Dispatcher`, `Window`, or WPF resource behavior.
- Do not introduce unrelated UI frameworks.

## Navigation and Dialogs

- `NavigationView` behavior: [if applicable]
- `Frame` navigation: [if applicable]
- `ContentDialog` behavior: [if applicable]

## WebView2 Integration

- Required: [yes/no]
- Source/content policy: [local/remote]
- Navigation restrictions: [if any]
- Message passing: [if any]

## Threading, Lifecycle, and OS Integration

- UI updates must use `DispatcherQueue` when crossing threads.
- File/folder picker behavior: [window handle/lifetime considerations]
- App lifecycle behavior: [activation, suspend/resume if relevant]
- MSIX packaging considerations: [capabilities, manifest, signing if applicable]

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

- Keep implementation aligned with the existing WinUI architecture.
- Prefer minimal vertical slices over large UI rewrites.
- Do not use WPF-specific APIs.
- Do not introduce unrelated UI frameworks.
