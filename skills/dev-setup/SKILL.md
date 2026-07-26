---
name: dev-setup
description: Bootstrap or reorganize a Windows development workstation with a configurable directory layout, directory-scoped Git identities, and optional repository cloning. Use when setting up a new Windows PC, standardizing project folders, separating work and personal Git identities, or reproducing a development layout without embedding machine-specific or personal values in public files.
---

# Windows Development Setup

Use the bundled script as a generic executor and keep all machine-specific values
in a private PowerShell data file.

## Safety rules

- Keep names, email addresses, repository URLs, organization names, usernames, and
  machine-specific paths out of this skill directory.
- Store the populated configuration outside public repositories. Prefer a private
  dotfiles repository or another user-controlled location.
- Run a dry run before applying changes.
- Do not overwrite an existing `.gitconfig`. Let the script add directory-scoped
  `includeIf` entries that point to separate identity files.
- Treat a direct request to apply or run the setup as approval only after the dry-run
  output matches the requested scope.

## Workflow

1. Determine whether the user needs `Directories`, `Git`, `Repositories`, or `All`.
2. Copy `assets/config.example.psd1` to a private location.
3. Populate only the fields needed for the selected steps.
4. Inspect the configuration for unintended personal data before sharing or committing it.
5. Run the selected steps without `-Execute` and review the plan.
6. Rerun with `-Execute` when the plan is correct.
7. Verify created directories, effective Git identities, and repository clone results.

## Locate bundled files

Resolve the skill directory from the active skill location instead of assuming a
repository checkout path:

```powershell
$BootstrapScript = Join-Path $SkillDirectory "scripts\bootstrap.ps1"
$ConfigTemplate = Join-Path $SkillDirectory "assets\config.example.psd1"
```

Copy the template outside the public skill directory:

```powershell
Copy-Item -LiteralPath $ConfigTemplate -Destination $PrivateConfigPath
```

## Configuration

Use the following top-level keys:

| Key | Purpose |
|---|---|
| `RootPath` | Absolute path or a path relative to the private configuration file |
| `Directories.Work` | Work directory relative to `RootPath` |
| `Directories.Personal` | Personal directory relative to `RootPath` |
| `Directories.Additional` | Other directories relative to `RootPath` |
| `Directories.PersonalGroups` | Optional groups relative to the personal directory |
| `Git.ConfigDirectory` | Optional identity-file location; blank uses local application data |
| `Git.Personal` | Personal Git `Name` and `Email`; provide both or neither |
| `Git.Work` | Work Git `Name` and `Email`; provide both or neither |
| `Repositories` | Repository records with `Url` and optional personal-relative `Destination` |

Do not add real values to `assets/config.example.psd1`.

## Run

Preview all configured steps:

```powershell
& $BootstrapScript -ConfigPath $PrivateConfigPath
```

Preview a subset:

```powershell
& $BootstrapScript `
    -ConfigPath $PrivateConfigPath `
    -Step Directories, Git
```

Override `RootPath` for a one-off run without editing the private configuration:

```powershell
& $BootstrapScript `
    -ConfigPath $PrivateConfigPath `
    -RootPath $TemporaryDevelopmentRoot `
    -Step Directories
```

Apply the reviewed plan:

```powershell
& $BootstrapScript `
    -ConfigPath $PrivateConfigPath `
    -Step Directories, Git `
    -Execute
```

## Verify

- Confirm every planned directory exists.
- Run `git config user.name` and `git config user.email` from repositories under
  each configured identity root.
- Report each cloned, skipped, or failed repository without exposing credentials.
- Recommend runtime and IDE installation only when requested; do not hardcode a
  package list into this skill.
