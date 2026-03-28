# jiapeng-skills

English | [中文](README.zh-CN.md)

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

## 仓库结构

```text
jiapeng-skills/
├─ README.md
├─ skills/
│  ├─ winget-package-manager/
│  │  ├─ scripts/
│  │  └─ SKILL.md
│  └─ ...
├─ docs/
└─ scripts/
```
