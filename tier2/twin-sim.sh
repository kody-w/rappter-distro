#!/bin/bash
# rapp_swarm/twin-sim.sh — RAPP Twin Simulator (local dev tools)
#
# Spin up isolated local twin workspaces on this machine that simulate
# the full cloud Twin Stack ecosystem. Each twin gets:
#
#     ~/.rapp-twins/<name>/
#       workspace.json      port, name, created_at
#       swarms/<guid>/      hatched cloud(s)
#       t2t/                this twin's identity, peers, conversation log
#       documents/          twin-owned docs
#       inbox/              docs received from peer twins (T2T-signed)
#       outbox/             audit trail of sent docs
#       server.log
#       server.pid
#
# Each twin runs swarm/server.py on its own port (7090 + offset). The root
# .env is auto-loaded so all twins share the same Azure OpenAI keys (or
# whichever LLM provider is configured).
#
# Commands:
#     bash rapp_swarm/twin-sim.sh start <name>   Spin up a twin
#     bash rapp_swarm/twin-sim.sh stop  <name>   Stop one (data preserved)
#     bash rapp_swarm/twin-sim.sh stop  all      Stop every running twin
#     bash rapp_swarm/twin-sim.sh list           Show all known twins
#     bash rapp_swarm/twin-sim.sh logs  <name>   Tail one twin's log
#     bash rapp_swarm/twin-sim.sh open  [name]   Open onboard page in browser
#     bash rapp_swarm/twin-sim.sh peer  <a> <b>  Mutually whitelist a↔b for T2T
#     bash rapp_swarm/twin-sim.sh wipe  <name>   Stop AND delete the workspace
#
# Wire a peer once with `peer kody molly`, then twins can chat, share
# documents, and invoke each other's swarms via T2T over localhost.

set -e
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TWINS_HOME="${TWINS_HOME:-$HOME/.rapp-twins}"
mkdir -p "$TWINS_HOME"

# Deterministic port: 7090 + (name-hash % 100). Reproducible across runs.
port_for() {
    local name="$1"
    python3 -c "import sys, hashlib; n = sys.argv[1]; print(7090 + int(hashlib.sha256(n.encode()).hexdigest(), 16) % 100)" "$name"
}

