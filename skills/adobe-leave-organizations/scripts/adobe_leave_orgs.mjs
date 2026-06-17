#!/usr/bin/env node

import { createRequire } from "node:module";
import path from "node:path";

const require = createRequire(import.meta.url);

async function loadPlaywright() {
  const candidates = [];
  if (process.env.PLAYWRIGHT_NODE_MODULES) {
    candidates.push(process.env.PLAYWRIGHT_NODE_MODULES);
  }
  candidates.push(path.join(process.cwd(), "node_modules"));
  candidates.push(path.join(process.env.APPDATA || "", "npm", "node_modules"));
  candidates.push(path.join(process.env.USERPROFILE || "", ".cache", "codex-runtimes", "codex-primary-runtime", "dependencies", "node", "node_modules"));

  for (const dir of candidates) {
    if (!dir) continue;
    for (const pkg of ["playwright-core", "playwright"]) {
      try {
        return require(path.join(dir, pkg));
      } catch {
        // Try the next candidate.
      }
    }
  }

  for (const pkg of ["playwright-core", "playwright"]) {
    try {
      return await import(pkg);
    } catch {
      // Try the next package.
    }
  }

  throw new Error(
    "Playwright is not available. Install it and set PLAYWRIGHT_NODE_MODULES, for example: npm --prefix %TEMP%\\codex-pw-adobe install playwright --no-save"
  );
}

