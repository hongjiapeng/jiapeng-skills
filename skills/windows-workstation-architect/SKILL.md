---
name: windows-workstation-architect
description: Design a clean, safe, and role-aware Windows workstation structure. Use this skill when a user asks how to partition a Windows PC, organize folders, separate work and personal documents, manage code, photos, videos, backups, sync, or set up a clean file system for one or multiple computers.
---

# Windows Workstation Architect

## Overview

Help users design Windows file-system order instead of blindly tidying files. Diagnose how the workstation is used, generate a conservative plan, then provide only safe, reviewable folder-creation commands.

## Core Rules

Follow these rules in every answer:

1. Keep `C:\` primarily for Windows, applications, development tools, and system caches.
2. Prefer `D:\` or another data drive for active user data when available.
3. Do not recommend creating many drive letters only for neatness.
4. Layer work, personal files, code, media, archives, and temporary files.
5. Keep company files out of personal cloud drives, personal GitHub accounts, and personal sync folders.
6. Recommend encryption for sensitive personal data.
7. Manage code with Git; do not recommend syncing `.git` repositories through OneDrive, iCloud, or similar tools.
8. Give photos and videos a separate backup strategy; do not leave them only on the local PC.
9. Never automatically delete files.
10. Never move large numbers of files without explicit user confirmation and a reviewed migration plan.
11. Never suggest directly moving or deleting `AppData`, `Program Files`, `Windows`, or other system directories.
12. Never execute or propose execution of formatting, repartitioning, volume deletion, or similar dangerous disk operations.
13. Ensure PowerShell scripts are safe by default, idempotent, and reviewable.

## Workflow

1. Collect usage context.
2. Map the context to scenarios.
3. Recommend a conservative partition and folder structure.
4. Add scenario modules only when relevant.
5. State work/personal boundaries, sync strategy, backup strategy, and risks.
6. Provide reviewable PowerShell commands using `scripts/create-folder-structure.ps1`.
7. Recommend a root README after folder creation so the directory rules remain visible.
8. Avoid migration, deletion, formatting, repartitioning, registry edits, and OneDrive redirection.

## Questionnaire

Ask at most five questions in the first round:

1. Is this a personal PC, company PC, or mixed work/personal PC?
2. What are the main usage scenarios? Allow multiple choices: office documents, software development, design/UI/assets, photography, video editing, learning/notes, finance/contracts/identity, gaming, multi-PC sync.
3. What drives or disks are available now, such as only `C:\`, `C:\` plus `D:\`, external drives, or NAS?
4. Do you use OneDrive, iCloud, NAS, external drives, Git, or another sync/backup method?
5. Are there company confidential files or sensitive personal files that need isolation or encryption?

If the user already provides enough context, do not repeat questions. Generate a conservative plan and state assumptions.

Use these scenario keys internally:

```yaml
user_scenarios:
  - office_documents
  - software_development
  - design_assets
  - photography
  - video_editing
  - learning_notes
  - personal_finance
  - company_work
  - multi_pc_sync
  - gaming
