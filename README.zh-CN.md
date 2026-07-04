# jiapeng-skills

[English](README.md) | 中文

由 [hongjiapeng](https://github.com/hongjiapeng) 创建的可复用技能合集，专注于 Windows 自动化、工作站初始化、系统诊断和实用的 Agent 工作流。

本仓库是一个 **ClawHub / OpenClaw 技能的 Monorepo**。  
每个技能都独立存放在各自的文件夹中，可单独发布。

---

## 为什么要建这个仓库

我计划持续构建和维护多个技能，而不是为每个技能单独创建一个仓库。

本仓库用于：

- 将所有技能统一管理在一处
- 保持每个技能自包含、可独立发布
- 更方便地进行版本管理和维护
- 为发布到 ClawHub 的每个技能提供清晰的主页入口

---

## 技能列表

| Id | 技能 | 说明 |
|----|------|------|
| 001 | [adobe-leave-organizations](skills/adobe-leave-organizations/) | 自动从 Adobe Account 企业/团队组织中退出，同时保留指定组织；包含登录、资料选择、重复认证和最终确认页面的安全浏览器自动化流程。 |
| 002 | [clipvault](skills/clipvault/) | 转录、摘要、归档互联网视频/文章内容到个人知识库。支持 YouTube、Bilibili、小红书、X、TikTok 等平台。 |
| 003 | [dev-setup](skills/dev-setup/) | 初始化新 Windows 开发机：标准目录结构、个人/工作 Git 身份配置，以及个人仓库克隆。 |
| 004 | [directory-lock-detector](skills/directory-lock-detector/) | 通过 WMI 和 PowerShell 模块扫描，检测哪个进程正在锁定或占用某个 Windows 目录。 |
| 005 | [dotnet-unused-code-audit](skills/dotnet-unused-code-audit/) | 审计 C#/.NET 与 Visual Studio 仓库中的保守清理候选项，包括未使用代码、陈旧项目、不可达解决方案节点和生成产物。 |
| 006 | [fix-uwp-proxy-loopback](skills/fix-uwp-proxy-loopback/) | 诊断并修复 Windows UWP/AppContainer 应用因本地代理 loopback 限制导致的打开、登录、下载或联网失败。 |
| 007 | [publish-skill-to-repo](skills/publish-skill-to-repo/) | 将本地 Codex skill 发布到 Git 仓库，同时通过目录联接和校验流程保持 Codex skill discovery 可用。 |
| 010 | [spec-driven-delivery](skills/spec-driven-delivery/) | 将模糊的产品或工程需求整理为轻量、可实施的规格说明、实现计划、验收标准、验证清单和最终 coding-agent prompt。 |
| 008 | [windows-app-manager](skills/windows-app-manager/) | 受控 Windows 应用管理技能，当前基于 winget；支持搜索、详情查看、下载安装包、安装、升级、卸载、本机应用解析和升级列表，并返回结构化 JSON 输出。 |
| 009 | [windows-workstation-architect](skills/windows-workstation-architect/) | 设计干净、安全、按角色适配的 Windows 工作站结构，覆盖分区、文件夹、工作/个人隔离、媒体、备份、同步和多电脑场景。 |

每个目录都是自包含的 skill。部分 skill 会在 `SKILL.md` 之外附带脚本、模板、参考资料或 agent manifest。

---

## 初始化：让 Agent 可以发现技能

VS Code Copilot Agent 会扫描 `%USERPROFILE%\.agents\skills\` 来发现可用技能。
初始化脚本 [`scripts/Link-Skills.ps1`](scripts/Link-Skills.ps1) 会从该目录向本仓库创建 **目录联接（Junction）**，技能文件仍在仓库中统一做版本管理，同时对 Agent 全局可见。

默认初始化时，可以直接双击 [`scripts/Link-Skills.cmd`](scripts/Link-Skills.cmd)。
它会调用 PowerShell 脚本，并在结束后保留窗口，方便查看执行结果。

```powershell
# 链接全部技能
.\scripts\Link-Skills.ps1

# 也可以通过双击入口执行同样的默认初始化
.\scripts\Link-Skills.cmd

# 或只链接指定技能
.\scripts\Link-Skills.ps1 -SkillName dev-setup

# 可选：指定自定义目标目录
.\scripts\Link-Skills.ps1 -AgentsSkillsDir "D:\other\.agents\skills"
```

脚本可以安全地重复运行：已链接的技能会直接跳过，冲突项只会警告，不会覆盖现有文件。

### 为什么用 Junction 而不是快捷方式？

| | 目录联接（Junction） | Windows 快捷方式（.lnk） |
|---|---|---|
| **层级** | NTFS 文件系统级 | 应用层普通文件 |
| **对程序透明** | 是，看起来就是真实文件夹 | 否，工具需要主动解析 `.lnk` |
| **资源管理器图标** | 普通文件夹，无箭头 | 文件夹带小箭头 |
| **VS Code / Agent 可用** | 是 | 否 |
| **需要管理员权限** | 否 | 否 |

Junction 由操作系统在文件系统层处理，任何程序打开该路径都会直接看到真实目录内容，无需额外适配。

---

## 仓库结构

```text
jiapeng-skills/
├─ README.md
├─ README.zh-CN.md
├─ scripts/
│  ├─ Link-Skills.cmd
│  └─ Link-Skills.ps1
├─ skills/
│  ├─ adobe-leave-organizations/
│  ├─ clipvault/
│  ├─ dev-setup/
│  ├─ directory-lock-detector/
│  ├─ dotnet-unused-code-audit/
│  ├─ fix-uwp-proxy-loopback/
│  ├─ publish-skill-to-repo/
│  ├─ spec-driven-delivery/
│  ├─ windows-app-manager/
│  └─ windows-workstation-architect/
└─ ...
```
