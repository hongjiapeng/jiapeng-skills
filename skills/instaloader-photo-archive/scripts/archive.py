import argparse
import hashlib
import json
import lzma
import os
import re
import sys
from collections import Counter, defaultdict
from contextlib import contextmanager
from datetime import datetime
from pathlib import Path
from urllib.parse import urlsplit

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".avif"}
STATE_NAME = ".instaloader-photo-archive.json"
STEM_PATTERN = re.compile(r"\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_UTC_([A-Za-z0-9_-]+)")


def profile_name(value):
    url = urlsplit(value)
    if url.scheme:
        if url.scheme != "https" or url.netloc.lower() not in {"instagram.com", "www.instagram.com"}:
            raise argparse.ArgumentTypeError("Use an Instagram profile URL or username.")
        value = url.path.strip("/")
    if not re.fullmatch(r"[A-Za-z0-9_][A-Za-z0-9_.]{0,29}", value.lstrip("@")):
        raise argparse.ArgumentTypeError("Use an Instagram profile URL or username.")
    return value.lstrip("@").lower()


def expected_images(stem, kind, video_flags=()):
    if kind == "GraphImage":
        return {stem}
    if kind == "GraphSidecar":
        return {f"{stem}_{i}" for i, video in enumerate(video_flags, 1) if not video}
    if kind == "GraphVideo":
        return set()
    raise ValueError(f"Unknown post type: {kind}")


def inspect_archive(target):
    files = [path for path in target.iterdir() if path.is_file()
             and path.suffix.lower() in IMAGE_SUFFIXES and path.stat().st_size > 0]
    images = {path.stem for path in files}
    complete, incomplete, missing, expected = set(), set(), set(), set()
    for path in sorted(target.glob("*.json.xz")):
        stem = path.name.removesuffix(".json.xz")
        match = STEM_PATTERN.fullmatch(stem)
        if not match:
            continue
        code = match[1]
        try:
            with lzma.open(path, "rt", encoding="utf-8") as stream:
                node = json.load(stream)["node"]
            kind = node["__typename"]
            edges = node["edge_sidecar_to_children"]["edges"] if kind == "GraphSidecar" else []
            names = expected_images(stem, kind, (edge["node"]["is_video"] for edge in edges))
        except (EOFError, ValueError, KeyError, TypeError, lzma.LZMAError):
            incomplete.add(code)
            continue
        expected.update(names)
        missing.update(names - images)
        (complete if names <= images else incomplete).add(code)
    return complete - incomplete, incomplete, missing, expected, files


def read_state(target):
    path = target / STATE_NAME
    return json.loads(path.read_text(encoding="utf-8")) if path.is_file() else {}


def write_state(target, iterator, seen, pending, done=False):
    path = target / STATE_NAME
    tmp = path.with_suffix(".tmp")
    data = {"iterator": iterator.freeze()._asdict(), "seen": sorted(seen),
            "pending": sorted(pending), "done": done}
    tmp.write_text(json.dumps(data), encoding="utf-8")
    tmp.replace(path)


def audit(target):
    complete, incomplete, missing, expected, files = inspect_archive(target)
    state = read_state(target)
    sizes = defaultdict(list)
    hashes = defaultdict(list)
    for path in files:
        sizes[path.stat().st_size].append(path)
    for group in sizes.values():
        if len(group) > 1:
            for path in group:
                with path.open("rb") as stream:
                    hashes[hashlib.file_digest(stream, "sha256").hexdigest()].append(path.name)
    counts = Counter(path.stem for path in files)
    print(json.dumps({
        "timeline_exhausted": state.get("done"),
        "timeline_posts_seen": len(state["seen"]) if state else None,
        "archived_posts_complete": len(complete),
        "photos": len(files),
        "missing_posts": sorted((set(state.get("seen", ())) - complete) | incomplete),
        "missing_photo_positions": sorted(missing),
        "photos_without_matching_metadata": sorted(counts.keys() - expected),
        "duplicate_photo_positions": sorted(stem for stem, n in counts.items() if n > 1),
        "identical_file_groups": sorted(sorted(group) for group in hashes.values() if len(group) > 1),
    }, indent=2))


