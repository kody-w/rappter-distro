#!/usr/bin/env bash
# Fixture: the swarm_estate organ exposes /api/swarm-estate/* endpoints.
#
# Asserts:
#   - GET /api/swarm-estate/ returns the organ index
#   - GET /api/swarm-estate/species-root returns the canonical species root rappid
#   - GET /api/swarm-estate/parse?rappid=<s> parses correctly
#   - POST /api/swarm-estate/walk walks a synthetic vault to the species root
#
# Reference: rapp_brainstem/utils/organs/swarm_estate_organ.py

set -euo pipefail
cd "$(dirname "$0")/../.."

LOG="/tmp/rapp-organism-19.log"
PID_FILE="/tmp/rapp-organism-19.pid"
SYNTH_VAULT=$(mktemp -d)
trap "rm -rf $SYNTH_VAULT; if [ -f $PID_FILE ]; then kill \$(cat $PID_FILE) 2>/dev/null || true; rm -f $PID_FILE; fi" EXIT

# Build a synthetic vault with Wildhaven + Molly fakes (same shape as test 14)
mkdir -p "$SYNTH_VAULT/blessings/144d673475618dfbc9710e999e7d2907"
cat > "$SYNTH_VAULT/blessings/144d673475618dfbc9710e999e7d2907/root.json" <<EOF
{
  "alg": "ecdsa-p256",
  "schema": "swarm-estate-record/1.0",
  "kind": "root",
  "rappid": "rappid:v2:organism:@wildhaven/ai-homes:144d673475618dfbc9710e999e7d2907@github.com/kody-w/wildhaven-ceo",
  "issued_at": "2026-04-30T00:00:00Z",
  "issued_by": "fp:M:test",
  "issued_by_role": "M",
  "payload": {
    "parent_rappid": "rappid:v2:prototype:@rapp/origin:0b635450c04249fbb4b1bdb571044dec@github.com/kody-w/RAPP"
  },
  "signature": "synthetic"
}
EOF

# Pick a free port
PORT=""
for p in 7090 7091 7092 7093 7094 7095; do
    if ! lsof -i ":$p" -sTCP:LISTEN >/dev/null 2>&1; then
        PORT="$p"; break
    fi
done
[ -n "$PORT" ] || { echo "FAIL: no free port"; exit 1; }

PYTHON="${PYTHON:-$HOME/.brainstem/venv/bin/python}"
[ -x "$PYTHON" ] || PYTHON="$(command -v python3)"

BOOT_PATH=""
if [ -f rapp_brainstem/utils/boot.py ]; then BOOT_PATH="utils/boot.py"
elif [ -f rapp_brainstem/boot.py ]; then BOOT_PATH="boot.py"
else echo "FAIL: no boot sidecar"; exit 1; fi
echo "▶ booting brainstem via $BOOT_PATH on :$PORT (LLM_FAKE=1) for organ smoke test"
# Use the boot sidecar so organs get dispatched (per Constitution Article XXXIII)
( cd rapp_brainstem && exec env PORT="$PORT" LLM_FAKE=1 "$PYTHON" "$BOOT_PATH" ) > "$LOG" 2>&1 &
echo $! > "$PID_FILE"

# Wait for boot
for i in $(seq 1 20); do
    if curl -sf "http://localhost:$PORT/health" > /dev/null; then break; fi
    sleep 0.5
done

# 1. GET /api/swarm-estate/
RESP=$(curl -sf "http://localhost:$PORT/api/swarm-estate/")
echo "$RESP" | grep -qE "swarm-estate-(body-function|organ)/1.0" || { echo "FAIL: index response"; echo "$RESP"; exit 1; }

# 2. GET /api/swarm-estate/species-root
RESP=$(curl -sf "http://localhost:$PORT/api/swarm-estate/species-root")
echo "$RESP" | grep -q "rappid:v2:prototype:@rapp/origin" || { echo "FAIL: species-root response"; echo "$RESP"; exit 1; }
echo "$RESP" | grep -q "0b635450c04249fbb4b1bdb571044dec" || { echo "FAIL: species-root hash"; echo "$RESP"; exit 1; }

# 3. GET /api/swarm-estate/parse?rappid=<s>
RAPPID="rappid:v2:organism:@wildhaven/ai-homes:144d673475618dfbc9710e999e7d2907@github.com/kody-w/wildhaven-ceo"
RESP=$(curl -sf -G --data-urlencode "rappid=$RAPPID" "http://localhost:$PORT/api/swarm-estate/parse")
echo "$RESP" | grep -q "wildhaven" || { echo "FAIL: parse publisher"; echo "$RESP"; exit 1; }
echo "$RESP" | grep -q "ai-homes" || { echo "FAIL: parse slug"; echo "$RESP"; exit 1; }

# 4. POST /api/swarm-estate/walk
RESP=$(curl -sf -X POST "http://localhost:$PORT/api/swarm-estate/walk" \
    -H "Content-Type: application/json" \
    -d "{\"rappid\":\"$RAPPID\",\"vault_root\":\"$SYNTH_VAULT\"}")
echo "$RESP" | grep -q "terminated_at_species_root" || { echo "FAIL: walk response"; echo "$RESP"; exit 1; }
# Extract: terminated_at_species_root should be true
echo "$RESP" | python3 -c "import json,sys; d=json.load(sys.stdin); assert d['terminated_at_species_root'], d; assert d['depth'] == 1, f\"depth {d['depth']}\""

echo "PASS: 19-swarm-estate-organ"
