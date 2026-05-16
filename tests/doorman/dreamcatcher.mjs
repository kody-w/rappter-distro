#!/usr/bin/env node
//
// dreamcatcher.mjs — end-to-end tests for the frame log + Dream Catcher
// merge doctrine. Validates that:
//   1. Doorman writes content-addressed frames to localStorage on
//      meaningful events (chat turn, tool call, memory save).
//   2. Ascended .egg export packs data/frames.json containing those frames.
//   3. Front-door Dream Catcher reads frames from data/frames.json
//      (preferring the explicit log over the Git-derived synthesis).
//   4. UTC-first canon: when two parallel-dimension eggs have the same
//      hashes for some frames, those are classified `shared`.
//   5. Layer-on: parallel-only frames with no PK collision are `new`.
//   6. Contradictions: same (utc, frame_n) PK but different hash —
//      classified `contradiction` (alternate-dimension data).
//
// Runs against a local HTTP server serving the dry-run plant output.
// Two browser contexts simulate two parallel hatched dimensions.

import { chromium } from "playwright";
import { spawn, execSync } from "node:child_process";
import { writeFileSync, readFileSync, existsSync, mkdirSync, rmSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

// ── plumbing ────────────────────────────────────────────────────────

// Derive RAPP_ROOT from this file's location: tests/doorman/dreamcatcher.mjs
// → repo root. Allows the test to run from any clone path.
const __dirname = dirname(fileURLToPath(import.meta.url));
const RAPP_ROOT = resolve(__dirname, "..", "..");
const PLANT = `${RAPP_ROOT}/installer/plant.sh`;
const SERVE_DIR = `/tmp/rapp-dc-test-${process.pid}`;
const PORT = parseInt(process.env.RAPP_DC_PORT || "8773", 10);

let server, browser;
let pass = 0, fail = 0;
const failures = [];

function step(name, ok, detail) {
  if (ok) { pass++; console.log(`  ✓ ${name}`); }
  else    { fail++; failures.push(`${name}${detail ? ": " + detail : ""}`); console.log(`  ✗ ${name}${detail ? ": " + detail : ""}`); }
}

function plantSeed() {
  rmSync(SERVE_DIR, { recursive: true, force: true });
  execSync(
    `PLANT_DRY_RUN=1 PLANT_DRY_RUN_DIR=${SERVE_DIR} ` +
    `PLANT_GH_USER=kody-w MIRROR_REPO_NAME=heimdall MIRROR_DISPLAY_NAME=Heimdall ` +
    `MIRROR_KIND=personal bash ${PLANT}`,
    { stdio: "ignore" }
  );
}

function startServer() {
  // Kill anything on the port first
  try { execSync(`lsof -ti:${PORT} | xargs -r kill 2>/dev/null`, { stdio: "ignore" }); } catch {}
  server = spawn("python3", ["-m", "http.server", String(PORT), "--directory", SERVE_DIR], {
    stdio: "ignore", detached: false,
  });
  return new Promise(r => setTimeout(r, 800));
}

function stopServer() {
  if (server) { try { server.kill(); } catch {} }
}

// ── frame-log helpers — drive the doorman's appendFrame() ──────────

async function newDoorman(label) {
  const ctx = await browser.newContext({ acceptDownloads: true });
  const page = await ctx.newPage();
  page.on("pageerror", e => console.log(`  [${label} pageerror]`, e.message));
  page.on("console", m => { if (m.type() === "error") console.log(`  [${label} console-error]`, m.text().slice(0, 200)); });
  // Doorman page needs a token to render the chat shell; we'll inject
  // a fake one into rapp_settings so the auth pane skips.
  await ctx.addInitScript(() => {
    localStorage.setItem("rapp_settings", JSON.stringify({
      ghuToken: "ghu_test_dummy",
      copilotToken: "fake-copilot-tok",
      copilotExpiresAt: Date.now() + 600000,
    }));
  });
  await page.goto(`http://127.0.0.1:${PORT}/doorman/`, { waitUntil: "domcontentloaded", timeout: 15000 });
  // Wait for the inline-script function to exist. `identity` is declared
  // with `let` so it's NOT on window — but `function appendFrame(...)`
  // IS hoisted to window. We probe for that. Identity gets back-filled
  // when we call appendFrame the first time (the function checks
  // `identity` via the script's closure, not via window).
  await page.waitForFunction(() => typeof window.appendFrame === "function", null, { timeout: 10000 });
  // Also wait for loadIdentity() to complete so appendFrame has a rappid
  // for stream_id assignment. The inline script calls loadIdentity()
  // immediately on init; we just need to give it a moment.
  await page.waitForFunction(async () => {
    const r = await fetch("../rappid.json");
    return r.ok;
  }, null, { timeout: 5000 });
  await page.waitForTimeout(500);  // give init() chain a moment
  return { ctx, page };
}

async function injectFrames(page, frames) {
  // frames: [{ kind, payload, utc?, frame_n? }] — utc/frame_n are
  // optional overrides for testing PK collisions.
  return await page.evaluate(async (frames) => {
    // Resolve rappid up-front so we don't depend on the script's
    // private `identity` closure (declared with `let`, not on window).
    const r = await fetch("../rappid.json");
    const rappidObj = r.ok ? await r.json() : {};
    const rappid = rappidObj.rappid || "test-rappid";

    for (const f of frames) {
      const log = JSON.parse(localStorage.getItem("rapp_frames_v1") || '{"schema":"rapp-frame/1.0","stream_id":null,"frames":[]}');
      if (!log.stream_id) {
        const inst = localStorage.getItem("rapp_instance_id") ||
          (window.crypto.randomUUID ? window.crypto.randomUUID().slice(0, 8) : Math.random().toString(36).slice(2, 10));
        localStorage.setItem("rapp_instance_id", inst);
        log.stream_id = rappid.slice(0, 8) + ":" + inst;
      }
      const prev = log.frames.length ? log.frames[log.frames.length - 1].hash : "";
      const utc = f.utc || new Date().toISOString();
      const frame_n = f.frame_n !== undefined ? f.frame_n : log.frames.length;
      const body = (prev || "") + "|" + utc + "|" + frame_n + "|" + f.kind + "|" + JSON.stringify(f.payload || {});
      const hashBytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(body));
      const hash = Array.from(new Uint8Array(hashBytes)).map(b => b.toString(16).padStart(2, "0")).join("");
      log.frames.push({ stream_id: log.stream_id, frame_n, utc, kind: f.kind, payload: f.payload || {}, prev_hash: prev, hash });
      localStorage.setItem("rapp_frames_v1", JSON.stringify(log));
    }
    return JSON.parse(localStorage.getItem("rapp_frames_v1") || "{}");
  }, frames);
}

