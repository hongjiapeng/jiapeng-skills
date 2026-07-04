# Acceptance Checklist: [Feature Name]

## Functional Verification

- [ ] [Requirement is satisfied]
- [ ] [Core workflow succeeds]
- [ ] [Edge case behaves as specified]

## UI Verification

- [ ] [Default state is correct]
- [ ] [Loading state is correct]
- [ ] [Empty state is correct]
- [ ] [Error state is clear and recoverable]
- [ ] [Keyboard and screen reader basics are acceptable]
- [ ] [Phone and desktop layouts work, if applicable]

## Error Handling Verification

- [ ] [Invalid input produces expected validation]
- [ ] [File/network/service failure is handled]
- [ ] [Logs contain useful diagnostics without secrets]

## Build/Test Verification

- [ ] Build passes: `[command]`
- [ ] Tests pass: `[command]`
- [ ] Packaging check passes, if applicable: `[command]`
- [ ] No unrelated files are changed

## Regression Checks

- [ ] [Existing workflow still works]
- [ ] [Existing settings/data remain compatible]
- [ ] [No unrelated UI or API behavior changed]

## Manual Verification Steps

1. [Step]
2. [Step]
3. [Expected result]
