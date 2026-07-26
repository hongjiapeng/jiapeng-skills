---
name: browser-bookmark-manager
description: Safely scan, audit, back up, restore, and optimize desktop browser bookmarks across Windows, macOS, and Linux. Use when Codex needs to locate Edge or Chrome Bookmarks JSON profiles, report duplicate bookmarks, empty folders, suspicious titles or URLs, HTTP failures, redirects, timeouts, or certificate errors, create recoverable backups, restore a backup, or manage Microsoft Edge Favorites bar icon-only display without clearing bookmark names. Default to report-only/dry-run behavior and require a verified before/after Edge JSON diff plus explicit confirmation before any batch modification.
---

# Browser Bookmark Manager

Manage browser bookmarks as user-owned assets. Prefer diagnosis, evidence, backups, and reversible changes over deletion.

## Supported scope

- Support Edge and Chrome `Bookmarks` JSON on Windows, macOS, and Linux.
- Scan profiles and generate structural or optional network-health reports.
- Plan and apply exact-URL deduplication with a reviewed, hash-bound plan.
- Back up and restore complete `Bookmarks` files.
- Optimize Edge Favorites bar URL nodes by changing the verified `show_icon` field while preserving `name`.
- Treat Firefox, Netscape HTML import/export, folder merging, title shortening, and domain sorting as future scope. Report related findings, but do not claim these mutations are implemented.

Read [references/platform-and-safety.md](references/platform-and-safety.md) when resolving custom profile locations, performing a write, interpreting link-health results, or handling Edge icon-only fields.

## Core workflow

1. Locate the bundled CLI:

   ```text
   scripts/bookmark_manager.py
   ```

2. Run `scan` first. Use `--bookmarks <path>` for a custom profile or nonstandard browser installation.
3. Run `report` without `--check-links` for a fast local-only audit. Add `--check-links` only when the user wants live URL health checks.
4. Keep report and dry-run operations read-only.
5. Before any restore or icon-only update:
   - require the affected browser to be fully closed;
   - validate the JSON;
   - create a complete timestamped backup;
   - show the proposed change;
   - require the command's explicit apply confirmation;
   - report the backup path and generated restore command.

## Duplicate cleanup workflow

Preserve meaningful URL fragments such as SPA routes and page anchors. Do not treat two URLs as exact duplicates merely because their fragment-free base URL matches.

Start with the conservative same-folder plan:

```powershell
python .\scripts\bookmark_manager.py plan-dedupe `
  --browser edge `
  --scope same-folder `
  --output .\edge-dedupe-plan.json
```

The planner keeps the strongest title in each exact-URL group and otherwise keeps the first bookmark in tree order. Review every `keep` and `remove` entry.
It validates the current Chromium bookmark checksum before producing the hash-bound plan. Applying the plan recalculates the MD5 and optional SHA-256 bookmark checksums after removal.

Preview the reviewed plan:

```powershell
python .\scripts\bookmark_manager.py apply-dedupe --plan .\edge-dedupe-plan.json
```

Apply only after the browser is fully closed and the user confirms:

```powershell
python .\scripts\bookmark_manager.py apply-dedupe `
  --plan .\edge-dedupe-plan.json `
  --apply --confirm APPLY
```

Use `--scope all` only when the user explicitly wants cross-folder duplicates removed. Cross-folder copies may be intentional organization. The plan is bound to the source file SHA-256; regenerate it whenever the live file changes.

## Commands

Use Python 3.9 or newer.

Scan Edge and Chrome profiles:

```powershell
python .\scripts\bookmark_manager.py scan --browser all
```

Generate a local structural report:

```powershell
python .\scripts\bookmark_manager.py report --browser all --output .\bookmark-report.json
```

Include HTTP status, redirect, timeout, and TLS certificate checks:

```powershell
python .\scripts\bookmark_manager.py report --browser edge --check-links --timeout 8 --output .\edge-health.json
```

Create explicit backups:

```powershell
python .\scripts\bookmark_manager.py backup --browser all --output-dir .\bookmark-backups
```

Preview a restore, then apply it only after the user confirms:

```powershell
python .\scripts\bookmark_manager.py restore --browser edge --bookmarks "<Bookmarks path>" --backup "<backup path>"
python .\scripts\bookmark_manager.py restore --browser edge --bookmarks "<Bookmarks path>" --backup "<backup path>" --apply --confirm RESTORE
```

## Edge Favorites bar icon-only workflow

Do not infer or create `show_icon` from memory. Verify it for the current Edge version and platform:

1. Fully close Edge and copy `Bookmarks` to a `before` snapshot.
2. Open Edge, manually toggle **Show icon only** for one Favorites bar URL, fully close Edge, and copy `Bookmarks` to an `after` snapshot.
3. Generate a confirmation artifact:

   ```powershell
   python .\scripts\bookmark_manager.py verify-icon-diff `
     --before "<before.json>" `
     --after "<after.json>" `
     --live-bookmarks "<profile>/Bookmarks" `
     --output .\edge-icon-field-confirmation.json
   ```

4. Preview the batch update:

   ```powershell
   python .\scripts\bookmark_manager.py optimize-icon-only `
     --browser edge `
     --bookmarks "<profile>/Bookmarks" `
     --confirmation .\edge-icon-field-confirmation.json
   ```

5. Apply only after reviewing the preview and receiving user confirmation:

   ```powershell
   python .\scripts\bookmark_manager.py optimize-icon-only `
     --browser edge `
     --bookmarks "<profile>/Bookmarks" `
     --confirmation .\edge-icon-field-confirmation.json `
     --apply --confirm APPLY
   ```

Add `--recurse` to include URL bookmarks inside Favorites bar folders. Add `--disable` to restore name-and-icon display. Never clear or shorten `name` as a substitute for icon-only display.

## Reporting

Report:

- OS, browser, profile name, and exact `Bookmarks` path;
- URL and folder counts;
- duplicate groups, empty folders, title anomalies, suspicious URLs;
- link-check method, final URL, status code, error category, and redirects when requested;
- dry-run versus applied status;
- changed and skipped counts;
- backup path and exact restore command for every write.

Do not label every `403` as a dead bookmark. Authentication, bot protection, `HEAD` handling, and network policy can produce false positives. Classify observed results and let the user decide what to remove.
