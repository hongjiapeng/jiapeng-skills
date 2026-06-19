---
name: dev-setup
description: "Bootstrap a new Windows development machine with a standardized directory layout, Git identity config (personal vs work), and personal repo cloning. Triggered when user says: set up a new PC, bootstrap dev environment, organize projects on new machine, or similar."
---

# Dev Environment Setup

Activate this skill when the user wants to set up a new Windows development machine,
or wants to apply the standard project layout to an existing machine.

## Design Principles

- **Path consistency** — All machines use `C:\Dev\` as the root. C drive is used
  because not all machines have a D drive. Short paths reduce friction in terminals.
- **Work / Personal isolation** — Company code lives under `C:\Dev\Work\` and never
  syncs to personal cloud. Personal code lives under `C:\Dev\Personal\` and is backed
  by GitHub.
- **Git identity auto-switching** — `.gitconfig` uses `includeIf "gitdir:..."` so
  the correct email is used automatically per directory. No manual switching needed.
- **One-command bootstrap** — A single `bootstrap.ps1` script recreates the full
  environment on any new machine.

## Directory Layout

Customize the subdirectory grouping under `Personal\` to match your own project
categories. A typical layout looks like:

```
C:\Dev\
├── Work\            # Company projects — Git remote only, no personal cloud sync
├── Personal\        # Personal projects — backed by GitHub
│   ├── <group-a>\   # e.g. a product ecosystem
│   ├── <group-b>\   # e.g. ai-tools, livestream, etc.
│   └── ...
├── Lab\             # Learning / experiments — push to GitHub if worth keeping
└── Sandbox\         # Throwaway tests — not versioned, delete freely
```

## Private Config (dotfiles)

The bundled `bootstrap.ps1` is a **generic template** — no real names, emails, or
repo URLs are included. Keep your personal version (with real config) in a **private
`dotfiles` repository** and source this template from there:

```
dotfiles/  (private repo)
└── bootstrap.ps1    ← fill in your real name, emails, and repo list here
```

This way the skill stays open-source while your actual setup stays private.

## Workflow

1. **Gather info** — Ask the user which step they want:
   - A) Create directory structure only
   - B) Configure Git identity only
   - C) Clone personal repos only
   - D) Full bootstrap (A + B + C)

2. **Locate the bootstrap script.** Either from this skill directory (template):

```powershell
$SkillDir = Resolve-Path ".\skills\dev-setup"
$Script   = Join-Path $SkillDir "scripts\bootstrap.ps1"
```

   Or from the user's private dotfiles repo (with real config filled in).

3. **Run in dry-run mode first** — always preview before executing:

```powershell
# Preview only (safe — no changes made)
powershell -NoProfile -ExecutionPolicy Bypass -File $Script

# Execute after user confirms
powershell -NoProfile -ExecutionPolicy Bypass -File $Script -Execute
```

4. **Manual steps after bootstrap** — remind the user:
   - Clone company repos into `C:\Dev\Work\` from the company Git server
   - Install language runtimes (Node, Python, .NET SDK) as needed
   - Set up IDE settings sync (VS Code Settings Sync, JetBrains Settings Sync)

## Customization

The bootstrap script has a clearly marked `CONFIG` section at the top.
Guide the user to fill it in before running:

| Variable        | What to change                                        |
|-----------------|-------------------------------------------------------|
| `$PersonalName` | Full name for Git commits                             |
| `$PersonalEmail`| Personal GitHub email                                 |
| `$WorkEmail`    | Company email                                         |
| `$SubDirs`      | Subdirectory groups under `Personal\`                 |
| `$PersonalRepos`| List of personal GitHub repo URLs to clone            |
| `$RepoGroups`   | Keyword → subdirectory mapping for auto-routing repos |

## Output Guidance

After running, confirm:
- ✅ Directories created: `C:\Dev\Work`, `C:\Dev\Personal`, `C:\Dev\Lab`, `C:\Dev\Sandbox`
- ✅ Git config written: `~/.gitconfig` and `~/.gitconfig-work`
- ✅ Repos cloned (list with success/failure per repo)
- ⚠️ Any repos that failed to clone (network, auth, etc.)
- 💡 Next steps: install runtimes, clone work repos, IDE sync