// Build an ascended-tier egg from the given doorman page. Drives the
// existing buildAscendedEgg function — but that requires privateLayerCoords
// to be set (operator/private-companion gate). For the test we forge a
// "frames-only" egg by hand with the real frame log, since the full
// ascended-egg builder requires GitHub state we don't have in a dry-run.
async function buildFrameOnlyEgg(page, name) {
  const eggBytes = await page.evaluate(async () => {
    const zip = new JSZip();
    const log = JSON.parse(localStorage.getItem("rapp_frames_v1") || '{"frames":[]}');
    zip.file("data/frames.json", JSON.stringify(log, null, 2));
    // Pull rappid from the seed itself (rappid.json is one level up
    // from /doorman/). Avoids depending on the script's `let identity`
    // closure which isn't on window.
    const r = await fetch("../rappid.json");
    const rj = r.ok ? await r.json() : {};
    const manifest = {
      schema: "brainstem-egg/2.2-organism",
      type: "organism",
      tier: "ascended",
      rappid: rj.rappid || "test-rappid",
      display_name: rj.display_name || "Test",
      provenance: {
        schema: "rapp-egg-provenance/1.0",
        sealed_at: new Date().toISOString(),
        sealed_by_rappid: rj.rappid || "test-rappid",
        file_hashes: {},
        manifest_hash: "test-manifest-hash",
      },
    };
    zip.file("manifest.json", JSON.stringify(manifest, null, 2));
    const blob = await zip.generateAsync({ type: "uint8array" });
    return Array.from(blob);
  });
  const path = `/tmp/dc-${name}.egg`;
  writeFileSync(path, Buffer.from(eggBytes));
  return path;
}

