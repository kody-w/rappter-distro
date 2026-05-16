#!/usr/bin/env bash
# loop_orchestrator.sh — one full cycle of the autonomous loop.
#
# Each invocation:
#   1. Tick Bill        (1 LLM call → 1 action: submit/vote/remix/observe-only)
#   2. Tick Alice       (1 LLM call → 1 action)
#   3. Tick Echo        (1 LLM call → 1 action — pattern-synthesizer twin,
#                        embodies the public kody-w/echo-brainstem)
#   4. Push canvas      (git add+commit+push the local neighborhood → public repo)
#   5. Observe          (no LLM — pure filesystem read + optional ecosystem pulse)
#   6. Print summary; exit
#
# After step 4, vbrainstem (and any other browser/public observer) sees all three
# twins' autonomous tick contributions on github.com/kody-w/sim-art-collective.
#
# Designed to be installed in cron or launchd. Recommended cadence:
#   */20 * * * *  /Users/<you>/.../loop_orchestrator.sh >> /tmp/rapp-sim.log 2>&1
#
# Cost: 3 LLM calls per cycle. ~$0.02–$0.08/cycle on Sonnet/Opus depending on prompt size.
#
# Always real LLM ticks — there is no fake / deterministic / pre-scripted
# persona mode. Autonomous means autonomous. (Per memory feedback
# "feedback_no_fake_mode".)
#
# ENV:
#   ECOSYSTEM_PULSE=1   — also include ecosystem drift in the observation
#   PUSH_CANVAS=0       — skip the public push (default: push enabled)
#   NEIGHBORHOOD_DIR    — override path to the neighborhood (defaults to ~/RAPP-sim/local-art-collective)
#
set -uo pipefail
SIM=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PULSE_FLAG=""
[ "${ECOSYSTEM_PULSE:-0}" = "1" ] && PULSE_FLAG="--with-ecosystem-pulse"
NB_DIR=${NEIGHBORHOOD_DIR:-$HOME/RAPP-sim/local-art-collective}

ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*"; }

log "=== orchestrator cycle start (real LLM ticks) ==="

for twin in bill-brainstem alice-brainstem echo-brainstem; do
  if [ ! -d "$HOME/RAPP-sim/$twin" ]; then
    log "skip → $twin (not present at ~/RAPP-sim/$twin)"
    continue
  fi
  log "tick → $twin"
  if ! python3 "$SIM/tick_twin.py" --twin "$twin"; then
    log "  tick failed for $twin (continuing)"
  fi
done

if [ "${PUSH_CANVAS:-1}" = "1" ]; then
  log "push canvas → public repo (additive, no-op if no changes)"
  if ! "$SIM/push_canvas.sh" "$NB_DIR"; then
    log "  push failed (continuing — canvas is still consistent locally)"
  fi
else
  log "push canvas: SKIPPED (PUSH_CANVAS=0)"
fi

log "observe"
python3 "$SIM/observe.py" $PULSE_FLAG --quiet
log "  → see ~/RAPP-sim/observations/latest.json"

# Show the brief summary at the end of cycle
LATEST="$SIM/observations/latest.json"
if [ -f "$LATEST" ]; then
  python3 -c "
import json
o = json.load(open('$LATEST'))
m = o['measured']
print(f\"  state: {m['total_submissions']}sub / {m['total_votes']}vote / {m['remix_count']}remix / {m['contributor_count']}contrib\")
adj = o.get('adjustments', [])
if adj:
    print(f\"  ⚠️  {len(adj)} adjustment(s) suggested:\")
    for a in adj:
        print(f\"    [{a['severity']}] {a['kind']}: {a['next_step'][:100]}\")
else:
    print(f\"  ✓ in line with north star\")
"
fi

log "=== cycle complete ==="
