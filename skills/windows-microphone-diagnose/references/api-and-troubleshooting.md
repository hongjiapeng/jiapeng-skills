# 接口与故障判读

## 返回结构

`schemaVersion/action/success/changed/data/before/after/steps/error`。
诊断 `success=true` 只代表信息采集完成，不代表麦克风正常。
修改带前后快照；`changed=false` 可以是目标本来就处于请求状态的幂等操作。
失败后的 `after` 是尽力查询的结果；`changed=null` 表示无法确认是否修改。
切换全部默认角色可能部分成功，检查 `steps` 和 `after.defaults` 再决定后续操作。
PowerShell 参数绑定失败（未知 action、超范围数值等）发生在脚本运行前，会返回 PowerShell 错误而不是 JSON，不执行修改。

`DeviceId` 使用刚枚举的录音端点 ID，形如 `{0.0.1.00000000}.{GUID}`，不是 PnP InstanceId。脚本按枚举结果校验，C# 再通过 `IMMEndpoint::GetDataFlow` 确认 capture 方向，防止误改扬声器。

## API 分层

| 用途 | 接口 | 性质 |
|---|---|---|
| 端点、默认角色、状态 | `IMMDeviceEnumerator` / `IMMDevice::GetState` | 公开 API |
| 输入/输出方向 | `IMMEndpoint::GetDataFlow` | 公开 API |
| 启用声音面板停用的麦克风 | `IPolicyConfig::SetEndpointVisibility(id, true)` | 未公开文档的 COM 接口 |
| 切换默认录音设备 | `IPolicyConfig::SetDefaultEndpoint(id, role)` | 未公开文档的 COM 接口 |
| 音量、静音 | `IAudioEndpointVolume` | 公开 API |
| 输入电平 | `IAudioMeterInformation` | 公开 API；不等价于录音测试 |
| 驱动/PnP 状态 | `Get-PnpDevice` | Windows 内置模块 |

实时状态 `1=active`、`2=disabled`、`4=not-present`、`8=unplugged`。注册表 `DeviceState` 可能含额外内部标志，不能直接套用 API 状态常量，也不能写它来启用设备。

`IPolicyConfig` CLSID `870AF99C-171D-4F9E-AF0D-E63DF40C2BC9`，IID `F8679F50-850A-41CF-9C72-430F290290C8`。COM vtable 顺序必须完整保留；只声明最后两个方法会调用错误槽位。不同版本可能改变未公开接口，不通过猜测 IID/vtable 在用户机器上试错。

## 常见结果

- 无 active 输入且有 disabled 内置阵列：驱动可能正常，优先针对该端点启用。
- 默认虚拟声卡：先确定需要本机输入还是远程/混音，再选目标。名称不能证明应用已卸载；残留排查需另查安装程序和驱动。
- 默认查询 `0x80070490`：可能无默认输入；查看全部端点。禁用端点仍可能被枚举。
- `0x80004002`：接口不支持。核对随附代码和 SDK 的 IID、方法顺序；不反复猜接口。
- `0x80070005`：访问拒绝。区分管理策略、设备权限和 PnP 操作所需管理员权限；不自动提升或绕过策略。
- 权限 `Deny` 或 AppPrivacy 策略值 `2`：提示检查 Windows 麦克风权限或组织策略；脚本只读取。
- 服务 stopped：独立服务故障；重启影响其他音频应用，获得相应授权再按需处理。
- `peak=0`：可能无人说话、无录音流、静音或故障，不能单独判断硬件损坏。非零可能只是噪声。
- 录音正常但无法转文字：检查具体应用、所选输入、浏览器权限、网络/识别服务，不把电平活动称为语音识别成功。

## 回退

API 失败时，通过可用 Computer Use 技能进入“系统 → 声音 → 更多声音设置 → 录制”，显示禁用设备，启用用户指定麦克风，按需设默认设备/默认通信设备。遵守工具当前规则，不用 UI 输入 shell 命令、不改隐私策略。
UI 不可用时提供相同路径的手动步骤；不为兼容问题下载第三方驱动工具或改注册表权限。

## 来源

- [Microsoft：端点状态](https://learn.microsoft.com/en-us/windows/win32/coreaudio/device-state-xxx-constants)
- [Microsoft：端点枚举](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nf-mmdeviceapi-immdeviceenumerator-enumaudioendpoints)
- [Microsoft：输入/输出方向](https://learn.microsoft.com/en-us/windows/win32/api/mmdeviceapi/nf-mmdeviceapi-immendpoint-getdataflow)
- [Microsoft：音量接口](https://learn.microsoft.com/en-us/windows/win32/api/endpointvolume/nn-endpointvolume-iaudioendpointvolume)
- [Microsoft：电平接口](https://learn.microsoft.com/en-us/windows/win32/api/endpointvolume/nn-endpointvolume-iaudiometerinformation)
- [AudioDeviceCmdlets：IPolicyConfig 接口顺序](https://github.com/frgnca/AudioDeviceCmdlets/blob/master/SOURCE/IPolicyConfig.cs)

签名参照 API/SDK，执行逻辑为本技能自包含实现，不依赖上述项目的安装。
