# jiapeng-skills

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

## Repository structure

```text
jiapeng-skills/
├─ README.md
├─ skills/
│  ├─ winget-package-manager/
│  │  ├─ SKILL.md
│  │  ├─ README.md
│  │  └─ winget-skill.ps1
│  └─ ...
├─ docs/
└─ scripts/