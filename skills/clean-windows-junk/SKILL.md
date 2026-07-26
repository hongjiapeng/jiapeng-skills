---
name: clean-windows-junk
description: Safely inspect and remove Windows application caches, temporary files, logs, and similar disposable data by using Winapp2.ini rules. Use when the user asks to find junk files, estimate reclaimable disk space, clean selected Windows or application caches, inspect a Winapp2 rule, or prepare a reviewable cleanup plan. Default to read-only scanning and require explicit confirmation of the generated plan before deleting files.
---

# Clean Windows Junk

Use the bundled PowerShell script as the only deletion engine. Do not download or invoke a cleaner executable.

## Safety contract

- Treat `List`, `ValidateRules`, and `Scan` as read-only.
- Run `Scan` before every cleanup and save its immutable JSON plan.
- Show the user the selected entries, file count, estimated bytes, warnings, skipped rules, and plan ID.
- Obtain explicit user confirmation of that exact plan ID before running `Clean`.
- Never infer confirmation from the original cleanup request.
- Never add `-AllowRisky` unless the user confirms the displayed `Default=False` or `Warning` risks.
- Never execute registry rules. The script reports and ignores them.
- Reject Winapp3 rules.
- Do not force-close applications, elevate privileges, clear the Recycle Bin, schedule cleanup, or download updated rules.

Read [references/safety-policy.md](references/safety-policy.md) before executing `Clean` or changing safety behavior. Read [references/winapp2-compatibility.md](references/winapp2-compatibility.md) when selecting, updating, or debugging a rules file.

## Workflow

1. Locate a user-provided `Winapp2.ini`. If none is available, ask the user to choose a local rules file; do not download one implicitly.
2. Validate the rules:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsJunkCleaner.ps1 `
     -Action ValidateRules `
     -RulesPath "C:\path\to\Winapp2.ini"
   ```

3. Find applicable entries. Use `-Query` only for discovery:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsJunkCleaner.ps1 `
     -Action List `
     -RulesPath "C:\path\to\Winapp2.ini" `
     -Query "Chrome Cache"
   ```

4. Scan exact entry names and create a plan:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsJunkCleaner.ps1 `
     -Action Scan `
     -RulesPath "C:\path\to\Winapp2.ini" `
     -Entry "Google Chrome Caches" `
     -PlanPath "$env:TEMP\clean-windows-junk-plan.json"
   ```

5. Present the scan summary and ask the user to confirm the returned `plan_id`.
6. After confirmation, execute the exact plan:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-WindowsJunkCleaner.ps1 `
     -Action Clean `
     -PlanPath "$env:TEMP\clean-windows-junk-plan.json" `
     -ConfirmPlanId "sha256:..."
   ```

7. Report deleted, skipped, stale, and failed counts plus actual reclaimed bytes. Preserve the plan for audit unless the user asks to remove it.

## Selection rules

- Pass exact Winapp2 entry names to `-Entry`; never clean a fuzzy match.
- Prefer cache, temporary-file, crash-report, and log entries.
- Explain that privacy/history entries may sign users out, remove sessions, or erase recent-item history.
- Treat `Default=False` and any entry with `Warning` as risky.
- If an entry is detected only through unsupported registry detection, report that limitation instead of bypassing detection.
- If a rule resolves outside the allowed cache roots, report the blocked rule instead of weakening the path guard.

## Output

The script emits structured JSON. Use its fields rather than parsing human-readable console text. A successful scan returns `plan_id`, `plan_path`, selected entry summaries, file count, estimated bytes, warnings, and skipped rules.
