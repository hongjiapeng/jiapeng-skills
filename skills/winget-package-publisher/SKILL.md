---
name: winget-package-publisher
description: Publish or update public Windows applications in the Microsoft WinGet community repository. Use when Codex needs to assess WinGet eligibility, choose a stable PackageIdentifier, generate and validate manifests for portable ZIP, EXE, MSI, or MSIX releases, create or sync a winget-pkgs fork, submit a clean pull request, monitor CLA and WinGet validation, address bot or maintainer feedback, or automate later package-version updates. Especially useful for GitHub Releases and cross-platform projects that publish Windows artifacts.
---

# WinGet Package Publisher

Publish a Windows release to `microsoft/winget-pkgs` without hard-coding one project. Keep deterministic manifest work in the bundled PowerShell script and use judgment for packaging safety, GitHub operations, and review feedback.

## Required reading

- Read [references/configuration.md](references/configuration.md) before selecting an installer type or creating the JSON configuration.
- Read [references/troubleshooting.md](references/troubleshooting.md) when a bot adds a label, a pipeline fails, a release asset is temporarily unavailable, or a PR must be recovered.
- Browse current Microsoft documentation and the current `microsoft/winget-pkgs` contribution guidance before submission because schemas and repository policy change.

## Workflow

1. Inspect the source repository, license, release workflow, published Windows assets, current Git state, and existing user changes.
2. Decide whether the release is eligible:
   - Require a stable, public HTTPS download URL and an immutable versioned asset.
   - Require a supported installer or portable executable and a distributable license.
   - For portable packages, verify user data is stored outside the executable/package directory. WinGet may replace or remove that directory during upgrade or uninstall.
   - For ZIP portable packages that need sibling files, set `ArchiveBinariesDependOnPath: true` and smoke-test the extracted archive, not only the executable file.
3. Choose the PackageIdentifier before the first accepted submission:
   - Prefer a short, durable `Publisher.Product` identifier.
   - Search both the WinGet source and open `winget-pkgs` PRs for conflicts.
   - Treat the identifier as immutable after acceptance. Do not rename it merely for display preferences in later releases.
4. Verify the release asset:
   - Wait for GitHub Release propagation when a newly uploaded asset briefly returns 404.
   - Download the exact public URL, compute SHA256, inspect archive layout, and confirm the expected executable path.
   - Smoke-test startup and essential operations with browser/tray launch disabled when the app supports those switches.
5. Create a project JSON file described in `references/configuration.md` and run:

```powershell
& "<skill-dir>\scripts\New-WinGetManifest.ps1" `
  -ConfigPath "<package-config.json>" `
  -OutputDirectory "<winget-pkgs-version-directory>" `
  -Validate
```

6. Treat every validation warning as actionable. Do not suppress warnings for submission. Use `-Offline` only when every installer hash is already supplied.
7. Test installation proportionally to risk:
   - Prefer Windows Sandbox, a disposable VM, or a clean user context.
   - Local manifest installation requires the `LocalManifestFiles` administrator setting. Ask before enabling it and restore its previous state afterward.
   - Verify launch, command alias, upgrade behavior, uninstall, and preservation of user data.
   - If elevation is unavailable, report that limitation explicitly and perform archive-level smoke tests; never mark the local install checklist complete.
8. Prepare the contribution from a clean upstream base:
   - Reuse or create the user's fork only within the authorized publishing scope.
   - Fetch the latest upstream `master` and create a new branch from that exact commit.
   - Add the complete version directory, validate it, stage it, and make one focused commit.
   - Push only after the final diff is complete. Never push a transient deletion-only or empty diff; the policy bot may close the PR as `noContent` or label it `Unexpected-File`.
9. Open a ready-for-review PR using the repository title convention, normally `New package: Publisher.Product version X.Y.Z` or `Update: Publisher.Product to X.Y.Z`.
10. Observe human gates:
    - Never accept a CLA or make an employer/ownership declaration for the user. Ask the user to read and respond personally.
    - Ask the user to sign in, approve elevation, solve CAPTCHA, or respond to a legal prompt only when required.
11. Monitor both surfaces separately:
    - GitHub checks may show the CLA as passed while the linked Azure WinGet validation pipeline is still running.
    - Inspect the linked pipeline and distinguish package failures from Microsoft infrastructure warnings.
    - Address actionable bot or maintainer feedback on the same branch, revalidate, and push a complete fix.
12. Finish only when the PR is merged or when an external human gate is clearly reported. After merge and source propagation, verify `winget show --id <id> --exact` and a normal install query.

## Version updates

For an accepted package, preserve the existing identifier, publisher casing, installer type where practical, and locale set. Sync the fork, create only the new version directory, update URLs and hashes, validate, smoke-test, and submit a fresh one-commit PR. Never edit a previously published version to point at a different binary.

## Safety boundaries

- Do not upload private artifacts, secrets, signing keys, or local logs to GitHub.
- Do not overwrite or retag a published release after its hash has been submitted.
- Do not enable administrator settings, install software, create forks, push branches, or open PRs without authorization covering that action.
- Do not delete user data to test uninstall behavior.
- Preserve unrelated worktree changes and use a separate sparse clone or worktree for `winget-pkgs`.