twin_dir() { echo "$TWINS_HOME/$1"; }
twin_pid() { local d=$(twin_dir "$1"); [ -f "$d/server.pid" ] && cat "$d/server.pid" || echo ""; }
twin_running() {
    local pid=$(twin_pid "$1")
    [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

cmd_start() {
    local name="$1"
    [ -z "$name" ] && { echo "usage: twin-sim.sh start <name>"; exit 2; }
    name=$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')

    if twin_running "$name"; then
        echo "✓ '$name' already running on http://127.0.0.1:$(port_for "$name")"
        return 0
    fi

    local d=$(twin_dir "$name")
    local port=$(port_for "$name")
    mkdir -p "$d"

    # Free the port if a stale server is squatting on it
    lsof -ti:$port 2>/dev/null | xargs -r kill -9 2>/dev/null || true

    # Ensure workspace metadata exists (port + name)
    python3 - "$d" "$name" "$port" <<'PY'
import json, sys, datetime, pathlib
d, name, port = pathlib.Path(sys.argv[1]), sys.argv[2], int(sys.argv[3])
mp = d / "workspace.json"
meta = json.loads(mp.read_text()) if mp.exists() else {}
meta.setdefault("name", name)
meta.setdefault("created_at", datetime.datetime.utcnow().isoformat() + "Z")
meta["port"] = port
meta["url"] = f"http://127.0.0.1:{port}"
mp.write_text(json.dumps(meta, indent=2))
PY

    cd "$ROOT"
    nohup python3 swarm/server.py --port "$port" --root "$d" \
        > "$d/server.log" 2>&1 &
    echo $! > "$d/server.pid"
    cd - > /dev/null

    # Wait up to 5s for it to come up
    for i in 1 2 3 4 5 6 7 8 9 10; do
        if curl -fsS "http://127.0.0.1:$port/api/swarm/healthz" >/dev/null 2>&1; then
            echo "✓ Twin '$name' running on http://127.0.0.1:$port (workspace: $d)"
            # Set its T2T handle to @<name>.local
            curl -fsS "http://127.0.0.1:$port/api/t2t/identity" >/dev/null 2>&1 || true
            python3 - "$d" "$name" <<'PY' >/dev/null 2>&1
import json, sys, pathlib
d = pathlib.Path(sys.argv[1])
name = sys.argv[2]
ip = d / "t2t" / "identity.json"
if ip.exists():
    j = json.loads(ip.read_text())
    j["handle"] = f"@{name}.local"
    ip.write_text(json.dumps(j, indent=2))
PY
            return 0
        fi
        sleep 0.5
    done
    echo "✗ Twin '$name' failed to start. Check $d/server.log"
    return 1
}

cmd_stop() {
    local name="$1"
    [ -z "$name" ] && { echo "usage: twin-sim.sh stop <name|all>"; exit 2; }
    if [ "$name" = "all" ]; then
        for d in "$TWINS_HOME"/*/; do
            [ -d "$d" ] || continue
            cmd_stop "$(basename "$d")"
        done
        return 0
    fi
    local pid=$(twin_pid "$name")
    if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
        echo "  '$name' not running"
        return 0
    fi
    kill "$pid" 2>/dev/null && sleep 0.3
    kill -9 "$pid" 2>/dev/null || true
    rm -f "$(twin_dir "$name")/server.pid"
    echo "✓ Stopped '$name' (workspace preserved at $(twin_dir "$name"))"
}

cmd_list() {
    printf "%-16s %-6s %-7s %-30s %s\n" "NAME" "PORT" "STATUS" "URL" "WORKSPACE"
    printf "%-16s %-6s %-7s %-30s %s\n" "----" "----" "------" "---" "---------"
    local found=0
    for d in "$TWINS_HOME"/*/; do
        [ -d "$d" ] || continue
        local name=$(basename "$d")
        local port=$(port_for "$name")
        local status="stopped"
        twin_running "$name" && status="running"
        printf "%-16s %-6s %-7s %-30s %s\n" "$name" "$port" "$status" "http://127.0.0.1:$port" "$d"
        found=1
    done
    [ $found -eq 0 ] && echo "  (no twins yet — run: $0 start kody)"
}

cmd_logs() {
    local name="$1"
    [ -z "$name" ] && { echo "usage: twin-sim.sh logs <name>"; exit 2; }
    local f="$(twin_dir "$name")/server.log"
    [ -f "$f" ] || { echo "no log: $f"; exit 1; }
    tail -f "$f"
}

cmd_open() {
    local name="${1:-}"
    local url="file://$ROOT/brainstem/onboard/index.html"
    if [ -n "$name" ]; then
        local port=$(port_for "$name")
        url="$url#endpoint=http://127.0.0.1:$port"
    fi
    if command -v open >/dev/null; then open "$url"; \
    elif command -v xdg-open >/dev/null; then xdg-open "$url"; \
    else echo "Open in browser: $url"; fi
}

cmd_peer() {
    local a="$1" b="$2"
    [ -z "$a" ] || [ -z "$b" ] && { echo "usage: twin-sim.sh peer <a> <b>"; exit 2; }
    twin_running "$a" || { echo "✗ '$a' not running"; exit 1; }
    twin_running "$b" || { echo "✗ '$b' not running"; exit 1; }

    local pa=$(port_for "$a"); local pb=$(port_for "$b")

    # Read both identities + secrets directly from disk (out-of-band exchange)
    local a_id=$(python3 -c "import json; print(json.load(open('$(twin_dir "$a")/t2t/identity.json'))['cloud_id'])")
    local a_sec=$(python3 -c "import json; print(json.load(open('$(twin_dir "$a")/t2t/identity.json'))['secret'])")
    local b_id=$(python3 -c "import json; print(json.load(open('$(twin_dir "$b")/t2t/identity.json'))['cloud_id'])")
    local b_sec=$(python3 -c "import json; print(json.load(open('$(twin_dir "$b")/t2t/identity.json'))['secret'])")

    # a ← b (a knows b's secret, can verify b's signed messages)
    curl -fsS -X POST "http://127.0.0.1:$pa/api/t2t/peers" \
        -H 'Content-Type: application/json' \
        -d "{\"cloud_id\":\"$b_id\",\"secret\":\"$b_sec\",\"handle\":\"@$b.local\",\"url\":\"http://127.0.0.1:$pb\",\"allowed_caps\":[\"*\"]}" >/dev/null
    # b ← a
    curl -fsS -X POST "http://127.0.0.1:$pb/api/t2t/peers" \
        -H 'Content-Type: application/json' \
        -d "{\"cloud_id\":\"$a_id\",\"secret\":\"$a_sec\",\"handle\":\"@$a.local\",\"url\":\"http://127.0.0.1:$pa\",\"allowed_caps\":[\"*\"]}" >/dev/null

    echo "✓ Mutual T2T peering: @$a.local ($a_id) ↔ @$b.local ($b_id)"
    echo "  Now twins can chat, share docs, and invoke each other's swarms."
}

cmd_wipe() {
    local name="$1"
    [ -z "$name" ] && { echo "usage: twin-sim.sh wipe <name>"; exit 2; }
    cmd_stop "$name" 2>/dev/null
    local d=$(twin_dir "$name")
    [ -d "$d" ] || { echo "no workspace: $d"; exit 0; }
    chmod -R u+w "$d" 2>/dev/null || true
    rm -rf "$d"
    echo "✓ Wiped '$name' (workspace deleted: $d)"
}

cmd_demo() {
    local which="${1:-hero}"
    case "$which" in
      hero)         cmd_demo_hero ;;
      book-factory) cmd_demo_book ;;
      *) echo "unknown demo: $which (try: hero | book-factory)"; exit 2 ;;
    esac
}

