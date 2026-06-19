# ============================================================
# bootstrap.ps1  —— Windows 开发环境一键初始化脚本（通用模板）
#
# 用法：
#   预览（不实际执行）：  .\bootstrap.ps1
#   确认后执行：          .\bootstrap.ps1 -Execute
#
# ⚠️  这是开源模板，不含任何个人信息。
#    请将此文件复制到你的私有 dotfiles 仓库，
#    并在下方 CONFIG 区填入真实信息后使用。
#
# 后续维护：
#   - 新增个人项目时，把 GitHub URL 加到 $PersonalRepos 里
#   - 换新电脑时，直接运行私有版脚本即可复原环境
# ============================================================

param(
    [switch]$Execute   # 不加此参数为 Dry Run 预览模式
)

# ════════════════════════════════════════════════════════════
# ✏️  CONFIG — 在你的私有 dotfiles 版本中填写以下信息
# ════════════════════════════════════════════════════════════

# Git 身份
$PersonalName  = "Your Name"                    # Git 提交显示的姓名
$PersonalEmail = "you@personal.example.com"     # 个人 GitHub 邮箱
$WorkEmail     = "you@company.example.com"      # 公司邮箱（Work 目录自动使用）

# Personal\ 下的子目录分组 —— 按你自己的项目类别定义
$SubDirs = @(
    # "group-a",    # 例如：某个产品生态的所有项目
    # "group-b",    # 例如：ai-tools
    # "group-c",    # 例如：livestream
    # TODO: 按需添加
)

# 个人项目列表 —— 每行一个 GitHub 仓库 URL
$PersonalRepos = @(
    # "https://github.com/your-username/repo-a",
    # "https://github.com/your-username/repo-b",
    # TODO: 逐步补充
)

# 仓库名关键字 → 子目录映射
# 匹配规则：URL 包含 key 时自动放到对应子目录，否则放 Personal 根目录
$RepoGroups = @{
    # "keyword-a" = "group-a"
    # "keyword-b" = "group-b"
    # TODO: 按需添加
}

# ════════════════════════════════════════════════════════════
# 以下为脚本逻辑，通常无需修改
# ════════════════════════════════════════════════════════════

$Root   = "C:\Dev"
$DryRun = -not $Execute

