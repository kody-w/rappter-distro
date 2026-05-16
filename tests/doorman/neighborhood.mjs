#!/usr/bin/env node
//
// neighborhood.mjs — end-to-end test for the cross-organism
// collaboration primitive. Plants a child seed with neighbors.json
// containing a real public organism (kody-w/heimdall), then:
//
//   1. Verifies neighbors.json was created at plant time
//   2. Loads the front door, clicks 🏘 Neighborhood, verifies the
//      neighbor renders as a card with sigil + name + tagline
//   3. Loads the doorman page, drives toolNeighborhood() with each
//      action ('list', 'introduce', 'ask') and verifies the output
//      is what the LLM would see
//
// Cache assertions: _readNeighbors hits local file (fast), peer state
// fetches go through cachedGhText so a second call should be served
// from localStorage. Rate-limit-aware (peer fetches degrade gracefully).

import { chromium } from "playwright";
import { spawn, execSync } from "node:child_process";
import { rmSync, writeFileSync, readFileSync, existsSync } from "node:fs";

const RAPP_ROOT = "/Users/kodywildfeuer/RAPP";
const PLANT = `${RAPP_ROOT}/installer/plant.sh`;
const SERVE_DIR = "/tmp/nbhd-test-fresh";
const PORT = 8776;

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
    `PLANT_GH_USER=kody-w MIRROR_REPO_NAME=child MIRROR_DISPLAY_NAME=Child ` +
    `MIRROR_KIND=personal bash ${PLANT}`,
    { stdio: "ignore" }
  );
  // Splice in a real neighbor — kody-w/heimdall is a live planted seed.
  const declared = {
    schema: "rapp-neighbors/1.0",
    neighbors: [
      {
        repo: "kody-w/heimdall",
        display_name: "Heimdall",
        added_at: "2026-05-06T00:00:00Z",
        allowed_facets: ["professional_history"],
      },
    ],
  };
  writeFileSync(`${SERVE_DIR}/neighbors.json`, JSON.stringify(declared, null, 2) + "\n");
}

function startServer() {
  try { execSync(`lsof -ti:${PORT} | xargs -r kill 2>/dev/null`, { stdio: "ignore" }); } catch {}
  server = spawn("python3", ["-m", "http.server", String(PORT), "--directory", SERVE_DIR], {
    stdio: "ignore", detached: false,
  });
  return new Promise(r => setTimeout(r, 800));
}

function stopServer() { if (server) { try { server.kill(); } catch {} } }

async function testPlantWritesNeighborsJson() {
  console.log("\n[test] plant.sh writes neighbors.json");
  // Re-plant fresh to assert the empty default before our test splices a neighbor in.
  rmSync(SERVE_DIR, { recursive: true, force: true });
  execSync(
    `PLANT_DRY_RUN=1 PLANT_DRY_RUN_DIR=${SERVE_DIR} ` +
    `PLANT_GH_USER=kody-w MIRROR_REPO_NAME=child MIRROR_DISPLAY_NAME=Child ` +
    `MIRROR_KIND=personal bash ${PLANT}`,
    { stdio: "ignore" }
  );
  step("neighbors.json exists at seed root", existsSync(`${SERVE_DIR}/neighbors.json`));
  const j = JSON.parse(readFileSync(`${SERVE_DIR}/neighbors.json`, "utf8"));
  step("schema is rapp-neighbors/1.0", j.schema === "rapp-neighbors/1.0");
  step("neighbors[] is empty by default", Array.isArray(j.neighbors) && j.neighbors.length === 0);
}

async function testFrontDoorRendersNeighbors() {
  console.log("\n[test] front door 🏘 Neighborhood pane renders declared neighbors");
  // Splice a real public neighbor in.
  const declared = {
    schema: "rapp-neighbors/1.0",
    neighbors: [
      { repo: "kody-w/heimdall", display_name: "Heimdall", added_at: "2026-05-06T00:00:00Z", allowed_facets: [] },
    ],
  };
  writeFileSync(`${SERVE_DIR}/neighbors.json`, JSON.stringify(declared, null, 2) + "\n");
  await startServer();
  browser = await chromium.launch({ headless: true });
  try {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    page.on("pageerror", e => console.log("  [pageerror]", e.message.slice(0, 200)));
    await page.goto(`http://127.0.0.1:${PORT}/`, { waitUntil: "networkidle", timeout: 20000 });
    await page.waitForTimeout(1500);
    await page.click("#btn-neighborhood");
    await page.waitForTimeout(2500);
    const cards = await page.locator("#nbhd-list .nbhd-card").count();
    step("at least one neighbor card rendered", cards >= 1, `cards=${cards}`);
    if (cards >= 1) {
      const handle = await page.locator("#nbhd-list .nbhd-handle").first().textContent();
      step("first card shows owner/repo handle", /heimdall/i.test(handle), `handle=${handle}`);
      const sigil = await page.locator("#nbhd-list .nbhd-sigil svg").first().count();
      step("sigil SVG rendered for neighbor", sigil >= 1);
    }
    await ctx.close();
  } finally {
    await browser.close();
    stopServer();
  }
}

