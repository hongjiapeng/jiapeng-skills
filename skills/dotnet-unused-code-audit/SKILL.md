---
name: dotnet-unused-code-audit
description: Audit C#/.NET and Visual Studio repositories for unused-code cleanup candidates, stale projects, unreachable solution graph nodes, WPF/UWP temporary projects, generated artifacts, and low-confidence symbol candidates. Use when an agent or user is asked to find conservative cleanup opportunities in .NET, WPF, UWP, Visual Studio solution, or mixed native/.NET repositories.
---

# .NET Unused Code Audit

## Overview

Use this skill to perform conservative unused-code analysis for .NET-oriented repositories. Prefer evidence from build configuration and dependency graphs over raw text search. Never delete candidates during the detection pass unless the user explicitly asks for cleanup.

## Workflow

1. Establish the analysis root and main entry points.
   - For Visual Studio repositories, identify the `.sln`, package projects, executable projects, and product entry projects.
   - If entry points are ambiguous, run the bundled script with defaults, then interpret the roots it selected.

2. Resolve the bundled scanner from this skill directory, then run it from the repository root. Do not hard-code a user profile, Codex, or machine-specific install path.

When using this skill from a cloned/open-source copy, set `$SkillDir` to the directory that contains this `SKILL.md`:

```powershell
$SkillDir = Resolve-Path ".\skills\dotnet-unused-code-audit"
$Scanner = Join-Path $SkillDir "scripts\analyze-unused-code.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File $Scanner -Root .
```

Use explicit product roots when known:

```powershell
$SkillDir = Resolve-Path ".\skills\dotnet-unused-code-audit"
$Scanner = Join-Path $SkillDir "scripts\analyze-unused-code.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File $Scanner -Root . -ProductRoots "App\App.csproj","Package\App.wapproj"
```

Add symbol-level candidates only when the user wants a deeper, slower pass:

```powershell
$SkillDir = Resolve-Path ".\skills\dotnet-unused-code-audit"
$Scanner = Join-Path $SkillDir "scripts\analyze-unused-code.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File $Scanner -Root . -IncludeSymbolScan
```

The report hides the absolute analysis root by default. Add `-ShowAbsoluteRoot` only for local debugging when full paths are useful.

3. Classify findings by confidence:
   - **High confidence**: WPF temporary projects, generated artifacts tracked in git, exact files explicitly removed from `Compile`/`Page` but still present, source files included only as `None`, projects outside the solution with no external references.
   - **Medium confidence**: Solution projects unreachable from selected product roots, duplicate project copies, sample/debug/test projects not in the product graph, local projects replaced by package references.
   - **Low confidence**: Type or member names with no text references. Treat WPF XAML, DI, reflection, serialization, plugin loading, native exports, app manifests, and string-based routing as possible hidden references.

4. Verify before recommending deletion:
   - Search for candidate names across code, XAML, JSON, manifests, build scripts, package scripts, docs, and CI.
   - Check `.csproj`, `.vcxproj`, `.wapproj`, `.sln`, `.props`, `.targets`, `.projitems`, and packaging files.
   - If a project is not reachable by `ProjectReference`, check shared-project `Import` entries and packaged binaries.
   - Build or run tests after any cleanup proposal if the user asks to make changes.

## Output Guidance

Report findings as cleanup candidates, not absolute truth. Include the evidence source: solution graph, project item removal, git-tracked generated artifact, no product-root reachability, or symbol scan.

Suggested sections:

- High-confidence cleanup candidates
- Product-unreachable projects
- Not-in-solution or stale project files
- Generated artifacts and temporary files
- Symbol-level candidates needing manual review
- Risks and verification steps

Keep warnings explicit: static analysis can miss reflection, XAML bindings, MEF/DI registration, native P/Invoke exports, dynamically loaded assemblies, and plugin/config driven code.
