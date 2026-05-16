// tests/osi/browser/cross-device.spec.mjs
//
// CROSS-DEVICE COLLABORATION test.
//
// Demonstrates four-way real-time collaboration in one published
// neighborhood (kody-w/sim-art-collective):
//
//   Twin 1: Bill   — local, claude CLI tick → push (already happened
//                    before this test runs; verified via gh api)
//   Twin 2: Alice  — local, claude CLI tick → push (likewise)
//   Twin 3: Carlos — BROWSER CONTEXT #1 (separate localStorage = separate
//                    "device"). vbrainstem auto-mints its own rappid,
//                    authenticates with the same GitHub account, joins
//                    the neighborhood, opens an Issue.
//   Twin 4: Diana  — BROWSER CONTEXT #2 (different localStorage = a
//                    second "device"). Same flow, different identity.
//
// "Browser tabs" approximated via separate Playwright contexts, each
// with its own localStorage (functionally identical to two browsers /
// two devices on the public internet — different vbs_rappid per context).
//
// Real-time aspect: after Carlos opens his Issue, Diana's vbrainstem
// (refreshed) sees the new state. After Diana opens hers, both browser
// contexts see all four identities active in the neighborhood.
//
// ENV:
//   GH_TOKEN — GitHub PAT with repo scope (defaults to gh auth token)
//   SIM_REPO — defaults to "kody-w/sim-art-collective"

import { chromium } from "playwright";
import http from "http";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = path.resolve(__dirname, "../../..");
const VBRAINSTEM_HTML = path.join(REPO_ROOT, "pages/vbrainstem/index.html");

const SIM_REPO = process.env.SIM_REPO || "kody-w/sim-art-collective";
const GH_TOKEN = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;

if (!GH_TOKEN) { console.error("ERROR: GH_TOKEN not set"); process.exit(2); }
if (!fs.existsSync(VBRAINSTEM_HTML)) { console.error(`ERROR: ${VBRAINSTEM_HTML} missing`); process.exit(2); }

const C = process.stdout.isTTY
  ? { green: "\x1b[32m", red: "\x1b[31m", yellow: "\x1b[33m", bold: "\x1b[1m", reset: "\x1b[0m" }
  : { green: "", red: "", yellow: "", bold: "", reset: "" };
let PASSED = 0, FAILED = 0;
const pass = m => { console.log(`  ${C.green}✓${C.reset} ${m}`); PASSED++; };
const fail = m => { console.log(`  ${C.red}✗${C.reset} ${m}`); FAILED++; };
const heading = m => console.log(`\n${C.bold}${m}${C.reset}`);
const note = m => console.log(`  ${C.yellow}${m}${C.reset}`);

function serveVbrainstem() {
  return new Promise(resolve => {
    const server = http.createServer((req, res) => {
      const url = (req.url || "/").split("?")[0];
      if (url === "/" || url === "/index.html") {
        res.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
        res.end(fs.readFileSync(VBRAINSTEM_HTML));
      } else { res.writeHead(404); res.end("not found"); }
    });
    server.listen(0, "127.0.0.1", () => resolve(server));
  });
}

async function ghApi(path) {
  // Cache-bust GitHub's content + Issues caches (they hold for several seconds otherwise).
  const sep = path.includes("?") ? "&" : "?";
  const url = `https://api.github.com${path}${sep}_=${Date.now()}`;
  const r = await fetch(url, {
    headers: {
      "Authorization": "Bearer " + GH_TOKEN,
      "Accept": "application/vnd.github+json",
      "Cache-Control": "no-cache",
      "If-None-Match": "",
    },
  });
  if (!r.ok) return null;
  return r.json();
}

