# jiapeng-skills

[中文](README.zh-CN.md) | English

A collection of reusable skills by [hongjiapeng](https://github.com/hongjiapeng), focused on Windows automation, workstation setup, system diagnostics, and practical agent workflows.

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

| Id | Skill | Description |
|----|-------|-------------|
| 001 | [adobe-leave-organizations](skills/adobe-leave-organizations/) | Automate leaving Adobe Account enterprise/team organizations while keeping named organizations, with guarded browser automation for login, profile chooser, reauthentication, and confirmation pages. |
| 002 | [clipvault](skills/clipvault/) | Transcribe, summarize, and archive online video/article content into a personal knowledge vault. Supports YouTube, Bilibili, 小红书, X, TikTok, and more. |
| 003 | [dev-setup](skills/dev-setup/) | Bootstrap or reorganize a Windows development workstation with a configurable directory layout, directory-scoped Git identities, dry-run previews, and optional repository cloning. |
| 004 | [directory-lock-detector](skills/directory-lock-detector/) | Detect which process is locking or occupying a Windows directory using WMI and PowerShell module scanning. |
| 005 | [dotnet-unused-code-audit](skills/dotnet-unused-code-audit/) | Audit C#/.NET and Visual Studio repositories for conservative unused-code cleanup candidates, stale projects, unreachable solution graph nodes, and generated artifacts. |
| 006 | [fix-uwp-proxy-loopback](skills/fix-uwp-proxy-loopback/) | Diagnose and repair Windows UWP/AppContainer app failures caused by local proxy loopback restrictions. |
| 007 | [publish-skill-to-repo](skills/publish-skill-to-repo/) | Publish a local Codex skill into a Git repository while keeping Codex skill discovery working through junctions and validation checks. |
| 008 | [windows-app-manager](skills/windows-app-manager/) | Controlled Windows app management, currently powered by winget. Supports safe search, show, download, install, upgrade, uninstall, installed-app resolution, and upgrade listing with structured JSON output. |
| 009 | [windows-workstation-architect](skills/windows-workstation-architect/) | Design a clean, safe, role-aware Windows workstation structure for partitions, folders, work/personal separation, media, backups, sync, and multi-computer setups. |
| 010 | [spec-driven-delivery](skills/spec-driven-delivery/) | Create lightweight implementation-ready specs, plans, acceptance criteria, verification checklists, and final coding-agent prompts from vague product or engineering requests. |
| 011 | [winget-package-publisher](skills/winget-package-publisher/) | Publish and update public Windows applications in WinGet with guarded manifest generation, validation, fork/PR submission, CLA handoff, and pipeline troubleshooting. |
| 012 | [browser-bookmark-manager](skills/browser-bookmark-manager/) | Safely scan, audit, deduplicate, back up, restore, and optimize Edge and Chrome bookmarks across Windows, macOS, and Linux, including verified Edge Favorites bar icon-only display. |
| 013 | [clean-windows-junk](skills/clean-windows-junk/) | Safely scan and clean selected Windows application caches, temporary files, and logs with Winapp2.ini rules, reviewable plans, and explicit confirmation before deletion. |
| 014 | [github-cli-setup](skills/github-cli-setup/) | Detect, install, locate, authenticate, and verify GitHub CLI on Windows, including PATH refresh handling after WinGet installation. |

Each folder is self-contained. Some skills include scripts, templates, references, or agent manifests alongside `SKILL.md`.

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
├─ README.zh-CN.md
├─ scripts/
│  ├─ Link-Skills.cmd
│  └─ Link-Skills.ps1
├─ skills/
│  ├─ adobe-leave-organizations/
│  ├─ browser-bookmark-manager/
│  ├─ clean-windows-junk/
│  ├─ clipvault/
│  ├─ dev-setup/
│  ├─ directory-lock-detector/
│  ├─ dotnet-unused-code-audit/
│  ├─ fix-uwp-proxy-loopback/
│  ├─ github-cli-setup/
│  ├─ publish-skill-to-repo/
│  ├─ spec-driven-delivery/
│  ├─ winget-package-publisher/
│  ├─ windows-app-manager/
│  └─ windows-workstation-architect/
└─ ...
```
