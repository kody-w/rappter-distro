#!/usr/bin/env node
//
// tether-egg.mjs — test for the one-tap egg send protocol over the
// tether channel (Charizard handoff hero use case).
//
// Pairing through the public PeerJS broker is flaky in headless test
// environments. Instead of relying on the broker handshake, we exercise
// the egg-send/receive PROTOCOL in isolation:
//
//   1. Inject a fake `conn` object with .send / .open=true on the page
//   2. Drive sendEggToPeer() directly — it builds the doorman-tier
//      egg, chunks it, and emits {egg-begin, egg-chunk*, egg-end}
//      messages through conn.send
//   3. Capture every emitted message
//   4. Pass them all to _handleEggMessage() on the same page (which is
//      the receiver side of the protocol — independent of how the
//      messages got there)
//   5. Wait for the download event → verify byte-identical sha256
//
// This validates the protocol end-to-end (build, chunk, emit, parse,
// reassemble, verify, download) without depending on PeerJS broker.

import { chromium } from "playwright";
import { spawn, execSync } from "node:child_process";
import { rmSync, readFileSync, existsSync } from "node:fs";
import crypto from "node:crypto";

const RAPP_ROOT = "/Users/kodywildfeuer/RAPP";
const PLANT = `${RAPP_ROOT}/installer/plant.sh`;
const SERVE_DIR = "/tmp/te-test-fresh";
const PORT = 8774;

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
  try { execSync(`lsof -ti:${PORT} | xargs -r kill 2>/dev/null`, { stdio: "ignore" }); } catch {}
  server = spawn("python3", ["-m", "http.server", String(PORT), "--directory", SERVE_DIR], {
    stdio: "ignore", detached: false,
  });
  return new Promise(r => setTimeout(r, 800));
}

function stopServer() { if (server) { try { server.kill(); } catch {} } }

async function testEggSendProtocol() {
  console.log("\n[test] egg-send protocol (chunk → emit → reassemble → verify)");
  const ctx = await browser.newContext({ acceptDownloads: true });
  const page = await ctx.newPage();
  page.on("pageerror", e => console.log("  [pageerror]", e.message.slice(0, 200)));
  await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "domcontentloaded", timeout: 20000 });
  await page.waitForTimeout(1000);

  // Sanity-check that buildDoormanEgg produces a non-empty blob with
  // a real sha256. Builds are non-deterministic across calls (JSZip
  // stamps timestamps in the central directory), so we don't capture
  // an "expected" sha256 here; we'll compare receiver output against
  // what the SENDER actually declared in egg-begin.
  const sanity = await page.evaluate(async () => {
    const blob = await buildDoormanEgg();
    const buf = new Uint8Array(await blob.arrayBuffer());
    const sha256 = await sha256Hex(buf);
    return { size: buf.length, sha256 };
  });
  step("buildDoormanEgg produces non-empty blob", sanity.size > 1000, `size=${sanity.size}`);
  step("sanity sha256 has correct length",        sanity.sha256.length === 64);

  // Phase 1: collect every message _streamEggThroughChannel emits via
  // an injected fake channel. Bypasses the module-scope `conn` binding.
  await page.evaluate(() => {
    window._sentMessages = [];
    window._fakeChan = {
      open: true,
      send: function(msg) { window._sentMessages.push(msg); },
    };
  });
  await page.evaluate(() => _streamEggThroughChannel(window._fakeChan));

  // Phase 2: replay collected messages through the receive handler,
  // then wait for the download event the receiver triggers on egg-end.
  const dlPromise = page.waitForEvent("download", { timeout: 30000 });
  const replay = await page.evaluate(async () => {
    const log = [];
    for (const m of window._sentMessages) {
      const parsed = JSON.parse(m);
      try {
        await _handleEggMessage(parsed);
        log.push({ type: parsed.type, ok: true });
      } catch (e) {
        log.push({ type: parsed.type, ok: false, error: e.message });
      }
    }
    // Read the chat-log in the tether pane to see what the receiver said
    const chat = document.getElementById("chat-log");
    return { log, chatText: chat ? chat.textContent.slice(0, 500) : "(no chat-log)" };
  });
  if (replay.chatText) console.log("  [receiver chat]", replay.chatText.slice(0, 300));
  const dl = await dlPromise;
  const target = "/tmp/te-protocol-received.egg";
  await dl.saveAs(target);
  step("loopback received → download triggered", existsSync(target));

  // Inspect the wire protocol — should be: 1 egg-begin, N egg-chunks, 1 egg-end
  const msgs = await page.evaluate(() => window._sentMessages.map(m => JSON.parse(m)));
  step("first message is egg-begin",      msgs[0].type === "egg-begin");
  step("egg-begin carries size + sha256",
    typeof msgs[0].size === "number" && msgs[0].size > 0 &&
    typeof msgs[0].sha256 === "string" && msgs[0].sha256.length === 64);
  step("last message is egg-end",         msgs[msgs.length - 1].type === "egg-end");
  const chunkCount = msgs.filter(m => m.type === "egg-chunk").length;
  step("at least one egg-chunk emitted",  chunkCount >= 1, `chunks=${chunkCount}`);
  step("chunk count matches size",
    chunkCount === Math.ceil(msgs[0].size / (16 * 1024)),
    `expected=${Math.ceil(msgs[0].size / (16 * 1024))} actual=${chunkCount}`);
  step("chunks have monotonic seq",
    msgs.filter(m => m.type === "egg-chunk").every((m, i) => m.seq === i));

  // Integrity claim: received sha256 must match the sha256 the sender
  // DECLARED in egg-begin. (This is what the receiver verified before
  // triggering the download; passing here means the wire was lossless
  // AND the sender's stated hash was honest about its bytes.)
  const got = readFileSync(target);
  const actual = crypto.createHash("sha256").update(got).digest("hex");
  step("received sha256 matches egg-begin's declared sha256",
    actual === msgs[0].sha256,
    `declared=${msgs[0].sha256.slice(0,12)}… actual=${actual.slice(0,12)}…`);
  step("received size matches egg-begin's declared size",
    got.length === msgs[0].size,
    `declared=${msgs[0].size} actual=${got.length}`);
  step("filename ends in -doorman.egg", dl.suggestedFilename().endsWith("-doorman.egg"));

  await ctx.close();
}

