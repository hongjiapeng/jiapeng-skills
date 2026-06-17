---
name: adobe-leave-organizations
description: Automate leaving Adobe Account enterprise/team organizations from account.adobe.com while keeping named organizations. Use when the user wants Codex to batch退出/leave Adobe organizations, preserve specific organization names such as an organization to keep, handle Edge remote debugging, configurable Google or Adobe email login flows, Adobe profile chooser pages, repeated reauthentication, and final confirmation pages safely.
---

# Adobe Leave Organizations

## Purpose

Use this skill to remove many Adobe enterprise/team organization memberships from an Adobe Account page while keeping a named allowlist. The workflow is intentionally conservative because leaving an organization is destructive: it removes organization-provided apps and access to organization-owned assets.

## Default Workflow

1. Confirm the keep list in plain text before acting, for example `--keep "Example Organization"`.
2. Use Microsoft Edge with a remote debugging port so Codex can control the user's real logged-in browser profile.
3. Run `scripts/adobe_leave_orgs.mjs` instead of rewriting browser automation from scratch.
4. Let the script log each organization before and after exit. Stop if it reports manual auth is required.
5. Verify the final organization list contains only kept names.

## Edge Setup

Prefer the user's existing Edge profile so Google and Adobe sessions are available.

If Edge is not already running with a debugging port:

```powershell
Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -ArgumentList @("--remote-debugging-port=9222","--profile-directory=Default","https://account.adobe.com/profile")
```

Check the port before automation:

```powershell
Invoke-RestMethod http://127.0.0.1:9222/json/version
```

Do not use a copied/new browser profile for Google login. Google may reject automated/copy-profile browsers as unsafe. The reliable path is the real Edge profile with CDP enabled.

## Script Usage

Use Node.js with Playwright available. If `playwright-core` is not importable, install Playwright into a temporary folder and set `PLAYWRIGHT_NODE_MODULES`:

```powershell
$pkg = Join-Path $env:TEMP "codex-pw-adobe"
New-Item -ItemType Directory -Force -Path $pkg | Out-Null
npm --prefix $pkg install playwright --no-save
$env:PLAYWRIGHT_NODE_MODULES = Join-Path $pkg "node_modules"
node "$env:CODEX_HOME\skills\adobe-leave-organizations\scripts\adobe_leave_orgs.mjs" --keep "Example Organization"
```

Common options:

- `--keep "Example Organization"`: Keep all organizations with this exact name. Repeat or comma-separate for multiple names.
- `--port 9222`: CDP port. Default is `9222`.
- `--auth google`: Use Google OAuth login. This is the default.
- `--google-email "user@example.com"`: Select a specific Google account from the Google account chooser.
- `--google-index 0`: Select a Google account by visible order when no email is provided.
- `--auth adobe-email --adobe-email "user@example.com"`: Fill the Adobe email field and stop for manual password/2FA if Adobe asks.
- `--auth none`: Never attempt authentication.
- `--dry-run`: Read and report targets without leaving anything.
- `--no-login`: Do not attempt Google login; useful with `--dry-run` when checking an already-open profile tab.
- `--verbose`: Print progress diagnostics to stderr.
- `--max 1`: Leave at most one target for a cautious first pass.

## Hard-Won Pitfalls

- Adobe may redirect to `auth.services.adobe.com` after every successful exit. Continue with the configured auth strategy: Google account by `--google-email`/`--google-index`, Adobe email entry, or manual user intervention.
- Adobe may show a profile chooser after Google login. Only click the exact personal profile option when the page text says "选择一个配置文件" or "Choose a profile"; never match generic "个人资料" buttons on the account page.
- Old account tabs can show stale organization lists. For decisions, open a fresh `https://account.adobe.com/profile` page after each successful exit.
- Old `t2e-leave-organization` completion tabs can pollute detection. Ignore or close completed pages whose text says `您已离开 ...`.
- Before final confirmation, require both the expected organization name and `最终确认` on the leave page. If either is missing, stop.
- Do not enter, request, print, or store passwords. If Adobe or Google asks for password, passkey, phone, or 2FA, pause for the user unless the browser session completes auth without exposing secrets.

## Safety Rules

- Never leave names in the keep list, even if duplicates exist. Duplicate same-name organizations should all be kept.
- Never rely on screen coordinates for final destructive clicks.
- Never continue from a leave page for a different organization.
- Report final remaining organization names explicitly.
