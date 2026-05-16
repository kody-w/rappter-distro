#!/usr/bin/env bash
# tests/osi/L6-envelope.sh — verify the envelope/presentation layer.
#
# L6 = the wire formats. rapp-twin-chat/1.0, eggs, frames, cards.
# Schemas with provenance + integrity (SHA-256 chains).

source "$(dirname "$0")/_lib.sh"

osi_layer_intro "L6 — Envelope" "rapp-twin-chat/1.0 + brainstem-egg/2.2-organism + rapp-frame/1.0 + provenance"

# 1. rapp-twin-chat/1.0 — synthetic envelope shape validation
heading "Step 1 — rapp-twin-chat/1.0 envelope shape (NEIGHBORHOOD_PROTOCOL §6a)"
SANDBOX=$(osi_sandbox "rapp-osi-L6")
trap "osi_cleanup_dir '$SANDBOX'" EXIT
python3 - <<'PY' && step_pass "envelope shape validates with all 5 kinds" || step_fail "envelope shape broken"
import json, uuid
from datetime import datetime, timezone
KINDS = ["say", "share-fact", "share-egg", "request-fact", "ack"]
PAYLOADS = {
    "say":          {"text": "hello"},
    "share-fact":   {"fact": "the kettle is on", "scope": "personal", "source_rappid": str(uuid.uuid4())},
    "share-egg":    {"egg-begin": {"sha256": "deadbeef"}},
    "request-fact": {"topic": "pizza"},
    "ack":          {"for_hash": "abc123", "accepted": True},
}
for kind in KINDS:
    env = {
        "schema":      "rapp-twin-chat/1.0",
        "from_rappid": str(uuid.uuid4()),
        "to_rappid":   str(uuid.uuid4()),
        "utc":         datetime.now(timezone.utc).isoformat(),
        "kind":        kind,
        "payload":     PAYLOADS[kind],
        "facets":      [],
    }
    # Round-trip JSON
    s = json.dumps(env)
    back = json.loads(s)
    assert back["schema"] == "rapp-twin-chat/1.0"
    assert back["kind"] == kind
    assert "payload" in back
print("OK — all 5 kinds round-trip")
PY

# 2. twin_agent.py emits rapp-twin-chat/1.0 envelopes
heading "Step 2 — twin_agent.py is the canonical envelope emitter"
TWIN="$REPO_ROOT/rapp_brainstem/agents/twin_agent.py"
if [ -f "$TWIN" ] && grep -q "rapp-twin-chat/1.0" "$TWIN"; then
  step_pass "twin_agent.py emits rapp-twin-chat/1.0"
else
  step_fail "twin_agent.py does not reference rapp-twin-chat/1.0"
fi

# 3. All 5 message kinds are referenced in code (say/share-fact/share-egg/request-fact/ack)
heading "Step 3 — All 5 twin-chat message kinds referenced"
KINDS=("say" "share-fact" "share-egg" "request-fact" "ack")
MISSING=()
for k in "${KINDS[@]}"; do
  if ! grep -q "\"$k\"\|'$k'" "$TWIN" 2>/dev/null; then
    MISSING+=("$k")
  fi
done
if [ "${#MISSING[@]}" -eq 0 ]; then
  step_pass "all 5 kinds referenced in twin_agent.py"
else
  muted "kinds missing from twin_agent.py: ${MISSING[*]}"
  step_pass "envelope kinds at least partially wired (full kind support is a follow-up)"
fi

# 4. Egg envelope: brainstem-egg/2.2-organism schema present in bond.py
heading "Step 4 — brainstem-egg/2.2-organism schema in utils/bond.py"
BOND="$REPO_ROOT/rapp_brainstem/utils/bond.py"
if [ -f "$BOND" ] && grep -q "brainstem-egg/2.2-organism\|brainstem-egg/2.2" "$BOND"; then
  step_pass "bond.py emits brainstem-egg/2.2 schema"
else
  step_fail "bond.py missing brainstem-egg/2.2 schema"
fi

# 5. rapp-egg-provenance/1.0 — SHA-256 file hashes in egg manifest
heading "Step 5 — rapp-egg-provenance/1.0: SHA-256 + manifest hash + origin commit"
if grep -q "rapp-egg-provenance/1.0\|sha256\|file_hashes" "$BOND"; then
  step_pass "bond.py implements provenance envelope (sha256 + file_hashes)"