# ── 颜色输出辅助 ─────────────────────────────────────────────
function Write-Step($msg) { Write-Host "  → $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "  - $msg" -ForegroundColor DarkGray }
function Write-Warn($msg) { Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err($msg)  { Write-Host "  ✗ $msg" -ForegroundColor Red }

# ── Banner ───────────────────────────────────────────────────
Write-Host ""
if ($DryRun) {
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Magenta
    Write-Host "║   DEV SETUP  —  DRY RUN 预览模式     ║" -ForegroundColor Magenta
    Write-Host "║   运行 -Execute 参数才会实际执行      ║" -ForegroundColor Magenta
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Magenta
} else {
    Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║   DEV SETUP  —  正在初始化环境...    ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Green
}
Write-Host ""

# ── 配置完整性检查 ────────────────────────────────────────────
if ($PersonalName -eq "Your Name" -or $PersonalEmail -match "example\.com") {
    Write-Warn "检测到未修改的占位符配置！"
    Write-Warn "请先编辑脚本顶部的 CONFIG 区填入真实信息，再运行 -Execute。"
    Write-Host ""
    if ($Execute) {
        Write-Err "已中止：请填写真实配置后重试。"
        exit 1
    }
}

# ════════════════════════════════════════════════════════════
# STEP 1 — 创建目录结构
# ════════════════════════════════════════════════════════════
Write-Host "📂 Step 1 — 创建目录结构" -ForegroundColor White

$Dirs = @(
    "$Root\Work",
    "$Root\Personal"
) + ($SubDirs | ForEach-Object { "$Root\Personal\$_" }) + @(
    "$Root\Lab",
    "$Root\Sandbox"
)

foreach ($dir in $Dirs) {
    if (Test-Path $dir) {
        Write-Skip "$dir  (已存在)"
    } else {
        Write-Step "创建 $dir"
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-OK "已创建"
        }
    }
}

# ════════════════════════════════════════════════════════════
# STEP 2 — 配置 Git 身份
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "🔑 Step 2 — 配置 Git 身份" -ForegroundColor White

$GitConfigPath     = "$env:USERPROFILE\.gitconfig"
$GitConfigWorkPath = "$env:USERPROFILE\.gitconfig-work"

$MainConfig = @"
[user]
    name  = $PersonalName
    email = $PersonalEmail

[includeIf "gitdir:C:/Dev/Work/"]
    path = ~/.gitconfig-work

[core]
    autocrlf = true

[init]
    defaultBranch = main
"@

$WorkConfig = @"
[user]
    email = $WorkEmail
"@

Write-Step "写入 ~/.gitconfig  (默认个人邮箱，Work 目录自动切换为公司邮箱)"
Write-Step "写入 ~/.gitconfig-work  (公司邮箱)"

if (-not $DryRun) {
    Set-Content -Path $GitConfigPath     -Value $MainConfig -Encoding UTF8
    Set-Content -Path $GitConfigWorkPath -Value $WorkConfig  -Encoding UTF8
    Write-OK "Git 配置已写入"
}

# ════════════════════════════════════════════════════════════
# STEP 3 — Clone 个人项目
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "📥 Step 3 — Clone 个人项目" -ForegroundColor White

if ($PersonalRepos.Count -eq 0) {
    Write-Warn "PersonalRepos 列表为空，跳过 Clone 步骤"
    Write-Warn "请在脚本顶部 CONFIG 区填入仓库 URL 后重新运行"
} else {
    $CloneOK = 0; $CloneFail = 0

    foreach ($url in $PersonalRepos) {
        # 从 URL 提取仓库名
        $repoName = ($url -split "/")[-1] -replace "\.git$", ""

        # 根据关键字决定目标子目录
        $subDir = "Personal"
        foreach ($key in $RepoGroups.Keys) {
            if ($repoName -match $key -or $url -match $key) {
                $subDir = "Personal\$($RepoGroups[$key])"
                break
            }
        }

        $cloneDest = "$Root\$subDir\$repoName"

        if (Test-Path $cloneDest) {
            Write-Skip "$repoName  →  $cloneDest  (已存在，跳过)"
            continue
        }

        Write-Step "$repoName  →  $Root\$subDir\"

        if (-not $DryRun) {
            Push-Location "$Root\$subDir"
            git clone $url 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Clone 成功"
                $CloneOK++
            } else {
                Write-Err "Clone 失败：$url"
                $CloneFail++
            }
            Pop-Location
        }
    }

    if (-not $DryRun) {
        Write-Host ""
        Write-Host "  Clone 结果：成功 $CloneOK，失败 $CloneFail" `
            -ForegroundColor $(if ($CloneFail -gt 0) { "Yellow" } else { "Green" })
    }
}

# ════════════════════════════════════════════════════════════
# 完成汇总
# ════════════════════════════════════════════════════════════
Write-Host ""
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray

if ($DryRun) {
    Write-Host "预览完成。确认无误后运行：" -ForegroundColor Magenta
    Write-Host "  .\bootstrap.ps1 -Execute" -ForegroundColor Magenta
} else {
    Write-Host "✅ 环境初始化完成！" -ForegroundColor Green
}

Write-Host @"

📋 后续手动步骤：
   1. 将公司项目 clone 到 C:\Dev\Work\（从公司 Git 服务器）
   2. 安装运行时：Node.js / Python / .NET SDK（按需）
   3. 登录 IDE 同步设置（VS Code Settings Sync / JetBrains）

💡 提示：
   - C:\Dev\Work\ 下的 Git 操作自动使用公司邮箱
   - 其他目录默认使用个人邮箱
   - 可用 git config user.email 在任意目录验证当前生效的身份
"@ -ForegroundColor Yellow
