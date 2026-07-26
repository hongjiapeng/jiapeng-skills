# Safety policy

## Confirmation boundary

Treat scanning and deletion as separate user decisions:

1. Scan exact entries and write a plan.
2. Show the plan ID and material effects.
3. Ask for explicit confirmation.
4. Execute only when `-ConfirmPlanId` exactly matches the saved plan.

The initial request to "clean junk" authorizes scanning, not deletion. A valid confirmation identifies the plan or unambiguously confirms the plan just shown.

If the plan contains `requires_allow_risky: true`, display every associated warning and ask the user to confirm those risks. Only then add `-AllowRisky`.

## Filesystem guards

The script permits files only beneath:

- the current user's temporary directory;
- `%LOCALAPPDATA%`;
- `%APPDATA%`;
- `%PROGRAMDATA%`;
- `%SystemRoot%\Temp`.

It permits the temporary-directory root and `%SystemRoot%\Temp` themselves as scan roots, but never deletes those directories. Other allowed roots must resolve to a descendant directory.

The script rejects:

- drive roots;
- `%USERPROFILE%` outside AppData;
- `%SystemRoot%` outside its Temp directory;
- Program Files;
- UNC paths;
- unresolved environment variables;
- paths outside the allowlist;
- directories or files reached through reparse points.

Do not weaken these guards to make an upstream rule run. Report the blocked rule and let the user decide whether to use another cleaning tool.

## Plan integrity

The plan records:

- the rules file path, SHA-256, and declared version;
- exact entry names;
- exact file paths, sizes, and UTC last-write ticks;
- warnings, unsupported registry-rule counts, and skipped rules;
- an SHA-256 plan ID over the plan payload.

Before deletion, the script revalidates the plan hash, rules-file hash, allowed roots, file type, reparse-point state, size, and timestamp. Changed files are marked stale and skipped.

## Prohibited behavior

- Do not execute `RegKey` rules.
- Do not load Winapp3.
- Do not delete directories in this MVP, including `REMOVESELF` roots.
- Do not run FluentCleaner `/AUTO`.
- Do not close processes or retry locked files automatically.
- Do not elevate privileges automatically.
- Do not install or update cleaning rules without explicit user approval.
- Do not turn ignored or blocked items into ad hoc `Remove-Item` commands.