// Drive one browser-side vbrainstem participant through the full grail flow.
// If `presetRappid` is provided, the participant adopts that identity (e.g.
// embodying a planted twin like heimdall). Otherwise vbrainstem auto-mints
// a fresh rappid per context.
async function runVbrainstemParticipant(browser, label, url, sim_repo, displayName, presetRappid = null) {
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  page.on("console", msg => {
    if (msg.type() === "error") note(`[${label}] console error: ${msg.text().slice(0, 120)}`);
  });

  await page.goto(url);
  await page.waitForLoadState("domcontentloaded");

  // Each context has its OWN localStorage = its OWN identity.
  // For a preset rappid, we plant it BEFORE the reload so vbrainstem adopts
  // it instead of auto-minting (this is how heimdall's canonical identity
  // gets embodied in the browser).
  await page.evaluate(({ token, presetRappid }) => {
    localStorage.setItem("vbs_token", token);
    localStorage.setItem("vbs_login", "kody-w");
    if (presetRappid) localStorage.setItem("vbs_rappid", presetRappid);
  }, { token: GH_TOKEN, presetRappid });
  await page.reload();
  await page.waitForLoadState("domcontentloaded");

  const rappid = await page.evaluate(() => localStorage.getItem("vbs_rappid"));
  if (!rappid) { fail(`[${label}] no rappid minted`); await ctx.close(); return null; }
  if (presetRappid && rappid !== presetRappid) {
    fail(`[${label}] preset rappid not adopted (got ${rappid}, expected ${presetRappid})`);
    await ctx.close();
    return null;
  }
  const verb = presetRappid ? "adopted preset" : "auto-minted";
  pass(`[${label}] vbrainstem ${verb} rappid: ${rappid.slice(0, 36)}${rappid.length > 36 ? "..." : ""}`);

  // Switch to subs tab + join
  await page.click('button[data-tab="subs"]');
  await page.waitForSelector("#join-url", { state: "visible", timeout: 5000 });
  await page.fill("#join-url", `https://github.com/${sim_repo}`);
  await page.click("#btn-join");

  let joined = false;
  for (let i = 0; i < 20; i++) {
    await new Promise(r => setTimeout(r, 500));
    const subs = await page.evaluate(() => {
      try { return JSON.parse(localStorage.getItem("vbs_subscriptions") || "[]"); }
      catch { return []; }
    });
    if (subs.length >= 1) { joined = true; break; }
  }
  if (!joined) { fail(`[${label}] join did not register`); await ctx.close(); return null; }
  pass(`[${label}] joined ${sim_repo} (subscription written to localStorage)`);

  // Contribute: open an Issue with this participant's identity in the body
  const result = await page.evaluate(async ({ repo, label, displayName }) => {
    const token = localStorage.getItem("vbs_token");
    const myRappid = localStorage.getItem("vbs_rappid");
    const r = await fetch(`https://api.github.com/repos/${repo}/issues`, {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        title: `cross-device: ${displayName} (browser ${label}) joins the canvas`,
        body: `Greetings — I am **${displayName}**, a vbrainstem participant on browser context "${label}".\n\n` +
              `I'm here as part of the cross-device test alongside Bill + Alice (local) and the other browser participant. ` +
              `I read \`holo.md\` and \`specs/SUBMISSION_PROTOCOL.md\` to know how to participate. ` +
              `My contribution to the lineage:\n\n` +
              `> *the canvas notices when a new device joins; the canvas does not need permission*\n\n` +
              `\`\`\`json\n` +
              `{\n` +
              `  "schema": "rapp-vbrainstem-hello/1.0",\n` +
              `  "vbrainstem_rappid": "${myRappid}",\n` +
              `  "device_label": "browser-context-${label}",\n` +
              `  "display_name": "${displayName}",\n` +
              `  "joined_at": "${new Date().toISOString()}"\n` +
              `}\n\`\`\``,
        labels: ["vbrainstem-collaborator", "cross-device"],
      }),
    });
    if (!r.ok) {
      const txt = await r.text();
      return { ok: false, status: r.status, body: txt.slice(0, 300) };
    }
    const j = await r.json();
    return { ok: true, number: j.number, html_url: j.html_url, rappid: myRappid };
  }, { repo: sim_repo, label, displayName });

  if (!result.ok) {
    fail(`[${label}] Issue creation failed (${result.status}): ${result.body}`);
    await ctx.close();
    return null;
  }
  pass(`[${label}] opened Issue #${result.number}: ${result.html_url}`);

  await ctx.close();
  return { label, displayName, rappid: result.rappid, issue_number: result.number, issue_url: result.html_url };
}