cmd_demo_book() {
    # Multi-twin pipeline: kody (source) → writer → editor → publisher.
    # Molly (CEO) chimes in with strategic guidance. All twins driven by
    # ONE OpenAI endpoint, all running on this device.
    echo "════════════════════════════════════════════════════════════════"
    echo "  📚 DIGITAL TWIN BOOK FACTORY"
    echo "════════════════════════════════════════════════════════════════"
    echo "  Source:    @kody.local       (consultant, off-hours, has the story)"
    echo "  CEO:       @molly.local      (strategic call on what stays in)"
    echo "  Pipeline:  @writer @editor @publisher @reviewer"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    # Workflow artifacts live in the shared dir so twin-egg pack captures them.
    local BOOK_DIR="$TWINS_HOME/.shared/book-factory"
    mkdir -p "$BOOK_DIR"

    # Spin up & peer all twins
    for t in kody molly writer editor publisher reviewer; do
        twin_running "$t" || { echo "▶ Starting $t ..."; cmd_start "$t" >/dev/null; }
    done
    echo ""
    echo "▶ Mutual peering for the pipeline"
    bash "$0" peer kody writer    >/dev/null
    bash "$0" peer writer editor  >/dev/null
    bash "$0" peer editor publisher >/dev/null
    bash "$0" peer publisher reviewer >/dev/null
    bash "$0" peer kody molly     >/dev/null
    bash "$0" peer molly publisher >/dev/null

    # Auto-hatch each twin's cloud from the registry
    cd "$ROOT"
    _build_book_bundles
    for t in kody molly writer editor publisher reviewer; do
        local port=$(port_for "$t")
        local guid_count=$(curl -fsS http://127.0.0.1:$port/api/swarm/healthz | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_count"])')
        if [ "$guid_count" = "0" ]; then
            echo "▶ Hatching $t's cloud"
            curl -fsS -X POST http://127.0.0.1:$port/api/swarm/deploy \
                -H 'Content-Type: application/json' --data-binary @/tmp/${t}-bundle.json >/dev/null
        fi
    done

    # Resolve guids
    declare -A GUID
    declare -A PORT
    for t in kody molly writer editor publisher reviewer; do
        PORT[$t]=$(port_for "$t")
        GUID[$t]=$(curl -fsS http://127.0.0.1:${PORT[$t]}/api/swarm/healthz | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarms"][0]["swarm_guid"])')
    done

    # ── STEP 1 — Kody's twin extracts source material from real repo ──
    echo ""
    echo "▶ STEP 1: Kody's twin extracts source material from this repo"
    {
        echo "# Source material — the platform-build story"
        echo ""
        echo "## Recent shipping cadence (from git)"
        git log --oneline -n 15 --since="2 weeks ago" || true
        echo ""
        echo "## Engineering field notes (blog posts about the build)"
        local i=0
        for p in blog/7[2-9]-*.md; do
            [ -f "$p" ] || continue
            i=$((i+1)); [ $i -gt 5 ] && break
            echo "### $(basename "$p")"
            sed -n '1,10p' "$p"
            echo ""
        done
    } > $BOOK_DIR/source-material.md
    echo "  wrote $BOOK_DIR/source-material.md ($(wc -c < $BOOK_DIR/source-material.md | tr -d ' ') bytes)"

    # Save into Kody's workspace + send to Writer via T2T
    python3 - <<PY > /dev/null
import sys, json, base64, urllib.request
url = "http://127.0.0.1:${PORT[kody]}"
data = open("$BOOK_DIR/source-material.md","rb").read()
urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/workspace/documents/source-material.md",
    data=json.dumps({"content_b64": base64.b64encode(data).decode()}).encode(),
    headers={"Content-Type":"application/json"}, method="POST"))
PY

    WRITER_ID=$(python3 -c "import json; print(json.load(open('$(twin_dir writer)/t2t/identity.json'))['cloud_id'])")
    curl -fsS -X POST "http://127.0.0.1:${PORT[kody]}/api/t2t/send-document" \
        -H 'Content-Type: application/json' \
        -d "{\"to\":\"$WRITER_ID\",\"document_name\":\"source-material.md\"}" >/dev/null
    echo "  ✓ source-material.md → @writer.local inbox"

    # ── STEP 2 — Writer twin drafts a chapter ──
    echo ""
    echo "▶ STEP 2: @writer drafts a chapter from the source (live LLM)"
    {
        echo "You just received source-material.md from @kody.local in your inbox. Here it is:"
        echo ""
        cat $BOOK_DIR/source-material.md
        echo ""
        echo "Outline a chapter titled 'Why local-first is the whole pitch'. Then draft it."
        echo "Lead with one concrete scene from the source. Plain prose, no markdown headings"
        echo "except a single H1. Under 800 words. Sign off as @writer.local."
    } > $BOOK_DIR/prompt-writer.txt
    DRAFT=$(_chat_file "${PORT[writer]}" "${GUID[writer]}" $BOOK_DIR/prompt-writer.txt)
    echo "$DRAFT" > $BOOK_DIR/draft.md
    echo "  ✓ Draft written ($(wc -w < $BOOK_DIR/draft.md | tr -d ' ') words)"
    echo "  ┌── Excerpt:"
    head -8 $BOOK_DIR/draft.md | sed 's/^/  │ /'
    echo "  └──"

    # Send draft → editor
    python3 - <<PY > /dev/null
import sys, json, base64, urllib.request
url = "http://127.0.0.1:${PORT[writer]}"
data = open("$BOOK_DIR/draft.md","rb").read()
urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/workspace/documents/draft.md",
    data=json.dumps({"content_b64": base64.b64encode(data).decode()}).encode(),
    headers={"Content-Type":"application/json"}, method="POST"))
