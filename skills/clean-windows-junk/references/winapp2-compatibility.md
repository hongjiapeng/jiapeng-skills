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

Pin a reviewed rules file or commit for repeatable behavior. Run `ValidateRules` and a read-only representative scan before adopting a new revision. Never update the local rules file as a side effect of scanning or cleaning.

## Licensing

FluentCleaner source code is MIT licensed. Winapp2 data is CC BY-SA 4.0. If a Winapp2 file is bundled, modified, or redistributed, preserve its attribution and license header and distribute adapted rule data under compatible share-alike terms.
