---
title: Fixture 02 — Soul Read on Non-UTF-8 Windows Locale
status: published
section: Fixtures
hook: A Microsoft engineer in Shanghai installed v0.6.0, hit `UnicodeDecodeError: 'gbk' codec` on first boot. The kernel was reading soul.md through Python's locale-default encoding. The fix is universal — every text open() in the kernel takes encoding="utf-8" explicitly.
---

# Fixture 02 — Soul Read on Non-UTF-8 Windows Locale

> **Hook.** A Microsoft engineer in Shanghai installed v0.6.0, hit `UnicodeDecodeError: 'gbk' codec` on first boot. The kernel was reading soul.md through Python's locale-default encoding. The fix is universal — every text open() in the kernel takes encoding="utf-8" explicitly.

## What this fixture is

The second permanent organism fixture (after [[Fixture 01 — Canonical Kernel local_storage Drop-In]]). Records a real wild encounter: a Chinese-Windows organism receiving the canonical kernel and crashing on the first file read because Python's default text encoding is the OS locale (GBK on Chinese Windows), not UTF-8.

## The encounter

Reported by **Michael Jiang** (Microsoft, GBB AI Business Solution, Shanghai) — installed v0.6.0 on a Chinese-Windows host:

```
🧠 RAPP Brainstem v0.6.0 starting on http://localhost:7071
   Soul:   C:\Users\zhijian\.brainstem\src\rapp_brainstem\soul.md
   Agents: C:\Users\zhijian\.brainstem\src\rapp_brainstem\agents
   Model:  gpt-4o
   ...

Traceback (most recent call last):
  File "...\brainstem.py", line 1539, in <module>
    load_soul()
  File "...\brainstem.py", line 595, in load_soul
    _soul_cache = f.read().strip()
UnicodeDecodeError: 'gbk' codec can't decode byte 0x94 in position 14:
illegal multibyte sequence
```

Byte `0x94` at position 14 of `soul.md` is almost certainly a UTF-8 smart quote or emoji. On Chinese Windows the OS codepage is GBK (codepage 936). When Python opens a file in text mode without an explicit encoding, it uses the locale's preferred encoding — GBK in this case — and the read fails on any byte sequence that isn't valid GBK.

## Why this matters

The kernel's promise is universal drop-in compatibility. A canonical kernel must boot on **every** organism, including Windows hosts running locales other than UTF-8 (Chinese GBK, Japanese Shift_JIS, Korean EUC-KR, Russian cp1251, Western European cp1252, etc.). Bare `open()` calls in the kernel are a latent landmine — they work on Linux/macOS (UTF-8 by default) and Western Windows installs that happen to have UTF-8 soul files, then crash silently on the first non-Latin1 deployment.

This is the same bug class as Fixture 01: the kernel reaching into the environment for resolution rather than self-contained resolution. Fixture 01 was about Python's import path; this is about Python's text-encoding default.

## The resolution shape

Two layers, both additive in the architectural sense (no new kernel features — just making the existing code safe across all locales):

### Layer 1 — every `open()` in the kernel takes `encoding="utf-8"` explicitly

Ten sites in `brainstem.py`:

| Line | What it reads/writes |
|---|---|
| 48 | `VERSION` file at startup |
| 128 | `.brainstem_book.json` (flight log save) |
| 139 | `.brainstem_book.json` (flight log load) |
| 169 | `.copilot_token` |
| 232 | `.copilot_token` (write) |
| 270 | `.copilot_session` |
| 281 | `.copilot_session` (write) |
| 404 | `.copilot_pending` (write) |
| 417 | `.copilot_pending` |
| 594 | `soul.md` — the site that crashed for Michael |

Binary opens (`'wb'`) and `zipfile.ZipFile.open(...)` calls are unchanged — they don't need text encoding.

This is a kernel edit, requiring user authorization per Article XXXIII §4. Authorized in the same conversation that produced this fixture.

### Layer 2 — `PYTHONUTF8=1` defaults in start scripts

`start.sh` (Unix) and `start.ps1` (Windows) both set `PYTHONUTF8=1` before launching `brainstem.py`. PEP 540 (Python 3.7+) makes UTF-8 the default for **every** `open()` call regardless of OS locale, which catches:

- Agents that do bare `open(...)` without thinking about encoding
- Body functions that read user-provided files
- Any future kernel siblings that forget the explicit encoding

Belt-and-suspenders: the kernel is safe on its own, and the launcher protects everything around it too.

## What the test fixture asserts

`tests/organism/05-fixture-02-utf8-file-encoding.sh` will:

1. Stage a fixture organism with a `soul.md` containing UTF-8 multibyte sequences (smart quotes, emoji, CJK characters).
2. Set `LANG=zh_CN.GBK` (or simulate the locale) before launching the kernel.
3. Boot the canonical kernel.
4. Assert `/health` returns 200 (no UnicodeDecodeError).
5. Assert `load_soul()` produces the correct UTF-8 string in memory.

## What this fixture is not

- It is not specific to Chinese Windows. The same bug appears on every non-UTF-8 OS locale: Japanese (Shift_JIS), Korean (EUC-KR), Russian (cp1251), and surprisingly often on Western European Windows (cp1252) when the soul file contains a smart quote or em dash.
- It is not a one-time fix. Every future kernel edit that adds an `open()` call must take `encoding="utf-8"` explicitly. The test suite enforces this going forward.

## What changed in the kernel

- Every text-mode `open(...)` gained `encoding="utf-8"`.
- Behavior on Linux/macOS: identical (their default is already UTF-8).
- Behavior on Windows GBK/cp1252/Shift_JIS/etc: now reads/writes UTF-8 universally instead of crashing or silently producing mojibake.

## See also

- Constitution Article XXXIII §3 (Drop-in replaceability is the test, not just the goal).
- Constitution Article XXXIII §4 (AI assistants do not edit DNA — this fixture's kernel edit was explicitly user-authorized).
- [[Fixture 01 — Canonical Kernel local_storage Drop-In]] — the first wild encounter, where the kernel imported through the environment instead of shipping its own siblings.
