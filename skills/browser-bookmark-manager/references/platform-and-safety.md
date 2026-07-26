# Platform and safety reference

## Profile discovery

Prefer the profile path displayed by `edge://version` or `chrome://version`. Default roots are:

| OS | Edge | Chrome |
|---|---|---|
| Windows | `%LOCALAPPDATA%\Microsoft\Edge\User Data` | `%LOCALAPPDATA%\Google\Chrome\User Data` |
| macOS | `~/Library/Application Support/Microsoft Edge` | `~/Library/Application Support/Google/Chrome` |
| Linux | `${XDG_CONFIG_HOME:-~/.config}/microsoft-edge` | `${CHROME_CONFIG_HOME:-${XDG_CONFIG_HOME:-~/.config}}/google-chrome` |

Each browser profile is a child directory containing a `Bookmarks` file. Common directory names are `Default` and `Profile N`, but do not assume those are the only valid names.

Custom enterprise policies and `--user-data-dir` can override these locations. Accept an explicit `Bookmarks` path rather than guessing.

Implementation references:

- [Chromium user data directory documentation](https://chromium.googlesource.com/chromium/src/+/main/docs/user_data_dir.md)
- [Microsoft Edge profile path guidance](https://learn.microsoft.com/en-us/deployedge/edge-learnmore-create-user-directory-vars)
- [Chromium bookmark codec](https://chromium.googlesource.com/chromium/src/+/HEAD/components/bookmarks/browser/bookmark_codec.h)

## Read and write rules

- Scan and report operations are read-only.
- A live browser can rewrite `Bookmarks` at shutdown. Require the affected browser to be fully closed before backup-for-change, restore, or optimization.
- Never edit `Preferences`, `Secure Preferences`, `Local State`, favicon databases, history databases, sync metadata, or unknown files for the supported workflows.
- Validate the source and serialized destination as JSON.
- Validate the stored Chromium bookmark checksum before planning a mutation. Recompute MD5 and optional SHA-256 checksums after any title, URL, folder, or child-list change, following the persisted root order.
- Back up the complete original file before each write.
- Write a temporary sibling file and atomically replace `Bookmarks`.
- Preserve unknown JSON keys and bookmark names.
- Stop when a required field or expected tree shape is missing.
- Never delete bookmarks or folders as an automatic consequence of a report.
- Preserve meaningful URL fragments during duplicate matching. A Swagger route, page anchor, or single-page-app state can change the destination.
- Apply duplicate removal only from a reviewed plan bound to the exact `Bookmarks` path and SHA-256 hash.
- Default duplicate cleanup to exact normalized URLs within the same folder. Treat cross-folder copies as potentially intentional.

## Link-health interpretation

Network results are observations, not deletion authorization:

- `2xx`: normally reachable.
- `3xx` followed to a different final URL: redirect candidate; preserve both URLs in the report.
- `401` or `403`: may require authentication or reject automated clients.
- `404` or `410`: stronger dead-link candidate, but still require user review.
- `429`: rate limiting; retry later rather than treating it as dead.
- `5xx`: remote service failure; do not assume permanent loss.
- timeout, DNS, proxy, or certificate failure: record the exact category and local error text.
- non-HTTP URLs such as `file:`, `javascript:`, extension pages, or internal browser pages: classify as unsupported for network checking, not dead.

The CLI uses a bounded request timeout, follows redirects, avoids downloading response bodies, and falls back from `HEAD` to a minimal `GET` only when the server rejects `HEAD`.

## Edge icon-only field verification

The known Edge representation is a boolean `show_icon` property on URL bookmark nodes beneath `roots.bookmark_bar`; the bookmark `name` remains intact.

Treat this as a version- and platform-sensitive field:

1. Capture before and after snapshots around one manual UI toggle.
2. Verify at least one boolean `show_icon` change.
3. Reject name, URL, child-list, or unknown structural changes.
4. Allow only expected bookkeeping differences such as checksum and modification timestamps in addition to `show_icon`.
5. Bind the confirmation artifact to the live `Bookmarks` absolute path and SHA-256 hash.
6. Recheck both before applying. If the live file changed, repeat the diff procedure.

Chrome does not receive Edge-only `show_icon` writes.