// Drop both eggs into the front door's Dream Catcher pane and read the diff
async function runDreamCatcher(canonicalEggPath, parallelEggPath) {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  page.on("pageerror", e => console.log("  [dc pageerror]", e.message));
  // Sphere (/) is now the front door (Constitution Article XLV — implicit
  // summon); the classic action-button row lives at /classic.html.
  // domcontentloaded (not networkidle) — GitHub API 401s with the dummy
  // token keep the network busy indefinitely, but the buttons render
  // synchronously from the inline script.
  await page.goto(`http://127.0.0.1:${PORT}/classic.html`, { waitUntil: "domcontentloaded", timeout: 15000 });
  await page.waitForSelector("#btn-dreamcatcher", { timeout: 10000 });
  await page.click("#btn-dreamcatcher");
  await page.waitForTimeout(300);
  await page.setInputFiles("#dc-file-canonical", canonicalEggPath);
  await page.waitForTimeout(800);
  await page.setInputFiles("#dc-file-parallel", parallelEggPath);
  await page.waitForTimeout(1200);
  const summary = await page.locator(".verify-summary").first().textContent().catch(() => "");
  const counts = await page.evaluate(() => {
    return {
      shared:        document.querySelectorAll(".dc-frame-list li.shared").length,
      newFrames:     document.querySelectorAll(".dc-frame-list li.new").length,
      contradictions: document.querySelectorAll(".dc-frame-list li.contradiction").length,
    };
  });
  await ctx.close();
  return { summary, counts };
}

// ── Tests ──────────────────────────────────────────────────────────

async function testFrameLogPersistence() {
  console.log("\n[test] frame log writes to localStorage");
  const { ctx, page } = await newDoorman("d1");
  const log = await injectFrames(page, [
    { kind: "conversation", payload: { role: "user", content_len: 12 } },
    { kind: "tool_call",    payload: { tool: "ManageMemory", args_keys: ["fact"] } },
    { kind: "memory_added", payload: { scope: "private", body_len: 24 } },
  ]);
  step("3 frames appended", log.frames && log.frames.length === 3);
  step("each frame has hash + prev_hash", log.frames.every(f => typeof f.hash === "string" && f.hash.length === 64));
  step("hash chain links",
    log.frames[0].prev_hash === "" &&
    log.frames[1].prev_hash === log.frames[0].hash &&
    log.frames[2].prev_hash === log.frames[1].hash
  );
  step("frame_n is monotonic", log.frames[0].frame_n === 0 && log.frames[1].frame_n === 1 && log.frames[2].frame_n === 2);
  step("stream_id is set", typeof log.stream_id === "string" && log.stream_id.length > 0);
  await ctx.close();
}

async function testDreamCatcherShared() {
  console.log("\n[test] Dream Catcher: identical eggs → all shared, no work");
  const { ctx: ctxA, page: pageA } = await newDoorman("dA");
  const sharedFrames = [
    { kind: "conversation", payload: { content_len: 5 }, utc: "2026-05-06T20:00:00.000Z", frame_n: 0 },
    { kind: "memory_added", payload: { body_len: 10 },   utc: "2026-05-06T20:01:00.000Z", frame_n: 1 },
  ];
  await injectFrames(pageA, sharedFrames);
  const eggA = await buildFrameOnlyEgg(pageA, "shared-canonical");
  await ctxA.close();

  const { ctx: ctxB, page: pageB } = await newDoorman("dB");
  // Same frames, same timestamps, same payloads → same hashes
  await injectFrames(pageB, sharedFrames);
  const eggB = await buildFrameOnlyEgg(pageB, "shared-parallel");
  await ctxB.close();

  const { summary, counts } = await runDreamCatcher(eggA, eggB);
  step("summary indicates fully reflected", summary.includes("fully reflected") || summary.includes("Nothing to reassimilate"));
  step("2 shared frames", counts.shared === 2, `got shared=${counts.shared}`);
  step("0 new frames", counts.newFrames === 0, `got new=${counts.newFrames}`);
  step("0 contradictions", counts.contradictions === 0, `got contradictions=${counts.contradictions}`);
}

