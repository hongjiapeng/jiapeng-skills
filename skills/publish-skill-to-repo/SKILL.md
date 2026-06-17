---
name: publish-skill-to-repo
description: Publish a local Codex skill into a Git repository while keeping Codex skill discovery working. Use when the user wants to move or link a skill from CODEX_HOME skills into a repo such as a personal GitHub skills collection, create a Windows junction back to the repo copy, inspect an existing junction, avoid duplicate skill copies, validate the skill, or prepare a skill folder for open sourcing.
---

# Publish Skill To Repo

## Purpose

Use this skill to make a Git repository the source of truth for a Codex skill while preserving the usual `$CODEX_HOME/skills/<skill-name>` discovery path through a Windows directory junction.

## Workflow

1. Identify the skill name, repo skills directory, and Codex skills directory.
2. Run the helper script in dry-run mode first.
3. If the plan is safe, run it without `-DryRun`.
4. Validate the skill from the repo path.
5. Check Git status in the repo and report new or changed files.

## Helper Script

Use `scripts/Publish-SkillToRepo.ps1`.

Typical command:

```powershell
& "$env:CODEX_HOME\skills\publish-skill-to-repo\scripts\Publish-SkillToRepo.ps1" `
  -SkillName "my-skill" `
  -RepoSkillsDir "<repo-skills-dir>" `
  -DryRun
```

Then run again without `-DryRun`.

The script supports:

- Moving a real local skill directory from `$CODEX_HOME/skills/<skill>` into the repo.
- Creating a junction from `$CODEX_HOME/skills/<skill>` to the repo copy.
- Recreating a missing junction when the repo copy already exists.
- Reporting when the skill is already correctly linked.
- Refusing unsafe states, especially when both source and repo contain real directories.

## Safety Rules

- Do not delete or overwrite a real skill directory automatically.
- Do not create a junction if the target path resolves outside `-RepoSkillsDir`.
- Treat `$CODEX_HOME/skills/<skill>` as the discovery entrance, not necessarily the source of truth.
- Use `Remove-Item` only for an existing junction/reparse point, not for a real directory.
- After linking, run the skill validator from the repo copy.

## Validation

After publishing:

```powershell
$env:PYTHONUTF8 = "1"
python "$env:CODEX_HOME\skills\.system\skill-creator\scripts\quick_validate.py" `
  "<repo-skills-dir>\my-skill"
```

For open-source preparation, also scan the repo skill folder for local paths, emails, tokens, and real organization names before committing.