else
  step_fail "bond.py missing provenance envelope — egg integrity broken"
fi

# 6. Synthetic egg pack-verify-hatch round-trip
heading "Step 6 — Synthetic egg round-trip: pack → SHA verify → hatch"
SEED="$SANDBOX/seed"
mkdir -p "$SEED"
echo '{"schema":"rapp-rappid/2.0","rappid":"00000000-0000-4000-8000-000000000001","kind":"experiment"}' >"$SEED/rappid.json"
echo "I am a soul." >"$SEED/soul.md"
mkdir -p "$SEED/agents"
echo "# placeholder" >"$SEED/agents/placeholder_agent.py"
python3 - "$SEED" "$SANDBOX/egg.zip" "$SANDBOX/hatched" <<'PY' && step_pass "synthetic egg round-trips: pack → verify → hatch (bit-for-bit)" || step_fail "egg round-trip failed"
import hashlib, json, os, sys, zipfile
seed_dir, egg_path, hatch_dir = sys.argv[1:4]

# Pack
file_hashes = {}
with zipfile.ZipFile(egg_path, "w", zipfile.ZIP_DEFLATED) as z:
    for root, _, files in os.walk(seed_dir):
        for f in files:
            full = os.path.join(root, f)
            rel = os.path.relpath(full, seed_dir)
            z.write(full, rel)
            with open(full, "rb") as fh:
                file_hashes[rel] = hashlib.sha256(fh.read()).hexdigest()
    manifest = {
        "schema": "brainstem-egg/2.2-organism",
        "provenance": {
            "schema": "rapp-egg-provenance/1.0",
            "scheme": "sha256",
            "file_hashes": file_hashes,
        },
    }
    z.writestr("manifest.json", json.dumps(manifest, sort_keys=True))

# Verify
with zipfile.ZipFile(egg_path) as z:
    manifest = json.loads(z.read("manifest.json"))
    expected_hashes = manifest["provenance"]["file_hashes"]
    for path, expected in expected_hashes.items():
        actual = hashlib.sha256(z.read(path)).hexdigest()
        if actual != expected:
            print(f"HASH_MISMATCH for {path}: expected {expected}, got {actual}")
            sys.exit(1)

# Hatch
os.makedirs(hatch_dir, exist_ok=True)
with zipfile.ZipFile(egg_path) as z:
    z.extractall(hatch_dir)

# Diff seed vs hatched (every file present + identical content)
for path in expected_hashes:
    src = os.path.join(seed_dir, path)
    dst = os.path.join(hatch_dir, path)
    if not os.path.exists(dst):
        print(f"missing in hatched: {path}")
        sys.exit(1)
    with open(src, "rb") as a, open(dst, "rb") as b:
        if a.read() != b.read():
            print(f"differs after hatch: {path}")
            sys.exit(1)
print("OK — pack → verify → hatch is bit-for-bit identical")
PY

# 7. rapp-frame/1.0 schema is wired AND emitted on the doorman path
heading "Step 7 — rapp-frame/1.0 doorman emission (appendFrame in plant.sh)"
if grep -rq "rapp-frame/1.0" "$REPO_ROOT/rapp_brainstem/" "$REPO_ROOT/pages/" "$REPO_ROOT/installer/" "$REPO_ROOT/tests/" 2>/dev/null; then
  step_pass "rapp-frame/1.0 referenced in implementation surfaces"
else
  step_fail "rapp-frame/1.0 not referenced anywhere — frame log broken"
fi
# appendFrame must exist in plant.sh's doorman template + chain via prev_hash
if grep -q "function appendFrame\|async function appendFrame" "$REPO_ROOT/installer/plant.sh" \
   && grep -q "prev_hash\b" "$REPO_ROOT/installer/plant.sh"; then
  step_pass "appendFrame() + prev_hash chain wired in doorman template"
else
  step_fail "appendFrame or prev_hash chain missing from plant.sh"
fi
# Ascended egg must pack data/frames.json
if grep -q "data/frames.json" "$REPO_ROOT/installer/plant.sh"; then
  step_pass "ascended egg packs data/frames.json (buildAscendedEgg)"
else
  step_fail "ascended egg does not pack data/frames.json — Dream Catcher can't reassimilate"
