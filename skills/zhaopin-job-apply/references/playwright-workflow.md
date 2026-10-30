# Playwright CLI与界面观察

这些是2026年10月观察到的界面，不是接口契约。先读当前快照后使用。

## Windows接入

```powershell
Get-Command npx
npx.cmd --yes --package @playwright/cli playwright-cli list
# 会话不存在时才接入，已有会话优先复用：
npx.cmd --yes --package @playwright/cli playwright-cli attach --extension=msedge --session=jobs
npx.cmd --yes --package @playwright/cli playwright-cli -s=jobs tab-list
npx.cmd --yes --package @playwright/cli playwright-cli -s=jobs snapshot
```

接入成功不代表当前页正确；核对账号显示名、简历所属人和地区。连接或登录失败先保留草稿，不读取认证存储。若CLI返回运行中的session_id，使用对应进程交互工具收取结果；不要因观察超时重新发起同一批。

在最新快照找到“搜索职位、公司”输入框，填关键词并提交，再取快照。旧版页面可能打开新标签而不切换；用tab-list确认后选择。多词查询的实际效果需要看结果，不能假定平台执行AND匹配。

## 已观察到的列表及详情

|用途|曾观察到的DOM|
|---|---|
|职位卡片|`.job-card`|
|标题|`.job-card__title-clamp`|
|公司/招聘发布方|`.job-card__company-name`|
|详情区域|`.job-detail-panel`|
|详情标题|`.job-detail-summary__title-text`|
|详情头部|`.job-detail-summary`|
|完整描述|`.job-description`|
|详情链接|名称为“查看更多职位信息”的link|
|提交|详情头部名称为“立即投递”的button|
|成功|heading“已向对方发送简历和打招呼语”|
|成功后关闭|button“留在此页”|

卡片可能自动加载下一页。滚动最后一张卡片后等待新卡片实际出现，再记录本次已观察的范围；不要对未加载的第N项操作。采集脚本的start/count仅针对当前已加载列表，换搜索词后重新编号。

招聘服务商发布的岗位，其详情头部可能显示“客户公司：某公司”，并没有发布方链接。核对时可使用整个详情面板中的已观察公司节点及准确职位链接，不能只等待头部存在同名link。

可见内容以浏览器DOM为边界，不读Vue/React内部状态、隐藏token或通过私有API投递。`run-code --filename`适合批次及多行中文；不要把公司名、JD或正文拼成PowerShell命令。

```powershell
npx.cmd --yes --package @playwright/cli playwright-cli -s=jobs run-code --filename output/playwright/apply-01.cjs > output/playwright/result-01.txt
```

文件必须是`async (page) => { ... }`函数表达式，不使用`module.exports`。CLI返回“### Result”后的JSON是本地记账入口；网络错误或只有“### Error”不等于空结果成功。

## 状态判断

- “立即投递”点击后出现明确发送成功heading：本次确认成功，保存时间和岗位链接。
- 操作前详情显示“已投递”：此前已投，不计新增。
- 只显示“继续沟通”：可能只有聊天记录，不能直接认定已投。
- 点击后未弹出成功提示，但按钮变化：提交结果未知；即使独立详情显示已投，也不能据此推断投递时间。
- 提示当日超过上限：记录rate_limited，结束批次。不要再读取下一个卡片并因弹窗阻挡把它误记为投递失败。
- 页面跳到登录或出现验证码：停止，提示用户自行完成，保留未处理队列。

页面被固定导航或弹窗遮挡时，先读页面。必要时把目标滚到居中再操作；不要用force跳过遮挡。不应在页面未知时切换另一种工具绕过限制。

```powershell
npx.cmd --yes --package @playwright/cli playwright-cli -s=jobs screenshot --filename output/playwright/progress.png
npx.cmd --yes --package @playwright/cli playwright-cli -s=jobs detach
```
