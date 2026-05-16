#!/usr/bin/env node
// vault-check.mjs — verifies the vault's wikilinks, frontmatter, manifest
// completeness, and PII posture. Run from the repo root or anywhere; paths
// resolve relative to the script's location.
//
// Exits non-zero on any failure. Prints a summary either way.

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve, relative, sep } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(__dirname, '..');
const VAULT = resolve(REPO, 'pages', 'vault');

let failures = 0;
let warnings = 0;

function fail(msg) { console.error(`FAIL: ${msg}`); failures += 1; }
function warn(msg) { console.warn(`WARN: ${msg}`); warnings += 1; }
function ok(msg)   { console.log(`PASS: ${msg}`); }

// ── Walk vault for .md files ────────────────────────────────────────────────

function walk(dir, out = []) {
  for (const entry of readdirSync(dir)) {
    if (entry.startsWith('.')) continue;
    const full = resolve(dir, entry);
    const s = statSync(full);
    if (s.isDirectory()) walk(full, out);
    else if (entry.endsWith('.md')) out.push(full);
  }
  return out;
}

const mdFiles = walk(VAULT);
const mdRel = mdFiles.map((f) => relative(VAULT, f).split(sep).join('/'));

console.log(`Scanning vault at ${VAULT}`);
console.log(`Found ${mdFiles.length} markdown files.\n`);

// ── 1. Manifest matches filesystem ──────────────────────────────────────────

const manifestPath = resolve(VAULT, '_manifest.json');
let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
} catch (e) {
  fail(`could not parse _manifest.json: ${e.message}`);
  process.exit(1);
}

const manifestPaths = new Set(manifest.notes.map((n) => n.path));
const filesystemPaths = new Set(mdRel);

for (const p of manifestPaths) {
  if (!filesystemPaths.has(p)) {
    fail(`manifest references missing file: ${p}`);
  }
}
for (const p of filesystemPaths) {
  if (!manifestPaths.has(p)) {
    warn(`filesystem has note not in manifest: ${p}`);
  }
}
if (manifestPaths.size && [...manifestPaths].every((p) => filesystemPaths.has(p))) {
  ok(`manifest covers ${manifestPaths.size} notes; all paths resolve`);
}

// ── 2. Frontmatter sanity ───────────────────────────────────────────────────

const VALID_STATUSES = new Set(['stub', 'published', 'living', 'draft', 'shipped']);
const titleByPath = new Map();
const bodyByPath = new Map();

for (const f of mdFiles) {
  const rel = relative(VAULT, f).split(sep).join('/');
  const raw = readFileSync(f, 'utf8');
  const fm = parseFrontmatter(raw);

  if (!fm.meta.title) {
    warn(`${rel}: frontmatter has no title`);
  }
  if (fm.meta.status && !VALID_STATUSES.has(fm.meta.status)) {
    fail(`${rel}: invalid status "${fm.meta.status}" (must be stub/published/living)`);
  }
  // Optional: session pointer fields. We don't require them anywhere, but if a
  // note declares them they must be well-formed so future Claude / future
  // contributor can navigate back to the right session in their local Claude
  // Code store. No transcript is ever stored — only the pointer.
  if (fm.meta.session_id && !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(fm.meta.session_id)) {
    fail(`${rel}: malformed session_id "${fm.meta.session_id}" (expected UUID)`);
  }
  if (fm.meta.session_date && !/^\d{4}-\d{2}-\d{2}$/.test(fm.meta.session_date)) {
    fail(`${rel}: malformed session_date "${fm.meta.session_date}" (expected YYYY-MM-DD)`);
  }
  titleByPath.set(rel, fm.meta.title || basename(rel).replace(/\.md$/, ''));
  bodyByPath.set(rel, fm.body);
}
ok(`frontmatter valid across ${mdFiles.length} notes`);

// ── 3. Wikilinks resolve ────────────────────────────────────────────────────

const titleToPath = new Map();
for (const [path, title] of titleByPath) {
  titleToPath.set(title.toLowerCase(), path);
  // Also map by stem so [[Foo]] resolves to "Foo.md".
  const stem = basename(path).replace(/\.md$/, '');
  titleToPath.set(stem.toLowerCase(), path);
}