PY
    EDITOR_ID=$(python3 -c "import json; print(json.load(open('$(twin_dir editor)/t2t/identity.json'))['cloud_id'])")
    curl -fsS -X POST "http://127.0.0.1:${PORT[writer]}/api/t2t/send-document" \
        -H 'Content-Type: application/json' \
        -d "{\"to\":\"$EDITOR_ID\",\"document_name\":\"draft.md\"}" >/dev/null
    echo "  ✓ draft.md → @editor.local inbox"

    # ── STEP 3 — Editor twin cuts and flags ──
    echo ""
    echo "▶ STEP 3: @editor cuts ruthlessly + voice-checks (live LLM)"
    {
        echo "You received draft.md from @writer.local. Here it is:"
        echo ""
        cat $BOOK_DIR/draft.md
        echo ""
        echo "Edit it: cut the weakest 20%, flag two claims that need sourcing, note any voice"
        echo "drift from the original Kody source. Return the EDITED draft followed by '---'"
        echo "followed by your editor's note (max 5 bullets)."
    } > $BOOK_DIR/prompt-editor.txt
    EDITED=$(_chat_file "${PORT[editor]}" "${GUID[editor]}" $BOOK_DIR/prompt-editor.txt)
    echo "$EDITED" > $BOOK_DIR/edited.md
    echo "  ✓ Edited ($(wc -w < $BOOK_DIR/edited.md | tr -d ' ') words)"
    echo "  ┌── Editor's note (last section):"
    awk '/^---$/{found=1; next} found' $BOOK_DIR/edited.md | head -10 | sed 's/^/  │ /'
    echo "  └──"

    # Send edited → publisher
    python3 - <<PY > /dev/null
import sys, json, base64, urllib.request
url = "http://127.0.0.1:${PORT[editor]}"
data = open("$BOOK_DIR/edited.md","rb").read()
urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/workspace/documents/edited.md",
    data=json.dumps({"content_b64": base64.b64encode(data).decode()}).encode(),
    headers={"Content-Type":"application/json"}, method="POST"))
