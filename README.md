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
| [winget-package-manager](skills/winget-package-manager/) | Controlled Windows package management via winget. Safe search, install, upgrade, uninstall — structured JSON output. |
| [clipvault](skills/clipvault/) | Transcribe, summarize, and archive online video/article content into a personal knowledge vault. Supports YouTube, Bilibili, 小红书, X, TikTok, and more. |

> More skills will be added over time. Stay tuned!

---

## Repository structure

```text
jiapeng-skills/
├─ README.md
├─ skills/
│  ├─ clipvault/
│  │  └─ SKILL.md
│  ├─ winget-package-manager/
│  │  ├─ scripts/
│  │  └─ SKILL.md
│  └─ ...
├─ docs/
└─ scripts/