#!/usr/bin/env node
//
// smoke.js — sequential smoke tests across the planted-doorman fleet.
//
// Runs the headless harness against several known-live front doors,
// reports pass/fail per scenario. Drives the same code path a phone
// or laptop visitor would. Uses `gh auth token` for the authed runs.
//
// Usage:
//   node smoke.js                           # default fleet, authed scenarios
//   node smoke.js --anon                    # anonymous-only — checks the
//                                            doorman serves and welcome lands
//   node smoke.js --only=heimdall           # restrict to one slug
//   node smoke.js --verbose                 # browser console + errors
//

import { chromium } from "playwright";
import { execSync } from "node:child_process";

const FLEET = [
  {
    slug: "heimdall",
    url: "https://kody-w.github.io/heimdall/doorman/",
    expect_in_welcome: ["Heimdall"],
    test_message: "In one sentence — who are you?",
    expect_in_reply: ["Heimdall", "Bifrost"],  // either works
  },
  {
    slug: "kody-twin",
    url: "https://kody-w.github.io/kody-twin/doorman/",
    expect_in_welcome: ["Kody Wildfeuer"],
    test_message: "What's the bond cycle?",
    expect_in_reply: ["bond", "egg", "kernel"],
  },
  {
    slug: "pkstop-the-bean",
    url: "https://kody-w.github.io/pkstop-the-bean/doorman/",
    expect_in_welcome: ["Cloud Gate", "Bean"],
    test_message: "Where are you?",
    expect_in_reply: ["Chicago", "Millennium"],
  },
];

function arg(name) {
  for (const a of process.argv.slice(2)) {
    if (a === "--" + name) return true;
    if (a.startsWith("--" + name + "=")) return a.slice(name.length + 3);
  }
  return null;
}

const onlySlug = arg("only");
const anonOnly = arg("anon");
const verbose = arg("verbose");

let token = null;
if (!anonOnly) {
  try { token = execSync("gh auth token", { encoding: "utf8" }).trim() || null; }
  catch { console.error("[smoke] gh auth token failed; falling back to anonymous"); }
}

const fleet = FLEET.filter(s => !onlySlug || s.slug === onlySlug);
if (!fleet.length) {
  console.error("[smoke] no scenarios match --only=" + onlySlug);
  process.exit(2);
}

const browser = await chromium.launch({ headless: true });
let pass = 0, fail = 0;
const failures = [];

for (const s of fleet) {
  const tag = `${s.slug.padEnd(28)}`;
  process.stdout.write(`▸ ${tag}  `);

  const ctx = await browser.newContext();
  const page = await ctx.newPage();

  if (verbose) {
    page.on("console", m => console.error("\n  [browser]", m.type(), m.text()));
    page.on("pageerror", e => console.error("\n  [pageerror]", e.message));
  }

  if (token && !anonOnly) {
    await ctx.addInitScript((t) => {
      try {
        // ghuToken = the long-lived GitHub OAuth token from device-code flow.
        // Doorman exchanges it for a short-lived Copilot session on first chat.
        localStorage.setItem("rapp_settings", JSON.stringify({
          ghuToken: t,
        }));
      } catch (_) {}
    }, token);
  }

  let ok = true;
  let detail = "";
  try {
    await page.goto(s.url, { waitUntil: "domcontentloaded", timeout: 25000 });
    // Wait for first system welcome msg (signed-in) or auth pane (anon)
    await page.waitForFunction(() => {
      const sys = document.querySelector(".msg.system");
      if (sys && sys.textContent && sys.textContent.trim()) return true;
      const auth = document.querySelector("#auth-pane");
      if (auth && !auth.hidden) return true;
      return false;
    }, null, { timeout: 25000 });

    // Welcome / persona check — scan ALL system messages (the Pyodide
    // loader chats "loading agents…" BEFORE the persona welcome lands;
    // we want to find any message that contains an expected substring)
    let welcomeOK = false;
    let welcome = "";
    const deadline = Date.now() + 30000;
    while (Date.now() < deadline && !welcomeOK) {
      const all = await page.locator(".msg.system").allTextContents();
      welcome = all.join(" │ ");
      welcomeOK = s.expect_in_welcome.some(w =>
        all.some(m => m.includes(w))
      );
      if (welcomeOK) break;
      await page.waitForTimeout(500);
    }
    if (!welcomeOK) {
      ok = false;
      detail = `welcome missing any of [${s.expect_in_welcome.join(",")}] — got: ${welcome.slice(0, 200)}`;
    }

    // Message turn (only if authed)
    if (ok && token && !anonOnly && s.test_message) {
      const beforeAsst = await page.locator(".msg.assistant").count();
      await page.fill("#chat-input", s.test_message);
      await page.click("#btn-send");
      try {
        await page.waitForFunction(
          (prev) => document.querySelectorAll(".msg.assistant").length > prev,
          beforeAsst,
          { timeout: 60000 }
        );
      } catch {
        ok = false;
        detail = "no assistant reply within 60s";
      }
      if (ok) {
        const replies = await page.locator(".msg.assistant").allTextContents();
        const reply = replies[replies.length - 1] || "";
        const replyOK = s.expect_in_reply.some(p => reply.toLowerCase().includes(p.toLowerCase()));
        if (!replyOK) {
          ok = false;
          detail = `reply missing any of [${s.expect_in_reply.join(",")}] — got: ${reply.slice(0, 120)}`;
        }
      }
    }
  } catch (e) {
    ok = false;
    detail = "exception: " + (e.message || String(e)).slice(0, 200);
  }

  if (ok) { console.log("PASS"); pass++; }
  else    { console.log("FAIL  — " + detail); fail++; failures.push({ slug: s.slug, detail }); }

  await ctx.close();
}

await browser.close();

console.log("");
console.log(`──────────  ${pass} passed, ${fail} failed  ──────────`);
if (fail > 0) {
  console.log("\nFailures:");
  for (const f of failures) console.log(`  • ${f.slug}: ${f.detail}`);
  process.exit(1);
}