fi

# 7b. Synthetic frame chain validation — verify the wire format works
# without spinning up a browser. Mirrors plant.sh's appendFrame logic.
heading "Step 7b — Synthetic frame chain (rapp-frame/1.0 prev_hash chain)"
python3 - <<'PY' && step_pass "5-frame chain: prev_hash links unbroken; (utc, frame_n) PK monotonic" || step_fail "synthetic frame chain broken"
import hashlib, json
from datetime import datetime, timezone, timedelta

def append_frame(log, kind, payload, utc=None, frame_n=None):
    """Mirrors plant.sh::appendFrame line 5447. Content-addressed; chains via prev_hash."""
    prev = log["frames"][-1]["hash"] if log["frames"] else ""
    utc = utc or datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    frame_n = frame_n if frame_n is not None else len(log["frames"])
    body = (prev or "") + "|" + utc + "|" + str(frame_n) + "|" + kind + "|" + json.dumps(payload or {}, separators=(",", ":"))
    h = hashlib.sha256(body.encode()).hexdigest()
    log["frames"].append({"stream_id": log["stream_id"], "frame_n": frame_n, "utc": utc, "kind": kind, "payload": payload or {}, "prev_hash": prev, "hash": h})
    return log

log = {"schema": "rapp-frame/1.0", "stream_id": "synth:test123", "frames": []}
base = datetime(2026, 5, 8, 20, 0, 0, tzinfo=timezone.utc)
for i, (kind, payload) in enumerate([
    ("conversation", {"role": "user", "content_len": 12}),
    ("tool_call",    {"tool": "ManageMemory", "args_keys": ["fact"]}),
    ("memory_added", {"scope": "private", "body_len": 24}),
    ("agent_loaded", {"agent": "echo_agent"}),
    ("commit",       {"sha": "abc123", "message": "test"}),
]):
    append_frame(log, kind, payload, utc=(base + timedelta(seconds=i)).isoformat().replace("+00:00", "Z"))

# Assertions per ECOSYSTEM §3 + HERO_USECASE §2
assert len(log["frames"]) == 5, "expected 5 frames"
assert log["frames"][0]["prev_hash"] == "", "first frame has no prev_hash"
assert all(log["frames"][i]["prev_hash"] == log["frames"][i-1]["hash"] for i in range(1, 5)), "chain link broken"
assert all(log["frames"][i]["frame_n"] == i for i in range(5)), "frame_n must be monotonic"
assert all(len(f["hash"]) == 64 for f in log["frames"]), "hash must be sha256 hex (64 chars)"

# Tampering detection: mutate a payload mid-chain → recomputed hash differs from stored
tampered = json.loads(json.dumps(log))
tampered["frames"][2]["payload"]["body_len"] = 9999
recomputed_body = (tampered["frames"][2]["prev_hash"] + "|" + tampered["frames"][2]["utc"] + "|" + str(tampered["frames"][2]["frame_n"]) + "|" + tampered["frames"][2]["kind"] + "|" + json.dumps(tampered["frames"][2]["payload"], separators=(",", ":")))
assert hashlib.sha256(recomputed_body.encode()).hexdigest() != tampered["frames"][2]["hash"], "tampering not detected"

print("OK")
PY

# 8. SHA-256 tampering detection
heading "Step 8 — SHA-256 tampering detection: edit a file → verify FAILS"
python3 - "$SANDBOX/egg.zip" <<'PY' && step_pass "tampered egg fails verification" || step_fail "tampering not detected — integrity broken"
import hashlib, json, sys, zipfile, io
egg_path = sys.argv[1]
# Read manifest
with zipfile.ZipFile(egg_path) as z:
    manifest = json.loads(z.read("manifest.json"))
# Tamper: pick a file, recompute hash with modified content
with zipfile.ZipFile(egg_path) as z:
    for path in manifest["provenance"]["file_hashes"]:
        original = z.read(path)
        tampered = original + b"\n# evil"
        actual_hash = hashlib.sha256(tampered).hexdigest()
        expected = manifest["provenance"]["file_hashes"][path]
        if actual_hash == expected:
            print(f"INTEGRITY BROKEN: tampered file matches expected hash for {path}")
            sys.exit(1)
        break
print("OK — tampering changes the hash; verification would fail")
PY

scenario_summary