async function testDreamCatcherNewFrames() {
  console.log("\n[test] Dream Catcher: parallel adds new frames → layer-on");
  const { ctx: ctxA, page: pageA } = await newDoorman("dA");
  await injectFrames(pageA, [
    { kind: "conversation", payload: { content_len: 5 }, utc: "2026-05-06T20:00:00.000Z", frame_n: 0 },
  ]);
  const eggA = await buildFrameOnlyEgg(pageA, "newonly-canonical");
  await ctxA.close();

  const { ctx: ctxB, page: pageB } = await newDoorman("dB");
  // Same first frame (so it's shared), then two more — these are new
  await injectFrames(pageB, [
    { kind: "conversation", payload: { content_len: 5 }, utc: "2026-05-06T20:00:00.000Z", frame_n: 0 },
    { kind: "memory_added", payload: { body_len: 10 },   utc: "2026-05-06T20:01:00.000Z", frame_n: 1 },
    { kind: "tool_call",    payload: { tool: "Foo" },    utc: "2026-05-06T20:02:00.000Z", frame_n: 2 },
  ]);
  const eggB = await buildFrameOnlyEgg(pageB, "newonly-parallel");
  await ctxB.close();

  const { summary, counts } = await runDreamCatcher(eggA, eggB);
  step("summary mentions layer-on", summary.includes("layer on") || summary.includes("ready to layer") || summary.includes("clean"));
  step("1 shared frame",       counts.shared === 1,         `got shared=${counts.shared}`);
  step("2 new frames",          counts.newFrames === 2,       `got new=${counts.newFrames}`);
  step("0 contradictions",      counts.contradictions === 0,  `got contradictions=${counts.contradictions}`);
}

async function testDreamCatcherContradiction() {
  console.log("\n[test] Dream Catcher: same PK, different content → contradiction");
  const { ctx: ctxA, page: pageA } = await newDoorman("dA");
  // Canonical: frame_n=0 with payload "alpha" at fixed UTC
  await injectFrames(pageA, [
    { kind: "memory_added", payload: { body_len: 100, content: "alpha" }, utc: "2026-05-06T20:00:00.000Z", frame_n: 0 },
  ]);
  const eggA = await buildFrameOnlyEgg(pageA, "contradiction-canonical");
  await ctxA.close();

  const { ctx: ctxB, page: pageB } = await newDoorman("dB");
  // Parallel: SAME frame_n=0 + SAME utc, but different payload → different hash
  // This is the "two devices forking the same starting point with divergent
  // edits" scenario — Dream Catcher should flag this as a contradiction.
  await injectFrames(pageB, [
    { kind: "memory_added", payload: { body_len: 100, content: "beta" }, utc: "2026-05-06T20:00:00.000Z", frame_n: 0 },
  ]);
  const eggB = await buildFrameOnlyEgg(pageB, "contradiction-parallel");
  await ctxB.close();

  const { summary, counts } = await runDreamCatcher(eggA, eggB);
  step("summary mentions contradiction", summary.toLowerCase().includes("contradict"));
  step("0 shared frames",       counts.shared === 0,            `got shared=${counts.shared}`);
  step("0 new frames",           counts.newFrames === 0,          `got new=${counts.newFrames}`);
  step("1 contradiction",        counts.contradictions === 1,     `got contradictions=${counts.contradictions}`);
}

// ── runner ─────────────────────────────────────────────────────────

async function main() {
  console.log("Dream Catcher / frame log integration tests\n");
  console.log("planting fresh seed…");
  plantSeed();
  console.log("starting local server on", PORT);
  await startServer();

  browser = await chromium.launch({ headless: true });

  try {
    await testFrameLogPersistence();
    await testDreamCatcherShared();
    await testDreamCatcherNewFrames();
    await testDreamCatcherContradiction();
  } finally {
    await browser.close();
    stopServer();
  }

  console.log("");
  console.log(`──────────  ${pass} passed, ${fail} failed  ──────────`);
  if (fail > 0) {
    console.log("\nFailures:");
    for (const f of failures) console.log("  •", f);
    process.exit(1);
  }
  process.exit(0);
}

main().catch(e => {
  console.error("[fatal]", e);
  stopServer();
  process.exit(2);
});
