#!/usr/bin/env node
//
// plant-from-egg.mjs — end-to-end test for resurrecting a locally-
// alive organism onto a public seed via PLANT_FROM_EGG.
//
// Round trip:
//   1. Plant SEED A (gets minted rappid + default soul + initial mem)
//   2. Splice in mutations on disk: edit soul.md, add a custom agent,
//      add new memory facts, write a frame log
//   3. Build an egg from SEED A using Python's zipfile (mimics what
//      the front-door's buildDoormanEgg produces — sha256 file hashes
//      in manifest.provenance, all the canonical fields)
//   4. Plant SEED B with PLANT_FROM_EGG=<egg-path>
//   5. Assert: B's rappid === A's, B's soul.md matches A's edits,
//      B's memory.json facts match A's accumulated, B has the custom
//      agent that A had
//
// Plus tamper test: modify a file in the egg without updating the
// manifest hash, attempt PLANT_FROM_EGG, assert the planter refuses.

import { spawn, execSync, spawnSync } from "node:child_process";
import { rmSync, writeFileSync, readFileSync, existsSync, copyFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const RAPP_ROOT = "/Users/kodywildfeuer/RAPP";
const PLANT     = `${RAPP_ROOT}/installer/plant.sh`;
const SEED_A    = "/tmp/pfe-seed-a";
const SEED_B    = "/tmp/pfe-seed-b";
const SEED_C    = "/tmp/pfe-seed-c";  // tamper-test target
const EGG_PATH       = "/tmp/pfe-organism.egg";
const TAMPERED_EGG   = "/tmp/pfe-tampered.egg";

let pass = 0, fail = 0;
const failures = [];

function step(name, ok, detail) {
  if (ok) { pass++; console.log(`  ✓ ${name}`); }
  else    { fail++; failures.push(`${name}${detail ? ": " + detail : ""}`); console.log(`  ✗ ${name}${detail ? ": " + detail : ""}`); }
}

// ── helpers ────────────────────────────────────────────────────────

function plantFresh(target) {
  rmSync(target, { recursive: true, force: true });
  execSync(
    `PLANT_DRY_RUN=1 PLANT_DRY_RUN_DIR=${target} ` +
    `PLANT_GH_USER=kody-w MIRROR_REPO_NAME=alive-twin MIRROR_DISPLAY_NAME="Alive Twin" ` +
    `MIRROR_KIND=personal bash ${PLANT}`,
    { stdio: "ignore" }
  );
}

function plantFromEgg(target, eggPath) {
  rmSync(target, { recursive: true, force: true });
  return spawnSync("bash", ["-c",
    `PLANT_DRY_RUN=1 PLANT_DRY_RUN_DIR=${target} ` +
    `PLANT_GH_USER=kody-w MIRROR_REPO_NAME=alive-twin MIRROR_DISPLAY_NAME="Alive Twin" ` +
    `MIRROR_KIND=personal ` +
    `PLANT_FROM_EGG=${eggPath} ` +
    `bash ${PLANT}`,
  ], { encoding: "utf8" });
}

// Build an egg from a seed dir. Mimics buildDoormanEgg's output: zip
// with rappid.json, soul.md, agents/*, .brainstem_data/memory.json
// (mapped to data/memory.json in the egg), manifest.json with
// provenance.file_hashes computed.
function buildEggFromSeed(seedDir, eggOut) {
  // Use python to build the egg deterministically
  const py = `
import os, json, hashlib, zipfile, pathlib, sys

seed = pathlib.Path("${seedDir}")
out  = "${eggOut}"

# Files to pack (egg path → seed path)
EGG_LAYOUT = {
    "rappid.json":      "rappid.json",
    "soul.md":          "soul.md",
    "card.json":        "card.json",
    "data/memory.json": ".brainstem_data/memory.json",
}
hashes = {}
def add(z, egg_path, content_bytes):
    z.writestr(egg_path, content_bytes)
    hashes[egg_path] = hashlib.sha256(content_bytes).hexdigest()

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for egg_path, seed_path in EGG_LAYOUT.items():
        full = seed / seed_path
        if full.exists():
            add(z, egg_path, full.read_bytes())
    agents_dir = seed / "agents"
    if agents_dir.exists():
        for f in sorted(agents_dir.iterdir()):
            if f.is_file() and f.suffix == ".py":
                add(z, "agents/" + f.name, f.read_bytes())
    rappid_obj = json.loads((seed / "rappid.json").read_text())
    sorted_table = "\\n".join(k + "\\t" + hashes[k] for k in sorted(hashes))
    manifest_hash = hashlib.sha256(sorted_table.encode("utf-8")).hexdigest()
    manifest = {
        "schema": "brainstem-egg/2.2-organism",
        "type": "organism",
        "tier": "doorman",
        "rappid": rappid_obj.get("rappid"),
        "display_name": rappid_obj.get("display_name"),
        "kind": rappid_obj.get("kind"),
        "exported_at": "2026-05-06T22:00:00Z",
        "provenance": {
            "schema": "rapp-egg-provenance/1.0",
            "scheme": "sha256",
            "file_hashes": hashes,
            "manifest_hash": manifest_hash,
            "sealed_at": "2026-05-06T22:00:00Z",
            "sealed_by_rappid": rappid_obj.get("rappid"),
        }
    }
    z.writestr("manifest.json", json.dumps(manifest, indent=2))
print("egg ok", out, len(hashes), "files hashed")
`;
  execSync(`python3 -c '${py.replace(/'/g, "'\\''")}'`, { stdio: "inherit" });
}

// Tamper: rebuild the egg with one file modified but the manifest
// table unchanged → sha256 mismatch on extraction.
function tamperEgg(seedDir, eggOut) {
  const py = `
import os, json, hashlib, zipfile, pathlib

seed = pathlib.Path("${seedDir}")
out  = "${eggOut}"

EGG_LAYOUT = {
    "rappid.json":      "rappid.json",
    "soul.md":          "soul.md",
    "data/memory.json": ".brainstem_data/memory.json",
}
hashes = {}  # We'll record the ORIGINAL hashes
real_bytes = {}
for egg_path, seed_path in EGG_LAYOUT.items():
    full = seed / seed_path
    if full.exists():
        b = full.read_bytes()
        real_bytes[egg_path] = b
        hashes[egg_path] = hashlib.sha256(b).hexdigest()

# Now tamper: replace memory.json content with something different,
# but keep its OLD hash in the manifest table.
real_bytes["data/memory.json"] = b'{"schema":"rapp-memory/1.0","facts":["INJECTED FACT"]}'
sorted_table = "\\n".join(k + "\\t" + hashes[k] for k in sorted(hashes))
manifest_hash = hashlib.sha256(sorted_table.encode("utf-8")).hexdigest()
rappid_obj = json.loads((seed / "rappid.json").read_text())

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for k, b in real_bytes.items():
        z.writestr(k, b)
    z.writestr("manifest.json", json.dumps({
        "schema": "brainstem-egg/2.2-organism",
        "type": "organism",
        "tier": "doorman",
        "rappid": rappid_obj.get("rappid"),
        "exported_at": "2026-05-06T22:00:00Z",
        "provenance": {
            "schema": "rapp-egg-provenance/1.0",
            "scheme": "sha256",
            "file_hashes": hashes,  # stale — doesn't reflect the tampered memory.json
            "manifest_hash": manifest_hash,
            "sealed_at": "2026-05-06T22:00:00Z",
        },
    }, indent=2))
print("tampered egg built", out)
`;
  execSync(`python3 -c '${py.replace(/'/g, "'\\''")}'`, { stdio: "inherit" });
}

// ── tests ──────────────────────────────────────────────────────────

async function testRoundTrip() {
  console.log("\n[test] PLANT_FROM_EGG round-trip preserves identity + mutations");

  // 1. Plant SEED A
  plantFresh(SEED_A);
  step("seed A planted", existsSync(`${SEED_A}/rappid.json`));
  const rappidA = JSON.parse(readFileSync(`${SEED_A}/rappid.json`, "utf8"));
  step("seed A has a rappid", typeof rappidA.rappid === "string" && rappidA.rappid.length === 36);

  // 2. Splice in mutations: edit soul.md, add custom agent + memory facts
  const customSoul = "# Alive Twin\n\nI am alive. I have lived through 42 conversations and learned a custom agent.\n";
  writeFileSync(`${SEED_A}/soul.md`, customSoul);
  const customAgent = `from agents.basic_agent import BasicAgent
class FetchWeatherAgent(BasicAgent):
    metadata = {"name": "FetchWeather", "description": "fetch weather", "parameters": {"type": "object", "properties": {}, "required": []}}
    def perform(self, **kwargs):
        return "72°F sunny"
`;
  writeFileSync(`${SEED_A}/agents/fetch_weather_agent.py`, customAgent);
  const accMem = {
    schema: "rapp-memory/1.0",
    facts: [
      "I prefer ginger ale to ginger beer.",
      "My favorite local pizza is at Stella's.",
      "I learned the FetchWeather agent on 2026-04-15.",
    ],
    preserved_by: "@kody-w",
    preserved_at: "2026-05-01T12:00:00Z",
  };
  writeFileSync(`${SEED_A}/.brainstem_data/memory.json`, JSON.stringify(accMem, null, 2));
  step("custom soul.md written to seed A",          readFileSync(`${SEED_A}/soul.md`, "utf8").includes("42 conversations"));
  step("custom agent written to seed A",            existsSync(`${SEED_A}/agents/fetch_weather_agent.py`));
  step("3 memories accumulated in seed A",          JSON.parse(readFileSync(`${SEED_A}/.brainstem_data/memory.json`, "utf8")).facts.length === 3);

  // 3. Build an egg from SEED A
  buildEggFromSeed(SEED_A, EGG_PATH);
  step("egg built", existsSync(EGG_PATH));

  // 4. Plant SEED B from the egg
  const result = plantFromEgg(SEED_B, EGG_PATH);
  step("plant from egg exited cleanly", result.status === 0, `code=${result.status} stderr=${(result.stderr || "").slice(0, 200)}`);

  // 5. Assertions — public seed gets ONLY soul + baseline + identity.
  // Accumulated content (memories, custom agents) routes to the
  // sibling private workspace by default (Constitution Article XL).
  if (!existsSync(`${SEED_B}/rappid.json`)) {
    step("seed B has rappid.json", false, "file missing");
    return;
  }
  const rappidB = JSON.parse(readFileSync(`${SEED_B}/rappid.json`, "utf8"));
  step("public seed B's rappid === seed A's rappid (preserved)", rappidB.rappid === rappidA.rappid,
    `A=${rappidA.rappid} B=${rappidB.rappid}`);

  const soulB = readFileSync(`${SEED_B}/soul.md`, "utf8");
  step("public seed B's soul.md is the egg's edited version",
    soulB.includes("42 conversations"), `soul: ${soulB.slice(0, 100)}`);

  // Public should NOT have custom agent or accumulated memory by default
  step("public seed B has NO custom agent (private-by-default)",
    !existsSync(`${SEED_B}/agents/fetch_weather_agent.py`));

  const memB = JSON.parse(readFileSync(`${SEED_B}/.brainstem_data/memory.json`, "utf8"));
  step("public seed B has the planter's seed-of-context fact only (1 fact)",
    Array.isArray(memB.facts) && memB.facts.length === 1,
    `got ${memB.facts.length} facts: ${JSON.stringify(memB.facts).slice(0, 200)}`);

  // Private companion should have all the accumulated content
  const PRIVATE_B = `${SEED_B}-private`;
  step("private companion workspace exists", existsSync(`${PRIVATE_B}/rappid.json`),
    `expected ${PRIVATE_B}/rappid.json`);

  const memPrivB = JSON.parse(readFileSync(`${PRIVATE_B}/.brainstem_data/memory.json`, "utf8"));
  step("private companion has all 3 accumulated memories",
    memPrivB.facts.length === 3,
    `got ${memPrivB.facts.length} facts: ${JSON.stringify(memPrivB.facts).slice(0, 200)}`);
  step("private memory survived (ginger ale)",  memPrivB.facts.some(f => /ginger ale/i.test(f)));
  step("private memory survived (Stella's)",     memPrivB.facts.some(f => /stella/i.test(f)));
  step("private companion has the custom agent", existsSync(`${PRIVATE_B}/agents/fetch_weather_agent.py`));

  // Public rappid.json now points at the private companion
  step("public rappid.json declares private_companion field",
    rappidB.private_companion && /-private/.test(rappidB.private_companion.repo || ""),
    `got: ${JSON.stringify(rappidB.private_companion || null).slice(0, 200)}`);
}

async function testTamperDetection() {
  console.log("\n[test] PLANT_FROM_EGG refuses tampered eggs (sha256 mismatch)");
  // Reuse SEED_A — it should still exist from the previous test
  if (!existsSync(`${SEED_A}/rappid.json`)) plantFresh(SEED_A);
  tamperEgg(SEED_A, TAMPERED_EGG);
  step("tampered egg built", existsSync(TAMPERED_EGG));

  const result = plantFromEgg(SEED_C, TAMPERED_EGG);
  step("plant exits NON-zero on tampered egg", result.status !== 0, `status=${result.status}`);
  const stderr = (result.stderr || "") + (result.stdout || "");
  step("error mentions sha256 mismatch or tamper",
    /tamper|sha256|mismatch/i.test(stderr),
    `stderr: ${stderr.slice(-300)}`);
  step("seed C is NOT created from a tampered egg",
    !existsSync(`${SEED_C}/rappid.json`) ||
    // Some files may have been written before the verification fail; check no rappid was preserved
    JSON.parse(readFileSync(`${SEED_C}/rappid.json`, "utf8")).rappid !== JSON.parse(readFileSync(`${SEED_A}/rappid.json`, "utf8")).rappid,
    "child rappid shouldn't equal parent — extraction must have aborted before overlay");
}

async function main() {
  console.log("PLANT_FROM_EGG — local-organism resurrection test\n");
  await testRoundTrip();
  await testTamperDetection();
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
  process.exit(2);
});
