#!/usr/bin/env python3
"""Cross-platform, safety-first manager for Chromium Bookmarks JSON files."""

from __future__ import annotations

import argparse
import concurrent.futures
import datetime as dt
import hashlib
import json
import os
import platform
import re
import shutil
import socket
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Dict, Iterable, Iterator, List, Optional, Sequence, Tuple


SCHEMA_VERSION = 1
SCRIPT_PATH = Path(__file__).resolve()
CONTROL_CHAR_RE = re.compile(r"[\x00-\x1f\x7f]")
HTTP_SCHEMES = {"http", "https"}


@dataclass(frozen=True)
class ProfileRef:
    browser: str
    profile: str
    bookmarks: Path


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat()


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_json(path: Path) -> Dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8-sig") as stream:
            data = json.load(stream)
    except FileNotFoundError as exc:
        raise ValueError(f"File not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"Invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return data


def validate_bookmarks(data: Dict[str, Any], path: Path) -> None:
    roots = data.get("roots")
    if not isinstance(roots, dict):
        raise ValueError(f"Invalid Bookmarks structure in {path}: roots is missing")
    bookmark_bar = roots.get("bookmark_bar")
    if not isinstance(bookmark_bar, dict) or bookmark_bar.get("type") != "folder":
        raise ValueError(
            f"Invalid Bookmarks structure in {path}: roots.bookmark_bar is missing or not a folder"
        )


def compute_bookmark_checksum(data: Dict[str, Any], algorithm: str) -> str:
    digest = hashlib.new(algorithm)

    def update_utf8(value: Any) -> None:
        digest.update(str(value).encode("utf-8", errors="surrogatepass"))

    def update_utf16(value: Any) -> None:
        digest.update(str(value).encode("utf-16-le", errors="surrogatepass"))

    def visit(node: Dict[str, Any]) -> None:
        update_utf8(node.get("id", ""))
        update_utf16(node.get("name", ""))
        node_type = node.get("type")
        if node_type == "url":
            update_utf8("url")
            update_utf8(node.get("url", ""))
        elif node_type == "folder":
            update_utf8("folder")
            children = node.get("children", [])
            if not isinstance(children, list):
                raise ValueError("Folder node has a non-array children field")
            for child in children:
                if isinstance(child, dict):
                    visit(child)

    for root in data.get("roots", {}).values():
        if isinstance(root, dict):
            visit(root)
    return digest.hexdigest()


def validate_stored_checksums(data: Dict[str, Any], path: Path) -> None:
    stored_md5 = data.get("checksum")
    if not isinstance(stored_md5, str) or not stored_md5:
        raise ValueError(f"Bookmarks checksum is missing in {path}")
    computed_md5 = compute_bookmark_checksum(data, "md5")
    if stored_md5.casefold() != computed_md5:
        raise ValueError(
            f"Bookmarks checksum mismatch in {path}; refuse to plan or write"
        )
    stored_sha256 = data.get("checksum_sha256")
    if stored_sha256 is not None:
        if not isinstance(stored_sha256, str) or not stored_sha256:
            raise ValueError(f"Bookmarks checksum_sha256 is invalid in {path}")
        computed_sha256 = compute_bookmark_checksum(data, "sha256")
        if stored_sha256.casefold() != computed_sha256:
            raise ValueError(
                f"Bookmarks checksum_sha256 mismatch in {path}; refuse to plan or write"
            )


def refresh_bookmark_checksums(data: Dict[str, Any]) -> None:
    data["checksum"] = compute_bookmark_checksum(data, "md5")
    if "checksum_sha256" in data:
        data["checksum_sha256"] = compute_bookmark_checksum(data, "sha256")


def write_json_atomic(path: Path, data: Dict[str, Any]) -> None:
    encoded = json.dumps(data, ensure_ascii=False, indent=3).encode("utf-8")
    json.loads(encoded.decode("utf-8"))
    mode = path.stat().st_mode if path.exists() else None
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=str(path.parent)
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(encoded)
            stream.flush()
            os.fsync(stream.fileno())
        if mode is not None:
            os.chmod(temporary, mode)
        read_json(temporary)
        os.replace(temporary, path)
        read_json(path)
    finally:
        if temporary.exists():
            temporary.unlink()


def copy_file_atomic(source: Path, destination: Path) -> None:
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.", suffix=".tmp", dir=str(destination.parent)
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        shutil.copy2(source, temporary)
        read_json(temporary)
        os.replace(temporary, destination)
        read_json(destination)
    finally:
        if temporary.exists():
            temporary.unlink()


def default_user_data_roots() -> Dict[str, List[Path]]:
    home = Path.home()
    system = platform.system()
    if system == "Windows":
        local = Path(os.environ.get("LOCALAPPDATA", home / "AppData" / "Local"))
        return {
            "edge": [local / "Microsoft" / "Edge" / "User Data"],
            "chrome": [local / "Google" / "Chrome" / "User Data"],
        }
    if system == "Darwin":
        support = home / "Library" / "Application Support"
        return {
            "edge": [support / "Microsoft Edge"],
            "chrome": [support / "Google" / "Chrome"],
        }
    xdg = Path(os.environ.get("XDG_CONFIG_HOME", home / ".config"))
    chrome_config = Path(os.environ.get("CHROME_CONFIG_HOME", xdg))
    return {
        "edge": [xdg / "microsoft-edge"],
        "chrome": [chrome_config / "google-chrome"],
    }


def infer_browser(path: Path) -> Optional[str]:
    lowered = str(path).lower().replace("\\", "/")
    if "microsoft edge" in lowered or "/microsoft/edge/" in lowered or "/microsoft-edge/" in lowered:
        return "edge"
    if "/google/chrome/" in lowered or "/google-chrome/" in lowered:
        return "chrome"
    return None


def discover_profiles(browser: str) -> List[ProfileRef]:
    roots = default_user_data_roots()
    browsers = ("edge", "chrome") if browser == "all" else (browser,)
    found: List[ProfileRef] = []
    for current_browser in browsers:
        for root in roots[current_browser]:
            if not root.is_dir():
                continue
            for bookmarks in sorted(root.glob("*/Bookmarks")):
                if bookmarks.is_file():
                    found.append(
                        ProfileRef(current_browser, bookmarks.parent.name, bookmarks.resolve())
                    )
    return found


def resolve_profiles(
    browser: str, explicit_bookmarks: Optional[Sequence[str]], require_one: bool = False
) -> List[ProfileRef]:
    profiles: List[ProfileRef] = []
    if explicit_bookmarks:
        for raw_path in explicit_bookmarks:
            path = Path(raw_path).expanduser().resolve()
            selected_browser = browser
            if selected_browser == "all":
                selected_browser = infer_browser(path) or ""
                if not selected_browser:
                    raise ValueError(
                        f"Cannot infer browser for {path}; pass --browser edge or --browser chrome"
                    )
            profiles.append(ProfileRef(selected_browser, path.parent.name, path))
    else:
        profiles = discover_profiles(browser)
    unique = {
        (item.browser, os.path.normcase(str(item.bookmarks))): item for item in profiles
    }
    result = sorted(unique.values(), key=lambda item: (item.browser, str(item.bookmarks)))
    if not result:
        raise ValueError("No matching Edge or Chrome Bookmarks files were found")
    if require_one and len(result) != 1:
        raise ValueError("This operation requires exactly one Bookmarks file")
    return result


def iter_nodes(
    node: Dict[str, Any], json_path: str, folder_names: Tuple[str, ...]
) -> Iterator[Tuple[Dict[str, Any], str, Tuple[str, ...]]]:
    yield node, json_path, folder_names
    if node.get("type") != "folder":
        return
    children = node.get("children", [])
    if not isinstance(children, list):
        return
    next_names = folder_names + (str(node.get("name", "")),)
    for index, child in enumerate(children):
        if isinstance(child, dict):
            yield from iter_nodes(child, f"{json_path}.children[{index}]", next_names)


def all_root_nodes(data: Dict[str, Any]) -> Iterator[Tuple[Dict[str, Any], str, Tuple[str, ...]]]:
    roots = data.get("roots", {})
    for root_name, root_node in roots.items():
        if isinstance(root_node, dict):
            yield from iter_nodes(root_node, f"roots.{root_name}", ())


def canonical_url(raw_url: str) -> str:
    try:
        parsed = urllib.parse.urlsplit(raw_url.strip())
        scheme = parsed.scheme.lower()
        hostname = (parsed.hostname or "").lower()
        port = parsed.port
    except ValueError:
        return raw_url.strip()
    if (scheme == "http" and port == 80) or (scheme == "https" and port == 443):
        port = None
    host = hostname
    if ":" in hostname and not hostname.startswith("["):
        host = f"[{hostname}]"
    if port:
        host = f"{host}:{port}"
    path = parsed.path or "/"
    return urllib.parse.urlunsplit(
        (scheme, host, path, parsed.query, parsed.fragment)
    )


def structural_report(profile: ProfileRef, data: Dict[str, Any]) -> Dict[str, Any]:
    urls: List[Dict[str, Any]] = []
    empty_folders: List[Dict[str, str]] = []
    title_anomalies: List[Dict[str, str]] = []
    suspicious_urls: List[Dict[str, str]] = []
    folder_count = 0

    for node, json_path, folders in all_root_nodes(data):
        node_type = node.get("type")
        if node_type == "folder":
            folder_count += 1
            children = node.get("children")
            if isinstance(children, list) and not children:
                empty_folders.append(
                    {"path": json_path, "name": str(node.get("name", ""))}
                )
            continue
        if node_type != "url":
            continue
        name = str(node.get("name", ""))
        url = str(node.get("url", ""))
        record = {
            "path": json_path,
            "folder": " / ".join(name for name in folders if name),
            "name": name,
            "url": url,
        }
        urls.append(record)
        reasons: List[str] = []
        if not name.strip():
            reasons.append("blank_title")
        if name.strip() == url.strip() and url.strip():
            reasons.append("title_equals_url")
        if len(name) > 120:
            reasons.append("title_over_120_characters")
        if CONTROL_CHAR_RE.search(name):
            reasons.append("title_contains_control_character")
        for reason in reasons:
            title_anomalies.append({**record, "reason": reason})

        try:
            parsed = urllib.parse.urlsplit(url)
            _ = parsed.port
            scheme = parsed.scheme.lower()
            if not scheme:
                suspicious_urls.append({**record, "reason": "missing_scheme"})
            elif scheme in HTTP_SCHEMES and not parsed.hostname:
                suspicious_urls.append({**record, "reason": "missing_hostname"})
            elif scheme not in HTTP_SCHEMES:
                suspicious_urls.append(
                    {**record, "reason": f"non_http_scheme:{scheme}"}
                )
        except ValueError as exc:
            suspicious_urls.append(
                {**record, "reason": f"malformed_url:{exc}"}
            )

    by_url: Dict[str, List[Dict[str, Any]]] = {}
    for record in urls:
        by_url.setdefault(canonical_url(record["url"]), []).append(record)
    duplicates = [
        {"canonical_url": key, "count": len(records), "bookmarks": records}
        for key, records in sorted(by_url.items())
        if key and len(records) > 1
    ]

    return {
        "browser": profile.browser,
        "profile": profile.profile,
        "bookmarks_file": str(profile.bookmarks),
        "sha256": file_sha256(profile.bookmarks),
        "counts": {
            "url_bookmarks": len(urls),
            "folders": folder_count,
            "duplicate_groups": len(duplicates),
            "empty_folders": len(empty_folders),
            "title_anomalies": len(title_anomalies),
            "suspicious_urls": len(suspicious_urls),
        },
        "duplicates": duplicates,
        "empty_folders": empty_folders,
        "title_anomalies": title_anomalies,
        "suspicious_urls": suspicious_urls,
        "_urls_for_health_check": urls,
    }


def node_fingerprint(node: Dict[str, Any]) -> str:
    encoded = json.dumps(
        node, ensure_ascii=False, sort_keys=True, separators=(",", ":")
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def collect_url_locations(data: Dict[str, Any]) -> List[Dict[str, Any]]:
    locations: List[Dict[str, Any]] = []

    def visit_folder(
        folder: Dict[str, Any],
        folder_path: str,
        ancestor_names: Tuple[str, ...],
    ) -> None:
        children = folder.get("children", [])
        if not isinstance(children, list):
            raise ValueError(f"Expected children array at {folder_path}")
        current_names = ancestor_names + (str(folder.get("name", "")),)
        for index, child in enumerate(children):
            if not isinstance(child, dict):
                continue
            child_path = f"{folder_path}.children[{index}]"
            if child.get("type") == "url":
                locations.append(
                    {
                        "node": child,
                        "path": child_path,
                        "parent_path": folder_path,
                        "parent_children": children,
                        "index": index,
                        "folder": " / ".join(
                            name for name in current_names if name
                        ),
                        "name": str(child.get("name", "")),
                        "url": str(child.get("url", "")),
                        "fingerprint": node_fingerprint(child),
                    }
                )
            elif child.get("type") == "folder":
                visit_folder(child, child_path, current_names)

    roots = data.get("roots", {})
    for root_name, root in roots.items():
        if isinstance(root, dict) and root.get("type") == "folder":
            visit_folder(root, f"roots.{root_name}", ())
    return locations


def title_quality(name: str, url: str) -> Tuple[int, List[str]]:
    stripped = name.strip()
    lowered = stripped.casefold()
    score = 0
    reasons: List[str] = []
    if not stripped:
        score -= 100
        reasons.append("blank_title")
    else:
        score += 20
    error_markers = (
        "隐私错误",
        "privacy error",
        "404",
        "not found",
        "无法访问",
        "untitled",
    )
    if any(marker in lowered for marker in error_markers):
        score -= 50
        reasons.append("error_like_title")
    if stripped == url.strip():
        score -= 10
        reasons.append("title_equals_url")
    if stripped and len(stripped) <= 80:
        score += 5
        reasons.append("concise_title")
    return score, reasons


def public_location(location: Dict[str, Any]) -> Dict[str, Any]:
    score, reasons = title_quality(location["name"], location["url"])
    return {
        "path": location["path"],
        "fingerprint": location["fingerprint"],
        "folder": location["folder"],
        "name": location["name"],
        "url": location["url"],
        "title_quality_score": score,
        "title_quality_notes": reasons,
    }


def command_plan_dedupe(args: argparse.Namespace) -> Dict[str, Any]:
    profile = resolve_profiles(args.browser, args.bookmarks, require_one=True)[0]
    data = read_json(profile.bookmarks)
    validate_bookmarks(data, profile.bookmarks)
    validate_stored_checksums(data, profile.bookmarks)
    locations = collect_url_locations(data)
    grouped: Dict[Tuple[str, ...], List[Dict[str, Any]]] = {}
    for location in locations:
        normalized = canonical_url(location["url"])
        if not normalized:
            continue
        key = (
            (normalized, location["parent_path"])
            if args.scope == "same-folder"
            else (normalized,)
        )
        grouped.setdefault(key, []).append(location)

    plan_groups = []
    for key, records in sorted(grouped.items(), key=lambda item: item[0]):
        if len(records) < 2:
            continue
        ranked = []
        for order, record in enumerate(records):
            score, _ = title_quality(record["name"], record["url"])
            ranked.append((score, -order, record))
        keep = max(ranked, key=lambda item: (item[0], item[1]))[2]
        removals = [record for record in records if record is not keep]
        plan_groups.append(
            {
                "normalized_url": key[0],
                "scope_key": key[1] if len(key) > 1 else None,
                "keep": public_location(keep),
                "remove": [public_location(record) for record in removals],
            }
        )

    plan = {
        "schema_version": SCHEMA_VERSION,
        "kind": "browser-bookmark-dedupe-plan",
        "created_at": utc_now(),
        "browser": profile.browser,
        "profile": profile.profile,
        "bookmarks_file": str(profile.bookmarks),
        "bookmarks_sha256": file_sha256(profile.bookmarks),
        "scope": args.scope,
        "matching_rule": (
            "normalized full URL; scheme and host are case-insensitive, "
            "default ports and empty fragments are ignored, meaningful fragments are preserved"
        ),
        "group_count": len(plan_groups),
        "removal_count": sum(len(group["remove"]) for group in plan_groups),
        "groups": plan_groups,
    }
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
    return {
        "mode": "plan-dedupe",
        "read_only_bookmarks": True,
        "plan_file": str(output),
        "plan": plan,
    }


def command_apply_dedupe(args: argparse.Namespace) -> Dict[str, Any]:
    plan_path = Path(args.plan).expanduser().resolve()
    plan = read_json(plan_path)
    if plan.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("Unsupported dedupe plan schema version")
    if plan.get("kind") != "browser-bookmark-dedupe-plan":
        raise ValueError("The supplied file is not a bookmark dedupe plan")
    browser = str(plan.get("browser", ""))
    if browser not in ("edge", "chrome"):
        raise ValueError("Dedupe plan has an invalid browser")
    bookmarks = Path(str(plan.get("bookmarks_file", ""))).expanduser().resolve()
    data = read_json(bookmarks)
    validate_bookmarks(data, bookmarks)
    validate_stored_checksums(data, bookmarks)
    current_hash = file_sha256(bookmarks)
    if current_hash != plan.get("bookmarks_sha256"):
        raise ValueError(
            "Bookmarks changed after the dedupe plan was generated; generate a new plan"
        )
    removals = [
        item
        for group in plan.get("groups", [])
        for item in group.get("remove", [])
    ]
    result = {
        "mode": "apply-dedupe",
        "browser": browser,
        "profile": plan.get("profile"),
        "bookmarks_file": str(bookmarks),
        "plan_file": str(plan_path),
        "scope": plan.get("scope"),
        "planned_removals": len(removals),
        "dry_run": not args.apply,
        "applied": False,
        "backup_file": None,
        "restore_command": None,
    }
    if not args.apply:
        return result
    if args.confirm != "APPLY":
        raise ValueError("Applying a dedupe plan requires --confirm APPLY")
    require_browser_closed(browser)
    if file_sha256(bookmarks) != plan.get("bookmarks_sha256"):
        raise ValueError(
            "Bookmarks changed while waiting for the browser to close; generate a new plan"
        )

    locations = {item["path"]: item for item in collect_url_locations(data)}
    resolved = []
    for removal in removals:
        path = str(removal.get("path", ""))
        location = locations.get(path)
        if not location:
            raise ValueError(f"Planned bookmark path no longer exists: {path}")
        if location["fingerprint"] != removal.get("fingerprint"):
            raise ValueError(f"Planned bookmark content changed at: {path}")
        resolved.append(location)

    by_parent: Dict[str, List[Dict[str, Any]]] = {}
    for location in resolved:
        by_parent.setdefault(location["parent_path"], []).append(location)
    backup = create_backup(bookmarks, label="pre-dedupe")
    for parent_records in by_parent.values():
        children = parent_records[0]["parent_children"]
        for location in sorted(
            parent_records, key=lambda item: item["index"], reverse=True
        ):
            del children[location["index"]]
    refresh_bookmark_checksums(data)
    write_json_atomic(bookmarks, data)
    result.update(
        {
            "dry_run": False,
            "applied": True,
            "removed": len(resolved),
            "backup_file": str(backup),
            "restore_command": restore_command(browser, bookmarks, backup),
            "new_sha256": file_sha256(bookmarks),
        }
    )
    return result


def check_one_url(url: str, timeout: float) -> Dict[str, Any]:
    try:
        parsed = urllib.parse.urlsplit(url)
    except ValueError as exc:
        return {"url": url, "category": "malformed_url", "error": str(exc)}
    if parsed.scheme.lower() not in HTTP_SCHEMES:
        return {
            "url": url,
            "category": "unsupported_scheme",
            "scheme": parsed.scheme.lower(),
        }
    headers = {
        "User-Agent": "BrowserBookmarkManager/1.0 (+bookmark health check)",
        "Accept": "*/*",
    }

    def request(method: str) -> urllib.response.addinfourl:
        req = urllib.request.Request(url, headers=headers, method=method)
        return urllib.request.urlopen(req, timeout=timeout)

    try:
        try:
            response = request("HEAD")
        except urllib.error.HTTPError as exc:
            if exc.code not in (405, 501):
                raise
            request_headers = dict(headers)
            request_headers["Range"] = "bytes=0-0"
            req = urllib.request.Request(url, headers=request_headers, method="GET")
            response = urllib.request.urlopen(req, timeout=timeout)
        with response:
            status = int(response.getcode() or 0)
            final_url = response.geturl()
        return {
            "url": url,
            "category": "redirect" if final_url != url else "ok",
            "status": status,
            "final_url": final_url,
            "redirected": final_url != url,
        }
    except urllib.error.HTTPError as exc:
        return {
            "url": url,
            "category": "http_error",
            "status": exc.code,
            "final_url": exc.geturl(),
            "error": str(exc.reason),
        }
    except urllib.error.URLError as exc:
        reason = exc.reason
        if isinstance(reason, ssl.SSLCertVerificationError):
            category = "certificate_error"
        elif isinstance(reason, (socket.timeout, TimeoutError)):
            category = "timeout"
        elif isinstance(reason, ssl.SSLError):
            category = "tls_error"
        else:
            category = "network_error"
        return {"url": url, "category": category, "error": str(reason)}
    except (socket.timeout, TimeoutError) as exc:
        return {"url": url, "category": "timeout", "error": str(exc)}
    except ssl.SSLError as exc:
        return {"url": url, "category": "tls_error", "error": str(exc)}
    except Exception as exc:  # Preserve unexpected per-URL failures in the report.
        return {"url": url, "category": "unexpected_error", "error": str(exc)}


def health_report(urls: Iterable[str], timeout: float, workers: int) -> List[Dict[str, Any]]:
    unique_urls = sorted(set(urls))
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as executor:
        future_map = {
            executor.submit(check_one_url, url, timeout): url for url in unique_urls
        }
        results = [future.result() for future in concurrent.futures.as_completed(future_map)]
    return sorted(results, key=lambda item: item["url"])


def browser_is_running(browser: str) -> bool:
    system = platform.system()
    try:
        if system == "Windows":
            image = "msedge.exe" if browser == "edge" else "chrome.exe"
            result = subprocess.run(
                ["tasklist", "/FI", f"IMAGENAME eq {image}", "/NH"],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
            return image.lower() in result.stdout.lower()
        if system == "Darwin":
            marker = (
                "/Microsoft Edge.app/"
                if browser == "edge"
                else "/Google Chrome.app/"
            )
            result = subprocess.run(
                ["pgrep", "-f", marker],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
            return result.returncode == 0 and bool(result.stdout.strip())
        names = (
            ["msedge", "microsoft-edge"]
            if browser == "edge"
            else ["chrome", "google-chrome"]
        )
        for name in names:
            result = subprocess.run(
                ["pgrep", "-x", name],
                check=False,
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode == 0 and result.stdout.strip():
                return True
    except (FileNotFoundError, subprocess.SubprocessError):
        return False
    return False


def require_browser_closed(browser: str) -> None:
    if browser_is_running(browser):
        raise ValueError(
            f"{browser.title()} is running. Close it completely before modifying or restoring Bookmarks."
        )


def timestamp() -> str:
    return dt.datetime.now().strftime("%Y%m%d_%H%M%S")


def create_backup(source: Path, output_dir: Optional[Path] = None, label: str = "backup") -> Path:
    destination_dir = output_dir.resolve() if output_dir else source.parent
    destination_dir.mkdir(parents=True, exist_ok=True)
    if output_dir:
        safe_profile = re.sub(r"[^A-Za-z0-9._-]+", "_", source.parent.name)
        name = f"{safe_profile}_Bookmarks.{label}.{timestamp()}.json"
    else:
        name = f"Bookmarks.browser-bookmark-{label}.{timestamp()}"
    destination = destination_dir / name
    counter = 1
    while destination.exists():
        destination = destination.with_name(f"{destination.name}.{counter}")
        counter += 1
    shutil.copy2(source, destination)
    if file_sha256(source) != file_sha256(destination):
        destination.unlink(missing_ok=True)
        raise ValueError(f"Backup verification failed for {source}")
    return destination


def restore_command(browser: str, bookmarks: Path, backup: Path) -> str:
    def quoted(value: Path) -> str:
        return '"' + str(value).replace('"', '\\"') + '"'

    return (
        f"python {quoted(SCRIPT_PATH)} restore --browser {browser} "
        f"--bookmarks {quoted(bookmarks)} --backup {quoted(backup)} "
        "--apply --confirm RESTORE"
    )


def command_scan(args: argparse.Namespace) -> Dict[str, Any]:
    profiles = resolve_profiles(args.browser, args.bookmarks)
    records = []
    for profile in profiles:
        data = read_json(profile.bookmarks)
        validate_bookmarks(data, profile.bookmarks)
        report = structural_report(profile, data)
        records.append(
            {
                "browser": profile.browser,
                "profile": profile.profile,
                "bookmarks_file": str(profile.bookmarks),
                "sha256": report["sha256"],
                "counts": report["counts"],
            }
        )
    return {
        "mode": "scan",
        "read_only": True,
        "platform": platform.system(),
        "generated_at": utc_now(),
        "profiles": records,
    }


def command_report(args: argparse.Namespace) -> Dict[str, Any]:
    profiles = resolve_profiles(args.browser, args.bookmarks)
    reports = []
    all_urls: List[str] = []
    for profile in profiles:
        data = read_json(profile.bookmarks)
        validate_bookmarks(data, profile.bookmarks)
        report = structural_report(profile, data)
        all_urls.extend(record["url"] for record in report.pop("_urls_for_health_check"))
        reports.append(report)
    health = health_report(all_urls, args.timeout, args.workers) if args.check_links else []
    category_counts: Dict[str, int] = {}
    for result in health:
        category = str(result.get("category", "unknown"))
        category_counts[category] = category_counts.get(category, 0) + 1
    return {
        "mode": "report",
        "read_only": True,
        "platform": platform.system(),
        "generated_at": utc_now(),
        "link_check": {
            "performed": bool(args.check_links),
            "timeout_seconds": args.timeout if args.check_links else None,
            "unique_urls_checked": len(health),
            "category_counts": category_counts,
            "results": health,
        },
        "profiles": reports,
    }


def json_differences(before: Any, after: Any, path: str = "") -> List[Dict[str, Any]]:
    if type(before) is not type(after):
        return [{"path": path, "before": before, "after": after}]
    if isinstance(before, dict):
        differences: List[Dict[str, Any]] = []
        for key in sorted(set(before) | set(after)):
            child_path = f"{path}.{key}" if path else key
            if key not in before:
                differences.append({"path": child_path, "before": None, "after": after[key]})
            elif key not in after:
                differences.append({"path": child_path, "before": before[key], "after": None})
            else:
                differences.extend(json_differences(before[key], after[key], child_path))
        return differences
    if isinstance(before, list):
        if len(before) != len(after):
            return [{"path": path, "before_length": len(before), "after_length": len(after)}]
        differences = []
        for index, (left, right) in enumerate(zip(before, after)):
            differences.extend(json_differences(left, right, f"{path}[{index}]"))
        return differences
    if before != after:
        return [{"path": path, "before": before, "after": after}]
    return []


def is_expected_metadata_difference(path: str) -> bool:
    return (
        path == "checksum"
        or path.endswith(".date_modified")
        or path.endswith(".date_last_used")
    )


def command_verify_icon_diff(args: argparse.Namespace) -> Dict[str, Any]:
    before_path = Path(args.before).expanduser().resolve()
    after_path = Path(args.after).expanduser().resolve()
    live_path = Path(args.live_bookmarks).expanduser().resolve()
    before = read_json(before_path)
    after = read_json(after_path)
    live = read_json(live_path)
    validate_bookmarks(before, before_path)
    validate_bookmarks(after, after_path)
    validate_bookmarks(live, live_path)
    after_hash = file_sha256(after_path)
    live_hash = file_sha256(live_path)
    if after_hash != live_hash:
        raise ValueError(
            "The live Bookmarks file does not match the after snapshot; close Edge and recapture"
        )
    differences = json_differences(before, after)
    show_icon_changes = []
    metadata_changes = []
    unexpected_changes = []
    for difference in differences:
        path = str(difference["path"])
        if path.endswith(".show_icon"):
            before_value = difference.get("before")
            after_value = difference.get("after")
            if not isinstance(after_value, bool) or not (
                isinstance(before_value, bool) or before_value is None
            ):
                unexpected_changes.append(difference)
            else:
                show_icon_changes.append(difference)
        elif is_expected_metadata_difference(path):
            metadata_changes.append(difference)
        else:
            unexpected_changes.append(difference)
    if not show_icon_changes:
        raise ValueError("No boolean show_icon change was found in the before/after diff")
    if unexpected_changes:
        paths = ", ".join(item["path"] for item in unexpected_changes[:10])
        raise ValueError(f"Unexpected bookmark differences found: {paths}")
    confirmation = {
        "schema_version": SCHEMA_VERSION,
        "kind": "edge-show-icon-field-confirmation",
        "created_at": utc_now(),
        "platform": platform.system(),
        "live_bookmarks": str(live_path),
        "live_sha256": live_hash,
        "field_addition_confirmed": any(
            item.get("before") is None and isinstance(item.get("after"), bool)
            for item in show_icon_changes
        ),
        "show_icon_changes": show_icon_changes,
        "allowed_metadata_changes": metadata_changes,
        "safety_statement": "name and url fields were unchanged",
    }
    output = Path(args.output).expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(confirmation, ensure_ascii=False, indent=2), encoding="utf-8")
    return {
        "mode": "verify-icon-diff",
        "read_only_bookmarks": True,
        "confirmation_file": str(output),
        "confirmation": confirmation,
    }


def bookmark_bar_targets(data: Dict[str, Any], recurse: bool) -> List[Tuple[Dict[str, Any], str]]:
    root = data["roots"]["bookmark_bar"]
    targets: List[Tuple[Dict[str, Any], str]] = []

    def visit(folder: Dict[str, Any], path: str) -> None:
        children = folder.get("children", [])
        if not isinstance(children, list):
            raise ValueError(f"Expected children array at {path}")
        for index, child in enumerate(children):
            child_path = f"{path}.children[{index}]"
            if not isinstance(child, dict):
                continue
            if child.get("type") == "url":
                targets.append((child, child_path))
            elif recurse and child.get("type") == "folder":
                visit(child, child_path)

    visit(root, "roots.bookmark_bar")
    return targets


def load_icon_confirmation(path: Path, live: Path) -> Dict[str, Any]:
    confirmation = read_json(path)
    if confirmation.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("Unsupported confirmation schema version")
    if confirmation.get("kind") != "edge-show-icon-field-confirmation":
        raise ValueError("The confirmation file is not for Edge show_icon")
    confirmed_path = Path(str(confirmation.get("live_bookmarks", ""))).resolve()
    if os.path.normcase(str(confirmed_path)) != os.path.normcase(str(live.resolve())):
        raise ValueError("The confirmation artifact is bound to a different Bookmarks file")
    current_hash = file_sha256(live)
    if confirmation.get("live_sha256") != current_hash:
        raise ValueError(
            "Bookmarks changed after field verification; repeat the before/after diff"
        )
    return confirmation


def command_optimize_icon_only(args: argparse.Namespace) -> Dict[str, Any]:
    profile = resolve_profiles(args.browser, args.bookmarks, require_one=True)[0]
    if profile.browser != "edge":
        raise ValueError("Icon-only optimization is supported only for Microsoft Edge")
    data = read_json(profile.bookmarks)
    validate_bookmarks(data, profile.bookmarks)
    validate_stored_checksums(data, profile.bookmarks)
    confirmation_path = Path(args.confirmation).expanduser().resolve()
    confirmation = load_icon_confirmation(confirmation_path, profile.bookmarks)
    field_addition_confirmed = bool(confirmation.get("field_addition_confirmed"))
    desired = not args.disable
    targets = bookmark_bar_targets(data, args.recurse)
    eligible = []
    skipped_missing_field = []
    already_desired = []
    for node, path in targets:
        if "show_icon" not in node:
            if desired and field_addition_confirmed:
                eligible.append((node, path))
            elif not desired:
                already_desired.append(path)
            else:
                skipped_missing_field.append(path)
        elif not isinstance(node["show_icon"], bool):
            raise ValueError(f"Non-boolean show_icon found at {path}")
        elif node["show_icon"] == desired:
            already_desired.append(path)
        else:
            eligible.append((node, path))
    if (
        targets
        and not any("show_icon" in node for node, _ in targets)
        and not field_addition_confirmed
    ):
        raise ValueError("No Favorites bar URL node contains the verified show_icon field")
    preview = {
        "mode": "optimize-icon-only",
        "browser": "edge",
        "profile": profile.profile,
        "bookmarks_file": str(profile.bookmarks),
        "desired_show_icon": desired,
        "recursive": bool(args.recurse),
        "url_nodes_scanned": len(targets),
        "would_change": len(eligible),
        "already_desired": len(already_desired),
        "skipped_missing_show_icon": len(skipped_missing_field),
        "dry_run": not args.apply,
        "applied": False,
        "backup_file": None,
        "restore_command": None,
    }
    if not args.apply:
        return preview
    if args.confirm != "APPLY":
        raise ValueError("Applying icon-only changes requires --confirm APPLY")
    require_browser_closed("edge")
    load_icon_confirmation(confirmation_path, profile.bookmarks)
    if not eligible:
        preview["dry_run"] = False
        return preview
    backup = create_backup(profile.bookmarks, label="pre-optimize")
    for node, _ in eligible:
        node["show_icon"] = desired
    refresh_bookmark_checksums(data)
    write_json_atomic(profile.bookmarks, data)
    preview.update(
        {
            "dry_run": False,
            "applied": True,
            "changed": len(eligible),
            "backup_file": str(backup),
            "restore_command": restore_command("edge", profile.bookmarks, backup),
            "new_sha256": file_sha256(profile.bookmarks),
        }
    )
    return preview


def command_backup(args: argparse.Namespace) -> Dict[str, Any]:
    profiles = resolve_profiles(args.browser, args.bookmarks)
    output_dir = Path(args.output_dir).expanduser().resolve() if args.output_dir else None
    results = []
    for profile in profiles:
        require_browser_closed(profile.browser)
        data = read_json(profile.bookmarks)
        validate_bookmarks(data, profile.bookmarks)
        backup = create_backup(profile.bookmarks, output_dir, label=profile.browser)
        results.append(
            {
                "browser": profile.browser,
                "profile": profile.profile,
                "bookmarks_file": str(profile.bookmarks),
                "backup_file": str(backup),
                "sha256": file_sha256(backup),
                "restore_command": restore_command(
                    profile.browser, profile.bookmarks, backup
                ),
            }
        )
    return {
        "mode": "backup",
        "generated_at": utc_now(),
        "backups": results,
    }


def command_restore(args: argparse.Namespace) -> Dict[str, Any]:
    profile = resolve_profiles(args.browser, [args.bookmarks], require_one=True)[0]
    backup = Path(args.backup).expanduser().resolve()
    backup_data = read_json(backup)
    validate_bookmarks(backup_data, backup)
    validate_stored_checksums(backup_data, backup)
    result = {
        "mode": "restore",
        "browser": profile.browser,
        "profile": profile.profile,
        "bookmarks_file": str(profile.bookmarks),
        "restore_from": str(backup),
        "backup_sha256": file_sha256(backup),
        "dry_run": not args.apply,
        "applied": False,
        "pre_restore_backup": None,
    }
    if not args.apply:
        return result
    if args.confirm != "RESTORE":
        raise ValueError("Restoring requires --confirm RESTORE")
    require_browser_closed(profile.browser)
    current_data = read_json(profile.bookmarks)
    validate_bookmarks(current_data, profile.bookmarks)
    pre_restore = create_backup(profile.bookmarks, label="pre-restore")
    copy_file_atomic(backup, profile.bookmarks)
    if file_sha256(profile.bookmarks) != file_sha256(backup):
        raise ValueError(
            f"Restore verification failed; the original file remains at {pre_restore}"
        )
    result.update(
        {
            "dry_run": False,
            "applied": True,
            "pre_restore_backup": str(pre_restore),
            "restored_sha256": file_sha256(profile.bookmarks),
            "undo_restore_command": restore_command(
                profile.browser, profile.bookmarks, pre_restore
            ),
        }
    )
    return result


def add_target_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--browser", choices=("edge", "chrome", "all"), default="all"
    )
    parser.add_argument(
        "--bookmarks",
        action="append",
        help="Explicit path to a Bookmarks file; repeat for multiple profiles",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Safely scan, report, back up, restore, and optimize browser bookmarks."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan = subparsers.add_parser("scan", help="Discover and summarize bookmark profiles")
    add_target_arguments(scan)
    scan.set_defaults(handler=command_scan)

    report = subparsers.add_parser("report", help="Generate a read-only health report")
    add_target_arguments(report)
    report.add_argument("--check-links", action="store_true")
    report.add_argument("--timeout", type=float, default=8.0)
    report.add_argument("--workers", type=int, default=12)
    report.add_argument("--output", help="Optional JSON report output path")
    report.set_defaults(handler=command_report)

    plan_dedupe = subparsers.add_parser(
        "plan-dedupe", help="Create a hash-bound exact-duplicate removal plan"
    )
    add_target_arguments(plan_dedupe)
    plan_dedupe.add_argument(
        "--scope", choices=("same-folder", "all"), default="same-folder"
    )
    plan_dedupe.add_argument("--output", required=True)
    plan_dedupe.set_defaults(handler=command_plan_dedupe)

    apply_dedupe = subparsers.add_parser(
        "apply-dedupe", help="Preview or apply a reviewed dedupe plan"
    )
    apply_dedupe.add_argument("--plan", required=True)
    apply_dedupe.add_argument("--apply", action="store_true")
    apply_dedupe.add_argument("--confirm")
    apply_dedupe.set_defaults(handler=command_apply_dedupe)

    verify = subparsers.add_parser(
        "verify-icon-diff", help="Verify Edge show_icon from before/after snapshots"
    )
    verify.add_argument("--before", required=True)
    verify.add_argument("--after", required=True)
    verify.add_argument("--live-bookmarks", required=True)
    verify.add_argument("--output", required=True)
    verify.set_defaults(handler=command_verify_icon_diff)

    optimize = subparsers.add_parser(
        "optimize-icon-only", help="Preview or apply Edge Favorites bar icon-only state"
    )
    add_target_arguments(optimize)
    optimize.add_argument("--confirmation", required=True)
    optimize.add_argument("--recurse", action="store_true")
    optimize.add_argument("--disable", action="store_true")
    optimize.add_argument("--apply", action="store_true")
    optimize.add_argument("--confirm")
    optimize.set_defaults(handler=command_optimize_icon_only)

    backup = subparsers.add_parser("backup", help="Back up complete Bookmarks files")
    add_target_arguments(backup)
    backup.add_argument("--output-dir")
    backup.set_defaults(handler=command_backup)

    restore = subparsers.add_parser("restore", help="Preview or restore one Bookmarks file")
    restore.add_argument("--browser", choices=("edge", "chrome"), required=True)
    restore.add_argument("--bookmarks", required=True)
    restore.add_argument("--backup", required=True)
    restore.add_argument("--apply", action="store_true")
    restore.add_argument("--confirm")
    restore.set_defaults(handler=command_restore)
    return parser


def emit_result(result: Dict[str, Any], output: Optional[str] = None) -> None:
    rendered = json.dumps(result, ensure_ascii=False, indent=2)
    if output:
        output_path = Path(output).expanduser().resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if hasattr(args, "timeout") and args.timeout <= 0:
        parser.error("--timeout must be greater than zero")
    if hasattr(args, "workers") and not 1 <= args.workers <= 64:
        parser.error("--workers must be between 1 and 64")
    try:
        result = args.handler(args)
        emit_result(result, getattr(args, "output", None) if args.command == "report" else None)
        return 0
    except (ValueError, OSError) as exc:
        print(json.dumps({"error": str(exc), "command": args.command}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
