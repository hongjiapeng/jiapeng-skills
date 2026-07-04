# jiapeng-skills

[中文](README.zh-CN.md) | English

A collection of reusable skills by [hongjiapeng](https://github.com/hongjiapeng), focused on Windows automation, system tooling, and practical agent workflows.

This repository is a **monorepo for ClawHub / OpenClaw skills**.  
Each skill lives in its own folder and can be published independently.

---

## Why this repo exists

I plan to build and maintain multiple skills over time, instead of creating a separate repository for each one.

This repo is used to:

- organize all my skills in one place
- keep each skill self-contained and publishable
- make versioning and maintenance easier
- provide a clean homepage target for each skill published to ClawHub

---

## Skills

| Skill | Description |
|-------|-------------|
| [windows-app-manager](skills/windows-app-manager/) | Controlled Windows app management, currently powered by winget. Safe search, install, upgrade, local app resolution, and uninstall with structured JSON output. |
| [clipvault](skills/clipvault/) | Transcribe, summarize, and archive online video/article content into a personal knowledge vault. Supports YouTube, Bilibili, 小红书, X, TikTok, and more. |
| [dev-setup](skills/dev-setup/) | Bootstrap a new Windows dev machine with a standard directory layout, Git identity auto-switching (personal vs work), and personal repo cloning. |

> More skills will be added over time. Stay tuned!

---

## Setup: make skills available to agents

VS Code Copilot agents scan `%USERPROFILE%\.agents\skills\` to discover available skills.
The setup script [`scripts/Link-Skills.ps1`](scripts/Link-Skills.ps1) creates **directory junctions** from that location into this repository, so skills stay version-controlled here while being globally available to agents.

For the default setup, you can double-click [`scripts/Link-Skills.cmd`](scripts/Link-Skills.cmd).
It runs the PowerShell script and keeps the window open so you can read the result.

```powershell
# Link all skills
.\scripts\Link-Skills.ps1

# Same default setup through the double-click wrapper
.\scripts\Link-Skills.cmd

# Or link a specific skill only
.\scripts\Link-Skills.ps1 -SkillName dev-setup

# Optional: specify a custom target directory
.\scripts\Link-Skills.ps1 -AgentsSkillsDir "D:\other\.agents\skills"
```

The script is safe to re-run: already linked skills are skipped, and conflicts are reported without overwriting existing files.

### Why junctions, not shortcuts?

| | Directory Junction | Windows Shortcut (.lnk) |
|---|---|---|
| **Level** | NTFS filesystem | Application-layer file |
| **Transparent to programs** | Yes, looks like a real folder | No, tools must explicitly resolve it |
| **Icon in Explorer** | Normal folder, no arrow | Folder with arrow overlay |
| **Works with VS Code / agents** | Yes | No |
| **Admin required** | No | No |

Junctions are handled by the operating system at the filesystem layer; any program that opens the path sees the real directory contents directly.

---

## Repository structure

```text
jiapeng-skills/
├─ README.md
├─ skills/
│  ├─ clipvault/
│  │  └─ SKILL.md
│  ├─ windows-app-manager/
│  │  ├─ scripts/
│  │  └─ SKILL.md
│  └─ ...
├─ docs/
└─ scripts/
```
