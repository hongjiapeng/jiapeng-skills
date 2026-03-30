---
name: clipvault
description: "ClipVault — transcribe, summarize, and archive online content into a personal knowledge vault. 转录、摘要、归档互联网内容。Triggered when user sends a video/article URL and asks to transcribe, summarize, or store it. Supports YouTube, Bilibili, 小红书, X, TikTok, and more."
---

# ClipVault — Knowledge Archival Workflow

Activate this skill when the user sends a video or article URL and asks to
transcribe, process, summarize, or archive it.

## Supported Platforms

- YouTube
- Bilibili
- 小红书 / Xiaohongshu (video + image-text notes)
- X (Twitter)
- 抖音 / Douyin, Instagram, TikTok
- Any platform supported by yt-dlp

## Architecture

Package: `clipvault` (src layout at `src/clipvault/`).

```
src/clipvault/
  cli/          # argparse entry point
  config/       # AppSettings (immutable) + RuntimeConfig (per-run overrides)
  domain/       # Pure logic (transcript cleaning)
  models/       # Dataclasses: PipelineResult, ResourceInput, TranscriptResult, SummaryResult
  providers/    # ABCs + concrete: download/ytdlp, transcription/whisper_local, summarization/ollama_local, storage/notion
  services/     # pipeline (orchestrator), factory (composition root), checkpoint (resume)
  skill/        # SkillService — side-effect-free dict-in/dict-out facade
  platform/     # Windows UTF-8 fix
```

Provider modes (`PROVIDER_MODE` env var):
- `local` (default) — faster-whisper + Ollama, no API key needed
- `cloud` — OpenAI Whisper API + OpenAI Chat Completions
- `hybrid` — local first, automatic cloud fallback on failure

## Pipeline (5 steps)

**Video content:**
```
[1/5] Download   — yt-dlp extracts audio (m4a)
[2/5] Transcribe — faster-whisper (CUDA; auto CPU fallback, up to 3 retries)
[3/5] Clean      — remove fillers, timestamps; normalize whitespace
[4/5] Summarize  — Ollama LLM → summary / key_points / tags / category / sentiment
[5/5] Store      — write to Notion (optional; dedup by URL) or local JSON
```

**Image-text notes (小红书, X, etc.):**
```
[1/5] Download   — scrape title, description, comments
[2/5] Transcribe — auto-skipped (image_text type)
[3/5] Clean      — clean scraped text
[4/5] Summarize  — Ollama LLM → summary
[5/5] Store      — write to Notion or local JSON
```

**Checkpoint resume:**
Each step auto-saves to `checkpoints/<url_hash>.json`. Re-run resumes
from the last successful step — no redundant downloads or transcriptions.

## Trigger Patterns

User messages may contain (中文 or English):
- `转录这个资源：[URL]` / `转录 [URL]`
- `transcribe [URL]` / `summarize [URL]`
- Bare URL only

URL extraction regex:
```
https?://[^\s]+
```

## Execution

```powershell
# Auto-locate project dir (find pyproject.toml with name="clipvault")
$project = (Get-ChildItem -Path $env:WORKSPACE_FOLDER -Filter "pyproject.toml" -Recurse -Depth 1 |
    Where-Object { (Get-Content $_.FullName -Raw) -match 'name\s*=\s*"clipvault"' } |
    Select-Object -First 1).DirectoryName
if (-not $project) { $project = $env:WORKSPACE_FOLDER }
Set-Location $project

# 1) Ensure venv exists; bootstrap via setup.bat if missing
if (-not (Test-Path ".\venv\Scripts\python.exe")) {
    Write-Host "venv not found, running setup.bat ..." -ForegroundColor Yellow
    cmd /c setup.bat
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path ".\venv\Scripts\python.exe")) {
        Write-Host "Setup failed — check setup.bat output" -ForegroundColor Red
        exit 1
    }
}

# 2) Ensure .env exists
if (-not (Test-Path ".\.env")) {
    Write-Host "No .env found — copy .env.example to .env and fill in config" -ForegroundColor Yellow
    exit 1
}

# 3) Run pipeline
& ".\venv\Scripts\python.exe" -m clipvault "<EXTRACTED_URL>"

# Legacy entry still works:
# & ".\venv\Scripts\python.exe" .\main.py "<EXTRACTED_URL>"
```

