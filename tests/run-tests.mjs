#!/usr/bin/env node
/* tests/run-tests.mjs — Node test runner for the rapp.js core lib.
 *
 * Loads rapp_brainstem/utils/web/rapp.js into a synthetic global, then asserts the
 * RAPP v1 contract: agent parsing, manifest extraction, seed math,
 * mnemonic round-trips, card mint, card↔agent.py round-trips, binder
 * import/export.
 *
 * Run:   node tests/run-tests.mjs
 *
 * No deps. Web Crypto comes via the built-in `crypto.webcrypto` global
 * on Node 18+ — we polyfill globalThis.crypto if needed.
 */

import fs from 'node:fs';
import path from 'node:path';
import { webcrypto } from 'node:crypto';
import { fileURLToPath } from 'node:url';

if (typeof globalThis.crypto === 'undefined') globalThis.crypto = webcrypto;

const __filename = fileURLToPath(import.meta.url);
const __dirname  = path.dirname(__filename);
const ROOT = path.resolve(__dirname, '..');

// Load rapp.js into the global scope (it's an IIFE that attaches to `window`).
const rappSource = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'utils', 'web', 'rapp.js'), 'utf8');
// Provide a `window` so the IIFE can attach.
globalThis.window = globalThis;
new Function(rappSource).call(globalThis);
const RAPP = globalThis.RAPP;
if (!RAPP) {
  console.error('FAIL: RAPP global not present after loading rapp.js');
  process.exit(1);
}

/* ───── tiny test harness ─────────────────────────────────────── */
let pass = 0, fail = 0;
const failures = [];
function eq(a, b) { return JSON.stringify(a) === JSON.stringify(b); }
function test(name, fn) {
  return Promise.resolve().then(fn).then(() => {
    pass++; process.stdout.write(`  \x1b[32m✓\x1b[0m ${name}\n`);
  }).catch(err => {
    fail++; failures.push({ name, err });
    process.stdout.write(`  \x1b[31m✗\x1b[0m ${name}\n    ${err.message}\n`);
  });
}
function assert(cond, msg) { if (!cond) throw new Error(msg || 'assertion failed'); }
function assertEq(a, b, msg) { if (!eq(a, b)) throw new Error(`${msg || 'not equal'}\n    expected ${JSON.stringify(b)}\n    got      ${JSON.stringify(a)}`); }

const STARTER_FILES = ['manage_memory_agent.py','context_memory_agent.py','hacker_news_agent.py'];

