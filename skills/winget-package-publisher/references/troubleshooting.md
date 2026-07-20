# WinGet publication troubleshooting

## Contents

- Release and hash problems
- Local validation and installation
- Pull request labels and closures
- Pipeline interpretation
- Recovery rules

## Release and hash problems

- **New GitHub asset returns 404:** release uploads can propagate after the release page appears. Poll the exact URL with bounded retries, then download it. Do not substitute a workflow artifact URL because it may require authentication or expire.
- **Hash mismatch:** stop. Confirm the manifest URL, architecture, and asset version. A publisher must not replace an asset after submission; publish a new version instead.
- **ZIP validates but app fails:** inspect the archive tree. Confirm `NestedInstallerFiles.RelativeFilePath`, supporting files, and `ArchiveBinariesDependOnPath`.
- **Portable app loses user files:** move defaults to `%LOCALAPPDATA%\<Product>` or another user-data directory before publication. Preserve explicit configuration overrides.

## Local validation and installation

- `winget validate` returning a warning is not submission-ready. Fix the warning.
- `Scope is not supported for InstallerType portable`: remove `Scope` from the portable installer manifest.
- Local manifest installation requires the administrator-controlled `LocalManifestFiles` setting. Do not claim the test passed when elevation was unavailable.
- Test install and uninstall in a disposable environment when possible. Never remove an existing `%LOCALAPPDATA%\<Product>` directory merely to make a test clean.
- For archive-only smoke tests, disable automatic browser launch and tray behavior when supported, start on an unused port, exercise essential APIs or commands, and stop only the process created by the test.

## Pull request labels and closures

- **Needs-CLA:** the user must personally read and accept the Microsoft CLA. For personally owned contributions, the bot commonly requests `@microsoft-github-policy-service agree`. Employer-owned work needs the company form. Never post either statement for the user.
- **Unexpected-File:** inspect the final diff and commit history. Confirm that only one package version directory is changed and its path begins with the lowercase first character of the identifier.
- **noContent / “does not update any files”:** a policy bot observed an empty final diff, often because deletion and addition were pushed separately. Create a fresh branch from current upstream `master`, add the complete final directory, validate, commit once, and open a new PR.
- **Duplicate package/PR:** search the source and open PRs using the exact identifier and product name. Update the existing submission instead of opening another competing PR.

## Pipeline interpretation

GitHub and Azure DevOps expose different state:

- `All checks have passed` on GitHub can mean only the CLA check has passed.
- Open the `WinGetSvc-Validation-*` link from the wingetbot comment to see manifest, catalog, installer, and post-validation stages.
- A running Azure pipeline is not an approval and not a failure.
- Warnings from internal Guardian or 1ES dependency setup can be Microsoft infrastructure issues. Treat them as non-package failures only when package validation stages remain healthy and no actionable bot comment identifies the manifest.
- `Review required` means automation is complete or progressing but a maintainer with write access must approve. The contributor cannot satisfy that gate.

## Recovery rules

1. Preserve the published release and its hash.
2. Reproduce the reported issue locally when possible.
3. Fix the source package first when the installer is defective; do not paper over application defects in YAML.
4. Regenerate the entire version manifest set, run `winget validate`, and inspect `git diff --check`.
5. Push one complete fix. Do not expose intermediate empty or deletion-only diffs to policy bots.
6. If a bot already closed a PR for transient no-content state, prefer a clean branch and new PR with one final commit.
