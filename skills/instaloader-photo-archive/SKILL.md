---
name: instaloader-photo-archive
description: Archive public Instagram profile photos and carousels with Instaloader, resume interrupted downloads, and verify an existing archive for missing or duplicate images. Use for Instagram 摄影作品下载、整账号照片归档、断点续传和重复核验.
---

# Instaloader Photo Archive

Use the profile URL or username and the user's chosen archive root. The script creates one folder per account and preserves the platform's images, captions, and compressed post metadata. Its scope is photos from public profile posts, including photo slides in mixed carousels. For video, Reels, private profiles, or signed-in access, consult the [Instaloader documentation](https://instaloader.github.io/basic-usage.html) and use the workflow appropriate to the user's scope.

Use Python 3.11 or later. Install `instaloader==4.16` in a virtual environment if needed. The downloader is pinned because the public timeline iterator's shortcode adapter uses internals of that version. The offline audit requires only Python.

```sh
python -m pip install instaloader==4.16
python scripts/archive.py PROFILE --output "path/to/Instagram"
python scripts/archive.py PROFILE --output "path/to/Instagram" --audit
```

Run the same download command to resume. Preserve `.instaloader-photo-archive.json` alongside the archive. When the cursor expires or no checkpoint exists, the downloader scans the current timeline by shortcode and skips posts with complete local media. It resumes partial carousels by keeping their existing files. A completed run can be run again to check for newly visible posts and gaps. Keep the downloader's logs when running it in the background and verify the process reached the end of the timeline before reporting completion.

The downloader stops on HTTP 429 and retains its checkpoint. Wait for the rate limit to clear before retrying. For other failures, use the reported exception and pending shortcode to diagnose the interruption. Keep session files, download logs and photo archives outside any repository being published.

Use `--audit` to compare downloaded filenames with the archived metadata and the saved timeline, when available. It also reports byte-identical groups using SHA-256. Identical files in different posts or carousel positions may carry different attribution, so the archive preserves both positions. If the public profile's displayed count differs from the number of unique posts returned by pagination, report both counts and state whether the difference was resolved.