PY
    PUBLISHER_ID=$(python3 -c "import json; print(json.load(open('$(twin_dir publisher)/t2t/identity.json'))['cloud_id'])")
    curl -fsS -X POST "http://127.0.0.1:${PORT[editor]}/api/t2t/send-document" \
        -H 'Content-Type: application/json' \
        -d "{\"to\":\"$PUBLISHER_ID\",\"document_name\":\"edited.md\"}" >/dev/null
    echo "  ✓ edited.md → @publisher.local inbox"

    # ── STEP 4 — Molly (CEO) chimes in on whether to ship ──
    echo ""
    echo "▶ STEP 4: @molly (CEO) reviews for strategic message-discipline"
    {
        echo "As CEO, you have final say on whether this chapter ships externally or stays"
        echo "internal. The chapter is from the book about building this platform."
        echo "Here's the editor-cut version:"
        echo ""
        cat $BOOK_DIR/edited.md
        echo ""
        echo "In 3 short bullets:"
        echo "(1) Does this ship as-is, ship with edits, or hold?"
        echo "(2) What's the partner-conversation risk if it ships?"
        echo "(3) What's the one line you want changed before it goes out?"
    } > $BOOK_DIR/prompt-molly.txt
    MOLLY_REVIEW=$(_chat_file "${PORT[molly]}" "${GUID[molly]}" $BOOK_DIR/prompt-molly.txt)
    echo "  ┌── Molly's verdict:"
    echo "$MOLLY_REVIEW" | head -10 | sed 's/^/  │ /'
    echo "  └──"

    # ── STEP 5 — Publisher assembles final artifact ──
    echo ""
    echo "▶ STEP 5: @publisher assembles the publication-ready chapter"
    {
        echo "You received edited.md and a CEO note. Assemble the final chapter as one"
        echo "publication-ready markdown file with proper frontmatter (title, author, date,"
        echo "chapter number). Apply the CEO's requested change."
        echo ""
        echo "Edited draft:"
        cat $BOOK_DIR/edited.md
        echo ""
        echo "CEO note:"
        echo "$MOLLY_REVIEW"
        echo ""
        echo "Output the final markdown. Nothing else."
    } > $BOOK_DIR/prompt-publisher.txt
    FINAL=$(_chat_file "${PORT[publisher]}" "${GUID[publisher]}" $BOOK_DIR/prompt-publisher.txt)
    echo "$FINAL" > $BOOK_DIR/chapter-final.md
    echo "  ✓ Final chapter ready: $BOOK_DIR/chapter-final.md ($(wc -w < $BOOK_DIR/chapter-final.md | tr -d ' ') words)"

    # ── STEP 6 — Reviewer reads it cold ──
    echo ""
    echo "▶ STEP 6: @reviewer reads it the way a real reader would"
    {
        echo "Here is the final chapter. Read it as if you didn't build this platform."
        echo ""
        cat $BOOK_DIR/chapter-final.md
        echo ""
        echo "In 3 bullets:"
        echo "(1) score 1-5"
        echo "(2) strongest line in the chapter"
        echo "(3) would you keep reading the next chapter? Why or why not?"
    } > $BOOK_DIR/prompt-reviewer.txt
    REVIEW=$(_chat_file "${PORT[reviewer]}" "${GUID[reviewer]}" $BOOK_DIR/prompt-reviewer.txt)
    echo "  ┌── Reader's verdict:"
    echo "$REVIEW" | head -8 | sed 's/^/  │ /'
    echo "  └──"

    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  ✓ BOOK FACTORY COMPLETE"
    echo "════════════════════════════════════════════════════════════════"
    echo "  6 twins, 5 LLM calls, 3 T2T document hand-offs, 1 OpenAI endpoint."
    echo "  Final chapter: $BOOK_DIR/chapter-final.md"
    echo "  Source:    $BOOK_DIR/source-material.md"
    echo "  Draft:     $BOOK_DIR/draft.md"
    echo "  Edited:    $BOOK_DIR/edited.md"
    echo ""
    echo "  Replay anytime: bash rapp_swarm/twin-sim.sh demo book-factory"
    echo "════════════════════════════════════════════════════════════════"
}

# Helper: chat with one twin's swarm. Prompt is read from a FILE path —
# avoids all shell-quoting hell with multi-line / multi-byte prompts.
_chat_file() {
    local port="$1" guid="$2" prompt_file="$3"
    python3 - "$port" "$guid" "$prompt_file" <<'PY'
import sys, json, urllib.request
port, guid, pf = sys.argv[1], sys.argv[2], sys.argv[3]
prompt = open(pf).read()
body = json.dumps({"user_input": prompt}).encode()
r = urllib.request.urlopen(urllib.request.Request(
    f"http://127.0.0.1:{port}/api/swarm/{guid}/chat",
    data=body, headers={"Content-Type":"application/json"}, method="POST"), timeout=180)
print(json.loads(r.read()).get("response",""))
PY
}