function parseArgs(argv) {
  const args = {
    port: "9222",
    keep: [],
    auth: "google",
    adobeEmail: "",
    googleEmail: "",
    googleIndex: 0,
    dryRun: false,
    noLogin: false,
    verbose: false,
    max: Number.POSITIVE_INFINITY,
    profileUrl: "https://account.adobe.com/profile",
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--keep") {
      const value = argv[++i] || "";
      args.keep.push(...value.split(",").map((x) => x.trim()).filter(Boolean));
    } else if (arg === "--auth") {
      args.auth = argv[++i] || args.auth;
    } else if (arg === "--adobe-email") {
      args.adobeEmail = argv[++i] || "";
    } else if (arg === "--google-email") {
      args.googleEmail = argv[++i] || "";
    } else if (arg === "--google-index") {
      args.googleIndex = Number(argv[++i] || "0");
    } else if (arg === "--port") {
      args.port = argv[++i] || args.port;
    } else if (arg === "--max") {
      args.max = Number(argv[++i] || "1");
    } else if (arg === "--dry-run") {
      args.dryRun = true;
    } else if (arg === "--no-login") {
      args.noLogin = true;
    } else if (arg === "--verbose") {
      args.verbose = true;
    } else if (arg === "--profile-url") {
      args.profileUrl = argv[++i] || args.profileUrl;
    } else if (arg === "--help" || arg === "-h") {
      printHelp();
      process.exit(0);
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (args.keep.length === 0) {
    throw new Error("At least one --keep organization name is required.");
  }
  if (!["google", "adobe-email", "none"].includes(args.auth)) {
    throw new Error("--auth must be one of: google, adobe-email, none");
  }
  if (args.auth === "adobe-email" && !args.adobeEmail) {
    throw new Error("--auth adobe-email requires --adobe-email.");
  }

  return args;
}

function printHelp() {
  console.log(`Usage:
  node adobe_leave_orgs.mjs --keep "Example Organization" [--port 9222] [--dry-run] [--max 1]

Leaves every Adobe organization except exact names passed with --keep.
Requires Edge/Chrome to be running with --remote-debugging-port.

Auth options:
  --auth google --google-email user@example.com   Select a specific Google account
  --auth google --google-index 0                  Select Google account by visible order
  --auth adobe-email --adobe-email user@example.com
                                                 Fill Adobe email, then pause for manual password/2FA
  --auth none or --no-login                       Never attempt login
`);
}

function debug(args, message) {
  if (args.verbose) {
    console.error(`[adobe-leave-orgs] ${message}`);
  }
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function redactUrl(url) {
  return String(url || "")
    .replace(/#access_token=.*/, "#access_token=REDACTED")
    .replace(/\/social\/google\/[^?]+/, "/social/google/REDACTED");
}

async function text(page, timeout = 10000) {
  try {
    return await page.locator("body").innerText({ timeout });
  } catch (error) {
    return `ERR:${error.message}`;
  }
}

async function title(page) {
  try {
    return await page.title();
  } catch {
    return "";
  }
}

async function summarizePages(context) {
  const rows = [];
  const pages = context.pages();
  for (let i = 0; i < pages.length; i += 1) {
    const page = pages[i];
    let body = "";
    if (page.url().includes("adobe") || page.url().includes("google")) {
      body = await text(page, 4000);
    }
    rows.push({
      i,
      url: redactUrl(page.url()),
      title: await title(page),
      text: body.slice(0, 500),
    });
  }
  return rows;
}

function isLoginText(body) {
  return (
    body.includes("登录") ||
    body.includes("Sign in") ||
    body.includes("verify your identity") ||
    body.includes("验证您的身份") ||
    body.includes("Enter your password")
  );
}

async function chooseGoogleAccount(context, args) {
  const google = context.pages().find((page) => page.url().includes("accounts.google.com"));
  if (!google) return false;

  await google.bringToFront();
  const body = await text(google);
  if (body.includes("选择账号") || body.includes("Choose an account")) {
    let account = null;
    if (args.googleEmail) {
      account = google.locator(`[data-identifier="${args.googleEmail}"]`).first();
      if (!(await account.count().catch(() => 0))) {
        account = google.getByText(args.googleEmail, { exact: true }).first();
      }
    } else {
      account = google.locator("[data-identifier]").nth(args.googleIndex);
    }
    if (await account.count().catch(() => 0)) {
      await account.click();
    } else {
      await google.getByText(/@/).nth(args.googleIndex).click();
    }
    await google.waitForTimeout(8000);
    return true;
  }

  for (const label of ["继续", "Continue"]) {
    const button = google.getByRole("button", { name: label }).first();
    if (await button.count().catch(() => 0)) {
      await button.click();
      await google.waitForTimeout(8000);
      return true;
    }
  }

  return false;
}

async function clickGoogleLogin(page, context, args) {
  await page.bringToFront();
  for (const label of ["用 Google 继续登录", "Continue with Google", "Google social button"]) {
    const button = page.getByRole("button", { name: label }).first();
    if (await button.count().catch(() => 0)) {
      await button.click();
      await page.waitForTimeout(5000);
      await chooseGoogleAccount(context, args);
      return true;
    }
  }

  const textButton = page.locator("button").filter({ hasText: /Google/ }).first();
  if (await textButton.count().catch(() => 0)) {
    await textButton.click();
    await page.waitForTimeout(5000);
    await chooseGoogleAccount(context, args);
    return true;
  }

  return false;
}

async function fillAdobeEmailLogin(page, args) {
  await page.bringToFront();
  const selectors = [
    'input[type="email"]',
    'input[name="username"]',
    'input[name="email"]',
    'input[autocomplete="username"]',
    'input',
  ];
  for (const selector of selectors) {
    const input = page.locator(selector).first();
    if (await input.count().catch(() => 0)) {
      await input.fill(args.adobeEmail);
      const continueButton = page.getByRole("button", { name: /继续|Continue/ }).first();
      if (await continueButton.count().catch(() => 0)) {
        await continueButton.click();
      } else {
        await input.press("Enter");
      }
      await page.waitForTimeout(4000);
      return true;
    }
  }
  return false;
}

async function attemptLogin(page, context, args) {
  if (args.noLogin || args.auth === "none") return false;
  if (args.auth === "google") {
    return clickGoogleLogin(page, context, args);
  }
  if (args.auth === "adobe-email") {
    return fillAdobeEmailLogin(page, args);
  }
  return false;
}

async function choosePersonalProfileIfNeeded(context) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    for (const page of context.pages()) {
      if (!page.url().includes("auth.services.adobe.com")) continue;
      const body = await text(page, 5000);
      const isChooser =
        (body.includes("选择一个配置文件") || body.includes("Choose a profile")) &&
        (body.includes("个人资料") || body.includes("Personal"));
      if (!isChooser) continue;

      await page.bringToFront();
      const exactChinese = page.locator("button").filter({ hasText: /^个人资料$/ }).first();
      if (await exactChinese.count().catch(() => 0)) {
        await exactChinese.click();
      } else {
        const ariaPersonal = page.locator('button[aria-label="个人资料"], button[aria-label="Personal"]').first();
        await ariaPersonal.click();
      }
      await page.waitForTimeout(7000);
      return true;
    }
    await sleep(1000);
  }
  return false;
}

async function closeCompletedLeavePages(context) {
  for (const page of context.pages()) {
    if (!page.url().includes("/t2e-leave-organization")) continue;
    const body = await text(page, 3000);
    if (body.includes("您已离开") || body.includes("You have left")) {
      await page.close().catch(() => {});
    }
  }
}

async function findExistingProfileWithOrganizations(context) {
  const pages = context.pages().filter((page) => page.url().startsWith("https://account.adobe.com/profile"));
  for (let i = pages.length - 1; i >= 0; i -= 1) {
    const page = pages[i];
    const body = await text(page, 5000);
    if (body.includes("组织名称") && body.includes("离开组织")) {
      return { page, body };
    }
  }
  return null;
}

async function openProfile(context, profileUrl, options = {}) {
  const args = options.args || {};
  if (options.reuseExisting) {
    debug(args, "checking existing profile tabs");
    const existing = await findExistingProfileWithOrganizations(context);
    if (existing) return { ok: true, ...existing };
  }

  await closeCompletedLeavePages(context);
  debug(args, "opening fresh Adobe profile page");
  const page = await context.newPage();
  await page.goto(profileUrl, { waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(6000);

  let body = await text(page, 15000);
  if (!(body.includes("组织名称") && body.includes("离开组织")) && isLoginText(body)) {
    if (args.noLogin) {
      return { ok: false, page, reason: "login-needed", body };
    }
    debug(args, `profile requires login; trying ${args.auth} auth flow`);
    const clicked = await attemptLogin(page, context, args);
    if (!clicked) {
      return { ok: false, page, reason: "manual-auth-required", body };
    }
    await chooseGoogleAccount(context, args);
    await choosePersonalProfileIfNeeded(context);
    await page.goto(profileUrl, { waitUntil: "domcontentloaded", timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(7000);
    body = await text(page, 15000);
  }

  return {
    ok: body.includes("组织名称") && body.includes("离开组织"),
    page,
    body,
  };
}

async function organizationNames(page) {
  return page.evaluate(() => {
    return Array.from(document.querySelectorAll("li"))
      .map((li) => {
        const body = (li.innerText || li.textContent || "").replace(/\s+/g, " ").trim();
        if (!body.includes("组织名称") || !body.includes("离开组织")) return null;
        return body.replace(/^组织名称\s*/, "").replace(/\s*企业资料\s*离开组织.*$/, "").trim();
      })
      .filter(Boolean);
  });
}

async function waitForExpectedLeavePage(page, context, args, orgName) {
  for (let step = 0; step < 16; step += 1) {
    await page.waitForTimeout(3000);
    await chooseGoogleAccount(context, args);
    await choosePersonalProfileIfNeeded(context);

    let body = await text(page, 12000);
    if (page.url().includes("/t2e-leave-organization") && body.includes(orgName) && body.includes("最终确认")) {
      return { ok: true, page, body };
    }

    for (const candidate of context.pages()) {
      if (!candidate.url().includes("/t2e-leave-organization")) continue;
      const candidateBody = await text(candidate, 5000);
      if (candidateBody.includes(orgName) && candidateBody.includes("最终确认")) {
        return { ok: true, page: candidate, body: candidateBody };
      }
    }

    if (isLoginText(body)) {
      const clicked = await attemptLogin(page, context, args);
      if (!clicked) {
        return { ok: false, reason: "manual-auth-required", page, body };
      }
    }

  }

  return {
    ok: false,
    reason: "timeout-waiting-for-leave-page",
    page,
    body: await text(page, 10000),
  };
}

async function confirmLeave(page, orgName) {
  let body = await text(page, 15000);
  if (!(page.url().includes("/t2e-leave-organization") && body.includes(orgName) && body.includes("最终确认"))) {
    return { ok: false, reason: "unexpected-confirm-page", body };
  }

  const checkbox = page.locator('input[type="checkbox"]').first();
  if (await checkbox.count().catch(() => 0)) {
    await checkbox.check({ force: true });
  } else {
    await page.getByText("是，我想要离开此组织").click();
  }

  await page.waitForTimeout(700);
  await page.getByRole("button", { name: "离开组织" }).first().click();
  await page.waitForTimeout(9000);
  body = await text(page, 15000);

  return {
    ok: body.includes(`您已离开 ${orgName}`) || body.includes("您已离开") || body.includes("You have left"),
    body,
  };
}

async function leaveOrganization(context, args, orgName) {
  const profile = await openProfile(context, args.profileUrl, { args });
  if (!profile.ok) {
    return {
      org: orgName,
      status: "blocked-profile",
      url: redactUrl(profile.page?.url()),
      text: profile.body?.slice(0, 1200),
      reason: profile.reason,
    };
  }

  const names = await organizationNames(profile.page);
  if (!names.includes(orgName)) {
    return { org: orgName, status: "already-missing", names };
  }

  await profile.page.bringToFront();
  const row = profile.page.locator("li").filter({ hasText: orgName }).first();
  await row.scrollIntoViewIfNeeded();
  await row.getByRole("button", { name: "离开组织" }).click();

  const leavePage = await waitForExpectedLeavePage(profile.page, context, args, orgName);
  if (!leavePage.ok) {
    return {
      org: orgName,
      status: "blocked-leave-page",
      url: redactUrl(leavePage.page?.url()),
      text: leavePage.body?.slice(0, 1200),
      reason: leavePage.reason,
    };
  }

  const confirmed = await confirmLeave(leavePage.page, orgName);
  return {
    org: orgName,
    status: confirmed.ok ? "left" : "blocked-confirm",
    url: redactUrl(leavePage.page.url()),
    text: confirmed.body?.slice(0, 1200),
  };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  debug(args, "loading Playwright");
  const playwright = await loadPlaywright();
  debug(args, `connecting to CDP port ${args.port}`);
  const browser = await playwright.chromium.connectOverCDP(`http://127.0.0.1:${args.port}`, { timeout: 15000 });
  const context = browser.contexts()[0];

  const initial = await openProfile(context, args.profileUrl, { args, reuseExisting: args.dryRun });
  if (!initial.ok) {
    console.log(JSON.stringify({
      status: "blocked",
      reason: initial.reason || "could-not-open-profile",
      page: {
        url: redactUrl(initial.page?.url()),
        title: initial.page ? await title(initial.page) : "",
        text: initial.body?.slice(0, 1200),
      },
      pages: await summarizePages(context),
    }, null, 2));
    process.exitCode = 2;
    return;
  }

  const initialOrgs = await organizationNames(initial.page);
  const keep = new Set(args.keep);
  const targets = initialOrgs.filter((name) => !keep.has(name));

  if (args.dryRun) {
    console.log(JSON.stringify({ status: "dry-run", keep: args.keep, initialOrgs, targets }, null, 2));
    return;
  }

  const log = [];
  for (const org of targets.slice(0, args.max)) {
    const result = await leaveOrganization(context, args, org);
    log.push(result);
    console.log(JSON.stringify({ event: "leave-result", result }, null, 2));
    if (!["left", "already-missing"].includes(result.status)) {
      console.log(JSON.stringify({ status: "blocked", keep: args.keep, initialOrgs, targets, log }, null, 2));
      process.exitCode = 2;
      return;
    }
  }

  const finalProfile = await openProfile(context, args.profileUrl);
  const finalOrgs = finalProfile.ok ? await organizationNames(finalProfile.page) : [];
  console.log(JSON.stringify({
    status: finalProfile.ok && finalOrgs.every((name) => keep.has(name)) ? "complete" : "needs-review",
    keep: args.keep,
    initialOrgs,
    targets,
    log,
    finalOrgs,
  }, null, 2));
}

main()
  .then(() => {
    process.exit(process.exitCode || 0);
  })
  .catch((error) => {
    console.error(JSON.stringify({ status: "error", message: error.message, stack: error.stack }, null, 2));
    process.exit(1);
  });