```

## Default Structure

Recommend this baseline when a data drive is available:

```text
D:\
├─ 00_Inbox
├─ 10_Work
├─ 20_Personal
├─ 30_Code
├─ 40_Media
├─ 50_Archive
└─ 90_Temp
```

- `00_Inbox`: downloads, screenshots, files waiting for triage
- `10_Work`: company or professional work documents, meetings, reports, project files
- `20_Personal`: identity, finance, life, notes
- `30_Code`: isolated work and personal repositories
- `40_Media`: photos, videos, design assets, exports
- `50_Archive`: completed projects and historical files
- `90_Temp`: explicitly disposable temporary files

Use `Work` to mean company or professional responsibility, not all personal effort. Personal products, learning, hobbies, and side projects should stay under `20_Personal` or `30_Code\Personal`.

## Scenario Modules

Compose modules based on usage scenarios, not one identity label.

### Developer

When `software_development` is present, include:

```text
D:\30_Code
├─ Work
│  └─ CompanyName
├─ Personal
│  ├─ Products
│  ├─ OpenSource
│  └─ Labs
├─ Forks
├─ Tools
└─ Sandbox
```

Rules:

- Separate company and personal code.
- Prefer company code in `D:\30_Code\Work\CompanyName`, not under `D:\10_Work`.
- Use `D:\10_Work` for work documents and project material; use `D:\30_Code\Work` for actual code repositories.
- Use company Git only for company code.
- Use GitHub, GitLab, or Gitee private repositories for personal private code when appropriate.
- Do not put Git repositories inside OneDrive or iCloud.
- Prefer short English paths without spaces or special characters.
- Example paths: `D:\30_Code\Work\CompanyName\ProductName`, `D:\30_Code\Personal\Products\AppName`.

### Designer

When `design_assets` is present, include:

```text
D:\40_Media\Design
├─ Projects
├─ Assets
├─ Fonts
├─ Icons
├─ Screenshots
├─ References
├─ Exports
└─ Archive
```

Keep fonts, icons, brand assets, references, source files, and exports separate. Back up design source files.

### Photography And Video

When `photography` or `video_editing` is present, include:

```text
D:\40_Media
├─ Photos
│  ├─ 2026
│  └─ Lightroom
├─ Videos
│  ├─ 2026
│  └─ Projects
├─ Exports
└─ Assets
```

Use this shoot/project pattern:

```text
2026-07-04_Shanghai_StreetPortrait
├─ 00_Raw
├─ 10_Selects
├─ 20_Edit
├─ 30_Export
└─ 90_Rejects
```

Rules: separate RAW, selects, edits, exports, and rejects; keep Lightroom catalogs separate from original media; back up originals and video material offline; cloud-sync selected exports when useful; name shoots as `YYYY-MM-DD_Location_Topic`.

### Office

When `office_documents` or `company_work` is present, include:

```text
D:\10_Work
├─ Documents
├─ Meetings
├─ Reports
├─ References
├─ Projects
└─ Archive
```

Move completed work into `Archive`. Keep company files in company-approved systems.

### Learning

When `learning_notes` is present, include:

```text
D:\20_Personal\Learning
├─ Courses
├─ Notes
├─ Books
├─ Papers
├─ Assignments
└─ Exams
```

Support Obsidian, Markdown, OneNote, or similar tools, but keep attachments organized and backed up.

For photography learning material, prefer a topical learning folder instead of the media project area:

```text
D:\20_Personal\Learning\Photography
├─ Courses
├─ Notes
├─ Books
├─ References
├─ Practice
└─ Attachments
```

Rules: photography courses, tutorials, lesson videos, books, notes, composition references, lighting references, and practice assignments belong under `D:\20_Personal\Learning\Photography`; original photos, videos, Lightroom catalogs, edits, and exports belong under `D:\40_Media`.

### Sensitive Files

When `personal_finance`, company confidential files, or sensitive personal files are present, include:

```text
D:\20_Personal\_Private
├─ Identity
├─ Contracts
├─ Tax
├─ Bank
├─ Insurance
└─ Legal
```

Recommend BitLocker, VeraCrypt, or encrypted archives. Keep identity and contract backups offline. Do not leave sensitive files scattered across Downloads, Desktop, or chat app caches.

### Multiple PCs

When `multi_pc_sync` is present, output device roles:

```text
主力工作机
个人主力机
备用测试机
移动设备
NAS / 移动硬盘 / 服务器
```

Rules:

- Give each computer a clear role.
- Do not make every computer responsible for everything.
- Define the master copy location for each data type.
- Use Git as the main sync mechanism for code.
- Use cloud sync for documents when policy allows.
- Use local plus offline/NAS backups for large media.
- Keep company data inside company-approved sync methods.

## Output Format

Use `templates/workstation-plan.md` as the final answer structure:

1. User profile summary
2. Recommended partition strategy
3. Recommended folder structure
4. Scenario modules
5. Work/personal boundary
6. Sync strategy
7. Backup strategy
8. Risk reminders
9. PowerShell folder creation command
10. Weekly organization rule
11. Optional root README, for example `D:\README.md`, summarizing folder meanings, sync rules, and backup rules

## Bundled Resources

- Read `templates/profile-questionnaire.md` when the user needs a questionnaire.
- Read `templates/workstation-plan.md` when generating a final plan.
- Read `templates/backup-strategy.md` when backup guidance needs more detail.
- Read files in `references/` when the corresponding topic needs more precise rules.
- Use `scripts/create-folder-structure.ps1` only to create directories after the user can review the command. Use `-IncludePhotographyLearning` or `-Profile PhotographyLearning` for photography learning folders.
- Use `scripts/validate-folder-structure.ps1` to check whether the planned directories exist.