(async () => {
  console.log('\n\x1b[1mRAPP v1 contract tests\x1b[0m\n');

  /* ───── Suite 1: seed + mnemonic ────────────────────────────── */
  console.log('Seed & mnemonic');

  await test('seedHash is deterministic', () => {
    const a = RAPP.Seed.seedHash('hello');
    const b = RAPP.Seed.seedHash('hello');
    assertEq(a, b);
  });

  await test('seedHash differs for different input', () => {
    assert(RAPP.Seed.seedHash('a') !== RAPP.Seed.seedHash('b'));
  });

  await test('forgeSeed produces a 64-bit BigInt', () => {
    const s = RAPP.Seed.forgeSeed('@x/foo', 'core', 'community', ['a','b'], []);
    assert(typeof s === 'bigint', 'not a bigint');
    assert(s >= 0n && s < (1n << 64n), 'out of range');
  });

  await test('resolveCardFromSeed yields stable card', () => {
    const s = RAPP.Seed.forgeSeed('@x/foo', 'core', 'community', ['a','b'], []);
    const c1 = RAPP.Seed.resolveCardFromSeed(s);
    const c2 = RAPP.Seed.resolveCardFromSeed(s);
    assertEq(c1, c2);
  });

  await test('mnemonic round-trips a 64-bit seed', () => {
    const s = RAPP.Seed.forgeSeed('@y/bar', 'pipeline', 'verified', ['data','pipeline','x'], ['z']);
    const words = RAPP.Mnemonic.seedToWords(s);
    const back = RAPP.Mnemonic.wordsToSeed(words);
    assertEq(back.toString(), s.toString(), 'seed → words → seed');
    assertEq(words.split(' ').length, 7, 'must be exactly 7 words');
  });

  await test('mnemonic wordlist is exactly 1024 words', () => {
    assertEq(RAPP.Mnemonic.MNEMONIC_WORDS.length, 1024);
  });

  await test('wordsToSeed rejects bad word', () => {
    let threw = false;
    try { RAPP.Mnemonic.wordsToSeed('NOTAWORD ANVIL BLADE RUNE SHARD SMELT TEMPER'); }
    catch (e) { threw = true; }
    assert(threw, 'should reject unknown word');
  });

  /* ───── Suite 2: agent source parsing ───────────────────────── */
  console.log('\nAgent source parsing');

  for (const f of STARTER_FILES) {
    const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', f), 'utf8');
    await test(`parse ${f} — class + name + manifest`, () => {
      const p = RAPP.Agent.parseAgentSource(src, f);
      assert(p.hasBasicAgent, 'extends BasicAgent');
      assert(p.hasPerform, 'has perform()');
      assert(p.hasManifest, 'has __manifest__');
      assert(p.className && /Agent$/.test(p.className), `class ends with Agent (got ${p.className})`);
      assert(p.name, 'self.name extracted');
      assert(p.manifest && typeof p.manifest === 'object', 'manifest parsed to object');
      assertEq(p.manifest.schema, 'rapp-agent/1.0', 'schema field');
      assert(p.manifest.name && p.manifest.name.startsWith('@'), 'package name @publisher/slug');
    });
  }

  await test('parse agent without manifest still surfaces class/name', () => {
    const src = `from agents.basic_agent import BasicAgent
class TinyAgent(BasicAgent):
    def __init__(self):
        self.name = 'Tiny'
        self.metadata = {"name": self.name, "description": "tiny", "parameters": {"type": "object", "properties": {}, "required": []}}
        super().__init__(name=self.name, metadata=self.metadata)
    def perform(self, **kwargs):
        return "ok"
`;
    const p = RAPP.Agent.parseAgentSource(src, 'tiny_agent.py');
    assert(p.hasBasicAgent && p.hasPerform);
    assertEq(p.className, 'TinyAgent');
    assertEq(p.name, 'Tiny');
    assert(!p.hasManifest, 'no manifest expected');
  });

  /* ───── Suite 3: card mint + round-trip ─────────────────────── */
  console.log('\nCard mint & round-trip');

  for (const f of STARTER_FILES) {
    const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', f), 'utf8');
    await test(`mint card from ${f}`, async () => {
      const c = await RAPP.Card.mintCard(src, f);
      assertEq(c.schema, 'rapp-card/1.0');
      assertEq(c.filename, f);
      assertEq(c.source, src, 'source stored verbatim');
      assert(c.sha256.length === 64, 'sha256 hex');
      assert(c.card && c.card.seed, 'card has seed');
      assertEq(typeof c.card.incantation, 'string');
      assertEq(c.card.incantation.split(' ').length, 7);
      assert(Array.isArray(c.card.types) && c.card.types.length >= 1, 'types[]');
      assert(c.card.stats.hp >= 10 && c.card.stats.hp <= 100, 'stats in range');
    });

    await test(`card ↔ agent.py round-trip preserves source bytewise (${f})`, async () => {
      const c = await RAPP.Card.mintCard(src, f);
      const back = await RAPP.Card.cardToAgentSource(c);
      assertEq(back.filename, f);
      assertEq(back.source, src);
    });
  }

  await test('card SHA-256 mismatch is detected', async () => {
    const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', 'manage_memory_agent.py'), 'utf8');
    const c = await RAPP.Card.mintCard(src, 'manage_memory_agent.py');
    c.source = c.source + '\n# tampered\n';   // mutate but keep stale sha256
    let threw = false;
    try { await RAPP.Card.cardToAgentSource(c); } catch (e) { threw = true; }
    assert(threw, 'should reject sha mismatch');
  });

  /* ───── Suite 4: binder import/export ───────────────────────── */
  console.log('\nBinder import/export');

  await test('binder round-trips through JSON', async () => {
    const b = RAPP.Binder.empty('@test/me');
    for (const f of STARTER_FILES) {
      const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', f), 'utf8');
      const c = await RAPP.Card.mintCard(src, f);
      RAPP.Binder.addCard(b, c);
    }
    assertEq(b.cards.length, STARTER_FILES.length);
    const json = JSON.stringify(b);
    const back = JSON.parse(json);
    assertEq(back.schema, 'rapp-binder/1.0');
    assertEq(back.cards.length, STARTER_FILES.length);
    for (const c of back.cards) {
      const a = await RAPP.Card.cardToAgentSource(c);
      assert(a.source.length > 0);
    }
  });

  await test('binder addCard is idempotent for same filename', async () => {
    const b = RAPP.Binder.empty();
    const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', 'manage_memory_agent.py'), 'utf8');
    const c1 = await RAPP.Card.mintCard(src, 'manage_memory_agent.py');
    RAPP.Binder.addCard(b, c1);
    RAPP.Binder.addCard(b, c1);
    assertEq(b.cards.length, 1);
  });

  await test('binder removeCard works by predicate', async () => {
    const b = RAPP.Binder.empty();
    const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', 'manage_memory_agent.py'), 'utf8');
    const c = await RAPP.Card.mintCard(src, 'manage_memory_agent.py');
    RAPP.Binder.addCard(b, c);
    RAPP.Binder.removeCard(b, x => x.filename === 'manage_memory_agent.py');
    assertEq(b.cards.length, 0);
  });

  /* ───── Suite 5: SPEC.md tier-1 contract checks ─────────────── */
  console.log('\nSPEC §5 contract');

  for (const f of STARTER_FILES) {
    await test(`${f} satisfies §5 (BasicAgent + name + metadata + perform)`, () => {
      const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', f), 'utf8');
      const p = RAPP.Agent.parseAgentSource(src, f);
      assert(p.hasBasicAgent, 'extends BasicAgent');
      assert(p.name, 'self.name set');
      assert(p.parameters && p.parameters.type === 'object', 'parameters JSON schema');
      assert(p.hasPerform, 'has perform()');
    });
  }

  await test('pages/docs/SPEC.md exists and is non-empty', () => {
    const s = fs.readFileSync(path.join(ROOT, 'pages', 'docs', 'SPEC.md'), 'utf8');
    assert(s.length > 1000, 'pages/docs/SPEC.md content present');
    assert(s.includes('rapp-agent/1.0'), 'SPEC mentions schema tag');
  });

  /* ───── Suite 6: HTTP shape (SPEC §8) — frontend mock ───────── */
  console.log('\nSPEC §8 chat envelope');

  await test('chat request/response shapes match §8', () => {
    // Static check: ensure rapp_brainstem/utils/web/index.html declares the §8 contract.
    const html = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'utils', 'web', 'index.html'), 'utf8');
    assert(html.includes('user_input'), 'request includes user_input');
    assert(html.includes('conversation_history'), 'request includes conversation_history');
    assert(html.includes('session_id'), 'request includes session_id');
  });

  /* ───── Suite 7: pythonDictToJson edge cases ────────────────── */
  console.log('\npythonDictToJson edge cases');

  await test('parses single-quoted strings', () => {
    const x = RAPP.Agent.pythonDictToJson("{'a': 'hello', 'b': 1, 'c': True, 'd': None, 'e': [1, 2]}");
    assertEq(x.a, 'hello'); assertEq(x.b, 1); assertEq(x.c, true); assertEq(x.d, null); assertEq(x.e, [1,2]);
  });

  await test('handles escaped quote inside single-quoted string', () => {
    const x = RAPP.Agent.pythonDictToJson(`{'msg': 'don\\'t worry'}`);
    assert(x && typeof x.msg === 'string', 'parsed');
  });

  await test('strips trailing commas', () => {
    const x = RAPP.Agent.pythonDictToJson(`{"a": [1, 2, 3,], "b": {"c": 1,},}`);
    assertEq(x.a, [1,2,3]); assertEq(x.b.c, 1);
  });

  await test('strips Python comments', () => {
    const x = RAPP.Agent.pythonDictToJson(`{
      "a": 1,  # this is a comment
      "b": 2
    }`);
    assertEq(x.a, 1); assertEq(x.b, 2);
  });

  /* ───── Suite 8: multi-agent chain via data_slush ─────────── */
  console.log('\nMulti-agent chain (data_slush)');

  await test('two-step memory chain passes signals through slush', async () => {
    // Mint two starter agents to verify the contract; the chain itself uses
    // the stub below. (Memory split into save/recall agents historically;
    // they were merged into manage_memory_agent.py — see vault note
    // [[From save_recall to manage_memory]]. The data_slush wire shape is
    // what's under test here, not the agent identity.)
    const memSrc = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', 'manage_memory_agent.py'), 'utf8');
    const ctxSrc = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', 'context_memory_agent.py'), 'utf8');
    await RAPP.Card.mintCard(memSrc, 'manage_memory_agent.py');
    await RAPP.Card.mintCard(ctxSrc, 'context_memory_agent.py');
    // Use the same shape the UI's stub runner mirrors.
    const stub = (name, kw, slush) => {
      if (name === 'SaveMemory') {
        return JSON.stringify({status:'success', summary:'saved', data_slush:{saved_id:'abc', memory_type:kw.memory_type, importance:kw.importance||3}});
      }
      if (name === 'RecallMemory') {
        return JSON.stringify({status:'success', memories:[], data_slush:{count:0, last_save_id: slush && slush.saved_id}});
      }
    };
    const r1 = JSON.parse(stub('SaveMemory', { memory_type: 'fact', content: 'name=Kody', importance: 5 }, null));
    assertEq(r1.data_slush.memory_type, 'fact');
    const r2 = JSON.parse(stub('RecallMemory', {}, r1.data_slush));
    assertEq(r2.data_slush.last_save_id, 'abc');
  });

  /* ───── Suite 9: card import wire-compat with manifest ─────── */
  console.log('\nCard wire-compat');

  await test('seed → mnemonic → seed → card is fully reproducible', async () => {
    const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', 'manage_memory_agent.py'), 'utf8');
    const c = await RAPP.Card.mintCard(src, 'manage_memory_agent.py');
    const seedBig = BigInt(c.card.seed);
    const words = RAPP.Mnemonic.seedToWords(seedBig);
    const back = RAPP.Mnemonic.wordsToSeed(words);
    assertEq(back.toString(), seedBig.toString());
    const c2 = RAPP.Seed.resolveCardFromSeed(back);
    assertEq(c2.stats, c.card.stats, 'stats reproduce from seed');
    assertEq(c2.types, c.card.types, 'types reproduce');
    assertEq(c2.abilities.map(a=>a.name), c.card.abilities.map(a=>a.name), 'abilities reproduce');
  });

  await test('card.json is valid JSON and round-trips', async () => {
    const src = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'agents', 'hacker_news_agent.py'), 'utf8');
    const c = await RAPP.Card.mintCard(src, 'hacker_news_agent.py');
    const json = JSON.stringify(c);
    const parsed = JSON.parse(json);
    const back = await RAPP.Card.cardToAgentSource(parsed);
    assertEq(back.source, src);
  });

  /* ───── Suite 9b: voice playback contract (Path B) ────────────
   * Locks in the legacy-parity rule: prefer the |||VOICE||| block,
   * fall back to a stripped main reply when the model forgets to
   * emit one, and stay silent when both are empty. The fallback is
   * what makes voice mode feel "always works" the way the legacy
   * brainstem did, without re-introducing /voice/toggle coupling. */
  console.log('\nVoice playback contract (Path B)');

  await test('RAPP.Voice is exposed', () => {
    assert(RAPP.Voice, 'RAPP.Voice missing');
    assert(typeof RAPP.Voice.pickVoiceText === 'function', 'pickVoiceText missing');
    assert(typeof RAPP.Voice.stripMarkdownForVoice === 'function', 'stripMarkdownForVoice missing');
  });

  await test('pickVoiceText: voice block wins when present', () => {
    const r = RAPP.Voice.pickVoiceText({
      voice: 'Two PRs are waiting on you.',
      text: '## Open PRs\n\n**3 open**, two waiting.\n\nLook at #42 first.',
    });
    assertEq(r, 'Two PRs are waiting on you.');
  });

  await test('pickVoiceText: trims whitespace-only voice and falls back', () => {
    const r = RAPP.Voice.pickVoiceText({
      voice: '   \n  ',
      text: 'Quick reply.',
    });
    assertEq(r, 'Quick reply.');
  });

  await test('pickVoiceText: empty voice → stripped main reply', () => {
    const r = RAPP.Voice.pickVoiceText({
      voice: '',
      text: '## Result\n\n**Done.** See `notes.md` for [details](https://x.test).',
    });
    assertEq(r, 'Result. Done. See notes.md for details.');
  });

  await test('pickVoiceText: both empty → empty string (silent turn)', () => {
    assertEq(RAPP.Voice.pickVoiceText({ voice: '', text: '' }), '');
    assertEq(RAPP.Voice.pickVoiceText({}), '');
    assertEq(RAPP.Voice.pickVoiceText(null), '');
  });

  await test('pickVoiceText: caps fallback length around 280 chars', () => {
    const longBody = 'Here is the situation. ' + 'Detail. '.repeat(100);
    const r = RAPP.Voice.pickVoiceText({ voice: '', text: longBody });
    assert(r.length <= RAPP.Voice.VOICE_FALLBACK_MAX, `expected ≤ ${RAPP.Voice.VOICE_FALLBACK_MAX}, got ${r.length}`);
    assert(r.startsWith('Here is the situation.'), 'should start at the top of the body');
  });

  await test('pickVoiceText: prefers cutting at sentence boundary', () => {
    const body = 'A'.repeat(100) + '. ' + 'B'.repeat(50) + '. ' + 'C'.repeat(400);
    const r = RAPP.Voice.pickVoiceText({ voice: '', text: body });
    assert(r.endsWith('.'), `should end at sentence boundary, got: ${JSON.stringify(r.slice(-30))}`);
  });

  await test('stripMarkdownForVoice: drops fenced code blocks entirely', () => {
    const md = 'Run this:\n\n```python\nprint("hi")\n```\n\nThen reload.';
    const r = RAPP.Voice.stripMarkdownForVoice(md);
    assertEq(r.includes('print('), false);
    assertEq(r.includes('```'), false);
    assert(r.includes('Run this'), 'kept narrative around the code block');
    assert(r.includes('Then reload'), 'kept narrative after the code block');
  });

  await test('stripMarkdownForVoice: unwraps inline code, links, bold, italic', () => {
    const md = 'See `x.py`, **really**, _seriously_, [docs](https://e.test).';
    const r = RAPP.Voice.stripMarkdownForVoice(md);
    assertEq(r, 'See x.py, really, seriously, docs.');
  });

  await test('stripMarkdownForVoice: drops bullet markers but keeps text', () => {
    const md = '- one\n- two\n- three';
    const r = RAPP.Voice.stripMarkdownForVoice(md);
    assertEq(r, 'one two three');
  });

  await test('stripMarkdownForVoice: collapses paragraph breaks cleanly', () => {
    // When prior sentence already has terminal punctuation, the
    // paragraph break collapses to a single space — no awkward "..".
    const r1 = RAPP.Voice.stripMarkdownForVoice('First.\n\nSecond.\n\nThird.');
    assertEq(r1, 'First. Second. Third.');
    // Bare paragraph break (no terminal punctuation) gets a period
    // inserted so TTS pauses naturally between thoughts.
    const r2 = RAPP.Voice.stripMarkdownForVoice('Headline\n\nBody copy here');
    assertEq(r2, 'Headline. Body copy here');
  });

  await test('soul.md instructs the model to emit |||VOICE||| on substantive turns', () => {
    const soul = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'soul.md'), 'utf8').replace(/\n/g, ' ');
    // Soul must (a) reference the voice delimiter, (b) tell the model
    // to emit it on substantive replies. The exact verb (emit / produce
    // / require) doesn't matter — the directive does.
    assert(/\|\|\|VOICE\|\|\|/.test(soul), 'soul should reference the voice delimiter');
    assert(/emit a `?\|\|\|VOICE\|\|\|/.test(soul), 'soul should tell the model to emit the voice block');
    // Guard against re-introducing the "near-copy of main" phrasing
    // that caused the model to double-emit content (Apr 2026 regression).
    assert(!/near.?copy/i.test(soul), 'soul must not tell the model to copy the main reply into voice');
  });

  await test('index.html chat hook calls RAPP.Voice.pickVoiceText', () => {
    const html = fs.readFileSync(path.join(ROOT, 'rapp_brainstem', 'index.html'), 'utf8');
    assert(html.includes('RAPP.Voice.pickVoiceText(resp)'),
      'chat-loop hook should pick spoken text via RAPP.Voice.pickVoiceText');
    // And must NOT have re-introduced the legacy /voice/toggle round-trip:
    assert(!/fetch\([^)]*\/voice\/toggle/.test(html),
      'voice toggle must remain local — no /voice/toggle round-trip');
  });

  /* ───── Suite 10: file presence (digital twin layout) ─────── */
  console.log('\nDigital twin layout');

  for (const p of [
    'index.html', 'pages/docs/SPEC.md', 'README.md',
    'installer/index.html', 'rapp_swarm/index.html', 'rapp_brainstem/utils/web/index.html', 'rapp_brainstem/utils/web/rapp.js',
    'rapp_brainstem/agents/basic_agent.py',
    'rapp_brainstem/agents/manage_memory_agent.py', 'rapp_brainstem/agents/context_memory_agent.py', 'rapp_brainstem/agents/hacker_news_agent.py',
    'tests/run-tests.mjs',
    'rapp_brainstem/brainstem.py',
    'installer/install-swarm.sh',
    'tests/test-sealing-snapshot.sh',
    'tests/test-hero-deploy.sh',
    'tests/test-llm-chat.sh',
    'rapp_brainstem/utils/llm.py',
    'rapp_brainstem/utils/web/onboard/index.html',
    'rapp_brainstem/utils/web/onboard/registry.json',
    'rapp_swarm/function_app.py',
    'rapp_swarm/host.json',
    'rapp_swarm/requirements.txt',
    'rapp_swarm/build.sh',
    'rapp_swarm/provision-twin.sh',
    'rapp_swarm/README.md',
  ]) {
    await test(`twin file present: ${p}`, () => {
      const full = path.join(ROOT, p);
      assert(fs.existsSync(full), `missing: ${full}`);
      assert(fs.statSync(full).size > 0, `empty: ${full}`);
    });
  }

  /* ───── Done ─────────────────────────────────────────────────── */
  const total = pass + fail;
  console.log(`\n${pass}/${total} passed${fail ? `, \x1b[31m${fail} failed\x1b[0m` : ''}.`);
  if (fail) {
    console.log('\nFailures:');
    for (const f of failures) console.log(` • ${f.name}: ${f.err.message}`);
    process.exit(1);
  }
})();