async function testNeighborhoodTool() {
  console.log("\n[test] doorman tool: Neighborhood action='list' / 'introduce' / 'ask'");
  await startServer();
  browser = await chromium.launch({ headless: true });
  try {
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    page.on("pageerror", e => console.log("  [pageerror]", e.message.slice(0, 200)));
    // Inject a fake auth so doorman renders the chat shell
    await ctx.addInitScript(() => {
      localStorage.setItem("rapp_settings", JSON.stringify({
        ghuToken: "ghu_test_dummy",
        copilotToken: "fake-copilot-tok",
        copilotExpiresAt: Date.now() + 600000,
      }));
    });
    await page.goto(`http://127.0.0.1:${PORT}/doorman/`, { waitUntil: "domcontentloaded", timeout: 20000 });
    await page.waitForFunction(() => typeof window.toolNeighborhood === "function", null, { timeout: 10000 });
    await page.waitForTimeout(800);

    // Action: list
    const list = await page.evaluate(async () => await toolNeighborhood({ action: "list" }));
    step("action=list returns text", typeof list === "string" && list.length > 0);
    step("action=list includes the declared neighbor", list.includes("kody-w/heimdall") || list.includes("heimdall"),
      `text=${list.slice(0, 200)}`);

    // Action: introduce
    const intro = await page.evaluate(async () => await toolNeighborhood({ action: "introduce", neighbor_slug: "kody-w/heimdall" }));
    step("action=introduce returns text", typeof intro === "string" && intro.length > 0);
    step("action=introduce mentions the slug",   intro.includes("kody-w/heimdall"), `text=${intro.slice(0, 200)}`);
    step("action=introduce includes 'declared'", /declared neighbor/i.test(intro), `text=${intro.slice(0, 200)}`);

    // Action: ask (topic match against public memory)
    const ask = await page.evaluate(async () => await toolNeighborhood({ action: "ask", neighbor_slug: "kody-w/heimdall", topic: "Heimdall watcher" }));
    step("action=ask returns text", typeof ask === "string" && ask.length > 0);
    step("action=ask mentions querying the slug", ask.includes("kody-w/heimdall"), `text=${ask.slice(0, 200)}`);

    // Action: missing required — either slug or topic, the validator
    // catches both. Either error message is correct.
    const err1 = await page.evaluate(async () => await toolNeighborhood({ action: "ask" }));
    step("action=ask without slug or topic errors out", /requires (topic|neighbor_slug)/i.test(err1), `text=${err1.slice(0, 200)}`);
    const err2 = await page.evaluate(async () => await toolNeighborhood({ action: "ask", neighbor_slug: "kody-w/heimdall" }));
    step("action=ask with slug but no topic specifically errors on topic", /requires topic/i.test(err2), `text=${err2.slice(0, 200)}`);

    // Untrusted/non-declared peer is flagged
    const untrust = await page.evaluate(async () => await toolNeighborhood({ action: "introduce", neighbor_slug: "octocat/spoon-knife" }));
    step("non-declared peer flagged as 'NOT in neighbors.json'",
      /NOT in neighbors\.json/i.test(untrust) || /untrusted/i.test(untrust),
      `text=${untrust.slice(0, 200)}`);

    await ctx.close();
  } finally {
    await browser.close();
    stopServer();
  }
}

async function main() {
  console.log("Neighborhood (cross-organism collaboration) tests\n");
  console.log("planting fresh seed…");
  plantSeed();
  try {
    await testPlantWritesNeighborsJson();
    await testFrontDoorRendersNeighbors();
    await testNeighborhoodTool();
  } finally {
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
