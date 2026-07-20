# Configuration and installer selection

## Contents

- Installer selection
- JSON configuration
- Generation commands
- Submission layout

## Installer selection

| Release artifact | Manifest settings | Important checks |
|---|---|---|
| `.msix` / `.msixbundle` | `installerType: msix` | Identity, signature, architecture, version |
| `.msi` | `installerType: msi` | Silent behavior, product code, scope |
| Setup `.exe` | `installerType: exe`, `inno`, `nullsoft`, `burn`, or `wix` | Correct silent switches and exit codes |
| Standalone `.exe` | `installerType: portable` | Command alias and external user-data storage |
| ZIP containing a portable app | `installerType: zip`, `nestedInstallerType: portable` | Executable relative path and sibling runtime files |
| ZIP containing an installer | `installerType: zip` plus the actual nested installer type | Nested installer path and silent behavior |

For a multi-file portable ZIP, use `archiveBinariesDependOnPath: true` when the executable needs DLLs, static web assets, configuration, or other sibling files. Do not set `scope` for a portable installer; WinGet validation warns that it is unsupported.

## JSON configuration

The generator accepts UTF-8 JSON. Required root fields are `packageIdentifier`, `packageVersion`, `defaultLocale`, `publisher`, `packageName`, `license`, `shortDescription`, `installerType`, and `installers`.

```json
{
  "packageIdentifier": "ExamplePublisher.ExampleTool",
  "packageVersion": "1.2.3",
  "defaultLocale": "en-US",
  "publisher": "ExamplePublisher",
  "publisherUrl": "https://github.com/example",
  "publisherSupportUrl": "https://github.com/example/example-tool/issues",
  "packageName": "ExampleTool",
  "packageUrl": "https://github.com/example/example-tool",
  "license": "MIT",
  "licenseUrl": "https://github.com/example/example-tool/blob/main/LICENSE",
  "shortDescription": "Transfer files between devices on a local network.",
  "description": "A longer optional description.",
  "moniker": "exampletool",
  "tags": ["file-transfer", "lan"],
  "releaseNotesUrl": "https://github.com/example/example-tool/releases/tag/v1.2.3",
  "releaseDate": "2026-07-20",
  "installerType": "zip",
  "nestedInstallerType": "portable",
  "archiveBinariesDependOnPath": true,
  "commands": ["exampletool"],
  "installers": [
    {
      "architecture": "x64",
      "installerUrl": "https://github.com/example/example-tool/releases/download/v1.2.3/example-tool-win-x64.zip",
      "installerSha256": null,
      "nestedInstallerFiles": [
        {
          "relativeFilePath": "exampletool.exe",
          "portableCommandAlias": "exampletool"
        }
      ]
    }
  ],
  "locales": [
    {
      "packageLocale": "zh-CN",
      "shortDescription": "在局域网设备之间传输文件。",
      "description": "可选的中文详细描述。",
      "tags": ["局域网", "文件传输"]
    }
  ]
}
```

Omit `installerSha256` or set it to `null` to download the asset and calculate the hash. Supply a 64-character SHA256 and use `-Offline` to prohibit downloads. Each installer may define its own `nestedInstallerFiles` array.

Optional root `scope` is supported for compatible non-portable installers. The generator rejects it for `portable` and ZIP-portable packages.

For EXE installers, provide verified silent switches at the root or per installer:

```json
{
  "installerType": "exe",
  "installModes": ["silent", "silentWithProgress"],
  "upgradeBehavior": "install",
  "installerSwitches": {
    "silent": "/S",
    "silentWithProgress": "/S",
    "upgrade": "/S"
  }
}
```

Supported switch keys are `silent`, `silentWithProgress`, `interactive`, `installLocation`, `log`, `upgrade`, `custom`, and `repair`. Common optional fields include root `minimumOSVersion`, `upgradeBehavior`, `installModes`, and installer-level `installerLocale`, `scope`, `productCode`, and `packageFamilyName`. Always discover and test real installer switches; never guess them from the file extension.

## Generation commands

```powershell
$skill = "<path-to-winget-package-publisher>"
$output = "<winget-pkgs>\manifests\e\ExamplePublisher\ExampleTool\1.2.3"

& "$skill\scripts\New-WinGetManifest.ps1" `
  -ConfigPath ".\winget-package.json" `
  -OutputDirectory $output `
  -Validate
```

Use `-Force` only after confirming the target version directory is the intended one. The script refuses to overwrite generated files by default.

## Submission layout

For `ExamplePublisher.ExampleTool` version `1.2.3`, submit:

```text
manifests/e/ExamplePublisher/ExampleTool/1.2.3/
├─ ExamplePublisher.ExampleTool.yaml
├─ ExamplePublisher.ExampleTool.installer.yaml
├─ ExamplePublisher.ExampleTool.locale.en-US.yaml
└─ ExamplePublisher.ExampleTool.locale.zh-CN.yaml
```

The first directory is the lowercase first character of the PackageIdentifier. Preserve identifier casing in every filename and YAML field.
