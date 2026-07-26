# Winapp2 compatibility

## Supported fields

The bundled script supports this safe subset:

- section names such as `[Google Chrome Caches *]`;
- `Default`;
- `Warning`;
- `DetectFile`;
- selected `SpecialDetect` values for major browsers and Windows Store apps;
- `FileKeyN`;
- `ExcludeKeyN` with `FILE` or `PATH`;
- `RECURSE` and `REMOVESELF` as recursive file-scan flags;
- semicolon-separated file patterns;
- environment variables and wildcard directory segments.

`REMOVESELF` does not remove directories in this MVP.

## Reported but not executed

- `Detect` registry checks;
- `RegKeyN` deletion rules;
- unsupported `SpecialDetect` values;
- entries without a supported detection method.

## Rejected sources and paths

- Winapp3 is rejected because it intentionally contains aggressive rules.
- Unknown environment variables are rejected.
- File rules outside the safety allowlist are skipped and recorded in the plan.

## Source selection

Use one rules source at a time. Do not merge FluentCleaner’s bundled snapshot with MoscaDotTo/Winapp2 because overlapping section names can produce duplicate or conflicting rules.

Resolve rules in this order:

1. an explicit `-RulesPath`;
2. an explicitly installed or updated copy at `%LOCALAPPDATA%\clean-windows-junk\Winapp2.ini`;
3. the bundled snapshot at `assets\rules\Winapp2.ini`.

The bundled snapshot is FluentCleaner `Winapp2.ini` version `260714` from commit `2793e740dab5053f6a44fbd23fe595c8dc54b892`. Its expected SHA-256 is `7e5380a5b9f5c027b17d3a0646f5b944c04bc32f1e6734396c4da86862540a6f`. See `assets/rules/SOURCE.json` for provenance and `assets/rules/LICENSE.md` for the full license.

Pin and validate a reviewed rules file for repeatable behavior. Run `ValidateRules` and a read-only representative scan before adopting a new revision. Never update the local rules file as a side effect of scanning or cleaning.

With explicit user approval, `InstallRules` downloads from one of two hard-coded HTTPS sources:

- `FluentCleaner`: the FluentCleaner-compatible snapshot, used by default;
- `Winapp2`: the upstream CCleaner flavor.

The installer writes to `%LOCALAPPDATA%\clean-windows-junk\Winapp2.ini` by default, preserves the license header, rejects Winapp3, validates the parsed entry count, and requires `-Force` to replace an existing file. It never accepts an arbitrary URL or modifies the bundled snapshot.

## Licensing

FluentCleaner source code is MIT licensed. Winapp2 data is CC BY-SA 4.0. The bundled rule file remains unmodified, preserves its attribution header, and is accompanied by the upstream CC BY-SA 4.0 license. Distribute adapted rule data under compatible share-alike terms.
