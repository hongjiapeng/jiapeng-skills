async (page) => {
  const task = __RESUME_TASK_JSON__;
  const norm = text => String(text).replace(/\s+/g, ' ').trim();
  const ensure = (condition, message) => { if (!condition) throw new Error(message); };
  const url = new URL(page.url());
  ensure(url.protocol === 'https:' && url.hostname === 'i.zhaopin.com' && /^\/resume\/?$/.test(url.pathname), '当前不是智联在线简历页；如需登录请由用户完成');
  ensure(await page.getByText(task.account_name, { exact: true }).filter({ visible: true }).count() > 0, '未确认简历所属人，停止修改');
  const fieldName = task.kind === 'advantage' ? /^智联建议您/ : task.kind === 'work' ? /^请输入工作内容/ : /^更完善的项目信息有助于HR/;
  const allEditors = page.getByRole('textbox', { name: /^(智联建议您|请输入工作内容|更完善的项目信息有助于HR)/ }).filter({ visible: true });
  ensure(await allEditors.count() === 0, '已有打开的编辑框；先核对并处理未完成的表单');

  if (task.kind === 'advantage') {
    await page.getByText('个人优势', { exact: true }).first().click({ timeout: 5000 });
    await page.locator('.zp-evalution-edit-text:visible').click({ timeout: 5000 });
  } else {
    const title = page.getByText(task.name, { exact: true }).filter({ visible: true });
    if (!(await title.count())) {
      const expand = page.getByText('查看全部', { exact: true }).filter({ visible: true });
      for (let step = 0; step < 2 && await expand.count(); step++) await expand.first().click({ timeout: 5000 });
    }
    await title.first().waitFor({ state: 'visible', timeout: 10000 });
    ensure(await title.count() === 1, '存在同名条目，不能自动判断修改对象');
    await title.click({ timeout: 5000 });
    await page.locator(task.kind === 'work' ? '.job-exp-pre-item-edit:visible' : '.project-exp-pre-item-edit:visible').click({ timeout: 5000 });
    const nameField = page.getByRole('textbox', { name: task.kind === 'work' ? '请输入公司名称' : '必填', exact: true });
    ensure(await nameField.inputValue() === task.name, '编辑对象与任务不符，停止修改');
    const start = await page.getByRole('textbox', { name: task.kind === 'work' ? '入职时间' : '选择开始时间', exact: true }).inputValue();
    const end = await page.getByRole('textbox', { name: task.kind === 'work' ? '离职时间' : '选择结束时间', exact: true }).inputValue();
    ensure(start === task.expected_start && end === task.expected_end, '日期与读取备份时不同，停止修改');
  }
  const field = page.getByRole('textbox', { name: fieldName });
  const before = await field.inputValue();
  if (norm(before) === norm(task.text)) {
    await page.getByText('取消', { exact: true }).filter({ visible: true }).click({ timeout: 5000 });
    await field.waitFor({ state: 'hidden', timeout: 10000 });
    return { status: 'unchanged', kind: task.kind, name: task.name || '个人优势' };
  }
  ensure(norm(before) === norm(task.expected_before), '原文与备份不一致；没有执行填入或保存');
  await field.fill(task.text, { timeout: 5000 });
  ensure(await field.inputValue() === task.text, '填入内容未完整保留，未保存');
  await page.getByRole('button', { name: '保存并更新', exact: true }).click({ timeout: 5000 });
  await field.waitFor({ state: 'hidden', timeout: 10000 });
  ensure(new URL(page.url()).hostname === 'i.zhaopin.com', '页面离开简历站点，不能确认保存');
  await page.getByText(norm(task.text), { exact: true }).filter({ visible: true }).first().waitFor({ state: 'visible', timeout: 10000 });
  return { status: 'saved-visible', kind: task.kind, name: task.name || '个人优势', needsReloadVerification: true };
}
