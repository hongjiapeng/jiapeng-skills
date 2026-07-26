---
name: github-cli-setup
description: Prepare GitHub CLI on Windows by detecting `gh`, installing it with WinGet when missing, locating a newly installed executable without requiring a terminal restart, and verifying GitHub authentication. Use when a GitHub workflow is blocked because `gh` is missing, `gh auth status` fails, or the machine needs GitHub CLI installation and login before repository-specific work can continue.
---

# GitHub CLI Setup

Prepare the local Windows environment for later GitHub workflows. Stop after `gh` is installed and authenticated; do not create repositories, configure remotes, commit, or push.

## Workflow

1. Run the bundled preflight without installation:

   ```powershell
   & "<skill-dir>\scripts\Ensure-GitHubCli.ps1"
   ```

2. Read the JSON result:
   - `ready`: Report success.
   - `missing`: Run the script again with `-Install`.
   - `needs-login`: Give the user the login command below and pause for them to complete browser authorization.
   - `install-failed` or `unsupported`: Report the returned details and do not claim readiness.

3. Install only when `status` is `missing`:

   ```powershell
   & "<skill-dir>\scripts\Ensure-GitHubCli.ps1" -Install
   ```

   The script tries the current `PATH` and standard WinGet installation locations after installation, so do not require a terminal restart unless the executable still cannot be found.

4. If authentication is required, ask the user to run this in an interactive PowerShell terminal:

   ```powershell
   gh auth login --hostname github.com --git-protocol https --web
   ```

   Browser authorization is user-controlled. Do not enter credentials, copy tokens, or claim authentication succeeded before verification.

5. After the user confirms completion, rerun the preflight. Finish only when it returns `status: ready`.

## Completion Criteria

Require both:

- `gh --version` succeeds.
- `gh auth status --hostname github.com` succeeds.

Treat remote configuration as outside scope. A later workflow may inspect or configure `git remote`, create a repository, and push.

## Script Output

`scripts/Ensure-GitHubCli.ps1` emits one JSON object with:

- `status`: `ready`, `missing`, `needs-login`, `install-failed`, or `unsupported`
- `ghPath`: resolved executable path when available
- `version`: first line of `gh --version` when available
- `message`: concise next-step or diagnostic text