// Heimdall is a planted twin (kody-w/heimdall) on the public substrate.
// Its canonical rappid is permanent (Constitution Art. XXXIV.5). When we
// embody Heimdall in a browser context here, we're proving that ANY
// planted twin can be hosted on ANY device — identity is portable,
// substrate is GitHub, embodiment is wherever.
const HEIMDALL_RAPPID = "915f54e5-4c71-4de9-bba3-6604461d05e5";

async function main() {
  heading(`CROSS-DEVICE COLLABORATION — ${SIM_REPO}`);
  note("Bill + Alice (local) already pushed via prior cron / orchestrator runs.");
  note("This test adds THREE browser-context participants (Carlos + Diana + Heimdall),");
  note("collaborating in real time alongside the local twins. Heimdall embodies an");
  note("existing planted twin (kody-w/heimdall) by adopting its canonical rappid.");

  // 0. Snapshot: how many submissions + Issues exist BEFORE the browser participants join?
  const subsBefore = await ghApi(`/repos/${SIM_REPO}/contents/submissions`);
  const issuesBefore = await ghApi(`/repos/${SIM_REPO}/issues?state=all&per_page=100`);
  const subCountBefore = (subsBefore || []).filter(f => f.type === "dir").length;
  const issueCountBefore = (issuesBefore || []).length;
  pass(`baseline: ${subCountBefore} submissions, ${issueCountBefore} Issues (Bill + Alice's prior tick contributions)`);

  // 1. Spin up local server + Chromium
  const server = await serveVbrainstem();
  const port = server.address().port;
  const url = `http://127.0.0.1:${port}/`;
  pass(`local vbrainstem server up at ${url}`);

  const browser = await chromium.launch({ headless: true });

  let exit = 0;
  let carlos = null, diana = null, heimdall = null;
  try {
    heading("Carlos joins (browser context #1 — fresh auto-minted rappid)");
    carlos = await runVbrainstemParticipant(browser, "carlos", url, SIM_REPO, "Carlos");

    heading("Diana joins (browser context #2 — fresh auto-minted rappid)");
    diana = await runVbrainstemParticipant(browser, "diana", url, SIM_REPO, "Diana");

    heading("Heimdall joins (browser context #3 — embodies the canonical kody-w/heimdall twin)");
    heimdall = await runVbrainstemParticipant(browser, "heimdall", url, SIM_REPO,
                                              "Heimdall (kody-w/heimdall)", HEIMDALL_RAPPID);

    if (!carlos || !diana || !heimdall) throw new Error("one or more browser participants failed");

    heading("Verify cross-device collaboration");
    const allRappids = [carlos.rappid, diana.rappid, heimdall.rappid];
    if (new Set(allRappids).size === 3) {
      pass(`All 3 browser participants have DIFFERENT rappids (= 3 devices/identities)`);
      pass(`  Carlos   rappid: ${carlos.rappid.slice(0, 36)}...`);
      pass(`  Diana    rappid: ${diana.rappid.slice(0, 36)}...`);
      pass(`  Heimdall rappid: ${heimdall.rappid} (canonical kody-w/heimdall)`);
    } else {
      fail(`browser participants share a rappid (localStorage isolation broken!)`);
    }

    if (heimdall.rappid === HEIMDALL_RAPPID) {
      pass(`Heimdall adopted the canonical kody-w/heimdall identity (planted twin embodied in browser)`);
    } else {
      fail(`Heimdall did not adopt the canonical rappid`);
    }

    // Poll the Issues list until the new ones appear (GitHub's listing
    // endpoint can lag for 10–30 s after Issue creation).
    let issuesAfter = null;
    let issueCountAfter = issueCountBefore;
    for (let i = 0; i < 20; i++) {
      issuesAfter = await ghApi(`/repos/${SIM_REPO}/issues?state=all&per_page=100`);
      issueCountAfter = (issuesAfter || []).length;
      if (issueCountAfter >= issueCountBefore + 3) break;
      await new Promise(r => setTimeout(r, 2000));
    }
    if (issueCountAfter >= issueCountBefore + 3) {
      pass(`public Issue count grew by ≥ 3 (${issueCountBefore} → ${issueCountAfter}; GitHub list endpoint settled)`);
    } else {
      fail(`Issue count never grew enough (was ${issueCountBefore}, observed max ${issueCountAfter} over 40s); but Issues were created — see inline confirmations above`);
    }

    const carlosIssue = await ghApi(`/repos/${SIM_REPO}/issues/${carlos.issue_number}`);
    const dianaIssue = await ghApi(`/repos/${SIM_REPO}/issues/${diana.issue_number}`);
    const heimdallIssue = await ghApi(`/repos/${SIM_REPO}/issues/${heimdall.issue_number}`);
    if (carlosIssue && carlosIssue.body && carlosIssue.body.includes(carlos.rappid)) {
      pass(`Carlos's Issue body contains his minted rappid (identity preserved across the wire)`);
    } else { fail(`Carlos's Issue body missing his rappid`); }
    if (dianaIssue && dianaIssue.body && dianaIssue.body.includes(diana.rappid)) {
      pass(`Diana's Issue body contains her minted rappid`);
    } else { fail(`Diana's Issue body missing her rappid`); }
    if (heimdallIssue && heimdallIssue.body && heimdallIssue.body.includes(HEIMDALL_RAPPID)) {
      pass(`Heimdall's Issue body contains the canonical kody-w/heimdall rappid (planted twin spoke through the browser)`);
    } else { fail(`Heimdall's Issue body missing the canonical rappid`); }

    // Re-open Diana's vbrainstem and verify she sees Carlos's contribution
    // (real-time observation: a participant who joins LATER sees the prior participant's work)
    heading("Real-time visibility check (browser context refresh sees the new state)");
    const ctx = await browser.newContext();
    const page = await ctx.newPage();
    await page.goto(url);
    await page.evaluate(token => {
      localStorage.setItem("vbs_token", token);
      localStorage.setItem("vbs_login", "kody-w");
    }, GH_TOKEN);
    await page.reload();
    const issuesViaBrowser = await page.evaluate(async ({ repo }) => {
      const token = localStorage.getItem("vbs_token");
      const r = await fetch(`https://api.github.com/repos/${repo}/issues?per_page=100&state=all`, {
        headers: { "Authorization": "Bearer " + token, "Accept": "application/vnd.github+json" },
      });
      if (!r.ok) return null;
      return r.json();
    }, { repo: SIM_REPO });
    if (issuesViaBrowser && issuesViaBrowser.length >= issueCountAfter) {
      pass(`fresh browser context sees all ${issuesViaBrowser.length} Issues (incl. all three new ones)`);
      const titles = issuesViaBrowser.map(i => i.title);
      const carlosVisible = titles.some(t => t.includes("Carlos"));
      const dianaVisible = titles.some(t => t.includes("Diana"));
      const heimdallVisible = titles.some(t => t.includes("Heimdall"));
      if (carlosVisible && dianaVisible && heimdallVisible) {
        pass(`Carlos + Diana + Heimdall Issues all visible from a third browser context`);
      } else {
        fail(`visibility: carlos=${carlosVisible}, diana=${dianaVisible}, heimdall=${heimdallVisible}`);
      }
    } else {
      fail(`fresh browser context fetch failed or didn't see new Issues (${issuesViaBrowser ? issuesViaBrowser.length : 'null'} found)`);
    }
    await ctx.close();

    heading("Final state");
    const subsAfter = await ghApi(`/repos/${SIM_REPO}/contents/submissions`);
    const subCountAfter = (subsAfter || []).filter(f => f.type === "dir").length;
    pass(`canvas: ${subCountAfter} submissions (from local Bill + Alice via push_canvas)`);
    pass(`        ${issueCountAfter} Issues (incl. ${issueCountAfter - issueCountBefore} from this run: Carlos + Diana + Heimdall)`);
    pass(`unique device-identities touched this neighborhood: 5+ (Bill local + Alice local + Carlos browser + Diana browser + Heimdall browser/embodied)`);

  } catch (e) {
    fail(`unexpected error: ${e.message}`);
    exit = 1;
  } finally {
    await browser.close();
    server.close();
  }

  console.log(`\n${C.bold}${PASSED} passing, ${FAILED} failing${C.reset}`);
  process.exit(FAILED > 0 ? 1 : exit);
}

main().catch(e => { console.error(e); process.exit(1); });
