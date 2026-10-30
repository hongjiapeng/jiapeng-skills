async (page) => {
  const config = /*CONFIG*/ {};
  const output = [];
  async function blocker() {
    const url = new URL(page.url());
    const text = await page.locator('body').innerText();
    if (/今日投递已超过上限|投递.{0,20}(?:超过|达到).{0,10}上限/.test(text)) return 'rate_limited';
    if (/验证码|安全验证|操作频繁|稍后再试/.test(text)) return 'blocked';
    if (url.hostname.includes('passport') || /\/login(?:[/?#]|$)/i.test(url.pathname)) return 'blocked';
    return null;
  }
  const stop = await blocker();
  if (stop) return {results:[],stopReason:stop};
  const cards = page.locator('.job-card');
  const end = Math.min(await cards.count(), config.start + config.count);
  if (config.start >= end) return {results:[],stopReason:'requested_cards_not_loaded'};
  for (let i = config.start; i < end; i++) {
    try {
      const stop = await blocker();
      if (stop) return {results:output,stopReason:stop};
      const card = cards.nth(i);
      const title = (await card.locator('.job-card__title-clamp').innerText()).trim();
      const company = (await card.locator('.job-card__company-name').innerText()).trim();
      const summary = await card.innerText();
      await card.click({timeout:5000});
      await page.waitForFunction(({title,company}) =>
        document.querySelector('.job-detail-summary__title-text')?.textContent.trim() === title &&
        document.querySelector('.job-detail-panel')?.innerText.includes(company), {title,company}, {timeout:6000});
      const url = await page.getByRole('link',{name:'查看更多职位信息',exact:true}).getAttribute('href');
      const description = await page.locator('.job-description').innerText();
      output.push({index:i,title,company,summary,url,description,
        languageRequired:/英语|英文|\bEnglish\b/i.test(description),
        international:/海外|跨国|国际化|外企|全球|international|global team/i.test(description)});
    } catch(error) {
      return {results:output,stopReason:'collection_failed',index:i,error:String(error).slice(0,800)};
    }
  }
  return {results:output,stopReason:null};
}
