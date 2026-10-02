---
name: windows-microphone-diagnose
description: Diagnose and repair Windows microphone input problems, including disabled recording endpoints, wrong default microphones, virtual audio devices, mute, low volume, and microphone access restrictions. Use for failed voice typing, missing built-in microphones, or recording apps receiving no sound. Independent of any particular speech app.
---

# Windows 麦克风诊断与修复

处理 Windows 10/11 麦克风输入问题。优先使用随附 PowerShell/C# 脚本直接调用 Core Audio API，无需下载程序或安装模块。

## 诊断

从技能目录运行 `scripts/microphone.ps1`，默认只读并输出 JSON。支持 Windows PowerShell 5.1 / PowerShell 7：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\microphone.ps1" -Action diagnose
```

结合症状区分：设备未连接、驱动异常、录音端点停用、默认输入错误、静音/音量、访问权限、应用选择了另一设备。必要时询问具体应用和外接麦克风是否已拔掉，继续独立的系统检查。

- `data.endpoints` 来自实时 API，包括 active、disabled、not-present、unplugged。不能单凭设备管理器 `Status=OK` 判断麦克风可以录音。
- `data.defaults` 分别报告 console、multimedia、communications 三种默认角色。虚拟麦克风不一定是故障，但可能没有本机声音来源；名称中的 `virtualHint` 仅是线索，不能证明软件残留。
- 权限字段是注册表线索；`unknown` 不等于 Allow。组织策略、浏览器权限、具体应用配置要分别检查。
- 驱动正常不排除录音端点禁用；未连接不等于驱动损坏；不因驱动日期旧便判定需更新。

## 修复

检查请求不自动改设置。用户已要求修复、启用、切换输入、取消静音时，在授权范围内继续，不重复询问同一项批准。先确定目标，使用刚返回的完整端点 `id`，不要硬编码本机 ID。多个候选无法确定时让用户选择。

所有修改仅作用于指定 capture endpoint，支持 `-WhatIf` 预览：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\microphone.ps1" -Action enable -DeviceId "<endpoint-id>" -WhatIf
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\microphone.ps1" -Action enable -DeviceId "<endpoint-id>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\microphone.ps1" -Action set-default -DeviceId "<endpoint-id>" -Role all
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\microphone.ps1" -Action unmute -DeviceId "<endpoint-id>"
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\microphone.ps1" -Action set-volume -DeviceId "<endpoint-id>" -Volume 60
```

只运行请求所需的操作。启用和默认输入使用未公开文档的 `IPolicyConfig`；音量和静音使用公开的 `IAudioEndpointVolume`。脚本输出前后快照和各步骤结果，并重新查询验证；不以“调用成功”代替“结果成功”。`success=false` 时检查部分修改和当前状态，不盲目重跑全套修复。详细接口、输出结构及回退见 [references/api-and-troubleshooting.md](references/api-and-troubleshooting.md)。

## 验证

修复后确认目标 active、默认角色正确、未静音及合理音量。保持用户要求的连接条件，例如拔掉外接耳麦后验证内置麦克风。

需要观察输入信号时，让用户在声音测试/录音应用打开麦克风后说话，再采样电平：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "<skill-dir>\scripts\microphone.ps1" -Action probe -DeviceId "<endpoint-id>" -Seconds 5
```

`probe` 只读电平，不打开录音流、不保存语音、不上传数据。未打开采集流时电平可能一直为零。非零只说明输入活动，不证明采到可理解的人声；零电平不能单独证明硬件故障。最后让用户在实际应用验证文字转换。系统配置正常时继续检查应用选中的输入、浏览器麦克风权限、Win+H 在线语音设置和应用错误。

## 边界与回退

- 不批量启用所有麦克风，不改无关播放设备，不默认重启音频服务。
- 脚本不改隐私策略、不安装/卸载驱动、不删除虚拟声卡、不重启电脑；这些操作需要独立诊断及相应授权。
- 设备管理器禁用的 PnP 设备与声音面板停用的录音端点属于不同层级，`Enable-PnpDevice` 不能直接替代端点启用。
- API 不兼容或访问受限时报告 HRESULT；可以使用可用的 Computer Use 技能进入“更多声音设置 → 录制”，启用指定设备并按需设默认，遵守工具当前限制。UI 不可用时提供精确手动步骤。不直接修改 `MMDevices\Audio\Capture\DeviceState` 注册表值。

结果先说明原因与已完成修改，区分系统配置验证、信号活动和实际语音输入验证。未验证的应用行为如实标注。
