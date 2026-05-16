#!/usr/bin/env bash
# utils/local_storage.py must survive concurrent writes without torn
# files or lost updates within a transaction. Test hammers many threads
# at the same JSON file, then validates:
#   - the final file is valid JSON (no torn writes)
#   - update_json transactions don't lose updates (count == thread count)
#   - write_file is also atomic
#
# Reference: review item — concurrent JSON write corruption.

set -euo pipefail
cd "$(dirname "$0")/../.."

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

TMP_DIR="$(mktemp -d /tmp/rapp-organism-12.XXXXXX)"
HARNESS="$TMP_DIR/harness.py"
trap 'rm -rf "$TMP_DIR"' EXIT

cat > "$HARNESS" <<'PY'
import json
import os
import sys
import threading
import time

import importlib.util
spec = importlib.util.spec_from_file_location(
    "local_storage_test",
    "rapp_brainstem/utils/local_storage.py",
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
LSM = mod.AzureFileStorageManager

tmp_dir = sys.argv[1]
target = os.path.join(tmp_dir, "concurrent.json")

# ── Test 1: torn-write resistance via write_json ───────────────────────
mgr = LSM()
THREAD_COUNT = 32
ITERATIONS = 20

def hammer_writer(thread_id):
    for i in range(ITERATIONS):
        payload = {"thread": thread_id, "iter": i, "padding": "x" * 1000}
        mgr.write_json(payload, file_path=target)

threads = [threading.Thread(target=hammer_writer, args=(i,)) for i in range(THREAD_COUNT)]
for t in threads:
    t.start()

torn_observations = 0
read_attempts = 0
while any(t.is_alive() for t in threads):
    if os.path.exists(target):
        read_attempts += 1
        try:
            with open(target, "r") as f:
                json.load(f)
        except Exception:
            torn_observations += 1
    time.sleep(0.001)

for t in threads:
    t.join()

with open(target, "r") as f:
    final = json.load(f)
assert isinstance(final, dict), "final file is not a dict"
assert "thread" in final and "iter" in final, f"final file shape wrong: {final}"

print(f"  write_json: {THREAD_COUNT} threads x {ITERATIONS} iters; {read_attempts} mid-flight reads; {torn_observations} torn")
assert torn_observations == 0, f"observed {torn_observations} torn writes during the race"

# ── Test 2: update_json preserves every caller's contribution ──────────
counter_target = os.path.join(tmp_dir, "counter.json")
TXN_THREAD_COUNT = 16
TXN_ITERATIONS = 50

def hammer_updater(thread_id):
    for i in range(TXN_ITERATIONS):
        def add(d):
            d.setdefault("entries", []).append({"t": thread_id, "i": i})
            return d
        mgr.update_json(add, file_path=counter_target)

txn_threads = [threading.Thread(target=hammer_updater, args=(i,)) for i in range(TXN_THREAD_COUNT)]
for t in txn_threads:
    t.start()
for t in txn_threads:
    t.join()

with open(counter_target, "r") as f:
    final = json.load(f)
entries = final.get("entries", [])
expected = TXN_THREAD_COUNT * TXN_ITERATIONS
assert len(entries) == expected, f"update_json LOST UPDATES: {len(entries)} entries (expected {expected})"
seen_pairs = {(e["t"], e["i"]) for e in entries}
assert len(seen_pairs) == expected, f"duplicate entries found: {len(seen_pairs)} unique vs {expected}"
print(f"  update_json: {TXN_THREAD_COUNT} threads x {TXN_ITERATIONS} appends; {len(entries)} entries (no lost updates)")

# ── Test 3: write_file atomic too ─────────────────────────────────────
file_target = "concurrent_file.txt"
def hammer_file_writer(thread_id):
    for i in range(10):
        mgr.write_file(file_target, f"thread={thread_id} iter={i}\n")

data_dir = os.path.dirname(os.path.abspath(mod.__file__)) + "/.brainstem_data"
file_threads = [threading.Thread(target=hammer_file_writer, args=(i,)) for i in range(8)]
for t in file_threads:
    t.start()

torn_file_obs = 0
file_reads = 0
full_path = os.path.join(data_dir, file_target)
while any(t.is_alive() for t in file_threads):
    if os.path.exists(full_path):
        file_reads += 1
        with open(full_path, "r") as f:
            content = f.read()
        if content and not content.endswith("\n"):
            torn_file_obs += 1
    time.sleep(0.001)

for t in file_threads:
    t.join()
print(f"  write_file: 8 threads x 10 iters; {file_reads} mid-flight reads; {torn_file_obs} torn")
assert torn_file_obs == 0, "torn write observed in write_file"
try:
    os.remove(full_path)
except OSError:
    pass

print("OK local_storage survives concurrent writes; update_json preserves all updates")
PY

OUT="$("$PYTHON" "$HARNESS" "$TMP_DIR")"
echo "$OUT"
echo "$OUT" | grep -q "^OK local_storage" || {
    echo "FAIL: concurrency test did not pass cleanly"
    exit 1
}

echo "✓ local_storage: atomic writes survive thread races; update_json transactions preserve all caller updates"
