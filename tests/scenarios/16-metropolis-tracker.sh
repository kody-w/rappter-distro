#!/usr/bin/env bash
# Scenario 16 — RAPP Metropolis tracker.
#
# Verifies the structure + content of the canonical metropolis index at
# pages/metropolis/. Anyone can fork this directory to run their own
# tracker; federation happens via federated_trackers cross-references.

source "$(dirname "$0")/_lib.sh"
scenario_parse_args "$@"

heading "Scenario 16 — RAPP Metropolis (decentralized neighborhood directory)"
note "Pattern: Kazaa/torrent-style index of planted neighborhoods"
note "Showcases: anyone can host their own tracker; federation via cross-tracker links"

METRO_DIR="$REPO_ROOT/pages/metropolis"
INDEX="$METRO_DIR/index.json"

# 1. Index exists + valid JSON
if [ ! -f "$INDEX" ]; then
  step_fail "metropolis index missing"; scenario_summary
fi
step_pass "metropolis index.json present"

if python3 -c "import json; json.load(open('$INDEX'))" 2>/dev/null; then
  step_pass "metropolis index.json is valid JSON"
else
  step_fail "metropolis index.json is malformed"
fi

# 2. Schema is rapp-metropolis-index/1.0
SCHEMA=$(python3 -c "import json; print(json.load(open('$INDEX')).get('schema'))")
if [ "$SCHEMA" = "rapp-metropolis-index/1.0" ]; then
  step_pass "schema = rapp-metropolis-index/1.0"
else
  step_fail "unexpected schema: $SCHEMA"
fi

# 3. Has at least the 5 canonical seeds + 2 sibling directories
COUNT=$(python3 -c "import json; print(len(json.load(open('$INDEX'))['entries']))")
if [ "$COUNT" -ge 5 ]; then
  step_pass "$COUNT entries listed (≥5 expected)"
else
  step_fail "only $COUNT entries"
fi

# 4. Each entry has the required fields per rapp-metropolis-entry/1.0
MISSING=$(python3 - "$INDEX" <<'PY'
import json, sys
required = ["schema", "name", "display_name", "kind", "visibility", "join_via"]
idx = json.load(open(sys.argv[1]))
missing = []
for i, e in enumerate(idx.get("entries") or []):
    for r in required:
        if r not in e:
            missing.append(f"entry[{i}].{r}")
print("\n".join(missing))
PY
)
if [ -z "$MISSING" ]; then
  step_pass "every entry has required schema fields"
else
  step_fail "missing fields: $MISSING"
fi

# 5. Each entry's schema is rapp-metropolis-entry/1.0
ENTRY_SCHEMAS=$(python3 - "$INDEX" <<'PY'
import json, sys
idx = json.load(open(sys.argv[1]))
schemas = set(e.get("schema") for e in idx["entries"])
print(",".join(sorted(schemas)))
PY
)
if [ "$ENTRY_SCHEMAS" = "rapp-metropolis-entry/1.0" ]; then
  step_pass "all entries declare rapp-metropolis-entry/1.0"
else
  step_fail "entry schemas: $ENTRY_SCHEMAS"
fi

# 6. The index covers the canonical 5 seeds
EXPECTED=("microsoft-se-team-neighborhood" "public-art-collective" "private-workspace-template" "braintrust-template" "local-only-test")
COVERED=$(python3 - "$INDEX" <<'PY'
import json, sys
idx = json.load(open(sys.argv[1]))
print(",".join(sorted(e["name"] for e in idx["entries"])))
PY
)
ALL_OK=1
for s in "${EXPECTED[@]}"; do
  if ! echo "$COVERED" | grep -q "$s"; then
    step_fail "$s not in metropolis index"
    ALL_OK=0
  fi
done
if [ "$ALL_OK" -eq 1 ]; then
  step_pass "all 5 canonical seeds listed in metropolis"
fi

# 7. Federation primitive is present (even if empty)
if python3 -c "import json; idx=json.load(open('$INDEX')); assert 'federated_trackers' in idx" 2>/dev/null; then
  step_pass "federated_trackers field present (federation primitive)"
else
  step_fail "federated_trackers field missing"
fi

# 8. Index page exists + references index.json
HTML="$METRO_DIR/index.html"
if [ -f "$HTML" ] && grep -q "./index.json" "$HTML" && grep -q "rapp-metropolis" "$HTML"; then
  step_pass "directory HTML present + fetches index.json client-side"
else
  step_fail "directory HTML missing or doesn't fetch index.json"
fi

# 9. README declares the protocol + the "anyone can fork" property
README="$METRO_DIR/README.md"
if [ -f "$README" ] && grep -q "fork" "$README" && grep -q "tracker" "$README"; then
  step_pass "README declares the decentralization + fork-your-own protocol"
else
  step_fail "README missing or incomplete"
fi

# 10. Distinct rappids per entry (where rappid is set)
DUPS=$(python3 - "$INDEX" <<'PY'
import json, sys
idx = json.load(open(sys.argv[1]))
rappids = [e.get("neighborhood_rappid") for e in idx["entries"] if e.get("neighborhood_rappid")]
seen, dups = set(), []
for r in rappids:
    if r in seen: dups.append(r)
    seen.add(r)
print(",".join(dups))
PY
)
if [ -z "$DUPS" ]; then
  step_pass "all listed rappids are distinct (no double-listings)"
else
  step_fail "duplicate rappids: $DUPS"
fi

heading "Why this matters"
cat <<'EOF'
  The metropolis is the AI version of a torrent tracker — a decentralized
  index of who's seeding what. Each entry is a real GitHub repo (the seed).
  Each brainstem subscribed to a neighborhood is a seeder for that
  neighborhood. The directory is just JSON + an HTML renderer; anyone can
  fork + run their own tracker; trackers federate by linking to each other.

  This makes neighborhood discovery a first-class capability without
  introducing any central infrastructure. Just like Napster + Kazaa
  without their central server failure mode — torrents-without-trackers
  finally apply to AI work, not just media.
EOF

scenario_summary
