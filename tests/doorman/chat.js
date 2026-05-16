#!/usr/bin/env node
//
// chat.js — talk to a planted RAPP doorman from the command line.
//
// Drives a real headless browser against the doorman page, optionally
// pre-seeding a GitHub token in localStorage (skipping the OAuth round-
// trip), sends a chat message, waits for the assistant's reply, prints
// the conversation. Same code path the visitor's browser would run.
//
// Usage:
//   node chat.js <doorman_url> [opts] "<message>"
//
// Options:
//   --token=auto         Use `gh auth token` for the auth — same scope as
//                         signing in via the OAuth flow on the doorman.
//   --token=<value>      Provide a token explicitly.
//   (no --token)         Run anonymously — chat won't work, but you'll see
//                         the welcome state.
//   --headed             Show the browser window (default: headless).
//   --verbose            Stream browser console + page errors to stderr.
//   --slow               Add 100ms artificial delay per Playwright action
//                         (helpful with --headed).
//   --timeout=<seconds>  Override the assistant-reply timeout (default: 60).
//   --keep-open          Don't close the browser after the reply (handy
//                         with --headed for poking around).
//
// Examples:
//   node chat.js https://kody-w.github.io/heimdall/doorman/ \
//       --token=auto "I am a traveler. Who are you?"
//
//   node chat.js https://kody-w.github.io/kody-twin/doorman/ \
//       --token=auto "What do you know about the bond cycle?"
//
//   node chat.js https://kody-w.github.io/heimdall/doorman/ \
//       --headed --keep-open "show me what you've got"