# Build per-twin bundles for all 6 personas in the book factory.
_build_book_bundles() {
    cd "$ROOT"
    python3 - <<'PY'
import json, re, datetime, pathlib
reg = json.load(open('brainstem/onboard/registry.json'))
all_clouds = (reg.get('hero_humans', []) + reg.get('hero_role_twins', []))
pick = {'kody': 'kody-cloud', 'molly': 'molly-cloud',
        'writer': 'writer', 'editor': 'editor',
        'publisher': 'publisher', 'reviewer': 'reviewer'}
def stub(cid, s):
    cls = re.sub(r'[^A-Za-z0-9]', '', s['name']) + 'Agent'
    desc = (s.get('description') or '').replace('"', '\\"')
    role = (s.get('role_framing') or '').replace('"', '\\"')
    return f'''from agents.basic_agent import BasicAgent
__manifest__ = {{"schema":"rapp-agent/1.0","name":"@twinstack/{cid}-{s['name'].lower()}","tier":"core","trust":"community","version":"0.1.0","tags":["twin-stack"]}}
class {cls}(BasicAgent):
    def __init__(self):
        self.name = "{s['name']}"
        self.metadata = {{"name": self.name, "description": "{desc}", "parameters": {{"type":"object","properties":{{}},"required":[]}}}}
        super().__init__(name=self.name, metadata=self.metadata)
    def perform(self, **kwargs):
        return ("[{s['name']}] role: {role}")
'''
for twin_name, cloud_id in pick.items():
    cloud = next((c for c in all_clouds if c['id'] == cloud_id), None)
    if not cloud: continue
    agents = [{'filename': re.sub(r'[^a-z0-9]','_', s['name'].lower())+'_agent.py',
               'name': s['name'], 'description': s.get('description',''),
               'source': stub(cloud['id'], s)} for s in cloud['swarms']]
    bundle = {'schema':'rapp-swarm/1.0','name':cloud['title'],'purpose':cloud.get('tagline',''),
              'soul':cloud.get('soul_addendum',''),'cloud_id':cloud['id'],
              'handle':cloud.get('owner_handle', f"@{twin_name}.local"),
              'created_at':datetime.datetime.utcnow().isoformat()+'Z',
              'created_by':f'@{twin_name}.local','agents':agents}
    pathlib.Path(f'/tmp/{twin_name}-bundle.json').write_text(json.dumps(bundle))
PY
}

