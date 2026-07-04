# Windows Workstation Plan

## 1. User Profile Summary

- PC ownership:
- Main scenarios:
- Current drives:
- Sync/backup tools:
- Sensitive or company data:

## 2. Recommended Partition Strategy

- Keep `C:\` for Windows, applications, tools, and caches.
- Use `D:\` or another data drive for active user data when available.
- Do not create extra drive letters only for visual neatness.

## 3. Recommended Folder Structure

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

## 4. Scenario Modules

Add only the modules that match the user's actual scenarios.

## 5. Work/Personal Boundary

Define which folders, accounts, Git remotes, and sync tools are allowed for work and personal material.

## 6. Sync Strategy

State the master copy for documents, code, media, and archives.

## 7. Backup Strategy

State local, cloud, offline, and NAS responsibilities.

## 8. Risk Reminders

- Do not delete files automatically.
- Do not move large file sets without a reviewed migration plan.
- Do not modify system directories.
- Do not format or repartition disks from this plan.

## 9. PowerShell Folder Creation Command

```powershell
.\create-folder-structure.ps1 -RootPath "D:\" -WhatIf
```

After review:

```powershell
.\create-folder-structure.ps1 -RootPath "D:\"
```

## 10. Weekly Organization Rule

Review `00_Inbox` and `90_Temp` weekly. Move useful files into the correct durable folder and leave only disposable material in `90_Temp`.

## 11. Root README

After creating the folder structure, recommend adding a root README such as `D:\README.md`. It should summarize folder meanings, work/personal boundaries, sync rules, backup rules, and what must not be stored in cloud-synced folders.
