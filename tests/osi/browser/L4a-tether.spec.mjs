// tests/osi/browser/L4a-tether.spec.mjs
//
// L4a (WebRTC tether) end-to-end conformance via Playwright.
//
// Spawns two real Chromium browser contexts pointed at the local fixture
// (mirrors plant.sh's PeerJS pair pattern). Verifies:
//   1. Both peers register with the public PeerJS broker
//   2. Page A can open a DTLS-encrypted DataChannel to Page B's peer ID
//   3. Messages round-trip A → B
//   4. Messages round-trip B → A
//
// This proves the L4a contract end-to-end — what the shell-only L4 test
// can't cover (it only verifies broker reachability + plant.sh wiring).
//
// Exit code 0 = green; non-zero = red. stdout is ✓/✗ lines for parsing.

import { chromium } from "playwright";
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const FIXTURE_FILE = path.join(__dirname, "fixture.html");

const C = process.stdout.isTTY
  ? { green: "\x1b[32m", red: "\x1b[31m", yellow: "\x1b[33m", bold: "\x1b[1m", reset: "\x1b[0m" }
  : { green: "", red: "", yellow: "", bold: "", reset: "" };

let PASSED = 0;
let FAILED = 0;
function pass(msg) { console.log(`  ${C.green}✓${C.reset} ${msg}`); PASSED++; }
function fail(msg) { console.log(`  ${C.red}✗${C.reset} ${msg}`); FAILED++; }
function heading(msg) { console.log(`\n${C.bold}${msg}${C.reset}`); }
function note(msg) { console.log(`  ${C.yellow}${msg}${C.reset}`); }