cmd_demo_hero() {
    # Hero demo: real git history → Kody's twin briefs Molly via T2T doc
    # share → Molly's twin returns CEO-shaped strategic decision.
    twin_running kody  || { echo "▶ Starting kody…";  cmd_start kody;  }
    twin_running molly || { echo "▶ Starting molly…"; cmd_start molly; }

    # Ensure peering
    bash "$0" peer kody molly >/dev/null

    local KODY_PORT=$(port_for kody)
    local MOLLY_PORT=$(port_for molly)
    local KODY_URL=http://127.0.0.1:$KODY_PORT
    local MOLLY_URL=http://127.0.0.1:$MOLLY_PORT

    # Auto-hatch if either is empty
    local k_count=$(curl -fsS $KODY_URL/api/swarm/healthz | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_count"])')
    local m_count=$(curl -fsS $MOLLY_URL/api/swarm/healthz | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarm_count"])')
    if [ "$k_count" = "0" ] || [ "$m_count" = "0" ]; then
        echo "▶ Auto-hatching missing twin clouds from registry"
        python3 "$ROOT/rapp_swarm/.demo-build-bundles.py" >/dev/null 2>&1 || \
            _build_bundles_inline
        [ "$k_count" = "0" ] && curl -fsS -X POST $KODY_URL/api/swarm/deploy \
            -H 'Content-Type: application/json' --data-binary @/tmp/kody-bundle.json >/dev/null
        [ "$m_count" = "0" ] && curl -fsS -X POST $MOLLY_URL/api/swarm/deploy \
            -H 'Content-Type: application/json' --data-binary @/tmp/molly-bundle.json >/dev/null
    fi

    local KODY_GUID=$(curl -fsS $KODY_URL/api/swarm/healthz | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarms"][0]["swarm_guid"])')
    local MOLLY_GUID=$(curl -fsS $MOLLY_URL/api/swarm/healthz | python3 -c 'import json,sys; print(json.load(sys.stdin)["swarms"][0]["swarm_guid"])')
    local MOLLY_CLOUD_ID=$(python3 -c "import json; print(json.load(open('$(twin_dir molly)/t2t/identity.json'))['cloud_id'])")

    cd "$ROOT"
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  HERO DEMO — Twin Stack on real repo data"
    echo "════════════════════════════════════════════════════════════════"

    # 1. Real git data → file
    {
    echo "# What shipped this week — RAPP repo"
    echo "Generated $(date -u +"%Y-%m-%d %H:%M UTC")"
    echo ""
    echo "## Commits (last 5)"
    git log --oneline -5
    echo ""
    echo "## Files changed in last commit"
    git show --stat HEAD --format= | head -25
    echo ""
    echo "## Blog posts: $(ls blog/ | grep -E '^[0-9]+-' | wc -l | tr -d ' ') field notes"
    echo "Latest 5:"
    ls blog/ | grep -E '^[0-9]+-' | sort -t- -k1n | tail -5 | sed 's/^/  - /'
    echo ""
    echo "## Live infrastructure"
    echo "- Local twins: $(bash "$0" list 2>/dev/null | grep running | awk '{print $1}' | tr '\n' ' ')"
    echo "- LLM provider: azure-openai (gpt-5.4)"
    } > /tmp/this-week.md
    echo "▶ Step 1: real repo activity → /tmp/this-week.md ($(wc -c < /tmp/this-week.md | tr -d ' ') bytes)"

    # 2. Save into Kody's workspace
    python3 - "$KODY_URL" /tmp/this-week.md <<'PY'
import sys, json, base64, urllib.request
url, path = sys.argv[1], sys.argv[2]
body = json.dumps({"content_b64": base64.b64encode(open(path,'rb').read()).decode()}).encode()
urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/workspace/documents/this-week.md",
    data=body, headers={"Content-Type":"application/json"}, method="POST"))
print("▶ Step 2: saved → kody/documents/this-week.md")
PY

    # 3. Kody's twin drafts brief
    echo "▶ Step 3: Kody's twin drafts the brief (live gpt-5.4)…"
    python3 - "$KODY_URL" "$KODY_GUID" /tmp/this-week.md /tmp/brief-for-molly.md <<'PY'
import sys, json, urllib.request
url, guid, doc, out = sys.argv[1:5]
prompt = (
    "You have a fresh weekly status report saved to your workspace as this-week.md. "
    "Here it is verbatim:\n\n--- this-week.md ---\n" + open(doc).read() + "\n--- end ---\n\n"
    "Write Molly (your CEO partner) a 4-bullet briefing email. Lead with what is "
    "most strategically important to her. Plain English, no markdown formatting. "
    "Sign off as Kody. Under 120 words."
)
r = json.loads(urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/swarm/{guid}/chat",
    data=json.dumps({"user_input": prompt}).encode(),
    headers={"Content-Type":"application/json"}, method="POST"), timeout=60).read())
brief = r.get("response","")
open(out, "w").write(brief)
print("\n   ┌─ Kody's brief ──────────────────────────────────────────")
for line in brief.split("\n"): print(f"   │ {line}")
print("   └─────────────────────────────────────────────────────────")
print(f"   [{r.get('provider')} · rounds={r.get('rounds')} · tools={len(r.get('agent_logs',[]))}]")
PY

    # 4. T2T send
    echo ""
    echo "▶ Step 4: HMAC-signed T2T doc share → Molly's inbox"
    python3 - "$KODY_URL" /tmp/brief-for-molly.md "$MOLLY_CLOUD_ID" <<'PY'
import sys, json, base64, urllib.request
url, doc, to_id = sys.argv[1:4]
urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/workspace/documents/brief-for-molly.md",
    data=json.dumps({"content_b64": base64.b64encode(open(doc,'rb').read()).decode()}).encode(),
    headers={"Content-Type":"application/json"}, method="POST")).read()
r = json.loads(urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/t2t/send-document",
    data=json.dumps({"to": to_id, "document_name": "brief-for-molly.md"}).encode(),
    headers={"Content-Type":"application/json"}, method="POST"), timeout=15).read())
print(f"   ✓ molly/inbox/{r['peer_response']['saved_as']}")
PY

    # 5. Molly's twin reads + decides
    echo ""
    echo "▶ Step 5: Molly's twin reads the inbox & responds (live gpt-5.4)…"
    python3 - "$MOLLY_URL" "$MOLLY_GUID" /tmp/brief-for-molly.md <<'PY'