let wikilinkTotal = 0;
const broken = [];
for (const [path, body] of bodyByPath) {
  // Strip out content that should not be considered for wikilink resolution:
  //   1. Fenced code blocks (``` ... ```)
  //   2. Inline code spans (`...`)
  // This makes literal references like `[[wikilinks]]` in prose safe.
  const stripped = body
    .replace(/```[\s\S]*?```/g, '')
    .replace(/`[^`\n]*`/g, '');
  const re = /\[\[([^\]|\n]+)(\|[^\]\n]+)?\]\]/g;
  let m;
  while ((m = re.exec(stripped))) {
    wikilinkTotal += 1;
    const title = m[1].trim();
    if (!titleToPath.has(title.toLowerCase())) {
      broken.push({ from: path, target: title });
    }
  }
}
if (broken.length) {
  for (const b of broken) {
    fail(`broken wikilink in ${b.from}: [[${b.target}]]`);
  }
} else {
  ok(`all ${wikilinkTotal} wikilinks resolve`);
}

// ── 4. PII scan ─────────────────────────────────────────────────────────────

const PII_PATTERNS = [
  // Email addresses (standard form)
  { name: 'email', re: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/g },
  // Specific PII strings the vault must never contain
  { name: 'real-name fragment', re: /\bwildfeuer\b/gi },
  { name: 'real-name fragment', re: /\bkody w\b(?!ildfeuer)/gi }, // not the github handle "kody-w"
  // Phone numbers (loose North American shape)
  { name: 'phone number', re: /\b(?:\+?1[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b/g },
];

// Allowlist: substrings within which a match is acceptable.
const PII_ALLOWLIST = [
  // The github handle "kody-w" appears in URLs and the install one-liner — fine.
  'kody-w.github.io',
  'github.com/kody-w',
  'raw.githubusercontent.com/kody-w',
];

const piiHits = [];
for (const [path, body] of bodyByPath) {
  for (const { name, re } of PII_PATTERNS) {
    re.lastIndex = 0;
    let m;
    while ((m = re.exec(body))) {
      const start = Math.max(0, m.index - 20);
      const end = Math.min(body.length, m.index + m[0].length + 20);
      const ctx = body.slice(start, end);
      if (PII_ALLOWLIST.some((al) => ctx.includes(al))) continue;
      piiHits.push({ path, name, match: m[0], context: ctx });
    }
  }
}
if (piiHits.length) {
  for (const h of piiHits) {
    fail(`PII (${h.name}) in ${h.path}: "${h.match}" — ${truncate(h.context, 60)}`);
  }
} else {
  ok('no PII patterns detected');
}

// ── 5. Status distribution ──────────────────────────────────────────────────

const counts = { stub: 0, published: 0, living: 0, none: 0 };
for (const f of mdFiles) {
  const raw = readFileSync(f, 'utf8');
  const fm = parseFrontmatter(raw);
  const s = fm.meta.status || 'none';
  counts[s] = (counts[s] || 0) + 1;
}
console.log(`\nStatus distribution: ${JSON.stringify(counts)}`);

// ── Summary ─────────────────────────────────────────────────────────────────

console.log(`\n${failures === 0 ? '✅' : '❌'} ${failures} failures, ${warnings} warnings, ${mdFiles.length} notes scanned.`);
process.exit(failures === 0 ? 0 : 1);

// ── Helpers ─────────────────────────────────────────────────────────────────

function parseFrontmatter(md) {
  if (!md.startsWith('---')) return { meta: {}, body: md };
  const end = md.indexOf('\n---', 3);
  if (end === -1) return { meta: {}, body: md };
  const rawYaml = md.slice(3, end).trim();
  const body = md.slice(end + 4).replace(/^\n/, '');
  const meta = {};
  for (const line of rawYaml.split(/\r?\n/)) {
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (m) meta[m[1]] = stripQuotes(m[2].trim());
  }
  return { meta, body };
}

function stripQuotes(s) {
  if (s.length >= 2 && (s[0] === '"' && s[s.length-1] === '"')) return s.slice(1, -1);
  if (s.length >= 2 && (s[0] === "'" && s[s.length-1] === "'")) return s.slice(1, -1);
  return s;
}

function basename(path) {
  return path.split('/').pop();
}

function truncate(s, n) {
  return s.length > n ? s.slice(0, n).replace(/\s+/g, ' ') + '…' : s.replace(/\s+/g, ' ');
}