async function testTamperDetection() {
  console.log("\n[test] receiver rejects tampered egg (sha256 mismatch)");
  const ctx = await browser.newContext({ acceptDownloads: true });
  const page = await ctx.newPage();
  page.on("pageerror", e => console.log("  [pageerror]", e.message.slice(0, 200)));
  await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "domcontentloaded", timeout: 20000 });
  await page.waitForTimeout(1000);

  // Send a deliberately wrong sha256 in egg-begin and see that the
  // receiver refuses to download. Captures system messages on the
  // tether chat-log to detect the rejection notice.
  const result = await page.evaluate(async () => {
    // Open the tether pane so chat-log exists for appendMsg
    const tetherPane = document.getElementById("pane-tether");
    if (tetherPane) tetherPane.hidden = false;

    const fakePayload = new Uint8Array([0xDE, 0xAD, 0xBE, 0xEF]);
    const wrongSha = "0".repeat(64);
    await _handleEggMessage({ type: "egg-begin", size: fakePayload.length, sha256: wrongSha, name: "tampered.egg" });
    let bin = "";
    for (let i = 0; i < fakePayload.length; i++) bin += String.fromCharCode(fakePayload[i]);
    await _handleEggMessage({ type: "egg-chunk", seq: 0, b64: btoa(bin) });
    await _handleEggMessage({ type: "egg-end" });
    // Read the last system message in the tether chat-log
    const log = document.getElementById("chat-log");
    return log ? log.textContent : "";
  });
  step("receiver flagged sha256 mismatch", /integrity check|sha256 mismatch/i.test(result), `text=${result.slice(0, 200)}`);
  await ctx.close();
}

async function main() {
  console.log("Tether egg send (Charizard handoff) protocol test\n");
  console.log("planting fresh seed…");
  plantSeed();
  console.log("starting local server on", PORT);
  await startServer();

  browser = await chromium.launch({ headless: true });

  try {
    await testEggSendProtocol();
    await testTamperDetection();
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