import { chromium } from "playwright";
import { execSync } from "node:child_process";
import { readFileSync, existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

// Find a ghu_* Copilot OAuth token from the canonical local-brainstem
// install. Tries the standard locations a `bash installer/install.sh`
// run leaves behind. Returns null if nothing's authed yet.
function findLocalCopilotToken() {
  const candidates = [
    join(homedir(), ".brainstem/src/rapp_brainstem/.copilot_token"),
    join(homedir(), ".brainstem/.copilot_token"),
    "/Users/kodywildfeuer/RAPP/rapp_brainstem/.copilot_token",
  ];
  for (const p of candidates) {
    if (!existsSync(p)) continue;
    try {
      const raw = readFileSync(p, "utf8").trim();
      if (raw.startsWith("ghu_") || raw.startsWith("gho_")) return raw;
      const parsed = JSON.parse(raw);
      if (parsed && typeof parsed.access_token === "string") return parsed.access_token;
    } catch (_) { /* try next */ }
  }
  return null;
}

function arg(name) {
  const flag = "--" + name;
  for (const a of process.argv.slice(2)) {
    if (a === flag) return true;
    if (a.startsWith(flag + "=")) return a.slice(flag.length + 1);
  }
  return null;
}

const url = process.argv.find(a => /^https?:\/\//.test(a));
const message = process.argv
  .slice(2)
  .filter(a => !a.startsWith("--") && !/^https?:\/\//.test(a))
  .join(" ")
  .trim();

if (!url) {
  console.error("Usage: node chat.js <doorman_url> [--token=auto|<pat>] [--headed] [--verbose] \"<message>\"");
  process.exit(2);
}

let token = arg("token");
if (token === "auto" || token === true) {
  // Prefer the canonical brainstem's ghu_* token (works with the Copilot
  // exchange + chat endpoint). Fall back to gh CLI as a last resort, but
  // note that gh's gho_* token won't pass the Copilot exchange.
  token = findLocalCopilotToken();
  if (!token) {
    try {
      token = execSync("gh auth token", { encoding: "utf8" }).trim() || null;
      console.error("[chat.js] using gh CLI token (gho_*) — Copilot exchange may fail; run brainstem.py once to mint a ghu_*");
    } catch {
      console.error("[chat.js] no ghu_* token found and gh CLI unavailable; running anonymous");
      token = null;
    }
  } else {
    console.error("[chat.js] using ghu_* from local brainstem .copilot_token");
  }
}

const headed = !!arg("headed");
const verbose = !!arg("verbose");
const slow = !!arg("slow");
const keepOpen = !!arg("keep-open");
const timeoutSec = parseInt(arg("timeout") || "60", 10);

const browser = await chromium.launch({
  headless: !headed,
  slowMo: slow ? 100 : 0,
});
const ctx = await browser.newContext();
const page = await ctx.newPage();

if (verbose) {
  page.on("console", m => console.error("[browser]", m.type(), m.text()));
  page.on("pageerror", e => console.error("[pageerror]", e.message));
  page.on("requestfailed", r => console.error("[request-failed]", r.url(), r.failure()?.errorText));
  page.on("response", r => {
    if (r.status() >= 400 && r.url().match(/api\.|raw\.|rapp-auth|github/)) {
      console.error("[http-error]", r.status(), r.url());
    }
  });
}

// Pre-seed token in localStorage so the doorman skips the auth pane and
// goes straight to chat — same effect as a visitor who's signed in.
if (token) {
  await ctx.addInitScript((t) => {
    try {
      // Same shape as rapp_brainstem/utils/web — ghuToken is the long-lived
      // GitHub OAuth token from the device-code flow. The doorman exchanges
      // it for a short-lived Copilot session token on the first chat turn.
      localStorage.setItem("rapp_settings", JSON.stringify({
        ghuToken: t,
      }));
    } catch (_) { /* ignore */ }
  }, token);
}

console.error("[chat.js] →", url, token ? "(authed)" : "(anonymous)");

await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });

// Wait until enterChat() (or the auth pane render) has finished. We
// detect "ready to interact" via the welcome system message dropping
// in (signed-in case) OR the auth pane being visible (anonymous case).
try {
  await page.waitForFunction(() => {
    const sys = document.querySelector(".msg.system");
    if (sys && sys.textContent && sys.textContent.trim()) return true;
    const auth = document.querySelector("#auth-pane");
    if (auth && !auth.hidden) return true;
    return false;
  }, null, { timeout: 25000 });
} catch {
  console.error("[chat.js] doorman didn't finish rendering within 25s");
}

// Read the badge + welcome lines
const badgeText = await page.locator("#private-indicator .private-badge").first().textContent().catch(() => "");
const welcomeMsg = await page.locator(".msg.system").first().textContent().catch(() => "");

console.error("[chat.js] welcome:", welcomeMsg.replace(/\s+/g, " ").slice(0, 200));
if (badgeText) console.error("[chat.js] badge:", badgeText.trim());

if (!message) {
  console.log(welcomeMsg);
  if (!keepOpen) await browser.close();
  process.exit(0);
}

if (!token) {
  console.error("[chat.js] no token → can't send messages (chat backend requires GitHub Models auth)");
  if (!keepOpen) await browser.close();
  process.exit(3);
}

// Capture system messages that fire during the response (tool calls,
// memory saves, agent loads) so we can report them.
const beforeSysCount = await page.locator(".msg.system").count();
const beforeAsstCount = await page.locator(".msg.assistant").count();

await page.fill("#chat-input", message);
await page.click("#btn-send");

// Wait until a new assistant reply lands
try {
  await page.waitForFunction(
    (prev) => document.querySelectorAll(".msg.assistant").length > prev,
    beforeAsstCount,
    { timeout: timeoutSec * 1000 }
  );
} catch {
  console.error(`[chat.js] no assistant reply within ${timeoutSec}s — printing what's visible`);
}

const allAsst = await page.locator(".msg.assistant").allTextContents();
const allSys = await page.locator(".msg.system").allTextContents();
const lastReply = allAsst[allAsst.length - 1] || "(no reply)";
const newSysMsgs = allSys.slice(beforeSysCount);

console.log("\n=== you ===");
console.log(message);
console.log("\n=== " + (badgeText.trim() || "doorman") + " ===");
console.log(lastReply);

if (newSysMsgs.length > 0) {
  console.log("\n=== system trace (tool calls, memory saves) ===");
  for (const s of newSysMsgs) {
    if (s.trim()) console.log("· " + s.replace(/\s+/g, " ").trim());
  }
}

if (!keepOpen) await browser.close();
else console.error("[chat.js] --keep-open: leaving browser running. Ctrl+C to exit.");
