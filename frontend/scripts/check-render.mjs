import { chromium } from "@playwright/test";
import fs from "node:fs/promises";
import path from "node:path";

const origin = process.argv[2];
const screenshotDir = process.env.SCREENSHOT_DIR;

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

async function expectVisible(page, selector, label) {
  const locator = page.locator(selector).first();
  await locator.waitFor({ state: "visible", timeout: 10_000 });
  console.log(`OK: ${label}`);
  return locator;
}

async function expectOpaque(page, selector, label) {
  const opacity = await page.locator(selector).first().evaluate((node) => Number.parseFloat(getComputedStyle(node).opacity));
  if (Number.isNaN(opacity) || opacity < 0.95) fail(`${label} opacity is ${opacity}`);
  console.log(`OK: ${label} is opaque`);
}

async function expectLoadedImage(page, selector, label) {
  const locator = await expectVisible(page, selector, label);
  const loaded = await locator.evaluate((node) => node instanceof HTMLImageElement && node.complete && node.naturalWidth > 0);
  if (!loaded) fail(`${label} image did not load`);
}

async function saveScreenshot(page, name) {
  if (!screenshotDir) return;
  await fs.mkdir(screenshotDir, { recursive: true });
  await page.screenshot({ path: path.join(screenshotDir, name), fullPage: true });
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
const failures = [];

page.on("pageerror", (error) => failures.push(`page error: ${error.message}`));
page.on("console", (message) => {
  if (message.type() === "error") failures.push(`console error: ${message.text()}`);
});

try {
  await page.goto(`${origin}/`, { waitUntil: "domcontentloaded", timeout: 20_000 });
  const hero = await expectVisible(page, ".hero__wordmark", "desktop hero wordmark");
  const heroText = (await hero.textContent())?.trim();
  if (heroText !== "Shouka") fail(`unexpected hero wordmark: ${heroText}`);
  await expectLoadedImage(page, 'img[alt="Shouka creator avatar refreshing into view"]', "desktop creator avatar");
  await expectVisible(page, ".writing-row", "desktop writing list");
  await expectOpaque(page, ".writing-row", "desktop writing row");
  await expectVisible(page, ".tars-fab", "desktop Agent launcher");
  await page.waitForFunction(
    () => document.querySelector(".hero-portrait__base")?.getAttribute("src")?.endsWith("/avatar/refresh/frame-11.png"),
    null,
    { timeout: 4_000 },
  );
  const desktopAvatarSrc = await page.locator(".hero-portrait__base").first().getAttribute("src");
  if (!desktopAvatarSrc?.endsWith("/avatar/refresh/frame-11.png")) {
    fail(`desktop avatar refresh ended on unexpected frame: ${desktopAvatarSrc}`);
  }
  await saveScreenshot(page, "desktop-home.png");

  await page.getByRole("button", { name: "ABOUT" }).click();
  await page.waitForFunction(() => window.location.hash === "#about", null, { timeout: 5_000 });
  console.log("OK: nav anchor updates hash");

  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${origin}/`, { waitUntil: "domcontentloaded", timeout: 20_000 });
  await expectVisible(page, ".brand", "mobile brand");
  await expectVisible(page, ".hero__wordmark", "mobile hero wordmark");
  await expectLoadedImage(page, 'img[alt="Shouka creator avatar refreshing into view"]', "mobile creator avatar");
  await page.waitForTimeout(900);
  const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
  if (overflow > 1) fail(`mobile viewport has ${overflow}px horizontal overflow`);
  console.log("OK: mobile viewport has no horizontal overflow");
  await saveScreenshot(page, "mobile-home.png");

  if (failures.length > 0) fail(failures.join("; "));
  console.log("Frontend browser render check complete.");
} finally {
  await browser.close();
}
