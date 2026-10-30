# 智联页面操作参考

## Playwright CLI 接入

先核对现有 Playwright 技能和本机 `npx`。本次成功的命令如下；复用已有会话，不能把示例会话名当作已存在。

```powershell
npx.cmd --yes --package @playwright/cli playwright-cli --help
npx.cmd --yes --package @playwright/cli playwright-cli list
npx.cmd --yes --package @playwright/cli playwright-cli attach --extension=msedge --session=zhaopin
npx.cmd --yes --package @playwright/cli playwright-cli -s=zhaopin snapshot
```

attach 成功后仍需确认 URL 为简历页、所属人正确且能打开编辑框。若命令返回进行中的进程，按返回的会话标识收取最终结果，不重复启动 attach。

当 snapshot 输出很大时，将它写入当前工作目录后用 `rg` 定位目标。`find` 也能返回带引用的局部快照。Windows `.cmd` 传参中避免带管道符的查询表达式；不要将 `JSON.stringify()` 当作 shell 转义。复杂操作、多行文字统一使用 `run-code --filename`。

CLI 操作文件内容是一个函数表达式：

```javascript
async (page) => {
  // 使用当前页面已观察到的字段和控件。
  return { result: '可核对的结果' };
}
```

文件不使用 `module.exports = ...;`；该格式在本次 CLI 中报语法错误。

## 已观察到的编辑入口

先通过快照/DOM确认这些选择器仍有效。它们不是所有版本的接口契约。

| 栏目 | 操作入口 | 文本字段 |
|---|---|---|
| 个人优势 | 点击第一个“个人优势”标题，再点击 `.zp-evalution-edit-text` | textbox，名称以“智联建议您”开头 |
| 工作经历 | 点击公司名称，再点击可见的 `.job-exp-pre-item-edit` | textbox，名称以“请输入工作内容”开头 |
| 项目经历 | 点击项目名称，再点击可见的 `.project-exp-pre-item-edit` | textbox，名称以“更完善的项目信息有助于HR”开头 |

工作编辑框的身份字段为“请输入公司名称”，日期字段为“入职时间”“离职时间”。项目名称字段曾为名称“必填”的 textbox，日期为“选择开始时间”“选择结束时间”。保存按钮为“保存并更新”。原流程观察到优势500字、工作3000字、项目2000字上限；实际操作以当前字段限制/页面计数为准。

“查看全部”在工作和项目栏可能同时存在。不要使用不加范围的严格唯一匹配。展开后可能异步加载；等待所需公司/项目出现，不能因马上读到空列表而重复新增。

## 单条修改任务格式

以下是格式示例，不是真实候选人资料。真实文件放在任务工作目录中。

```json
{
  "account_name": "示例候选人",
  "kind": "work",
  "name": "示例公司",
  "expected_before": "从编辑框读取的完整原文",
  "text": "经事实核对的完整替换文案\n第二行文案",
  "expected_start": "2024-10",
  "expected_end": "2026-06"
}
```

- `kind` 只能为 `advantage`、`work`、`project`。
- `advantage` 不需要 name 或日期；work/project 需要目标名称、开始/结束日期。日期保留编辑框的原始格式，仍在职的空结束值可用空字符串，不能凭空补日期。
- `expected_before` 必须来自当前简历的备份。内容已变化时更新事实和任务，不能把保护条件移除后硬覆盖。
- 每次生成一个任务，运行后核对返回结果再处理下一项。已有编辑框未关闭时脚本会停止，先按页面实况核对所属条目并决定保存或取消。
- apply 脚本的成功只代表该次表单已保存、对应展示文案可见；最终仍必须刷新验证持久化。

## 新增项目与日期

新增项目使用当前“添加项目经历”可见入口。开始前先确认完整列表没有目标项目，保留既有项目。项目名、描述、开始结束时间均取自真实经历。

只读日期框不能直接 fill。以下为已验证控件的可复用操作片段；使用前先核对 DOM，调用时传入已确认的年月。

```javascript
async function chooseMonth(page, label, year, month) {
  const input = page.getByRole('textbox', { name: label, exact: true });
  await input.click({ timeout: 5000 });
  const header = page.locator('.ivu-date-picker-header:visible');
  await header.waitFor({ state: 'visible', timeout: 5000 });
  let current = Number((await header.innerText()).match(/\d{4}/)[0]);
  // 本片段适合相近年份；较远年份先观察是否有年选择入口。
  for (let step = 0; current !== year && step < 5; step++) {
    const arrow = current > year ? '.ivu-date-picker-prev-btn:visible' : '.ivu-date-picker-next-btn:visible';
    await page.locator(arrow).click({ timeout: 5000 });
    const next = Number((await header.innerText()).match(/\d{4}/)[0]);
    if (next === current) throw new Error('年月选择器没有切换年份');
    current = next;
  }
  if (current !== year) throw new Error('需要重新观察年份选择方式');
  await page.getByText(month + '月', { exact: true }).filter({ visible: true }).click({ timeout: 5000 });
  const expected = year + '年' + String(month).padStart(2, '0') + '月';
  if (await input.inputValue() !== expected) throw new Error('日期值与目标不符');
  await header.waitFor({ state: 'hidden', timeout: 5000 });
}
```

选完开始时间必须等待弹层隐藏，再点击结束时间。此前若按“有任意弹层可见就不点击新输入框”判断，可能误用正在关闭的旧弹层，导致箭头点击超时。

## 保存后验证

保存前核对整个 inputValue；保存后等待对应编辑字段隐藏并核对展示文案。最后刷新、展开、等待异步条目出现，再检查条目数量和内容。项目节点曾为 `.project-exp-pre-item`、描述为 `.project-exp-pre-item-detail pre`、日期为 `.project-exp-pre-item-time`；日期悬停隐藏时，节点 textContent 仍可用于核对。

截图与断开命令：

```powershell
npx.cmd --yes --package @playwright/cli playwright-cli -s=zhaopin screenshot --filename <workspace>/output/playwright/resume-saved.png
npx.cmd --yes --package @playwright/cli playwright-cli -s=zhaopin detach
```

截图完成后查看图片并嵌入最终回复。不要因 detach 误报“关闭了用户浏览器”。
