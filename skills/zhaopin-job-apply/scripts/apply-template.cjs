async (page) => {
  const targets = /*TARGETS*/ [];
  const results = [];
  function key(url) {
    const parsed = new URL(url, page.url());
    if (parsed.hostname !== 'www.zhaopin.com' || !parsed.pathname.startsWith('/jobdetail/')) throw new Error('Unexpected job URL');
    return parsed.pathname.match(/J\d+/)?.[0] || parsed.origin + parsed.pathname;
  }
  async function blocker() {
    const url = new URL(page.url());
    const text = await page.locator('body').innerText();
    if (/今日投递已超过上限|投递.{0,20}(?:超过|达到).{0,10}上限/.test(text)) return {status:'rate_limited',evidence:'页面显示当日投递超过/达到上限'};
    if (/验证码|安全验证|操作频繁|稍后再试/.test(text)) return {status:'blocked',evidence:'页面显示验证码、安全验证或频率限制，需检查当前页面'};
    if (url.hostname.includes('passport') || /\/login(?:[/?#]|$)/i.test(url.pathname)) return {status:'blocked',evidence:'当前页面需要登录'};
    return null;
  }
  for (const target of targets) {
    let submitted = false;
    const record = {company:target.company,title:target.title,summary:target.summary,url:target.url,
      languageRequired:target.languageRequired ?? /英语|英文|\bEnglish\b/i.test(target.description || ''),
      international:target.international ?? /海外|跨国|国际化|外企|全球/i.test(target.description || ''),
      attemptedAt:new Date().toISOString()};
    try {
      const before = await blocker();
      if (before) {results.push({...record,...before,submitted});break;}
      const cards = page.locator('.job-card').filter({hasText:target.company})
        .filter({has:page.getByText(target.title,{exact:true})});
      if (await cards.count() !== 1) throw new Error('职位卡片不唯一或未加载，重新观察列表');
      const card = cards.first();
      if ((await card.locator('.job-card__company-name').innerText()).trim() !== target.company) throw new Error('发布方不一致');
      await card.click({timeout:5000});
      await page.waitForFunction(({title,company}) =>
        document.querySelector('.job-detail-summary__title-text')?.textContent.trim() === title &&
        document.querySelector('.job-detail-panel')?.innerText.includes(company), target, {timeout:6000});
      const actual = await page.getByRole('link',{name:'查看更多职位信息',exact:true}).getAttribute('href');
      if (key(actual) !== key(target.url)) throw new Error('详情职位ID与已审阅记录不一致');
      const panel = page.locator('.job-detail-summary');
      const apply = panel.getByRole('button',{name:'立即投递',exact:true});
      if (await panel.getByRole('button',{name:'已投递',exact:true}).count()) {
        results.push({...record,status:'already_applied',submitted:false,evidence:'提交前页面已显示已投递'});
        continue;
      }
      if (await apply.count() !== 1) {
        results.push({...record,status:'unknown',submitted:false,evidence:'无立即投递按钮，需核查已投/聊天/失效等当前状态'});
        break;
      }
      const stop = await blocker();
      if (stop) {results.push({...record,...stop,submitted});break;}
      // Treat a click timeout as possibly submitted: never retry it without checking.
      submitted = true;
      await apply.click({timeout:5000});
      const success = page.getByRole('heading',{name:'已向对方发送简历和打招呼语',exact:true});
      try {await success.waitFor({timeout:6000});}
      catch(error) {
        const stop = await blocker();
        results.push({...record,submitted,...(stop || {status:'unknown',evidence:'点击后未得到明确发送成功提示；检查当前页面或投递记录'})});
        break;
      }
      results.push({...record,submitted,status:'confirmed',evidence:await success.innerText(),confirmedAt:new Date().toISOString()});
      await page.getByRole('button',{name:'留在此页',exact:true}).click({timeout:5000});
    } catch(error) {
      const last = results[results.length-1];
      if (last?.url === record.url && last.status === 'confirmed') break;
      const stop = await blocker().catch(() => null);
      results.push({...record,submitted,...(stop || {status:submitted?'unknown':'failed',evidence:String(error).slice(0,800)})});
      break;
    }
  }
  return {results,stopReason:results.length && !['confirmed','already_applied'].includes(results[results.length-1].status) ? results[results.length-1].status : null};
}
