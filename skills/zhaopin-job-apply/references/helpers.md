# 本地批次与记账辅助

使用Python标准库，无需安装Python依赖。以下`<skill>`替换为当前技能文件夹的实际路径；所有生成物放在任务工作目录，不能写进技能目录。脚本不决定岗位是否适合，`plan`的索引必须由代理阅读岗位后选择。

## 初始化或导入旧进度

```powershell
python -X utf8 <skill>/scripts/jobs.py init --ledger output/playwright/jobs-ledger.json --target 200
```

`init`拒绝覆盖已有账本。`--target`仅在用户确实要求数量目标时提供，不能把示例200强加给其他任务。

继续已有任务时可导入旧数组JSON：

```powershell
python -X utf8 <skill>/scripts/jobs.py init --ledger output/playwright/jobs-ledger.json --target 200 --current output/playwright/mass-applications.json --history output/playwright/applications-2026-10-29.json
```

`--current`是本轮已存在进度，保留明确确认凭据；`--history`只用于去重，不计本轮新增。两项均可重复。旧记录中仅“已投递”+明确发送成功证据+确认时间可以计入本轮。旧记录缺少时间的，仍防止重投但不充数。原文件不被修改。账本不含招聘登录凭据。

## 收集及审阅

```powershell
python -X utf8 <skill>/scripts/jobs.py collect --start 0 --count 10 --out output/playwright/collect-01.cjs
npx.cmd --yes --package @playwright/cli playwright-cli -s=jobs run-code --filename output/playwright/collect-01.cjs > output/playwright/candidates-01.txt
python -X utf8 <skill>/scripts/jobs.py extract --input output/playwright/candidates-01.txt --out output/playwright/candidates-01.json
```

候选数组中的每条含`title/company/summary/url/description/languageRequired/international`。读取完整description，标注业务匹配与差距后选索引，不只读截断摘要。列表变化后重新收集，不能对旧索引盲点。

## 生成并执行人工审阅批次

```powershell
python -X utf8 <skill>/scripts/jobs.py plan --candidates output/playwright/candidates-01.json --indices 0,2,4 --ledger output/playwright/jobs-ledger.json --out output/playwright/apply-01.cjs
npx.cmd --yes --package @playwright/cli playwright-cli -s=jobs run-code --filename output/playwright/apply-01.cjs > output/playwright/result-01.txt
python -X utf8 <skill>/scripts/jobs.py merge --ledger output/playwright/jobs-ledger.json --input output/playwright/result-01.txt
python -X utf8 <skill>/scripts/jobs.py report --ledger output/playwright/jobs-ledger.json --out output/playwright/jobs-progress.md
```

`plan`会按职位J编号（否则规范化详情URL）排除当前及历史的confirmed/already_applied/unknown记录。执行前仍要查看页面是否登录、限额或有未处理表单。`blocked`（点击前的验证阻碍）、`rate_limited`和确定点击前的`failed`不作为已投；**只有阻碍实际解除后**才正常重试。`unknown`须先人工核实，不能通过删记录放开重投。

提交模板遇到限制、未知提交结果或异常就返回已完成的前缀结果，结束批次。每条带`submitted`字段区分是否已尝试点击。没有“立即投递”时如只有“继续沟通”，记unknown，停止核查，不把聊天当投递。

`merge`对重复导入同一结果幂等，唯一确认数不会翻倍。历史里已有的同一职位即使导入本轮成功事件也不充数。success判定只适用于模板曾观察到的成功文案；页面改变时先重新核实再改任务副本或做可审计的人工状态修正，不凭关键词降低成功标准。

## 续投交接

结束时在工作目录写续办说明：账本路径、数量口径/目标、已确认数、限制类型与发生日期、未执行的候选索引或下一搜索词、平台/地区限制、用户要求的恢复时间。每次续办从权威记录重算，不硬编码“还剩N个”。本技能不保存某个候选人的姓名、工资或特定聊天的具体进度。