def download(account, target):
    from instaloader import Instaloader, Post, Profile, __version__
    from instaloader.exceptions import InvalidArgumentException
    from instaloader.nodeiterator import FrozenNodeIterator

    if __version__ != "4.16":
        raise RuntimeError("This download adapter requires instaloader==4.16.")

    class PhotoLoader(Instaloader):
        def download_pic(self, filename, url, mtime, filename_suffix=None):
            stem = filename if filename_suffix is None else f"{filename}_{filename_suffix}"
            if any(Path(stem + suffix).is_file() and Path(stem + suffix).stat().st_size > 0
                   for suffix in IMAGE_SUFFIXES):
                return False
            return super().download_pic(filename, url, mtime, filename_suffix)

    complete, _, _, _, files = inspect_archive(target)
    images = {path.stem for path in files}
    print(f"Archive inventory: {len(complete)} complete posts, {len(files)} images.", flush=True)
    loader = PhotoLoader(dirname_pattern="{target}", filename_pattern="{date_utc}_UTC_{shortcode}",
                         download_videos=False, download_video_thumbnails=False,
                         sanitize_paths=True, max_connection_attempts=3, request_timeout=25,
                         fatal_status_codes=[429])
    iterator = Profile.from_username(loader.context, account).get_posts()
    # The public timeline exposes shortcodes. Hydrate full metadata only for missing posts.
    iterator._node_wrapper = lambda node: node["code"]
    iterator._is_first = None
    saved = read_state(target)
    seen, pending = set(), set(saved.get("pending", ()))
    if saved and not saved["done"] and (saved["iterator"]["best_before"] or 0) > datetime.now().timestamp():
        try:
            iterator.thaw(FrozenNodeIterator(**saved["iterator"]))
        except InvalidArgumentException:
            print("Saved cursor changed. Scanning the timeline by shortcode.", flush=True)
        else:
            seen.update(saved["seen"])

    def fetch(code):
        if code in complete:
            return
        post = Post.from_shortcode(loader.context, code)
        if post.shortcode != code:
            raise RuntimeError(f"Post {code} redirected to another post.")
        stem = loader.format_filename(post, target=target)
        flags = post.get_is_videos() if post.typename == "GraphSidecar" else ()
        expected = expected_images(stem, post.typename, flags)
        print(f"Post {code}: {len(expected - images)} photo positions to fill.", flush=True)
        loader.download_post(post, target)
        print(flush=True)
        for name in expected - images:
            if any((target / f"{name}{suffix}").is_file()
                   and (target / f"{name}{suffix}").stat().st_size > 0 for suffix in IMAGE_SUFFIXES):
                images.add(name)
        if expected - images or not (target / f"{stem}.json.xz").is_file():
            raise RuntimeError(f"Post {code} is incomplete on disk.")
        complete.add(code)

    try:
        for code in sorted(pending | (seen - complete)):
            fetch(code)
            pending.discard(code)
        for code in iterator:
            seen.add(code)
            if code not in complete:
                pending.add(code)
                write_state(target, iterator, seen, pending)
                fetch(code)
                pending.remove(code)
                write_state(target, iterator, seen, pending)
            if iterator.total_index % 25 == 0:
                write_state(target, iterator, seen, pending)
                print(f"Checked {len(seen)} distinct timeline posts.", flush=True)
        if iterator._data.get("page_info", {}).get("has_next_page"):
            raise RuntimeError("Instagram indicated more pages but returned no new page.")
        complete, incomplete, _, _, files = inspect_archive(target)
        pending.update((seen - complete) | incomplete)
        if pending:
            raise RuntimeError(f"Archive verification found {len(pending)} incomplete posts.")
        write_state(target, iterator, seen, pending, done=True)
        print(f"Timeline exhausted: {len(seen)} visible posts verified, {len(files)} images on disk.")
    except BaseException:
        write_state(target, iterator, seen, pending)
        raise


@contextmanager
def archive_lock(target):
    with (target / ".instaloader-photo-archive.lock").open("a+b") as lock:
        try:
            if os.name == "nt":
                import msvcrt

                lock.seek(0)
                msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl

                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError as exc:
            raise RuntimeError("Cannot lock this archive. Check for another downloader.") from exc
        yield


def main():
    parser = argparse.ArgumentParser(description="Archive and verify photos from a public Instagram profile.")
    parser.add_argument("profile", type=profile_name)
    parser.add_argument("--output", required=True, type=Path, help="Parent directory for the profile archive.")
    parser.add_argument("--audit", action="store_true", help="Inspect the existing archive without network access.")
    args = parser.parse_args()
    target = args.output.resolve() / args.profile
    if args.audit:
        audit(target)
    else:
        target.mkdir(parents=True, exist_ok=True)
        with archive_lock(target):
            download(args.profile, target)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:
        message = re.sub(r"https?://\S+|/v/t51\.\S+", "[URL]", str(exc))
        print(f"{type(exc).__name__}: {message}", file=sys.stderr)
        sys.exit(1)