## CLI Reference

```
clipvault <URL> [options]

  --skip [STEP ...]           Skip steps: download, transcribe, summarize, store
  --skip-notion               Skip Notion storage (same as --skip store)
  --disable-cleaning          Disable transcript cleaning
  --no-cleanup                Keep downloaded audio files
  --no-resume                 Ignore checkpoints, start fresh
  --dry-run                   Validate inputs only, do not execute
  --force-download            Re-download even if file exists
  --language LANG             Override transcription language (zh, en, ja, ...)
  --log-level LEVEL           DEBUG | INFO | WARNING | ERROR (default: INFO)
  --json                      JSON-only output (suppress progress logs)
```

Legacy flag translation (via `main.py` compat layer):
- `--skip-transcribe` → `--skip transcribe`
- `--skip-summary` → `--skip summarize`

## Environment Variables (.env)

```dotenv
# Notion (optional)
NOTION_TOKEN=secret_xxx
NOTION_DATABASE_ID=your_database_id
DISABLE_NOTION=0

# Provider mode
PROVIDER_MODE=local          # local | cloud | hybrid

# Whisper config
WHISPER_MODEL=small
CUDA_DEVICE=0

# LLM model (local mode, Ollama)
LLM_MODEL=qwen3.5:latest
LLM_MODEL_FALLBACK=qwen2.5:7b-instruct-q4_K_M

# Cloud API (cloud / hybrid mode)
# OPENAI_API_KEY=sk-xxxxxxxxxx
# OPENAI_BASE_URL=
# OPENAI_MODEL=gpt-4o-mini
# OPENAI_WHISPER_MODEL=whisper-1

# Misc
LOG_LEVEL=INFO
ENABLE_TRANSCRIPT_CLEANING=1
```

## Output Schema

JSON result fields:
- `url` — original URL
- `status` — `success` / `error` / `skipped`
- `content_type` — `video` / `image_text` / `audio` / `text`
- `platform` — `YouTube` / `Bilibili` / `Xiaohongshu` / `X` / `Unknown`
- `title` — content title
- `transcript` — transcribed text (with `language`, `duration`, `device`)
- `summary` — LLM-generated summary
- `key_points` — list of key takeaways
- `tags` — tag list
- `category` — category label
- `sentiment` — `positive` / `neutral` / `negative`
- `elapsed_seconds` — total wall time
- `steps` — per-step details (name, status, duration, metadata)
- `metadata` — extra info (e.g. `dry_run` flag)

Step names: `download` → `transcribe` → `clean` → `summarize` → `store`

**Notion output rule:**
If Notion write succeeds, you MUST output a clickable Notion link after the JSON:

```text
已存储到 Notion：<notion_url>
```

If duplicate URL detected and an existing Notion page is reused, output that page link as well.

## Programmatic Usage (SkillService)

```python
from clipvault.skill import SkillService

svc = SkillService()
result = svc.process("https://youtube.com/watch?v=xxx")
# result is a plain dict — no stdout side-effects
```

## setup.bat

Auto-bootstrap script:
- Detects system Python (`python` / `py`); prompts upgrade if < 3.9
- Installs Python 3.12 via **winget** if missing
- Creates venv, upgrades pip
- Installs PyTorch (CUDA 12.4 wheel)
- Installs requirements.txt + yt-dlp + imageio-ffmpeg
- Copies `.env.example` → `.env` if not present
- Validates torch / faster-whisper / yt-dlp availability

## Prerequisites

- **Ollama** must be running (for summarization). Recommended: `qwen3.5:latest` or `qwen2.5:7b-instruct-q4_K_M`
- **NVIDIA GPU** — Whisper + LLM needs ~6–7 GB VRAM
- First run downloads faster-whisper small model (~244 MB)
- Without Notion config (`DISABLE_NOTION=1`), falls back to local JSON storage
- 小红书 image-text scraping uses public API — private notes are inaccessible
- Transcription auto-retries with CPU fallback (up to 3 attempts)
