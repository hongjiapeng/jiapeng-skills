# jiapeng-skills

[English](README.md) | 中文

由 [hongjiapeng](https://github.com/hongjiapeng) 创建的可复用技能合集，专注于 Windows 自动化、系统工具和实用的 Agent 工作流。

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

| 技能 | 说明 |
|------|------|
| [winget-package-manager](skills/winget-package-manager/) | 基于 winget 的 Windows 软件包管理技能，支持搜索、安装、升级、卸载等操作，返回结构化 JSON 输出。 |
| [clipvault](skills/clipvault/) | 转录、摘要、归档互联网视频/文章内容到个人知识库。支持 YouTube、Bilibili、小红书、X、TikTok 等平台。 |

> 更多技能将持续更新，敬请关注！

---

## 仓库结构

```text
jiapeng-skills/
├─ README.md
├─ skills/
│  ├─ clipvault/
│  │  └─ SKILL.md
│  ├─ winget-package-manager/
│  │  ├─ scripts/
│  │  └─ SKILL.md
│  └─ ...
├─ docs/
└─ scripts/
```