function serveFixture() {
  return new Promise((resolve) => {
    const server = http.createServer((req, res) => {
      const url = (req.url || "/").split("?")[0];
      if (url === "/" || url === "/fixture.html") {
        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
        res.end(fs.readFileSync(FIXTURE_FILE));
      } else {
        res.writeHead(404, { "Content-Type": "text/plain" });
        res.end("not found");
      }
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function waitFor(predicate, { timeoutMs = 15000, intervalMs = 100, label = "condition" } = {}) {
  const start = Date.now();
  let lastErr = null;
  while (Date.now() - start < timeoutMs) {
    try {
      if (await predicate()) return true;
    } catch (e) {
      lastErr = e;
    }
    await new Promise((r) => setTimeout(r, intervalMs));
  }
  throw new Error(`timed out waiting for ${label}` + (lastErr ? ` (last error: ${lastErr.message})` : ""));
}

(async () => {
  console.log(`${C.bold}${C.bold}=== L4a — Tether (real WebRTC via Playwright) ===${C.reset}`);
  note("Two real Chromium contexts; PeerJS broker handshake; DTLS DataChannel; messages both ways.");

  const server = await serveFixture();
  const port = server.address().port;
  const url = `http://127.0.0.1:${port}/fixture.html`;
  console.log(`  fixture serving at ${url}`);

  // Launch TWO separate browser processes (not two contexts in one process).
  // Same-process contexts share a WebRTC stack and ICE candidate gathering
  // collapses to a single host — peer-to-peer negotiation never completes.
  // Two processes = two independent stacks = real ICE = real DataChannel.
  // Chromium WebRTC defaults block headless P2P negotiation:
  //   - WebRtcHideLocalIpsWithMdns: ICE candidates use unresolvable .local hostnames
  //   - WebRtcAllowInputVolumeAdjustment: not relevant but bundled with audio init
  // Disabling these gives us real IP candidates that resolve between two
  // sibling Chromium processes on 127.0.0.1.
  const launchOpts = {
    headless: true,
    args: [
      "--disable-features=WebRtcHideLocalIpsWithMdns,IsolateOrigins,site-per-process",
      "--no-sandbox",
      "--disable-dev-shm-usage",
    ],
  };
  let browserA = null;
  let browserB = null;
  try {
    [browserA, browserB] = await Promise.all([
      chromium.launch(launchOpts),
      chromium.launch(launchOpts),
    ]);
  } catch (e) {
    fail(`failed to launch chromium: ${e.message}`);
    note(`run "cd tests/osi/browser && npx playwright install chromium" first`);
    server.close();
    process.exit(1);
  }

  const pageA = await browserA.newPage();
  const pageB = await browserB.newPage();

  // Surface page console errors for debugging — but don't fail on them.
  for (const [name, page] of [["A", pageA], ["B", pageB]]) {
    page.on("pageerror", (err) => note(`page${name} pageerror: ${err.message}`));
    page.on("console", (m) => {
      if (m.type() === "error") note(`page${name} console.error: ${m.text()}`);
    });
  }

  let exitCode = 1;
  try {
    heading("Step 1 — Open both pages");
    await Promise.all([pageA.goto(url), pageB.goto(url)]);
    pass("both pages loaded");

    heading("Step 2 — Both peers register with PeerJS broker");
    await waitFor(async () => {
      const a = await pageA.evaluate(() => window.__rappTest.getMyId());
      const b = await pageB.evaluate(() => window.__rappTest.getMyId());
      return a && a !== "connecting…" && b && b !== "connecting…" && a !== b;
    }, { timeoutMs: 20000, label: "both peers to register with broker" });
    const idA = await pageA.evaluate(() => window.__rappTest.getMyId());
    const idB = await pageB.evaluate(() => window.__rappTest.getMyId());
    pass(`peer A registered: ${idA}`);
    pass(`peer B registered: ${idB}`);

    heading("Step 3 — Open DataChannel A → B");
    // Fire the connect (synchronous startConnect — we poll status separately).
    await pageA.evaluate((id) => window.__rappTest.startConnect(id), idB);
    try {
      await waitFor(async () => {
        const sa = await pageA.evaluate(() => window.__rappTest.getStatus());
        const sb = await pageB.evaluate(() => window.__rappTest.getStatus());
        return sa === "connected" && sb === "connected";
      }, { timeoutMs: 30000, label: "DataChannel to open both sides" });
      pass("DataChannel open both sides (DTLS-encrypted P2P; broker drops out)");
    } catch (e) {
      const sa = await pageA.evaluate(() => window.__rappTest.getStatus());
      const sb = await pageB.evaluate(() => window.__rappTest.getStatus());
      const evA = await pageA.evaluate(() => window.__rappTest.getEvents());
      const evB = await pageB.evaluate(() => window.__rappTest.getEvents());
      const stA = await pageA.evaluate(() => window.__rappTest.getPeerState());
      const stB = await pageB.evaluate(() => window.__rappTest.getPeerState());
      note(`A status: "${sa}" | B status: "${sb}"`);
      note(`A peer state: ${JSON.stringify(stA)}`);
      note(`B peer state: ${JSON.stringify(stB)}`);
      note(`A events: ${JSON.stringify(evA, null, 0)}`);
      note(`B events: ${JSON.stringify(evB, null, 0)}`);
      throw e;
    }

    heading("Step 4 — Message A → B over the tether");
    const msgAtoB = `hello-from-A-${Date.now()}`;
    await pageA.evaluate((m) => window.__rappTest.send(m), msgAtoB);
    await waitFor(async () => {
      const msgs = await pageB.evaluate(() => window.__rappTest.getMessages());
      return msgs && msgs.includes(msgAtoB);
    }, { timeoutMs: 8000, label: `B to receive "${msgAtoB}"` });
    pass(`A → B: B received "${msgAtoB}"`);

    heading("Step 5 — Message B → A over the tether");
    const msgBtoA = `hello-from-B-${Date.now()}`;
    await pageB.evaluate((m) => window.__rappTest.send(m), msgBtoA);
    await waitFor(async () => {
      const msgs = await pageA.evaluate(() => window.__rappTest.getMessages());
      return msgs && msgs.includes(msgBtoA);
    }, { timeoutMs: 8000, label: `A to receive "${msgBtoA}"` });
    pass(`B → A: A received "${msgBtoA}"`);

    heading("Step 6 — Envelope shape includes rapp-tether/1.0 schema");
    const msgsB = await pageB.evaluate(() => window.__rappTest.getMessages());
    if (msgsB.includes("rapp-tether/1.0")) {
      pass("payload includes the rapp-tether/1.0 schema field");
    } else {
      fail("payload missing rapp-tether/1.0 schema");
    }

    exitCode = FAILED === 0 ? 0 : 1;
  } catch (err) {
    fail(`error during run: ${err.message}`);
  } finally {
    try { await browserA.close(); } catch {}
    try { await browserB.close(); } catch {}
    server.close();
  }

  const total = PASSED + FAILED;
  console.log(`\n${C.bold}${PASSED} passing, ${FAILED} failing${C.reset} (of ${total})`);
  if (FAILED > 0) process.exit(1);
  process.exit(0);
})().catch((err) => {
  console.error(`${C.red}fatal: ${err.message}${C.reset}`);
  process.exit(1);
});