import sys, json, urllib.request
url, guid, brief = sys.argv[1:4]
prompt = (
    "Kody just sent you the following brief via T2T (now in your inbox as "
    "brief-for-molly.md):\n\n--- start ---\n" + open(brief).read() + "\n--- end ---\n\n"
    "You are Molly, the CEO. In 3 short bullets:\n"
    "(1) what one decision do you owe Kody by tomorrow?\n"
    "(2) which partner conversation does this unlock?\n"
    "(3) anything you need to push back on?\n"
    "Be terse — this is a CEO note, not an email."
)
r = json.loads(urllib.request.urlopen(urllib.request.Request(
    f"{url}/api/swarm/{guid}/chat",
    data=json.dumps({"user_input": prompt}).encode(),
    headers={"Content-Type":"application/json"}, method="POST"), timeout=60).read())
print("\n   ┌─ Molly's reply ─────────────────────────────────────────")
for line in r.get("response","").split("\n"): print(f"   │ {line}")
print("   └─────────────────────────────────────────────────────────")
print(f"   [{r.get('provider')} · rounds={r.get('rounds')}]")
PY
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  ✓ HERO DEMO COMPLETE — replay anytime: twin-sim.sh demo hero"
    echo "════════════════════════════════════════════════════════════════"
}

_build_bundles_inline() {
    cd "$ROOT"
    python3 - <<'PY'
import json, re, datetime, pathlib
reg = json.load(open('brainstem/onboard/registry.json'))
def stub(cid, s):
    cls = re.sub(r'[^A-Za-z0-9]', '', s['name']) + 'Agent'
    desc = (s.get('description') or '').replace('"', '\\"')
    role = (s.get('role_framing') or '').replace('"', '\\"')
    return f'''from agents.basic_agent import BasicAgent
__manifest__ = {{"schema":"rapp-agent/1.0","name":"@twinstack/{cid}-{s['name'].lower()}","tier":"core","trust":"community","version":"0.1.0","tags":["twin-stack"],"example_call":{{"args":{{}}}}}}
class {cls}(BasicAgent):
    def __init__(self):
        self.name = "{s['name']}"
        self.metadata = {{"name": self.name, "description": "{desc}", "parameters": {{"type":"object","properties":{{}},"required":[]}}}}
        super().__init__(name=self.name, metadata=self.metadata)
    def perform(self, **kwargs):
        return ("Stub for {s['name']}. Role framing: {role}. Replace once your twin learns this domain.")
'''
for c in reg['hero_humans']:
    agents = [{'filename': re.sub(r'[^a-z0-9]','_', s['name'].lower())+'_agent.py',
               'name': s['name'], 'description': s.get('description',''),
               'source': stub(c['id'], s)} for s in c['swarms']]
    bundle = {'schema':'rapp-swarm/1.0','name':c['title'],'purpose':c['tagline'],
              'soul':c.get('soul_addendum',''),'cloud_id':c['id'],
              'handle':c['owner_handle'],'created_at':datetime.datetime.utcnow().isoformat()+'Z',
              'created_by':c['owner_handle'],'agents':agents}
    name = c['id'].split('-')[0]
    pathlib.Path(f'/tmp/{name}-bundle.json').write_text(json.dumps(bundle))
PY
}

cmd_help() {
    cat <<EOF
RAPP Twin Simulator — local dev tools for the full Twin Stack ecosystem.

  start <name>      Spin up a twin on its own port + isolated workspace
  stop  <name|all>  Stop a running twin (workspace preserved)
  list              Show all known twins (running or stopped)
  logs  <name>      Tail a twin's server log
  open  [name]      Open the onboard page in your browser
  peer  <a> <b>     Mutually whitelist two twins for T2T (chat, doc share)
  wipe  <name>      Stop AND delete a twin's workspace
  demo  hero        Hero flow: real git history → Kody's brief → T2T → Molly's CEO decision
  demo  book-factory   6-twin pipeline: Kody → Writer → Editor → Molly (CEO) → Publisher → Reviewer

Each twin's full state lives at: $TWINS_HOME/<name>/
EOF
}

CMD="${1:-help}"
shift || true
case "$CMD" in
    start)  cmd_start  "$@" ;;
    stop)   cmd_stop   "$@" ;;
    list|ls) cmd_list  "$@" ;;
    logs)   cmd_logs   "$@" ;;
    open)   cmd_open   "$@" ;;
    peer)   cmd_peer   "$@" ;;
    wipe)   cmd_wipe   "$@" ;;
    demo)   cmd_demo   "$@" ;;
    help|-h|--help) cmd_help ;;
    *) echo "unknown command: $CMD"; cmd_help; exit 2 ;;
esac
