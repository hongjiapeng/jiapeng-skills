# Scripts

These scripts create and validate folder structures only.

They do not:

- delete files
- move files
- format or repartition disks
- edit the registry
- modify OneDrive
- require administrator rights

Dry run:

```powershell
.\create-folder-structure.ps1 -RootPath "D:\" -IncludeDeveloper -IncludePhotographer -IncludePrivate -WhatIf
.\create-folder-structure.ps1 -RootPath "D:\" -IncludePhotographyLearning -WhatIf
```

Create:

```powershell
.\create-folder-structure.ps1 -RootPath "D:\" -IncludeDeveloper -IncludePhotographer -IncludePrivate
.\create-folder-structure.ps1 -RootPath "D:\" -IncludePhotographyLearning
```

Validate:

```powershell
.\validate-folder-structure.ps1 -RootPath "D:\" -IncludeDeveloper -IncludePhotographer -IncludePrivate
.\validate-folder-structure.ps1 -RootPath "D:\" -IncludePhotographyLearning
```
