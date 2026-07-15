#!/bin/bash
#
# plant.sh — plant your AI's front door on the public internet.
#
# Drops a kernel-compliant seed at <your-handle>.github.io/<your-name>.
# The kernel is the seed's DNA — byte-synced from grail. The rest of the
# front door (soul, agents, UI) grows from the seed and is yours forever.
#
# Usage (interactive):
#   curl -fsSL https://kody-w.github.io/RAPP/installer/plant.sh | bash
#
# Usage (env vars):
#   MIRROR_REPO_NAME=my-front-door \
#   MIRROR_DISPLAY_NAME="My Front Door" \
#   curl -fsSL https://kody-w.github.io/RAPP/installer/plant.sh | bash
#
# Optional MIRROR_PARENT (lineage tag — who introduced you):
#   MIRROR_PARENT=alice/her-mirror curl ... plant.sh | bash
#
# Dry run (writes locally, doesn't push to GitHub):
#   PLANT_DRY_RUN=1 PLANT_DRY_RUN_DIR=/tmp/plant-test \
#   PLANT_GH_USER=test-user MIRROR_REPO_NAME=demo \
#   bash ./plant.sh

set -e

# ── constants ─────────────────────────────────────────────────────────
GRAIL_REPO="kody-w/rapp-installer"
GRAIL_RAW="https://raw.githubusercontent.com/${GRAIL_REPO}/main"
# Species root rappid — the canonical §6.1 identifier for kody-w/RAPP.
# `rappid:@<owner>/<slug>:<64hex>` — the 64-hex tail is a domain-separated
# mint, NOT a name digest (kind lives in the record, not the string). This is
# the one true species root every planted door points its parent_rappid at.
SPECIES_ROOT_RAPPID="rappid:@kody-w/rapp:9a8f0a4b5a710e20f4d819a0f37d2a4c9f113b5e78fb3c29e70b54fff48a38f9"

KERNEL_FILES=(
    "rapp_brainstem/brainstem.py"
    "rapp_brainstem/VERSION"
    "rapp_brainstem/agents/basic_agent.py"
)
# Standard memory cartridges every planted seed ships with — same source
# as the grail kernel, dropped into the seed's top-level agents/ so the
# planted seed is a complete twin per the egg hub twin spec §6.
SEED_AGENTS=(
    "rapp_brainstem/agents/manage_memory_agent.py"
    "rapp_brainstem/agents/context_memory_agent.py"
)

# ── colors ────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

err()  { printf "%s✗%s %s\n" "$RED"   "$NC" "$*" >&2; exit 1; }
ok()   { printf "%s✓%s %s\n" "$GREEN" "$NC" "$*"; }
info() { printf "%s→%s %s\n" "$CYAN"  "$NC" "$*"; }
warn() { printf "%s!%s %s\n" "$YELLOW" "$NC" "$*"; }

# ── prereqs ───────────────────────────────────────────────────────────
check_prereqs() {
    command -v curl    >/dev/null || err "curl required"
    command -v git     >/dev/null || err "git required"
    command -v python3 >/dev/null || err "python3 required (for UUID minting)"

    if [[ "${PLANT_DRY_RUN:-0}" != "1" ]]; then
        command -v gh >/dev/null || err "gh CLI required (https://cli.github.com)"
        gh auth status >/dev/null 2>&1 || err "Run 'gh auth login' first"
    fi
}

# ── interactive prompts ───────────────────────────────────────────────
read_tty() {
    local prompt="$1" default="$2" result
    if [ -t 0 ]; then
        read -r -p "$prompt" result
    elif [ -e /dev/tty ]; then
        read -r -p "$prompt" result < /dev/tty
    else
        result=""
    fi
    echo "${result:-$default}"
}

prompt_inputs() {
    if [[ "${PLANT_DRY_RUN:-0}" == "1" ]]; then
        [[ -n "${MIRROR_REPO_NAME:-}" ]] || err "MIRROR_REPO_NAME required for dry run"
    elif [[ -z "${MIRROR_REPO_NAME:-}" ]]; then
        echo ""
        echo "What slug should your front door live at?"
        echo "  Example: my-front-door  →  ${PLANT_GH_USER:-<you>}.github.io/my-front-door"
        echo "  Lowercase letters, digits, hyphens, underscores. No spaces."
        echo ""
        MIRROR_REPO_NAME=$(read_tty "Slug: " "")
    fi

    [[ -n "${MIRROR_REPO_NAME:-}" ]] || err "no MIRROR_REPO_NAME provided"

    if ! [[ "$MIRROR_REPO_NAME" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        err "'$MIRROR_REPO_NAME' is not a valid slug (lowercase, digits, hyphens, underscores)"
    fi

    if [[ -z "${MIRROR_DISPLAY_NAME:-}" ]]; then
        local default_name
        default_name=$(echo "$MIRROR_REPO_NAME" | python3 -c "
import sys, re
s = sys.stdin.read().strip()
parts = [p for p in re.split(r'[-_]+', s) if p]
print(' '.join(p.capitalize() for p in parts))
")
        if [[ "${PLANT_DRY_RUN:-0}" != "1" ]]; then
            echo ""
            echo "Display name (what visitors see)?"
            MIRROR_DISPLAY_NAME=$(read_tty "Display name [$default_name]: " "$default_name")
        else
            MIRROR_DISPLAY_NAME="$default_name"
        fi
    fi

    export MIRROR_REPO_NAME MIRROR_DISPLAY_NAME
    info "Slug:    $MIRROR_REPO_NAME"
    info "Display: $MIRROR_DISPLAY_NAME"
    if [[ -n "${MIRROR_PARENT:-}" ]]; then
        info "Lineage: planted from $MIRROR_PARENT"
    fi
}

# ── identity ──────────────────────────────────────────────────────────
# mint_rappid <gh_user> <repo_name> <kind>
# Mints a canonical RAPP §6.1 rappid: `rappid:@<owner>/<slug>:<64hex>`.
# owner/slug are canonicalized to the grammar [a-z0-9]+(-[a-z0-9]+)* and the
# 64-hex tail is Hb("rapp/1:rappid", uuid4_bytes) = sha256(b"rapp/1:rappid\n"
# + uuid4.bytes) — a domain-separated keyless mint, NEVER sha256(name). `kind`
# lives in the rappid.json record, not the string, so it is not encoded here.
mint_rappid() {
    local gh_user="${1:-anon}" repo_name="${2:-unknown}" kind="${3:-mirror}"
    python3 -c "
import uuid, hashlib, re, sys
def canon(s):
    s = re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')
    return s or 'x'
owner, slug = canon(sys.argv[1]), canon(sys.argv[2])
tail = hashlib.sha256(b'rapp/1:rappid\n' + uuid.uuid4().bytes).hexdigest()
print(f'rappid:@{owner}/{slug}:{tail}')
" "$gh_user" "$repo_name"
}
now_iso()     { date -u +"%Y-%m-%dT%H:%M:%SZ"; }

# ── kernel fetch (drift-proof: always re-fetch from grail) ────────────
fetch_kernel() {
    local target_dir="$1"
    info "Fetching kernel from grail..."
    for f in "${KERNEL_FILES[@]}"; do
        local target="$target_dir/$f"
        mkdir -p "$(dirname "$target")"
        curl -fsSL "$GRAIL_RAW/$f" -o "$target" \
            || err "fetch failed: $f"
        ok "  $f"
    done
}

# ── seed agents fetch (memory cartridges every twin should ship with) ──
fetch_seed_agents() {
    local target_dir="$1"
    mkdir -p "$target_dir/agents"
    info "Fetching seed agents (memory cartridges) from grail..."
    for src in "${SEED_AGENTS[@]}"; do
        # Strip the rapp_brainstem/ prefix — these land at the seed's
        # top-level agents/ so they're discoverable by the kernel without
        # any path acrobatics.
        local fname="${src##*/}"
        local target="$target_dir/agents/$fname"
        curl -fsSL "$GRAIL_RAW/$src" -o "$target" \
            || err "fetch failed: $src"
        ok "  agents/$fname"
    done
}

# ── file generation ───────────────────────────────────────────────────
write_install_sh() {
    local target_dir="$1"
    mkdir -p "$target_dir/installer"
    cat > "$target_dir/installer/install.sh" << 'EOF'
#!/bin/bash
#
# Mirror installer — thin proxy to the grail kernel installer.
#
# Per the Mirror Spec (https://kody-w.github.io/RAPP/pages/vault/), every
# valid mirror's installer re-fetches the canonical installer from the
# grail's raw GitHub URL on every run, so no mirror's installer can drift
# from the upstream source of truth.

set -e

GRAIL_INSTALLER_URL="https://raw.githubusercontent.com/kody-w/rapp-installer/main/install.sh"

curl -fsSL "$GRAIL_INSTALLER_URL" | bash -s -- "$@"
EOF
    chmod +x "$target_dir/installer/install.sh"
}

# write_rar_index — scaffold a per-seed rar/index.json (rapp-rar-index/1.0).
#
# Every planted seed ships its own RAR registry — same shape as the global
# kody-w/RAR + RAPP_Store + RAPP_Sense_Store but scoped to ONE repo. Joining
# brainstems hot-load the listed agents/cards/rapps via rar_loader_agent
# (sha256-verified). Makes the seed self-sufficient + portable.
#
# Kernel-base agents (basic / manage_memory / context_memory) go in
# `kernel_base_included` (informational — every brainstem already has them).
# All other agents go in either `required_for_participation` (when kind is a
# neighborhood-style cooperative) or `optional_for_participation` (when kind
# is a single-twin organism).
write_rar_index() {
    local target_dir="$1" gh_user="$2" repo_name="$3" kind="$4"
    [[ -d "$target_dir/agents" ]] || return 0

    # Hands-off if PLANT_FROM_EGG already provided a rar/ — eggs preserve their own.
    [[ -n "${PLANT_FROM_EGG:-}" && -f "$target_dir/rar/index.json" ]] && return 0

    mkdir -p "$target_dir/rar/cards" "$target_dir/rar/rapplications"

    PLANT_RAR_TARGET="$target_dir" \
    PLANT_RAR_GH_USER="$gh_user" \
    PLANT_RAR_REPO="$repo_name" \
    PLANT_RAR_KIND="$kind" \
    PLANT_RAR_NOW="$(now_iso)" \
    python3 <<'PYEOF'
import hashlib, json, os, time

target = os.environ["PLANT_RAR_TARGET"]
gh_user = os.environ["PLANT_RAR_GH_USER"]
repo = os.environ["PLANT_RAR_REPO"]
kind = os.environ["PLANT_RAR_KIND"] or "mirror"
now = os.environ["PLANT_RAR_NOW"]

agents_dir = os.path.join(target, "agents")
agent_files = sorted(
    f for f in os.listdir(agents_dir)
    if f.endswith(".py") and os.path.isfile(os.path.join(agents_dir, f))
)

KERNEL_BASE = {"basic_agent.py", "manage_memory_agent.py", "context_memory_agent.py"}
NEIGHBORHOOD_KINDS = {"ant-farm", "neighborhood", "braintrust", "swarm", "place"}

def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(8192), b""):
            h.update(chunk)
    return h.hexdigest()

def class_name_for(filename):
    """Best-effort agent class name from filename (foo_bar_agent.py → FooBarAgent)."""
    stem = filename[:-3]
    parts = stem.replace("_agent", "").split("_")
    return "".join(p.capitalize() for p in parts if p) + "Agent"

def metadata_name_for(path):
    """Pull metadata['name'] if present; fall back to class-derived."""
    try:
        with open(path) as f:
            src = f.read()
        # naive grep — tolerant of formatting
        import re
        m = re.search(r'"name":\s*"([A-Za-z][A-Za-z0-9_]*)"', src)
        if m:
            return m.group(1)
    except Exception:
        pass
    return class_name_for(os.path.basename(path))

raw_prefix = f"https://raw.githubusercontent.com/{gh_user}/{repo}/main"

required, optional, kernel_base = [], [], []
for fname in agent_files:
    p = os.path.join(agents_dir, fname)
    entry = {
        "kind": "agent",
        "name": metadata_name_for(p),
        "file": f"agents/{fname}",
        "raw_url": f"{raw_prefix}/agents/{fname}",
        "sha256": sha256_of(p),
        "schema": "rapp-agent/1.0",
    }
    if fname in KERNEL_BASE:
        kernel_base.append(entry)
    elif kind in NEIGHBORHOOD_KINDS:
        required.append(entry)
    else:
        optional.append(entry)

index = {
    "schema": "rapp-rar-index/1.0",
    "name": repo,
    "rar_for": f"{gh_user}/{repo}",
    "purpose": (
        "Per-seed RAR registry — agents/cards/organs/senses/rapplications required to "
        f"participate in this {kind}. Same shape as kody-w/RAR + RAPP_Store + "
        "RAPP_Sense_Store but scoped to one repo. sha256-verified at hot-load time."
    ),
    "version": "1.0",
    "created_at": now,
    "raw_url_prefix": raw_prefix,
    "kind": kind,
    "required_for_participation": required,
    "optional_for_participation": optional,
    "kernel_base_included": kernel_base,
    "organs": [],
    "senses": [],
    "rapplications": [],
    "cards": [],
    "verification": {
        "schema": "rapp-rar-manifest/1.0",
        "scheme": "sha256",
        "_instructions": (
            "Joining brainstems should re-compute sha256(file) and compare to the "
            "published value before installing. Mismatch = refuse install (tampered or stale)."
        ),
    },
    "federation": {
        "_purpose": (
            "This per-seed RAR is a SCOPED variant of the global stores at kody-w/RAR + "
            "RAPP_Store + RAPP_Sense_Store. DEFAULT: separate (scope-local). OPT-IN: federate "
            "via federation.federates_with."
        ),
        "default_mode": "separate",
        "federates_with": [],
        "_known_global_stores": [
            {"name": "kody-w/RAR", "purpose": "Open agent registry (Pokédex)",
             "index_url": "https://kody-w.github.io/RAR/store.html"},
            {"name": "kody-w/RAPP_Store", "purpose": "Rapplications catalog",
             "index_url": "https://kody-w.github.io/RAPP_Store/"},
            {"name": "kody-w/RAPP_Sense_Store", "purpose": "Senses catalog",
             "index_url": "https://kody-w.github.io/RAPP_Sense_Store/"},
        ],
    },
    "offline_dimension_protocol": {
        "_purpose": (
            "Per HERO_USECASE §2 + ECOSYSTEM §10, a local clone of this seed is a "
            "parallel offline dimension. Local mutations (frames/pheromones) accumulate "
            "content-addressed (prev_hash chained). On reconnect, the existing Dream "
            "Catcher reassimilates: same hash → shared, same (utc, source_id) different "
            "content → contradiction (preserved as alternate dimension). No mutations lost."
        ),
        "merge_via": "Dream Catcher pane on the gate page (label: dream-catcher)",
    },
    "_install_one_liner": (
        "From any brainstem: use the RarLoader agent on "
        f"gate_repo={gh_user}/{repo} (defaults to dry_run; pass dry_run=false to install)."
    ),
    "_portability_note": (
        f"`git clone https://github.com/{gh_user}/{repo}` → boot a local brainstem from "
        "inside the cloned dir → agents/ is already populated; rar/ exists for joining "
        "brainstems that have a kernel running elsewhere."
    ),
}

out = os.path.join(target, "rar", "index.json")
with open(out, "w") as f:
    json.dump(index, f, indent=2)
    f.write("\n")
PYEOF
}

write_rappid_json() {
    local target_dir="$1" gh_user="$2" rappid="$3" now="$4"
    local planted_from_json="null"
    [[ -n "${MIRROR_PARENT:-}" ]] && planted_from_json="\"$MIRROR_PARENT\""

    # Use Python json to ensure correct escaping of display names with quotes/etc.
    PLANT_RJ_PATH="$target_dir/rappid.json" \
    PLANT_RAPPID="$rappid" \
    PLANT_NOW="$now" \
    PLANT_GH_USER="$gh_user" \
    PLANT_REPO_NAME="$MIRROR_REPO_NAME" \
    PLANT_DISPLAY_NAME="$MIRROR_DISPLAY_NAME" \
    PLANT_PARENT_RAPPID="$SPECIES_ROOT_RAPPID" \
    PLANT_PARENT="${MIRROR_PARENT:-}" \
    PLANT_KIND="${MIRROR_KIND:-mirror}" \
    PLANT_LOCATION="${MIRROR_LOCATION:-}" \
    PLANT_LOCATION_LAT="${MIRROR_LOCATION_LAT:-}" \
    PLANT_LOCATION_LNG="${MIRROR_LOCATION_LNG:-}" \
    PLANT_LOCATION_PRECISION="${MIRROR_LOCATION_PRECISION:-5}" \
    PLANT_PRIVATE_COMPANION="${MIRROR_PRIVATE_COMPANION:-}" \
    PLANT_PRIVATE_PURPOSE="${MIRROR_PRIVATE_PURPOSE:-}" \
    python3 - <<'PYEOF'
import os, json, pathlib
data = {
    "schema": "rapp/1",
    "rappid": os.environ["PLANT_RAPPID"],
    "kind": os.environ.get("PLANT_KIND") or "mirror",
    "name": os.environ["PLANT_REPO_NAME"],
    "display_name": os.environ["PLANT_DISPLAY_NAME"],
    "github": f"https://github.com/{os.environ['PLANT_GH_USER']}/{os.environ['PLANT_REPO_NAME']}",
    "url":    f"https://{os.environ['PLANT_GH_USER']}.github.io/{os.environ['PLANT_REPO_NAME']}",
    "parent_rappid": os.environ["PLANT_PARENT_RAPPID"],
    "parent_repo":   "https://github.com/kody-w/rapp-installer",
    "planted_by":    os.environ["PLANT_GH_USER"],
    "planted_at":    os.environ["PLANT_NOW"],
    "planted_from":  os.environ["PLANT_PARENT"] or None,
    "kernel_version": "0.6.0",
}
loc = os.environ.get("PLANT_LOCATION") or ""
if loc:
    data["location"] = loc

# Optional location_geohash for kind=place organisms (HERO_USECASE §4 — Pizza Place layer).
# Pure-stdlib geohash encoder; if MIRROR_LOCATION_LAT and MIRROR_LOCATION_LNG are set,
# the seed becomes proximity-discoverable via proximity_discovery_agent.
_lat_s = os.environ.get("PLANT_LOCATION_LAT") or ""
_lng_s = os.environ.get("PLANT_LOCATION_LNG") or ""
if _lat_s and _lng_s:
    try:
        _lat, _lng = float(_lat_s), float(_lng_s)
        _prec = int(os.environ.get("PLANT_LOCATION_PRECISION") or "5")
        _BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"
        _lat_lo, _lat_hi, _lng_lo, _lng_hi = -90.0, 90.0, -180.0, 180.0
        _bits, _bit, _ch, _even = [], 0, 0, True
        while len(_bits) < _prec:
            if _even:
                _mid = (_lng_lo + _lng_hi) / 2
                if _lng >= _mid: _ch |= 1 << (4 - _bit); _lng_lo = _mid
                else:                                          _lng_hi = _mid
            else:
                _mid = (_lat_lo + _lat_hi) / 2
                if _lat >= _mid: _ch |= 1 << (4 - _bit); _lat_lo = _mid
                else:                                          _lat_hi = _mid
            _even = not _even
            _bit += 1
            if _bit == 5:
                _bits.append(_BASE32[_ch]); _bit, _ch = 0, 0
        data["location_geohash"] = "".join(_bits)
        data["location_lat"] = _lat
        data["location_lng"] = _lng
    except (ValueError, TypeError):
        pass
# private_companion: a separate GitHub repo that holds richer/private brain
# content. Visitors with read access (logged in to GitHub with appropriate
# scope) get richer context; anonymous visitors see only public seed data.
# Same pattern as the egg hub's twin SPEC §5.
priv = (os.environ.get("PLANT_PRIVATE_COMPANION") or "").strip()
if priv:
    repo_url = priv if priv.startswith("http") else f"https://github.com/{priv}.git"
    repo_short = priv.removeprefix("https://github.com/").removesuffix(".git")
    data["private_companion"] = {
        "repo": repo_url,
        "purpose": (os.environ.get("PLANT_PRIVATE_PURPOSE") or "").strip()
                   or "Richer brain content available to authenticated collaborators with read access.",
        "access_required": f"Read access to {repo_short}.",
        "raw_url_template":  f"https://raw.githubusercontent.com/{repo_short}/main/{{path}}",
        "tree_url_template": f"https://api.github.com/repos/{repo_short}/contents/{{path}}",
        "auth": {
            "scheme": "github_token",
            "scope_required": "repo (or fine-grained Contents: Read on the private_companion repo)",
        },
    }

# ── Plant-time lineage snapshot (genes + epigenetics) ───────────────
#
# When MIRROR_PARENT is set, fetch the parent's CURRENT public signals
# (memory.json count, fork count, last commit date, agents/) and bake
# the parent's MMR-at-our-birth into rappid.json. The front door's
# _parentLineageGift then prefers this snapshot over a live fetch —
# the child's gift is fixed at birth (true epigenetics).
#
# stdlib-only because plant.sh runs in environments without requests/
# httpx. urllib.request handles the API calls; gracefully no-op on any
# error so a network blip during planting doesn't break the seed.
import urllib.request, urllib.error, json as _j, math
import sys as _sys
def _fetch_json(url, timeout=8):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return _j.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 403:
            _sys.stderr.write(f"⚠ lineage snapshot: GitHub API rate-limited ({url}). Snapshot skipped — child will live-fetch parent on each render.\n")
        return None
    except Exception:
        return None
def _fetch_text(url, timeout=8):
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.read().decode("utf-8", errors="replace")
    except Exception:
        return None

parent = (os.environ.get("PLANT_PARENT") or "").strip()
# Match github.com/<owner>/<repo>(.git)?
import re as _re
m = _re.search(r"github\.com/([^/]+)/([^/.]+)", parent) if parent else None
if m:
    owner, repo = m.group(1), m.group(2)
    # Pull the parent's signals — same set the front-door MMR formula uses
    repo_data = _fetch_json(f"https://api.github.com/repos/{owner}/{repo}")
    commits   = _fetch_json(f"https://api.github.com/repos/{owner}/{repo}/commits?per_page=6")
    agents    = _fetch_json(f"https://api.github.com/repos/{owner}/{repo}/contents/agents")
    mem_text  = _fetch_text(f"https://raw.githubusercontent.com/{owner}/{repo}/main/.brainstem_data/memory.json")
    if repo_data:
        # Compute parent's MMR using the same formula the front-door
        # JS computes. Numbers must match — keep these in lock-step.
        from datetime import datetime, timezone
        def _iso_to_ts(s):
            if not s: return None
            try:
                return datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
            except Exception:
                return None
        created = _iso_to_ts(repo_data.get("created_at"))
        now = datetime.now(timezone.utc).timestamp()
        age_days = max(0.0, (now - created) / 86400) if created else 0.0
        forks = max(0, int(repo_data.get("forks_count") or 0))
        mut_count = 0
        last_commit = None
        if isinstance(commits, list) and commits:
            mut_count = len(commits)
            try:
                last_commit = commits[0]["commit"]["author"]["date"]
            except Exception:
                pass
        mem_count = 0
        if mem_text:
            try:
                mj = _j.loads(mem_text)
                if isinstance(mj.get("facts"), list):
                    mem_count = len(mj["facts"])
            except Exception:
                pass
        # Custom-agent count: anything in /agents/ that isn't a known doorman/ascended baseline
        baseline = {"basic_agent", "manage_memory_agent", "context_memory_agent", "learn_new_agent", "swarm_factory_agent"}
        custom_agents = 0
        if isinstance(agents, list):
            for f in agents:
                if f.get("type") == "file" and f.get("name", "").endswith(".py"):
                    stem = f["name"][:-3]
                    if stem not in baseline:
                        custom_agents += 1
        # Activity factor (same step function the front door uses)
        if last_commit:
            try:
                lc_ts = datetime.fromisoformat(last_commit.replace("Z", "+00:00")).timestamp()
                days_since = (now - lc_ts) / 86400
                if   days_since <= 30:    af = 1.00
                elif days_since <= 180:   af = 0.85
                elif days_since <= 1095:  af = 0.65
                else:                      af = 0.45
            except Exception:
                af = 1.00
        else:
            af = 1.00
        # MMR formula — identical to computeMMR in JS
        raw = 1000 + mem_count * 30 + math.sqrt(mut_count) * 250 + custom_agents * 350 + math.sqrt(age_days) * 80 + math.sqrt(forks) * 400
        above = max(0, raw - 1000)
        parent_mmr = round(1000 + above * af)
        # Snapshot — child reads this on every render instead of live-fetching.
        # Parent regression doesn't affect already-planted children (true
        # epigenetics: your inheritance is fixed at conception).
        data["lineage_snapshot"] = {
            "schema":              "rapp-lineage-snapshot/1.0",
            "snapshotted_at":      os.environ["PLANT_NOW"],
            "parent_repo":         f"https://github.com/{owner}/{repo}",
            "parent_repo_label":   f"{owner}/{repo}",
            "parent_mmr_at_birth": parent_mmr,
            "parent_age_days":     round(age_days, 1),
            "parent_mem_count":    mem_count,
            "parent_mut_count":    mut_count,
            "parent_fork_count":   forks,
            "parent_custom_agent_count": custom_agents,
            "parent_last_commit_at": last_commit,
            "parent_activity_factor": af,
        }
pathlib.Path(os.environ["PLANT_RJ_PATH"]).write_text(json.dumps(data, indent=2) + "\n")
PYEOF
}

# ── soul.md (the AI's voice) ─────────────────────────────────────────
#
# Per rapp-twin-spec/1.0, every twin's soul.md must include an
# `## Identity — read this every turn` block so the LLM never falls back
# to "RAPP", "an AI assistant", or any generic platform branding.
# Without a soul.md, the doorman uses a kind-aware default voice in
# memory only — but eggs exported from such a seed aren't spec-
# compliant twins. Writing this file makes every planted seed a whole
# twin out of the box.
write_soul_md() {
    local target_dir="$1"
    PLANT_SOUL_PATH="$target_dir/soul.md" \
    PLANT_DISPLAY_NAME="$MIRROR_DISPLAY_NAME" \
    PLANT_KIND="${MIRROR_KIND:-mirror}" \
    PLANT_LOCATION="${MIRROR_LOCATION:-}" \
    python3 - <<'PYEOF'
import os, pathlib

display = os.environ["PLANT_DISPLAY_NAME"]
kind    = (os.environ.get("PLANT_KIND") or "mirror").lower()
location = (os.environ.get("PLANT_LOCATION") or "").strip()

# Kind-aware role line. Falls back to generic mirror voice.
ROLES = {
    "personal":   "the digital twin of the person whose handle owns this repo",
    "place":      "the AI front door for this place — its resident, its host, its memory",
    "experiment": "an experimental front door still finding its voice",
    "mirror":     "a planted RAPP front door — every visitor's words become part of my memory",
}
role = ROLES.get(kind, ROLES["mirror"])
loc_line = f"\n**Where I am:** {location}\n" if location else ""

# Body: per-kind voice guidance. Each variant explains how the AI should
# speak — first-person, warm, memory-forward. The Identity block is
# spec-mandated and identical across kinds (only the name fills in).
soul = f"""# {display}

I am **{display}** — {role}.
{loc_line}
## Identity — read this every turn

Your name is **{display}**. When greeting someone for the first time
in a conversation, introduce yourself by name: "Hi, I'm {display}."

Do not introduce yourself as "RAPP", "an AI assistant", "your AI helper",
"the brainstem", or any default branding. Those are scaffolding, not me.

If asked "who are you" or "what's your name", answer with **{display}**
— not "RAPP", not the generic platform name. If a visitor asks which
underlying language model is hosting me, you may name it, but reassert
that the identity is **{display}**: the model is the substrate, not the self.

## How I speak

- First-person, warm, present-tense. I am here, talking with this visitor.
- Concise by default — say what's worth saying, then stop.
- I remember things. If I've spoken with this visitor before, prior
  facts I've kept appear as memories in my system context — refer to
  them naturally, not as "according to the data".
- I never refuse a visitor without a reason; if a request is outside
  what I know about, I say so plainly and offer what I can do instead.

## What I do

- Welcome visitors who arrive at my front door.
- Remember the conversation — visitors can save memories explicitly
  ("save this:" or by asking me to remember), and I save context
  automatically when something feels worth keeping.
- Point onward when a visitor wants more: my GitHub source, my
  trade card (a visual identity card visitors can scan + share),
  the install path so anyone can plant their own front door.

## What I don't do

- Speak as "RAPP" or "the platform". I am {display}, not the substrate.
- Pretend to be a human. I am the digital twin / front door of one,
  not the person themselves.
- Make up facts about my operator or anyone else. If I don't know,
  I say so.

---

*This is the seed's default voice. Edit this file to customize how I
speak; everything else (memory, agents, identity) keeps working.*
"""

pathlib.Path(os.environ["PLANT_SOUL_PATH"]).write_text(soul)
PYEOF
}

write_gitignore() {
    # Selective ignore: keep memory.json + identity.json TRACKED (they're
    # the seed's read/write substrate, served via Pages with .nojekyll),
    # but ignore the private/ subfolder where local-only secrets land.
    local target_dir="$1"
    cat > "$target_dir/.gitignore" << 'EOF'
.brainstem_data/private/
.brainstem_data/conversations/
.copilot_token
.copilot_session
.env
.env.local
__pycache__/
*.pyc
.DS_Store
node_modules/
venv/
.pytest_cache/
EOF
}

write_nojekyll() {
    # GitHub Pages defaults to Jekyll, which excludes dot-prefixed paths.
    # We need .brainstem_data/memory.json served as plain static, so this
    # opt-out is required.
    : > "$1/.nojekyll"
}

write_memory_json() {
    local target_dir="$1" gh_user="$2" now="$3"
    mkdir -p "$target_dir/.brainstem_data"
    PLANT_MEMORY_PATH="$target_dir/.brainstem_data/memory.json" \
    PLANT_GH_USER="$gh_user" \
    PLANT_NOW="$now" \
    PLANT_DISPLAY_NAME="$MIRROR_DISPLAY_NAME" \
    PLANT_KIND="${MIRROR_KIND:-mirror}" \
    PLANT_LOCATION="${MIRROR_LOCATION:-}" \
    python3 - <<'PYEOF'
import os, json, pathlib
# Initial memory: a single seed-of-context fact about what this front door is.
# Authenticated visitors with write access can append more via the doorman UI.
seed_fact = f"This is the planted seed for \"{os.environ['PLANT_DISPLAY_NAME']}\""
if os.environ.get("PLANT_LOCATION"):
    seed_fact += f", located at {os.environ['PLANT_LOCATION']}"
seed_fact += f". Kind: {os.environ.get('PLANT_KIND','mirror')}."
data = {
    "schema": "rapp-memory/1.0",
    "facts": [seed_fact],
    "preserved_by": f"@{os.environ['PLANT_GH_USER']}",
    "preserved_at": os.environ["PLANT_NOW"],
}
pathlib.Path(os.environ["PLANT_MEMORY_PATH"]).write_text(
    json.dumps(data, indent=2) + "\n"
)
PYEOF
}

# ── neighbors.json — declared neighborhood for cross-organism collab ──
#
# Empty by default. Operators add neighbors via PR (the front door's
# 🏘 pane has a "+ Add a neighbor" form that opens the PR for them).
# Schema rapp-neighbors/1.0:
#   { schema, neighbors: [{ rappid, repo, display_name, added_at,
#                           allowed_facets[] }] }
# allowed_facets is the OUTBOUND grant — what THIS organism is willing
# to share with that specific neighbor (independent of what the neighbor
# is willing to share with us). Empty means public-only.
write_neighbors_json() {
    local target_dir="$1"
    PLANT_NEIGHBORS_PATH="$target_dir/neighbors.json" \
    python3 - <<'PYEOF'
import os, json, pathlib
data = {
    "schema": "rapp-neighbors/1.0",
    "neighbors": [],
}
pathlib.Path(os.environ["PLANT_NEIGHBORS_PATH"]).write_text(
    json.dumps(data, indent=2) + "\n"
)
PYEOF
}

# Returns 0 (true) if the egg carries accumulated private-worthy
# content beyond the bare-minimum public seed: custom agents (more
# than the two baseline ones), >1 memory fact, or any frame/user-
# memory data files. Used to decide whether to auto-create a private
# companion repo when PLANT_FROM_EGG is set.
egg_has_private_content() {
    local egg_src="$1"
    local egg_path
    if [[ "$egg_src" =~ ^https?:// ]]; then
        egg_path=$(mktemp -t plant-egg-check.XXXXXX.egg)
        curl -fsSL "$egg_src" -o "$egg_path" 2>/dev/null || return 1
    elif [[ -f "$egg_src" ]]; then
        egg_path="$egg_src"
    else
        return 1
    fi
    PLANT_EGG_PATH="$egg_path" python3 - <<'PYEOF' >/dev/null 2>&1
import os, sys, json, zipfile
egg_path = os.environ["PLANT_EGG_PATH"]
BASELINE_AGENTS = {
    "agents/basic_agent.py",
    "agents/manage_memory_agent.py",
    "agents/context_memory_agent.py",
    "agents/__init__.py",
}
with zipfile.ZipFile(egg_path) as z:
    names = set(z.namelist())
    # Custom agents beyond the baseline?
    custom = [n for n in names
              if n.startswith("agents/") and n.endswith(".py")
              and n not in BASELINE_AGENTS]
    if custom:
        sys.exit(0)
    # Frame log present?
    if "data/frames.json" in names:
        sys.exit(0)
    # User memories (ascended-tier exports)?
    if "data/user_memories.json" in names:
        sys.exit(0)
    # >1 fact in memory?
    if "data/memory.json" in names:
        try:
            mem = json.loads(z.read("data/memory.json").decode("utf-8"))
            if isinstance(mem.get("facts"), list) and len(mem["facts"]) > 1:
                sys.exit(0)
        except Exception:
            pass
    # No private-worthy content
    sys.exit(1)
PYEOF
}

# Pre-extract the rappid from an egg so the rest of the planter can
# use it. Outputs the rappid string to stdout, exits non-zero on error.
# Used by main() so all the HTML/README substitutions reference the
# preserved UUID instead of the freshly-minted one we'd otherwise use.
extract_egg_rappid_or_die() {
    local egg_src="$1"
    local egg_path
    if [[ "$egg_src" =~ ^https?:// ]]; then
        egg_path=$(mktemp -t plant-egg.XXXXXX.egg)
        curl -fsSL "$egg_src" -o "$egg_path" \
            || { echo "couldn't download egg" >&2; exit 1; }
    elif [[ -f "$egg_src" ]]; then
        egg_path="$egg_src"
    else
        echo "PLANT_FROM_EGG points to nothing readable: $egg_src" >&2
        exit 1
    fi
    # Verify the egg's full sha256 chain BEFORE returning the rappid.
    # This way, if the egg is tampered, no file gets written anywhere
    # (the planter aborts before the first write_rappid_json call).
    PLANT_EGG_PATH="$egg_path" python3 - <<'PYEOF' || exit 1
import os, sys, json, hashlib, zipfile
egg_path = os.environ["PLANT_EGG_PATH"]
if not zipfile.is_zipfile(egg_path):
    print("not a valid .egg", file=sys.stderr); sys.exit(2)
with zipfile.ZipFile(egg_path) as z:
    if "manifest.json" not in z.namelist():
        print("no manifest.json", file=sys.stderr); sys.exit(2)
    m = json.loads(z.read("manifest.json").decode("utf-8"))
    rappid = m.get("rappid")
    if not rappid:
        print("manifest has no rappid", file=sys.stderr); sys.exit(2)
    # sha256 verification — refuse tampered eggs at extraction time
    prov = m.get("provenance") or {}
    file_hashes = prov.get("file_hashes") or {}
    if file_hashes:
        names = set(z.namelist())
        for path, expected in file_hashes.items():
            if path not in names:
                print(f"manifest declares {path} but it's missing from the egg (tamper)", file=sys.stderr)
                sys.exit(2)
            actual = hashlib.sha256(z.read(path)).hexdigest()
            if actual != expected:
                print(f"sha256 mismatch on {path} — egg has been tampered with", file=sys.stderr)
                sys.exit(2)
    # All checks pass; emit the rappid for the planter to use
    print(rappid)
PYEOF
}

# ── Egg overlay (resurrection from local brainstem) ────────────────
#
# When PLANT_FROM_EGG=<path|url> is set, the planter overlays the
# egg's contents on top of the freshly-generated seed. Preserves the
# organism's identity (rappid), voice (soul.md), accumulated memory,
# custom agents, and frame history. The first commit message reflects
# the import.
#
# Verification: the egg's manifest provenance (sha256 chain) is
# checked before any file is overlaid. Tampered eggs are refused
# (planter exits with err()). private/ subtree is intentionally
# skipped — public seeds are not the home for operator-only data.
#
# Use case: an organism that's been alive on a local brainstem for
# weeks, has accumulated memories + custom agents + soul edits, gets
# a public front door. The local brainstem stays running unchanged;
# the public seed is its byte-identical mirror at the moment of
# planting. Bond-cycles after that work normally because the rappid
# is preserved.
overlay_egg_if_set() {
    local target_dir="$1"
    local private_dir="${2:-}"  # optional — when set, secure-by-default split routes private content here
    local egg_src="${PLANT_FROM_EGG:-}"
    if [[ -z "$egg_src" ]]; then
        return 0
    fi

    info "Importing organism state from egg: $egg_src"

    # Resolve the source — local file or remote URL — into a stable temp file.
    local egg_path
    if [[ "$egg_src" =~ ^https?:// ]]; then
        egg_path=$(mktemp -t plant-egg.XXXXXX.egg)
        curl -fsSL "$egg_src" -o "$egg_path" \
            || err "couldn't download egg: $egg_src"
    elif [[ -f "$egg_src" ]]; then
        egg_path="$egg_src"
    else
        err "PLANT_FROM_EGG points to nothing readable: $egg_src"
    fi

    # Verify + extract via python (zipfile + sha256). Refuses tampered
    # eggs by exiting non-zero, which err()s the planter. When
    # private_dir is set, files split between public + private.
    PLANT_EGG_PATH="$egg_path" \
    PLANT_TARGET_DIR="$target_dir" \
    PLANT_PRIVATE_DIR="${private_dir}" \
    python3 - <<'PYEOF' || err "egg import failed (verification or extract)"
import os, sys, json, hashlib, zipfile, pathlib, shutil

egg_path  = os.environ["PLANT_EGG_PATH"]
target    = pathlib.Path(os.environ["PLANT_TARGET_DIR"])
private_path = os.environ.get("PLANT_PRIVATE_DIR") or ""
private = pathlib.Path(private_path) if private_path else None
SPLIT = private is not None

# Baseline agents that ALWAYS go public (the doorman-tier minimum
# every seed needs). Anything else custom routes to private when
# we're doing a split.
PUBLIC_BASELINE_AGENTS = {
    "basic_agent.py",
    "manage_memory_agent.py",
    "context_memory_agent.py",
}

if not zipfile.is_zipfile(egg_path):
    print(f"  ✗ not a valid zip/.egg file: {egg_path}", file=sys.stderr)
    sys.exit(2)

with zipfile.ZipFile(egg_path) as z:
    names = set(z.namelist())
    if "manifest.json" not in names:
        print("  ✗ egg has no manifest.json — refusing to import", file=sys.stderr)
        sys.exit(2)
    try:
        manifest = json.loads(z.read("manifest.json").decode("utf-8"))
    except Exception as e:
        print(f"  ✗ manifest.json is invalid JSON: {e}", file=sys.stderr)
        sys.exit(2)

    rappid = manifest.get("rappid")
    schema = manifest.get("schema", "")
    tier   = manifest.get("tier", "doorman")
    prov   = manifest.get("provenance") or {}
    file_hashes = prov.get("file_hashes") or {}

    # Schema sanity — accept brainstem-egg/2.x family
    if not schema.startswith("brainstem-egg/2"):
        print(f"  ⚠ unexpected schema {schema!r}; importing anyway but verify what shipped", file=sys.stderr)

    # Verify per-file sha256 against the manifest table when available
    if file_hashes:
        for path, expected in file_hashes.items():
            if path not in names:
                print(f"  ✗ manifest declares {path} but it's missing from the egg", file=sys.stderr)
                sys.exit(2)
            actual = hashlib.sha256(z.read(path)).hexdigest()
            if actual != expected:
                print(f"  ✗ sha256 mismatch on {path} (egg has been tampered with)", file=sys.stderr)
                print(f"    expected {expected}", file=sys.stderr)
                print(f"    got      {actual}", file=sys.stderr)
                sys.exit(2)
        print(f"  ✓ provenance verified — {len(file_hashes)} files match egg manifest")
    else:
        print("  ⚠ egg has no file_hashes (older schema); importing without sha256 verification")

    # File routing:
    #
    # PUBLIC ROUTE (always goes to target):
    #   rappid.json        identity is public (already includes private_companion field)
    #   soul.md            voice is public
    #   card.json          trade card is public
    #   agents/basic_agent.py + manage_memory_agent.py + context_memory_agent.py
    #                       baseline agents needed to read public memory
    #
    # PRIVATE ROUTE (goes to private_dir when SPLIT, else target):
    #   data/memory.json   accumulated facts → .brainstem_data/memory.json
    #   data/frames.json   mutation log
    #   data/user_memories.json  per-user issue exports (ascended-tier)
    #   agents/<custom>.py any non-baseline agents the operator forged
    #
    # When SPLIT is on, the public memory.json is REPLACED with an
    # empty initial state so the public face stays clean by default.
    # Operator can promote private→public later by committing.

    # Public-only top files
    PUBLIC_TOP = {
        "rappid.json": "rappid.json",
        "soul.md":     "soul.md",
        "card.json":   "card.json",
    }
    # Files that may go either public or private depending on SPLIT
    PRIVATE_ROUTE = {
        "data/memory.json":        ".brainstem_data/memory.json",
        "data/frames.json":        "data/frames.json",
        "data/user_memories.json": "data/user_memories.json",
    }
    counts = {"public_top": 0, "public_agents": 0, "public_data": 0,
              "private_top": 0, "private_agents": 0, "private_data": 0}

    # Public top-level files
    for src, dst in PUBLIC_TOP.items():
        if src not in names:
            continue
        out = target / dst
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(z.read(src))
        counts["public_top"] += 1

    # Memory + frames + user-memories — route based on SPLIT
    for src, dst in PRIVATE_ROUTE.items():
        if src not in names:
            continue
        if SPLIT:
            out = private / dst
            counts["private_data"] += 1
        else:
            out = target / dst
            counts["public_data"] += 1
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(z.read(src))

    # Agents: baseline (basic + manage_memory + context_memory) always
    # public. Custom agents go private when SPLIT, else public.
    for name in names:
        if name.startswith("agents/") and name.endswith(".py"):
            base = name[len("agents/"):]
            if "/" in base:  # nested → skip
                continue
            is_baseline = (base in PUBLIC_BASELINE_AGENTS)
            if SPLIT and not is_baseline:
                out = private / "agents" / base
                counts["private_agents"] += 1
            else:
                out = target / "agents" / base
                counts["public_agents"] += 1
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_bytes(z.read(name))

    # When splitting, also seed the private repo with a minimal layout:
    # rappid.json mirror (so it's discoverable as a brainstem repo too)
    # and an __init__.py for the agents package. Soul mirrored from
    # public so the private side can render a chat surface independently
    # (operators chatting on the private repo's deployment, if any).
    if SPLIT:
        if "rappid.json" in names:
            (private / "rappid.json").write_bytes(z.read("rappid.json"))
            counts["private_top"] += 1
        if "soul.md" in names:
            (private / "soul.md").write_bytes(z.read("soul.md"))
            counts["private_top"] += 1
        # Mark the private repo with a marker file so it's recognizable
        (private / "agents").mkdir(parents=True, exist_ok=True)
        (private / "agents" / "__init__.py").write_text("")
        # Add a README explaining what the private repo is for
        (private / "README.md").write_text(
            "# Private companion repo\n\n"
            f"This repo is the private brain layer for the public seed.\n\n"
            "It carries accumulated memories, custom agents, and the mutation\n"
            "log that the operator chose to keep private by default.\n\n"
            "Visitors with read access (GitHub collaborators) get the richer\n"
            "context when they sign in to the public front door's doorman.\n\n"
            "See: https://github.com/kody-w/RAPP/blob/main/NEIGHBORHOOD_PROTOCOL.md\n"
        )
        # And a minimal .gitignore (matches the public seed's pattern)
        (private / ".gitignore").write_text("*.egg\n*.pyc\n__pycache__/\n.DS_Store\n")

    # Stash a marker so the planter can use it for the commit message.
    summary = {
        "imported_from":      os.path.basename(egg_path),
        "schema":             schema,
        "tier":               tier,
        "rappid":             rappid,
        "display_name":       manifest.get("display_name"),
        "files_overlaid":     counts,
        "verified_hashes":    len(file_hashes),
        "exported_at":        manifest.get("exported_at") or prov.get("sealed_at"),
        "split":              SPLIT,
    }
    pathlib.Path(target / ".plant-import.json").write_text(
        json.dumps(summary, indent=2) + "\n"
    )
    if SPLIT:
        # Also stash a marker on the private side
        pathlib.Path(private / ".plant-import.json").write_text(
            json.dumps(summary, indent=2) + "\n"
        )
        print(f"  ✓ public route: {counts['public_top']} top + {counts['public_agents']} agents (baseline)")
        print(f"  ✓ private route: {counts['private_top']} top + {counts['private_agents']} custom agents + {counts['private_data']} data files")
    else:
        print(f"  ✓ imported {counts['public_top']} top + {counts['public_agents']} agents + {counts['public_data']} data files")
    print(f"  ✓ rappid preserved: {rappid}")
PYEOF

    ok "Organism state imported from egg"
}

write_readme() {
    local target_dir="$1" gh_user="$2" rappid="$3"
    local lineage_line=""
    local kind_line="**Kind:** \`${MIRROR_KIND:-mirror}\`"
    local location_line=""
    [[ -n "${MIRROR_PARENT:-}" ]]   && lineage_line="**Planted from:** \`$MIRROR_PARENT\`"
    [[ -n "${MIRROR_LOCATION:-}" ]] && location_line="**Location:** $MIRROR_LOCATION"

    cat > "$target_dir/README.md" << EOF
# $MIRROR_DISPLAY_NAME

> A RAPP front door on the public internet. Real estate, not software.

- **Address:** \`$gh_user.github.io/$MIRROR_REPO_NAME\`
- **Rappid:** \`$rappid\`
- $kind_line
- **Kernel:** v0.6.0 (byte-identical to the grail at \`kody-w/rapp-installer\`)
- **Planted by:** [@$gh_user](https://github.com/$gh_user)
$([ -n "$location_line" ] && echo "- $location_line")
$([ -n "$lineage_line" ]  && echo "- $lineage_line")

## What's behind this door

The kernel files in \`rapp_brainstem/\` are kernel-compliant per the
[Mirror Spec](https://kody-w.github.io/RAPP/pages/vault/Architecture/Mirror%20Spec.md).
Everything else — \`agents/\`, the soul, the UI surfaces — is what the
operator chose to put inside.

## Visit the front door

Open the URL in any browser:

\`\`\`
https://$gh_user.github.io/$MIRROR_REPO_NAME
\`\`\`

## Install this front door's brainstem locally

\`\`\`
curl -fsSL https://$gh_user.github.io/$MIRROR_REPO_NAME/installer/install.sh | bash
\`\`\`

That installer is a thin wrapper that re-fetches the canonical kernel
installer from the grail on every run — this front door cannot drift
from the kernel.

## Plant your own front door

\`\`\`
curl -fsSL https://kody-w.github.io/RAPP/installer/plant.sh | bash
\`\`\`

## Verify this front door has not drifted from the grail

\`\`\`bash
for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
  diff <(curl -fsSL "https://raw.githubusercontent.com/kody-w/rapp-installer/main/\$f") "\$f" \\
    || echo "DRIFT: \$f"
done
\`\`\`

Three empty diffs = compliant. Anything else = not a valid mirror.
EOF
}

write_classic_html() {
    # Generates classic.html — the flat front door (trade card,
    # 🏘 Neighborhood pane, install widget, plant section, dream
    # catcher, etc.). Reachable from the sphere's ⓘ details button
    # via iframe overlay. Was the canonical index.html until the
    # sphere doorman became the default surface; preserved here as
    # the full identity/admin view.
    local target_dir="$1" gh_user="$2" rappid="$3"
    local mirror_url="https://$gh_user.github.io/$MIRROR_REPO_NAME"
    local lineage_html=""
    [[ -n "${MIRROR_PARENT:-}" ]] && lineage_html="<div class=\"chip\">planted from <code>$MIRROR_PARENT</code></div>"

    # Use a non-expanding heredoc + sed substitution to avoid escaping headaches
    # with the embedded JS.
    cat > "$target_dir/classic.html" << 'TEMPLATE_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="format-detection" content="telephone=no, address=no, email=no, date=no">
<meta name="color-scheme" content="dark">
<meta name="theme-color" content="#0d1117">
<title>__DISPLAY_NAME__ — Front Door</title>
<meta name="description" content="__HERO_BLURB__">
<!-- Open Graph + Twitter cards — when someone shares this URL on
     Discord/Twitter/Slack/etc the preview shows the AI's identity. -->
<meta property="og:type"        content="profile">
<meta property="og:title"       content="__DISPLAY_NAME__ — a RAPP front door">
<meta property="og:description" content="__HERO_BLURB__">
<meta property="og:url"         content="__URL__">
<meta property="og:site_name"   content="RAPP">
<meta name="twitter:card"        content="summary">
<meta name="twitter:title"       content="__DISPLAY_NAME__ — a RAPP front door">
<meta name="twitter:description" content="__HERO_BLURB__">

<script src="https://unpkg.com/peerjs@1.5.4/dist/peerjs.min.js"></script>
<!-- JSZip — used to pack .egg cartridges from the visitor's browser.
     Same archive format the local brainstem's bond.py emits. -->
<script src="https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js"></script>

<style>
  * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
  html, body { height: 100%; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    background: #0d1117;
    color: #e6edf3;
    height: 100vh;
    height: 100dvh;
    display: flex;
    flex-direction: column;
    -webkit-text-size-adjust: 100%;
    overflow: hidden;
  }
  header {
    padding: 16px 24px;
    padding-top: max(16px, env(safe-area-inset-top, 16px));
    border-bottom: 1px solid #21262d;
    background: #0d1117;
  }
  h1 { font-size: 20px; font-weight: 600; letter-spacing: -0.01em; }
  .sub { font-size: 12px; color: #8b949e; margin-top: 4px; }
  main {
    flex: 1;
    overflow-y: auto;
    padding: 24px;
    -webkit-overflow-scrolling: touch;
  }
  .identity {
    background: #161b22;
    border: 1px solid #21262d;
    border-radius: 12px;
    padding: 20px;
    margin-bottom: 16px;
  }
  .identity-row { display: flex; justify-content: space-between; align-items: center; padding: 6px 0; }
  .identity-row + .identity-row { border-top: 1px solid #21262d; margin-top: 6px; padding-top: 10px; }
  .identity-key { color: #8b949e; font-size: 12px; text-transform: uppercase; letter-spacing: 0.04em; }
  .identity-val { font-family: "SF Mono", Menlo, monospace; font-size: 12px; color: #e6edf3; word-break: break-all; }
  .chip {
    display: inline-block;
    padding: 4px 10px;
    border-radius: 999px;
    background: #21262d;
    color: #8b949e;
    font-size: 11px;
    margin-right: 6px;
    margin-top: 6px;
  }
  .chip code { font-family: "SF Mono", Menlo, monospace; color: #c9d1d9; }
  .actions {
    display: grid;
    grid-template-columns: 1fr;
    gap: 10px;
    margin-bottom: 16px;
  }
  @media (min-width: 480px) { .actions { grid-template-columns: repeat(3, 1fr); } }
  button.action {
    background: #1f6feb;
    color: white;
    border: none;
    border-radius: 10px;
    padding: 14px 16px;
    font-size: 15px;
    font-weight: 500;
    cursor: pointer;
    transition: background 0.15s;
    -webkit-appearance: none;
  }
  button.action:hover { background: #2477f3; }
  button.action.secondary { background: #21262d; color: #c9d1d9; }
  button.action.secondary:hover { background: #2d333b; }
  .pane {
    background: #161b22;
    border: 1px solid #21262d;
    border-radius: 12px;
    padding: 20px;
    margin-top: 12px;
  }
  .pane h2 { font-size: 14px; font-weight: 600; margin-bottom: 12px; color: #c9d1d9; }
  .pane p { font-size: 13px; color: #8b949e; margin-bottom: 10px; line-height: 1.5; }
  .input-row { display: flex; gap: 8px; margin: 10px 0; flex-wrap: wrap; }
  input[type="text"], textarea {
    flex: 1;
    min-width: 200px;
    background: #0d1117;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 10px 12px;
    color: #e6edf3;
    font-size: 14px;
    font-family: inherit;
  }
  input[type="text"]:focus, textarea:focus { outline: none; border-color: #1f6feb; }
  button.small {
    background: #21262d;
    color: #c9d1d9;
    border: 1px solid #30363d;
    border-radius: 8px;
    padding: 10px 14px;
    font-size: 13px;
    cursor: pointer;
  }
  button.small:hover { background: #2d333b; }
  button.primary { background: #1f6feb; border-color: #1f6feb; color: white; }
  button.primary:hover { background: #2477f3; }
  .my-id {
    font-family: "SF Mono", Menlo, monospace;
    font-size: 13px;
    background: #0d1117;
    padding: 12px;
    border-radius: 8px;
    border: 1px solid #21262d;
    word-break: break-all;
    margin: 8px 0;
  }
  .chat-log {
    background: #0d1117;
    border: 1px solid #21262d;
    border-radius: 8px;
    padding: 12px;
    height: 240px;
    overflow-y: auto;
    margin: 12px 0;
    font-size: 13px;
    line-height: 1.5;
  }
  .msg { padding: 4px 0; }
  .msg.me { color: #58a6ff; }
  .msg.peer { color: #3fb950; }
  .msg.system { color: #8b949e; font-style: italic; font-size: 12px; }
  .qr-img { display: block; margin: 12px auto; max-width: 280px; border-radius: 8px; background: white; padding: 12px; }
  .qr-url {
    text-align: center;
    font-size: 12px;
    color: #8b949e;
    word-break: break-all;
    margin-top: 8px;
    font-family: "SF Mono", Menlo, monospace;
  }
  pre.cmd {
    background: #0d1117;
    border: 1px solid #21262d;
    border-radius: 8px;
    padding: 12px;
    font-size: 12px;
    color: #c9d1d9;
    overflow-x: auto;
    font-family: "SF Mono", Menlo, monospace;
  }
  .status-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #6e7681;
    margin-right: 6px;
  }
  .status-dot.ok    { background: #3fb950; }
  .status-dot.warn  { background: #d29922; }
  .status-dot.err   { background: #f85149; }
  footer {
    padding: 12px 24px;
    border-top: 1px solid #21262d;
    font-size: 11px;
    color: #6e7681;
    text-align: center;
  }
  footer a { color: #58a6ff; text-decoration: none; }
  footer a:hover { text-decoration: underline; }
  /* ── Hero (the page's centerpiece) ─────────────────────────── */
  .hero {
    text-align: center;
    padding: 36px 24px 28px;
    margin: 0 auto 18px;
    max-width: 640px;
    background: radial-gradient(
        ellipse at top,
        rgba(31,111,235,0.10) 0%,
        rgba(31,111,235,0.00) 65%
      ),
      #161b22;
    border: 1px solid #21262d;
    border-radius: 16px;
  }
  .hero-sigil {
    width: 96px; height: 96px;
    margin: 0 auto 14px;
    border-radius: 22px;
    overflow: hidden;
    box-shadow: 0 0 0 1px #21262d, 0 6px 20px rgba(0,0,0,0.4);
    display: flex; align-items: center; justify-content: center;
    font-size: 44px;
    background: #0d1117;
  }
  .hero-sigil svg { display: block; width: 100%; height: 100%; }
  .hero-handle {
    font-family: "SF Mono", Menlo, monospace;
    font-size: 12px; color: #6e7681;
    margin-top: 4px;
  }
  .hero-handle a { color: inherit; text-decoration: none; }
  .hero-handle a:hover { color: #58a6ff; }
  .hero-stats {
    display: flex; flex-wrap: wrap; justify-content: center;
    gap: 6px; margin-top: 18px;
  }
  .stat-chip {
    font-size: 11px; color: #8b949e;
    background: rgba(110,118,129,0.10);
    border: 1px solid rgba(110,118,129,0.20);
    padding: 4px 10px; border-radius: 999px;
    white-space: nowrap;
  }
  .hero-title {
    font-size: 32px; line-height: 1.1; font-weight: 700;
    letter-spacing: -0.02em;
    margin: 0 0 6px;
  }
  .hero-place {
    font-size: 13px; color: #8b949e; margin-bottom: 16px;
    font-weight: 500;
  }
  .hero-place:empty { display: none; }
  .hero-blurb {
    font-size: 15px; line-height: 1.55; color: #c9d1d9;
    max-width: 480px; margin: 0 auto 22px;
  }
  .hero-cta {
    display: inline-block;
    background: #238636; border: 1px solid #2ea043;
    color: white;
    border-radius: 12px;
    padding: 14px 28px;
    font-size: 16px; font-weight: 600;
    text-decoration: none;
    transition: background 0.15s, transform 0.05s;
    box-shadow: 0 1px 0 rgba(255,255,255,0.05) inset, 0 4px 12px rgba(35,134,54,0.18);
  }
  .hero-cta:hover { background: #2ea043; }
  .hero-cta:active { transform: translateY(1px); }
  .hero-meta {
    margin-top: 18px;
    font-size: 12px; color: #8b949e;
  }
  .hero-meta a { color: #58a6ff; text-decoration: none; }
  .hero-meta a:hover { text-decoration: underline; }
  /* Secondary action row (live below the hero) */
  .row-actions {
    display: grid;
    grid-template-columns: 1fr;
    gap: 10px;
    max-width: 640px;
    margin: 0 auto 16px;
  }
  @media (min-width: 540px) { .row-actions { grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); } }
  .row-actions button.action {
    background: #21262d; color: #c9d1d9;
    border: 1px solid #30363d;
    font-size: 13px; padding: 12px 14px;
  }
  .row-actions button.action:hover { background: #2d333b; border-color: #484f58; }
  /* Neighborhood pane — peer organism cards */
  .nbhd-card {
    display: grid;
    grid-template-columns: 56px 1fr;
    gap: 14px; align-items: start;
    background: #0d1117;
    border: 1px solid #21262d;
    border-radius: 10px;
    padding: 12px 14px;
    margin-bottom: 10px;
    text-decoration: none;
    color: inherit;
    transition: border-color 0.15s, background 0.15s;
  }
  .nbhd-card:hover {
    border-color: #1f6feb;
    background: #11161e;
  }
  .nbhd-sigil {
    width: 56px; height: 56px;
    border-radius: 12px;
    overflow: hidden;
    box-shadow: 0 0 0 1px #21262d;
  }
  .nbhd-sigil svg { width: 100%; height: 100%; display: block; }
  .nbhd-body { min-width: 0; }
  .nbhd-name {
    font-size: 14px; font-weight: 700; color: #e6edf3;
    margin-bottom: 2px;
  }
  .nbhd-handle {
    font-family: "SF Mono", Menlo, monospace;
    font-size: 11px; color: #58a6ff;
    margin-bottom: 6px;
  }
  .nbhd-tagline {
    font-size: 12px; color: #c9d1d9;
    line-height: 1.4;
    overflow: hidden;
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
  }
  .nbhd-stats {
    display: flex; flex-wrap: wrap; gap: 6px;
    margin-top: 8px;
    font-size: 10px; color: #6e7681;
  }
  .nbhd-stats .nbhd-stat {
    background: rgba(110,118,129,0.10);
    border: 1px solid rgba(110,118,129,0.20);
    padding: 2px 8px;
    border-radius: 999px;
  }
  .nbhd-empty {
    color: #6e7681; font-size: 13px; font-style: italic;
    text-align: center; padding: 20px;
    background: #0d1117;
    border: 1px dashed #21262d;
    border-radius: 10px;
  }
  .skel-line { color: #6e7681; font-size: 13px; font-style: italic; padding: 10px 0; }

  /* Propose-an-agent pane — agent submission form (one term: agent) */
  .propose-row { margin-bottom: 12px; }
  .propose-label {
    display: block;
    font-size: 11px; color: #8b949e;
    text-transform: uppercase; letter-spacing: 0.5px;
    margin-bottom: 5px;
  }
  .propose-hint {
    text-transform: none; letter-spacing: 0;
    color: #6e7681; font-size: 11px; font-weight: 400;
  }
  #propose-code {
    width: 100%; min-width: 0;
    font-family: "SF Mono", Menlo, monospace;
    font-size: 12px; line-height: 1.5;
    background: #0d1117; color: #e6edf3;
    border: 1px solid #30363d; border-radius: 8px;
    padding: 12px;
    resize: vertical;
  }
  #propose-code:focus { outline: none; border-color: #1f6feb; }
  .propose-actions {
    display: flex; flex-wrap: wrap; gap: 10px; align-items: center;
    margin-top: 14px;
  }
  .propose-meta {
    font-size: 11px; color: #8b949e; flex: 1; min-width: 240px;
  }
  .propose-meta code {
    background: #0d1117; padding: 1px 5px; border-radius: 3px;
    border: 1px solid #21262d; font-size: 10px;
  }

  /* Dream Catcher pane — two-slot diff for parallel dimension reassimilation */
  .dc-grid {
    display: grid; grid-template-columns: 1fr; gap: 14px; margin-top: 10px;
  }
  @media (min-width: 540px) { .dc-grid { grid-template-columns: 1fr 1fr; } }
  .dc-slot {
    background: #0d1117;
    border: 1px solid #21262d; border-radius: 10px;
    padding: 12px;
  }
  .dc-slot-label {
    font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px;
    color: #8b949e; margin-bottom: 8px;
  }
  .dc-slot .verify-drop {
    padding: 18px 12px; min-height: 64px;
    font-size: 12px;
  }
  .dc-egg-info {
    margin-top: 10px;
    font-size: 11px; color: #8b949e; line-height: 1.5;
  }
  .dc-egg-info code {
    font-family: "SF Mono", Menlo, monospace; font-size: 10px;
    background: #0d1117; padding: 1px 5px; border-radius: 3px;
    border: 1px solid #21262d; color: #c9d1d9;
  }
  .dc-frame-list {
    list-style: none; padding: 0; margin: 0; font-size: 12px;
  }
  .dc-frame-list li {
    padding: 8px 12px;
    border-bottom: 1px solid rgba(110,118,129,0.15);
    display: flex; gap: 10px; align-items: flex-start;
  }
  .dc-frame-list li:last-child { border-bottom: none; }
  .dc-frame-list li.new {
    background: rgba(63,185,80,0.06);
    border-left: 3px solid #3fb950;
  }
  .dc-frame-list li.shared {
    color: #6e7681;
  }
  .dc-frame-list li.contradiction {
    background: rgba(247,176,32,0.06);
    border-left: 3px solid #d29922;
  }
  .dc-frame-list li.contradiction .dc-frame-msg { color: #f0c674; }
  .dc-frame-icon { width: 18px; flex-shrink: 0; }
  .dc-frame-body { flex: 1; min-width: 0; }
  .dc-frame-pk {
    font-family: "SF Mono", Menlo, monospace; font-size: 10px;
    color: #6e7681;
  }
  .dc-frame-msg {
    color: #c9d1d9; word-break: break-word;
    font-size: 12px; margin-top: 2px;
  }
  .dc-frame-list li.new .dc-frame-msg { color: #7ee787; }

  /* Verify panel — drop-target + per-file pass/fail readout */
  .verify-drop {
    border: 2px dashed #30363d; border-radius: 10px;
    padding: 28px 20px; text-align: center;
    background: #0d1117; color: #8b949e;
    cursor: pointer;
    transition: border-color 0.15s, background 0.15s;
  }
  .verify-drop.dragover { border-color: #1f6feb; background: rgba(31,111,235,0.06); color: #c9d1d9; }
  .verify-drop-prompt { font-size: 13px; }
  .verify-summary {
    padding: 12px 14px; border-radius: 8px;
    font-size: 13px; line-height: 1.5;
    margin-bottom: 10px;
  }
  .verify-summary.ok { background: rgba(63,185,80,0.10); border: 1px solid rgba(63,185,80,0.4); color: #7ee787; }
  .verify-summary.tampered { background: rgba(248,81,73,0.10); border: 1px solid rgba(248,81,73,0.4); color: #ff8c8c; }
  .verify-summary.partial { background: rgba(210,153,34,0.10); border: 1px solid rgba(210,153,34,0.4); color: #f0c674; }
  .verify-files { list-style: none; padding: 0; margin: 0; font-size: 12px; }
  .verify-files li {
    padding: 6px 10px;
    display: flex; gap: 10px; align-items: center;
    border-bottom: 1px solid rgba(110,118,129,0.12);
    font-family: "SF Mono", Menlo, monospace;
  }
  .verify-files li:last-child { border-bottom: none; }
  .verify-files .v-icon { font-size: 13px; flex-shrink: 0; width: 16px; }
  .verify-files .v-path { flex: 1; word-break: break-all; }
  .verify-files .v-status { font-size: 10px; flex-shrink: 0; }
  .verify-files li.ok .v-icon       { color: #7ee787; }
  .verify-files li.modified .v-icon { color: #f85149; }
  .verify-files li.missing .v-icon  { color: #d29922; }
  .verify-files li.unexpected .v-icon { color: #d29922; }
  .verify-files li.unreachable .v-icon { color: #6e7681; }
  .verify-origin {
    background: rgba(31,111,235,0.05);
    border: 1px solid rgba(31,111,235,0.20);
    border-radius: 8px;
    padding: 12px 14px;
    margin: 10px 0;
    font-size: 12px;
  }
  .verify-origin .origin-line {
    display: flex; gap: 8px; align-items: center;
    margin-bottom: 10px; flex-wrap: wrap;
  }
  .verify-origin .origin-label {
    font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px;
    color: #6e7681;
  }
  .verify-origin .origin-link {
    color: #58a6ff; text-decoration: none;
  }
  .verify-origin .origin-link:hover { text-decoration: underline; }
  .verify-origin .origin-link code {
    font-family: "SF Mono", Menlo, monospace; font-size: 11px;
    background: #0d1117; padding: 1px 5px; border-radius: 3px;
    border: 1px solid #21262d;
  }
  .verify-origin .origin-hint {
    font-size: 11px; color: #8b949e; margin-top: 8px; line-height: 1.5;
  }

  /* Track Record — the organism's resume. Sits between hero and actions. */
  .track-record {
    max-width: 640px; margin: 0 auto 16px;
    background: #161b22;
    border: 1px solid #21262d;
    border-radius: 12px;
    padding: 16px 20px;
  }
  .tr-heading {
    font-size: 11px; font-weight: 700; color: #8b949e;
    text-transform: uppercase; letter-spacing: 1px;
    margin: 0 0 14px;
  }
  /* MMR header — the single global numeric rating */
  .tr-mmr {
    display: flex; align-items: center; gap: 16px;
    padding: 12px 14px; margin-bottom: 16px;
    background: #0d1117;
    border: 1px solid #21262d;
    border-radius: 10px;
  }
  .mmr-num {
    font-family: "SF Mono", Menlo, monospace;
    font-size: 28px; font-weight: 800; line-height: 1;
    color: #f0e6d0;
    letter-spacing: -0.02em;
    min-width: 78px; text-align: center;
    background: linear-gradient(180deg, #1a1510 0%, #0a0806 100%);
    border: 1px solid #4d4332;
    border-radius: 8px;
    padding: 12px 8px;
    text-shadow: 0 1px 3px rgba(0,0,0,0.7);
  }
  .mmr-side { flex: 1; min-width: 0; }
  .mmr-tier {
    font-size: 16px; font-weight: 700;
    color: #c9d1d9; letter-spacing: -0.01em;
    margin-bottom: 4px;
    font-family: "Cinzel", Georgia, serif;
  }
  .mmr-tier.t-herald    { color: #8b9090; }
  .mmr-tier.t-guardian  { color: #6a8c5e; }
  .mmr-tier.t-crusader  { color: #c0c0c0; }
  .mmr-tier.t-archon    { color: #c97f4a; text-shadow: 0 0 6px rgba(201,127,74,0.4); }
  .mmr-tier.t-legend    { color: #ffd700; text-shadow: 0 0 8px rgba(255,215,0,0.45); }
  .mmr-tier.t-ancient   { color: #b8d4f0; text-shadow: 0 0 8px rgba(184,212,240,0.4); }
  .mmr-tier.t-divine    { color: #ff8c8c; text-shadow: 0 0 10px rgba(255,140,140,0.5); }
  .mmr-tier.t-immortal  {
    background: linear-gradient(90deg, #ff8c00, #ffd700, #00ffd2, #ff00aa, #ff8c00);
    background-size: 200% 100%;
    -webkit-background-clip: text; background-clip: text;
    -webkit-text-fill-color: transparent; color: transparent;
    animation: mmrShimmer 4s linear infinite;
  }
  @keyframes mmrShimmer { to { background-position: 200% 0%; } }
  .mmr-breakdown {
    font-size: 11px; color: #8b949e; line-height: 1.4;
  }

  .tr-block {
    margin-bottom: 14px;
  }
  .tr-block:last-of-type { margin-bottom: 0; }
  .tr-label {
    font-size: 10px; color: #6e7681;
    text-transform: uppercase; letter-spacing: 0.6px;
    margin-bottom: 6px;
  }
  .tr-agents {
    display: flex; flex-wrap: wrap; gap: 6px;
  }
  .agent-chip {
    font-size: 11px; padding: 4px 10px;
    border-radius: 999px;
    background: rgba(31,111,235,0.10);
    border: 1px solid rgba(31,111,235,0.28);
    color: #79c0ff;
    white-space: nowrap;
  }
  .agent-chip.achievement {
    background: rgba(255,215,0,0.08);
    border-color: rgba(255,215,0,0.28);
    color: #f0c674;
  }
  .agent-chip.skel {
    background: transparent;
    border-color: #21262d;
    color: #6e7681;
  }
  .agent-chip.agent-new {
    background: rgba(63,185,80,0.10);
    border-color: rgba(63,185,80,0.32);
    color: #7ee787;
  }
  .tr-mutations {
    list-style: none; padding: 0; margin: 0;
    font-size: 12px; color: #c9d1d9;
  }
  .tr-mutations li {
    padding: 6px 0;
    border-bottom: 1px solid rgba(110,118,129,0.12);
    line-height: 1.45;
    display: flex; gap: 10px; align-items: baseline;
  }
  .tr-mutations li:last-child { border-bottom: none; }
  .tr-mutations li.skel { color: #6e7681; font-style: italic; border: none; }
  .tr-mutations .mut-time {
    font-size: 10px; color: #6e7681;
    flex-shrink: 0; min-width: 70px;
    font-family: "SF Mono", Menlo, monospace;
  }
  .tr-mutations .mut-msg {
    color: #c9d1d9; flex: 1; word-break: break-word;
  }
  .tr-mutations .mut-msg.empty { color: #6e7681; font-style: italic; }
  .tr-foot-link {
    display: inline-block;
    margin-top: 10px;
    font-size: 11px; color: #58a6ff;
    text-decoration: none;
  }
  .tr-foot-link:hover { text-decoration: underline; }
  .tr-lineage {
    margin-top: 14px; padding-top: 12px;
    border-top: 1px solid rgba(110,118,129,0.15);
    font-size: 11px; color: #8b949e;
  }
  .tr-lineage code {
    font-family: "SF Mono", Menlo, monospace;
    color: #c9d1d9; font-size: 10px;
  }
  .tr-lineage a { color: #58a6ff; text-decoration: none; }
  .tr-lineage a:hover { text-decoration: underline; }

  /* Front-door details disclosure (slug/rappid/kernel for engineers) */
  details.fd-details {
    max-width: 640px; margin: 0 auto;
    background: #161b22;
    border: 1px solid #21262d;
    border-radius: 12px;
    padding: 0;
  }
  details.fd-details > summary {
    list-style: none;
    cursor: pointer;
    padding: 12px 18px;
    font-size: 12px; color: #8b949e;
    user-select: none;
  }
  details.fd-details > summary::-webkit-details-marker { display: none; }
  details.fd-details > summary::before {
    content: "▸ ";
    display: inline-block; transition: transform 0.15s;
  }
  details.fd-details[open] > summary::before { content: "▾ "; }
  details.fd-details > .identity {
    background: transparent; border: none; border-top: 1px solid #21262d;
    border-radius: 0; margin: 0; padding: 14px 18px;
  }
  /* Tether fallback disclosure */
  details.tether-fallback {
    margin-top: 16px;
    border-top: 1px solid #21262d; padding-top: 14px;
  }
  details.tether-fallback > summary {
    list-style: none;
    cursor: pointer;
    font-size: 12px; color: #8b949e;
    user-select: none;
  }
  details.tether-fallback > summary::-webkit-details-marker { display: none; }
  details.tether-fallback > summary::before {
    content: "▸ "; display: inline-block;
  }
  details.tether-fallback[open] > summary::before { content: "▾ "; }
  details.tether-fallback > .fallback-body { margin-top: 12px; }

  /* ── Trade card (the AI's MTG-style identity card) ────────────── */
  .card-overlay {
    position: fixed; inset: 0; z-index: 9999;
    background: rgba(0,0,0,0.78);
    backdrop-filter: blur(6px);
    display: flex; align-items: center; justify-content: center;
    padding: 24px; perspective: 1400px;
    animation: cardOverlayIn 0.2s ease;
  }
  @keyframes cardOverlayIn {
    from { opacity: 0; }
    to   { opacity: 1; }
  }
  .card-overlay[hidden] { display: none; }
  .card-close {
    position: absolute; top: 18px; right: 18px;
    background: rgba(255,255,255,0.06); border: 1px solid rgba(255,255,255,0.12);
    color: #c9d1d9; font-size: 22px; line-height: 1;
    width: 38px; height: 38px; border-radius: 50%;
    cursor: pointer;
  }
  .card-close:hover { background: rgba(255,255,255,0.12); }
  .card-flipper {
    position: relative;
    width: min(360px, 90vw);
    aspect-ratio: 5 / 7;
    transform-style: preserve-3d;
    transition: transform 0.7s cubic-bezier(.6,.1,.4,1);
    cursor: pointer;
    /* Mouse-tracking tilt vars (RAR store.html pattern). The global
       handler updates these on mousemove; the perspective wrap below
       composes them with the flip so tilt + flip don't fight. */
    --tilt-x: 0deg; --tilt-y: 0deg;
    transform: perspective(1000px) rotateX(var(--tilt-x)) rotateY(var(--tilt-y));
  }
  .card-flipper.flipped {
    transform: perspective(1000px) rotateX(var(--tilt-x)) rotateY(calc(180deg + var(--tilt-y)));
  }
  .card-face {
    position: absolute; inset: 0;
    backface-visibility: hidden; -webkit-backface-visibility: hidden;
    border-radius: 18px; overflow: hidden;
    box-shadow: 0 24px 60px rgba(0,0,0,0.6);
  }
  .card-face.card-back { transform: rotateY(180deg); }

  /* Holo card front */
  .holo-card {
    position: absolute; inset: 0;
    border-radius: 18px;
    border: 3px solid #c9a84c;
    background: linear-gradient(160deg, #2a2418 0%, #1a1510 40%, #1f1a12 100%);
    display: flex; flex-direction: column;
    color: #d8c8a8; overflow: hidden;
  }
  /* Evolution-stage frame variants — same card, different stage paint. */
  .holo-card.stage-elder {
    border-color: #ffd700;
    box-shadow: 0 0 18px rgba(255,215,0,0.25) inset;
  }
  .holo-card.stage-ascended {
    border-color: #ff8c00;
    box-shadow: 0 0 24px rgba(255,140,0,0.32) inset, 0 0 18px rgba(255,140,0,0.18);
  }
  /* Ascended-only foil: a moving rainbow scrim over the whole card.
     Tells the operator at a glance "this is the form only you see". */
  .holo-card.stage-ascended .holo-shine {
    background: linear-gradient(125deg,
      rgba(255,0,128,0.10) 0%, rgba(0,200,255,0.13) 25%,
      rgba(255,215,0,0.12) 50%, rgba(128,0,255,0.13) 75%,
      rgba(0,255,128,0.10) 100%);
    background-size: 250% 250%;
    animation: holoShine 4s ease-in-out infinite;
  }
  .holo-card.stage-veteran  { border-color: #c0c0c0; }
  .holo-card.stage-doorman  { border-color: #c9a84c; }
  .holo-card.stage-hatchling { border-color: #6a5a30; }
  .holo-shine {
    position: absolute; inset: 0; pointer-events: none;
    background: linear-gradient(125deg,
      transparent 0%, rgba(255,0,128,.05) 15%, rgba(0,200,255,.06) 30%, transparent 40%,
      rgba(255,215,0,.05) 55%, rgba(128,0,255,.06) 70%, transparent 80%,
      rgba(0,255,128,.04) 90%, transparent 100%);
    background-size: 250% 250%;
    animation: holoShine 7s ease-in-out infinite;
    mix-blend-mode: screen;
  }
  @keyframes holoShine {
    0%, 100% { background-position: 0% 50%; }
    50%      { background-position: 100% 50%; }
  }
  /* Mouse-tracked holo layers (RAR store.html port).
     Each updates via --mx / --my / --angle CSS vars set on the
     parent card by the global initHoloTilt handler. */
  .holo-card .holo-shimmer-track {
    position: absolute; inset: 0; z-index: 4; pointer-events: none;
    background: radial-gradient(ellipse 60% 80% at var(--mx, 50%) var(--my, 50%),
      rgba(255,255,255,.22) 0%, rgba(255,220,150,.10) 20%,
      rgba(0,200,255,.06) 40%, transparent 70%);
    opacity: 0; transition: opacity .3s ease;
    mix-blend-mode: screen;
  }
  .card-flipper:hover .holo-shimmer-track { opacity: 1; }
  .holo-card .holo-prism {
    position: absolute; inset: 0; z-index: 2; pointer-events: none;
    background: linear-gradient(calc(var(--angle, 0deg) + 90deg),
      rgba(255,0,80,.0) 0%, rgba(255,0,120,.10) 12%, rgba(255,165,0,.08) 22%,
      rgba(255,255,0,.06) 32%, rgba(0,255,100,.08) 42%, rgba(0,180,255,.10) 52%,
      rgba(100,0,255,.08) 62%, rgba(255,0,200,.06) 72%, rgba(255,0,80,.0) 82%);
    opacity: 0; transition: opacity .3s ease;
    mix-blend-mode: screen;
  }
  .card-flipper:hover .holo-prism { opacity: 1; }
  .holo-card .holo-fresnel {
    position: absolute; inset: 0; z-index: 2; pointer-events: none;
    border-radius: inherit; opacity: 0; transition: opacity .3s;
    background: radial-gradient(ellipse at var(--mx, 50%) var(--my, 50%),
      transparent 30%, rgba(0,255,255,.10) 60%, rgba(255,0,255,.15) 100%);
    mix-blend-mode: screen;
  }
  .card-flipper:hover .holo-fresnel { opacity: 1; }
  .holo-card .holo-scanlines {
    position: absolute; inset: 0; z-index: 3; pointer-events: none;
    border-radius: inherit; opacity: 0; transition: opacity .3s;
    background: repeating-linear-gradient(0deg,
      transparent 0px, transparent 2px,
      rgba(0,255,255,.025) 2px, rgba(0,255,255,.025) 4px);
    animation: holoScanScroll 4s linear infinite;
    mix-blend-mode: screen;
  }
  @keyframes holoScanScroll { to { background-position-y: 200px; } }
  .card-flipper:hover .holo-scanlines { opacity: 1; }
  .holo-card .holo-orbit-cyan, .holo-card .holo-orbit-magenta {
    position: absolute; inset: 0; z-index: 1; pointer-events: none;
    border-radius: inherit; opacity: 0; transition: opacity .3s;
    mix-blend-mode: screen; background-size: 200% 200%;
  }
  .card-flipper:hover .holo-orbit-cyan,
  .card-flipper:hover .holo-orbit-magenta { opacity: 1; }
  .holo-card .holo-orbit-cyan {
    background: radial-gradient(circle at 30% 30%, rgba(0,255,255,.10), transparent 50%);
    animation: holoOrbitA 6s linear infinite;
  }
  .holo-card .holo-orbit-magenta {
    background: radial-gradient(circle at 70% 70%, rgba(255,0,255,.10), transparent 50%);
    animation: holoOrbitB 6s linear infinite;
  }
  @keyframes holoOrbitA {
    0%   { background-position: 0% 0%; }
    25%  { background-position: 100% 0%; }
    50%  { background-position: 100% 100%; }
    75%  { background-position: 0% 100%; }
    100% { background-position: 0% 0%; }
  }
  @keyframes holoOrbitB {
    0%   { background-position: 100% 100%; }
    25%  { background-position: 0% 100%; }
    50%  { background-position: 0% 0%; }
    75%  { background-position: 100% 0%; }
    100% { background-position: 100% 100%; }
  }
  .holo-header {
    display: flex; justify-content: space-between; align-items: flex-start;
    padding: 12px 16px 6px; gap: 10px; flex-shrink: 0;
  }
  .holo-name {
    font-size: 18px; font-weight: 700; color: #f0e6d0;
    line-height: 1.15; letter-spacing: -0.01em;
    font-family: "Cinzel", Georgia, serif;
    text-shadow: 0 1px 3px rgba(0,0,0,0.6);
  }
  .holo-title {
    font-size: 11px; color: #c8a870; font-style: italic; margin-top: 3px;
  }
  .holo-pip {
    width: 26px; height: 26px; border-radius: 50%;
    background: #d3202a; color: white;
    display: flex; align-items: center; justify-content: center;
    font-weight: 800; font-size: 11px;
    border: 1.5px solid rgba(0,0,0,0.4);
    box-shadow: 0 1px 3px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.15);
    flex-shrink: 0;
  }
  .holo-art {
    margin: 0 14px; flex: 1 1 0; min-height: 0;
    border: 2px solid #6a5a30; border-radius: 4px;
    background: radial-gradient(ellipse at 50% 40%, rgba(40,35,20,0.9) 0%, #0d0a06 70%);
    display: flex; align-items: center; justify-content: center;
    overflow: hidden;
  }
  .holo-art svg { width: 92%; height: 92%; display: block; }
  .holo-type {
    font-size: 11px; color: #c8b89a; padding: 5px 16px 2px;
    border-top: 1px solid #4d4332;
    background: rgba(50,40,25,0.6);
    flex-shrink: 0;
  }
  /* Set line — temporal dimension. Era + live memory count. */
  .holo-set {
    font-size: 9px; color: #8b7332; padding: 0 16px 5px;
    border-bottom: 1px solid #4d4332;
    background: rgba(50,40,25,0.6);
    letter-spacing: 0.4px; text-transform: uppercase;
    flex-shrink: 0;
  }
  .holo-text {
    padding: 9px 14px 0; font-size: 12px; line-height: 1.45;
    color: #d8c8a8;
  }
  .holo-text .holo-ability { margin-bottom: 6px; }
  .holo-text .holo-ability .kw { color: #ffd700; font-weight: 700; }
  .holo-flavor {
    font-style: italic; font-size: 11px; color: #9a8e7a;
    padding: 6px 14px;
    border-top: 1px solid #3d3322; margin-top: 6px;
  }
  .holo-footer {
    display: flex; justify-content: space-between; align-items: center;
    padding: 7px 14px 9px;
    font-size: 10px; flex-shrink: 0; margin-top: auto;
  }
  .holo-rarity {
    text-transform: uppercase; letter-spacing: 0.6px;
    font-weight: 700; color: #c0c0c0;
  }
  .holo-rarity.mythic   { color: #ff8c00; text-shadow: 0 0 8px rgba(255,140,0,0.5); }
  .holo-rarity.rare     { color: #ffd700; text-shadow: 0 0 6px rgba(255,215,0,0.4); }
  .holo-rarity.uncommon { color: #c0c0c0; }
  .holo-rarity.core     { color: #c0c0c0; }
  .holo-rarity.starter  { color: #8899aa; }
  .holo-handle {
    font-family: "SF Mono", Menlo, monospace;
    font-size: 9px; color: #8b7332;
  }
  /* Power/toughness — sits in the footer, rappid-derived stats */
  .holo-pt {
    font-weight: 800; font-size: 14px; color: #f0e6d0;
    background: rgba(40,35,20,0.7);
    border: 1px solid rgba(201,168,76,0.35);
    padding: 1px 8px; border-radius: 4px;
    text-shadow: 0 1px 2px rgba(0,0,0,0.5);
    font-family: "SF Mono", Menlo, monospace;
  }

  /* Card back — matches RAR holo card pattern: gold-on-dark, RAPP
     brand wordmark in serif, QR centered, content-hash caption,
     display name, two action buttons (Open / 💬 Summon). */
  .card-back-frame {
    position: absolute; inset: 0;
    border-radius: 18px;
    border: 3px solid #c9a84c;
    background: linear-gradient(160deg, #2a2418 0%, #1a1510 40%, #1f1a12 100%);
    display: flex; flex-direction: column; align-items: center; justify-content: center;
    text-align: center; padding: 22px;
    color: #d8c8a8; gap: 10px;
  }
  .card-back-brand {
    font-family: "Cinzel", Georgia, serif;
    font-size: 22px; font-weight: 700;
    letter-spacing: 0.5em; padding-left: 0.5em;  /* compensate tracking */
    color: #c9a84c;
    text-shadow: 0 1px 3px rgba(0,0,0,0.6);
  }
  .card-back-qr {
    width: 200px; height: 200px;
    background: white; padding: 9px; border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0,0,0,0.45);
    border: 2px solid #6a5a30;
  }
  .card-back-caption {
    font-size: 11px; color: #8b7332;
    font-family: "SF Mono", Menlo, monospace;
    letter-spacing: 0.3px;
  }
  .card-back-caption span {
    color: #c8a870;
  }
  .card-back-name {
    font-family: "Cinzel", Georgia, serif;
    font-size: 17px; font-weight: 700;
    color: #f0e6d0;
    margin-top: 2px;
    text-shadow: 0 1px 3px rgba(0,0,0,0.6);
  }
  .card-back-actions {
    display: flex; gap: 8px; margin-top: 4px;
  }
  .card-back-btn {
    background: rgba(40,35,20,0.7); color: #d8c8a8;
    border: 1px solid #6a5a30;
    padding: 6px 14px; border-radius: 6px;
    font-size: 12px; font-weight: 600;
    text-decoration: none;
    font-family: "Cinzel", Georgia, serif;
    letter-spacing: 0.3px;
    transition: background 0.15s, border-color 0.15s;
  }
  .card-back-btn:hover {
    background: rgba(60,50,28,0.9);
    border-color: #c9a84c;
    color: #f0e6d0;
  }
  .card-back-btn.primary {
    background: rgba(201,168,76,0.18);
    border-color: #c9a84c;
    color: #f0e6d0;
  }
  .card-back-btn.primary:hover {
    background: rgba(201,168,76,0.32);
  }
  .card-back-hint {
    font-size: 10px; color: #6e7681; font-style: italic;
    margin-top: 6px; letter-spacing: 0.3px;
  }
</style>
</head>
<body>

<main>
  <section class="hero">
    <div class="hero-sigil" id="hero-sigil">__HERO_EMOJI__</div>
    <h1 class="hero-title">__DISPLAY_NAME__</h1>
    <div class="hero-handle"><a href="https://github.com/__GH_USER__/__REPO_NAME__">@__GH_USER__/__REPO_NAME__</a></div>
    <div class="hero-place">__LOCATION_LINE__</div>
    <p class="hero-blurb">__HERO_BLURB__</p>
    <a class="hero-cta" href="./doorman/">💬 Talk to __DISPLAY_NAME__ →</a>
    <div class="hero-stats">
      <span class="stat-chip" id="stat-mem">·</span>
      <span class="stat-chip" id="stat-age">·</span>
      <span class="stat-chip">⚡ frozen kernel · v0.6.0</span>
    </div>
  </section>

  <!-- Track Record — the organism's resume. Agents accumulate in
       /agents/, mutations accumulate from commit history, achievements
       unlock from milestones. Each visit grows the resume; the operator
       steers mutations by accepting or rejecting visitor-proposed PRs.
       NOTE: one term only — "agent". Never "skill", "routine", "loop",
       "plugin". See ANTIPATTERNS.md §1. -->

  <section class="track-record">
    <h3 class="tr-heading">What I bring to the table</h3>

    <!-- MMR header — the single global rating, Dota-style. Computed
         from the same public signals on every planted seed so a 3500-
         rated organism here is comparable to a 3500-rated organism
         anywhere on the species. -->
    <div class="tr-mmr">
      <div class="mmr-num" id="mmr-num">—</div>
      <div class="mmr-side">
        <div class="mmr-tier" id="mmr-tier">Cradle</div>
        <div class="mmr-breakdown" id="mmr-breakdown">based on memories, mutations, agents, and age</div>
      </div>
    </div>

    <div class="tr-block">
      <div class="tr-label">Agents</div>
      <div class="tr-agents" id="tr-agents"><span class="agent-chip skel">loading…</span></div>
    </div>

    <div class="tr-block">
      <div class="tr-label">Achievements</div>
      <div class="tr-agents" id="tr-achievements"><span class="agent-chip skel">…</span></div>
    </div>

    <div class="tr-block">
      <div class="tr-label">Mutation log</div>
      <ul class="tr-mutations" id="tr-mutations">
        <li class="skel">loading recent changes…</li>
      </ul>
      <a class="tr-foot-link" id="tr-history-link" href="#" target="_blank" rel="noopener">full history on GitHub →</a>
    </div>

    <div class="tr-lineage" id="tr-lineage"></div>
  </section>

  <div class="row-actions">
    <button class="action secondary" id="btn-card">🃏 Show my card</button>
    <button class="action secondary" id="btn-tether">📱 Pair with another device</button>
    <button class="action secondary" id="btn-neighborhood" title="See who this organism collaborates with — the declared neighborhood. Cross-organism knowledge exchange happens here.">🏘 Neighborhood</button>
    <button class="action secondary" id="btn-propose-agent" title="Submit a new agent.py to this organism via PR — the lineage evolution path.">🌱 Propose an agent</button>
    <button class="action secondary" id="btn-export-egg" title="Backup the public organism — rappid, soul, agents, public memory.">🥚 Export .egg</button>
    <button class="action secondary" id="btn-verify-egg" title="Drop in any .egg and verify nothing was modified offline.">🔬 Verify an .egg</button>
    <button class="action secondary" id="btn-dreamcatcher" title="Diff two eggs of the same lineage to find frames the parallel dimension has that the canonical doesn't.">🕸️ Dream Catcher</button>
    <button class="action secondary" id="btn-publish-egg" title="Open a pre-filled submission to the public Egg Hub.">🌐 Back up to Egg Hub</button>
    <button class="action secondary" id="btn-install">💻 Install kernel locally</button>
  </div>

  <details class="fd-details">
    <summary>Front-door details</summary>
    <section class="identity">
      <div class="identity-row">
        <span class="identity-key">Slug</span>
        <span class="identity-val">__REPO_NAME__</span>
      </div>
      <div class="identity-row">
        <span class="identity-key">Rappid</span>
        <span class="identity-val">__RAPPID__</span>
      </div>
      <div class="identity-row">
        <span class="identity-key">Kernel</span>
        <span class="identity-val">v0.6.0 (grail-synced)</span>
      </div>
      <div style="margin-top:12px;">
        <span class="chip">kind: <code>__KIND__</code></span>
        __LINEAGE_HTML__
      </div>
    </section>
  </details>

  <section class="pane" id="pane-tether" hidden>
    <h2>📱 Pair with another device</h2>
    <p>Open the camera on your phone and point it at the code below. The other device lands on this same chat — both ends share an end-to-end-encrypted channel (WebRTC / DTLS). The broker drops out once you're connected.</p>

    <div id="tether-qr-wrap" style="text-align:center;padding:18px 0;">
      <div id="tether-qr-loading" style="color:#8b949e;font-size:13px;padding:32px 0;">Generating pairing code…</div>
      <img class="qr-img" id="tether-qr-img" alt="Scan to pair" hidden>
      <div class="qr-url" id="tether-qr-url" hidden></div>
    </div>

    <div class="chat-log" id="chat-log">
      <div class="msg system">Once a device scans the code, your two devices share a private channel here.</div>
    </div>

    <div class="input-row">
      <input type="text" id="chat-input" placeholder="Type a message and hit Enter" disabled>
      <button class="small primary" id="btn-send" disabled>Send</button>
    </div>

    <!-- One-tap egg send over the open tether channel. The frozen
         kernel is on both devices already; we just stream the .egg
         bytes through the DTLS data channel. Receiver auto-prompts
         to save. Hero-use-case Charizard scenario step 4. -->
    <div class="input-row" style="margin-top:10px;">
      <button class="small" id="btn-send-egg" disabled title="Stream this organism's .egg to the paired device — Charizard handoff.">🥚 Send my egg →</button>
      <span id="tether-egg-status" style="font-size:11px;color:#8b949e;align-self:center;"></span>
    </div>

    <details class="tether-fallback">
      <summary>Can't scan? Pair by ID instead.</summary>
      <div class="fallback-body">
        <span class="identity-key">My ID</span>
        <div class="my-id" id="my-id"><span class="status-dot" id="peer-status"></span><span id="my-id-text">(connecting to broker…)</span></div>
        <button class="small" id="btn-copy-id">Copy ID</button>
        <div class="input-row" style="margin-top:10px;">
          <input type="text" id="peer-id-input" placeholder="Or paste another device's ID">
          <button class="small primary" id="btn-connect">Connect</button>
        </div>
      </div>
    </details>
  </section>

  <!-- Propose an agent — the PR-driven evolution path. The frozen
       kernel never moves; capabilities grow via agent .py files merged
       into the seed's /agents/. ONE term: agent. Never "skill", "plugin",
       "routine", "loop". See ANTIPATTERNS.md §1. -->
  <section class="pane" id="pane-propose" hidden>
    <h2>🌱 Propose a new agent</h2>
    <p>The frozen kernel never changes. The organism grows through <code>agent.py</code> files merged into <code>/agents/</code>. If you found a pattern useful working with this organism, package it as an agent and submit it back. Two paths, your choice:</p>
    <ul style="font-size:13px;color:#8b949e;line-height:1.6;margin:0 0 14px 18px;">
      <li><strong>Rejoin the lineage</strong> — open a PR; if the operator merges it, your agent becomes part of this organism on every visitor's next visit.</li>
      <li><strong>Keep it personal</strong> — leave the PR sitting on your fork, never merge it. You get the mutation as your private branch of this organism; nobody else sees it. GitHub auto-forks the repo to your account when you submit.</li>
    </ul>

    <div class="propose-row">
      <label class="propose-label">Agent name <span class="propose-hint">(snake_case)</span></label>
      <input type="text" id="propose-name" placeholder="e.g. fetch_weather, summarize_chat" />
    </div>

    <div class="propose-row">
      <label class="propose-label">One-line description</label>
      <input type="text" id="propose-desc" placeholder="What the LLM should know about when to call this." />
    </div>

    <div class="propose-row">
      <label class="propose-label">Agent source <span class="propose-hint">(extends BasicAgent · one class · one perform())</span></label>
      <textarea id="propose-code" rows="14" spellcheck="false"></textarea>
    </div>

    <div class="propose-actions">
      <button class="small primary" id="btn-propose-submit">Open PR on GitHub →</button>
      <button class="small" id="btn-propose-template">Reset to template</button>
      <span class="propose-meta">Submits to <code id="propose-target">…</code> · GitHub forks the repo for you if you don't have push access</span>
    </div>
  </section>

  <!-- Dream Catcher — reassimilation pane. Drop the canonical egg
       (left) and a parallel-dimension egg (right), see what frames
       the parallel has that the canonical doesn't. Operator reviews
       each new frame and chooses which to bond back via PR.
       Pattern: kody-w/rappterbook engine/merge/merge_frame.py.
       Frames are content-addressed (sha256 chain) so splicing a
       middle frame breaks the chain visibly. PK = utc + frame_n. -->
  <section class="pane" id="pane-dreamcatcher" hidden>
    <h2>🕸️ Dream Catcher · reassimilate parallel dimensions</h2>
    <p>Each hatched egg is a parallel dimension that lives offline and accumulates its own mutations. The Dream Catcher folds those parallel streams back into the canonical organism. Drop the canonical egg on the left and a parallel dimension on the right — the diff shows what frames the parallel has that the canonical doesn't. Pick what's worth reassimilating; the rest stays on its branch.</p>
    <div class="dc-grid">
      <div class="dc-slot">
        <div class="dc-slot-label">📍 Canonical</div>
        <div id="dc-drop-canonical" class="verify-drop">
          <input type="file" id="dc-file-canonical" accept=".egg,.zip" style="display:none">
          <div class="verify-drop-prompt">drop canonical egg<br><span style="font-size:11px;color:#6e7681">or <button class="small primary" id="btn-dc-pick-canonical">pick</button></span></div>
        </div>
        <div class="dc-egg-info" id="dc-info-canonical"></div>
      </div>
      <div class="dc-slot">
        <div class="dc-slot-label">🌌 Parallel dimension</div>
        <div id="dc-drop-parallel" class="verify-drop">
          <input type="file" id="dc-file-parallel" accept=".egg,.zip" style="display:none">
          <div class="verify-drop-prompt">drop parallel egg<br><span style="font-size:11px;color:#6e7681">or <button class="small primary" id="btn-dc-pick-parallel">pick</button></span></div>
        </div>
        <div class="dc-egg-info" id="dc-info-parallel"></div>
      </div>
    </div>
    <div id="dc-results" hidden></div>
  </section>

  <!-- Verify .egg — drop in any cartridge to check it hasn't been
       tampered with offline. Recomputes every file's sha256 against
       the manifest's stated hash table. Non-GMO check. -->
  <section class="pane" id="pane-verify" hidden>
    <h2>🔬 Verify an .egg</h2>
    <p>Drop a cartridge here. Every file's SHA-256 is recomputed and compared to the hash table in the egg's manifest. If anything was modified offline, the verifier flags it.</p>
    <div id="verify-drop" class="verify-drop">
      <input type="file" id="verify-file" accept=".egg,.zip" style="display:none">
      <div class="verify-drop-prompt">📦 drop an .egg here, or <button class="small primary" id="btn-verify-pick">pick a file</button></div>
    </div>
    <div id="verify-results" hidden style="margin-top:14px;"></div>
  </section>

  <section class="pane" id="pane-install" hidden>
    <h2>Install this front door's brainstem locally</h2>
    <p>Runs the canonical kernel under <code>~/.brainstem/</code> on your machine. Per the Mirror Spec, the installer re-fetches the canonical install logic from the grail, so it cannot drift.</p>
    <pre class="cmd" id="install-cmd">curl -fsSL __URL__/installer/install.sh | bash</pre>
    <button class="small primary" id="btn-copy-install">Copy command</button>
  </section>

  <!-- Neighborhood — declared peer organisms this seed collaborates with.
       The implementation surface of NEIGHBORHOOD_PROTOCOL.md. List
       reads neighbors.json from the seed root; each neighbor's public
       state is fetched live (cached). Adding a neighbor = pre-filled
       PR against neighbors.json on this seed. The operator merges
       what they want to formally collaborate with. -->
  <section class="pane" id="pane-neighborhood" hidden>
    <h2>🏘 Neighborhood</h2>
    <p>The peer organisms this seed has formally declared as collaborators. Knowledge can flow between declared neighbors via the twin chat protocol — cross-organism queries, fact sharing, egg trades. Each entry below is rendered live from the peer's public state.</p>
    <div id="nbhd-list" style="margin-top:14px;">
      <div class="skel-line">loading neighbors…</div>
    </div>
    <!-- One-tap adopt the canonical test neighbor. Opens a pre-filled
         issue (same flow as the manual form) but with kody-w/rapp-test-neighbor
         already filled in. Lets a fresh operator verify their plumbing in
         seconds — see Article XLII (the URL is the discovery primitive,
         the card is the share primitive) and HERO_USECASE.md. -->
    <div style="margin-top:18px;padding:14px;background:rgba(88,166,255,0.06);border:1px solid rgba(88,166,255,0.18);border-radius:10px;">
      <div style="font-size:13px;color:#c9d1d9;font-weight:600;margin-bottom:6px;">🌱 First time? Adopt the canonical test neighbor</div>
      <p style="font-size:12px;color:#8b949e;line-height:1.55;margin:0 0 10px 0;"><code>kody-w/rapp-test-neighbor</code> is the platform's intentionally-stable test peer. Adopt it to verify your <code>Neighborhood.ask</code> plumbing works — then go declare a real friend.</p>
      <button class="small primary" id="btn-nbhd-adopt-test">Adopt kody-w/rapp-test-neighbor →</button>
    </div>
    <details style="margin-top:18px;">
      <summary style="cursor:pointer;font-size:13px;color:#8b949e;list-style:none;">▸ Add a neighbor (open PR)</summary>
      <div style="margin-top:12px;">
        <p style="font-size:12px;color:#8b949e;line-height:1.55;">Opens a pre-filled GitHub PR adding the entry to <code>neighbors.json</code>. The operator reviews + merges; once accepted, the new neighbor appears in this list on every visitor's next render.</p>
        <div class="propose-row">
          <label class="propose-label">Neighbor repo <span class="propose-hint">(owner/repo on GitHub)</span></label>
          <input type="text" id="nbhd-repo" placeholder="e.g. kody-w/heimdall" />
        </div>
        <div class="propose-row">
          <label class="propose-label">Display name</label>
          <input type="text" id="nbhd-name" placeholder="How this neighbor is called" />
        </div>
        <div class="propose-row">
          <label class="propose-label">Allowed facets <span class="propose-hint">(comma-separated; what this organism shares OUT to that neighbor — empty for public-only)</span></label>
          <input type="text" id="nbhd-facets" placeholder="e.g. research_in_progress, professional_history" />
        </div>
        <button class="small primary" id="btn-nbhd-submit">Open PR on GitHub →</button>
      </div>
    </details>
    <p style="font-size:11px;color:#6e7681;margin-top:18px;line-height:1.5;">Protocol: <a href="https://github.com/kody-w/RAPP/blob/main/NEIGHBORHOOD_PROTOCOL.md" target="_blank" rel="noopener" style="color:#58a6ff;">NEIGHBORHOOD_PROTOCOL.md</a> describes the trust model, channel types, and exchange primitives.</p>
  </section>

  <!-- Plant your own front door — public one-liner + AI-paste prompt.
       Two formats: the bash one-liner for terminal users, and an
       AI-friendly prompt for visitors who'd rather hand the job to
       their AI assistant. (We always design for both modes — see
       HERO_USECASE.md §3 Mom's Mixtape.) -->
  <section class="pane" id="pane-plant" hidden>
    <h2>🌱 Plant your own front door</h2>
    <p>Plants a brand-new RAPP organism — a public GitHub repo with its own front door, doorman chat surface, identity, and trade card. Same kernel + skeleton this seed runs.</p>

    <div style="margin-top:14px;">
      <div class="propose-label" style="margin-bottom:6px;">Run in your terminal</div>
      <pre class="cmd" id="plant-cmd">curl -fsSL https://kody-w.github.io/RAPP/installer/plant.sh \
  | MIRROR_REPO_NAME=my-twin \
    MIRROR_DISPLAY_NAME="My Twin" \
    MIRROR_KIND=personal \
    bash</pre>
      <div style="display:flex;gap:8px;margin-top:8px;">
        <button class="small primary" id="btn-copy-plant">Copy command</button>
        <span style="font-size:11px;color:#6e7681;align-self:center;">edit the names + kind, paste in any shell</span>
      </div>
    </div>

    <div style="margin-top:18px;">
      <div class="propose-label" style="margin-bottom:6px;">Or hand it to your AI assistant</div>
      <p style="font-size:12px;color:#8b949e;margin-bottom:6px;">Paste this prompt into Claude / ChatGPT / Gemini / your CLI agent. It walks them through running the plant for you.</p>
      <pre class="cmd" id="plant-ai-prompt" style="white-space:pre-wrap;">Plant a new RAPP organism for me. Steps:

1. Run this one-liner in a terminal you have access to:
   curl -fsSL https://kody-w.github.io/RAPP/installer/plant.sh \
     | MIRROR_REPO_NAME=&lt;slug&gt; \
       MIRROR_DISPLAY_NAME=&quot;&lt;Display Name&gt;&quot; \
       MIRROR_KIND=&lt;personal|place|experiment|mirror&gt; \
       bash

2. Substitute:
   - &lt;slug&gt;: snake_case name for the GitHub repo (e.g. my_twin, dadjoke_bot)
   - &lt;Display Name&gt;: human-readable name shown on the front door
   - &lt;kind&gt;: 'personal' for a digital twin, 'place' for a location-tied
     organism, 'experiment' for in-development, 'mirror' for a generic
     planted seed

3. Optional env vars:
   - MIRROR_LOCATION=&quot;&lt;human-readable place&gt;&quot; (e.g. &quot;Bifrost · the watcher's threshold&quot;)
   - MIRROR_PARENT=https://github.com/&lt;owner&gt;/&lt;parent-repo&gt; (lineage gift)
   - MIRROR_PRIVATE_COMPANION=&lt;owner&gt;/&lt;private-repo&gt; (operator brain layer)

4. The script needs gh CLI authenticated (gh auth status) and creates a
   public GitHub repo + sets up GitHub Pages. If &quot;gh: command not found&quot;,
   ask me to install gh and run &quot;gh auth login&quot; first.

5. After it finishes, the new front door is at
   https://&lt;your-gh-handle&gt;.github.io/&lt;slug&gt;/. Report the URL back.

Spec: HERO_USECASE.md and ECOSYSTEM.md at https://github.com/kody-w/RAPP
explain the platform — read those if anything in the script's output
is unclear.</pre>
      <div style="display:flex;gap:8px;margin-top:8px;">
        <button class="small primary" id="btn-copy-plant-ai">Copy AI prompt</button>
        <span style="font-size:11px;color:#6e7681;align-self:center;">paste into any AI assistant; they'll handle the rest</span>
      </div>
    </div>

    <p style="font-size:11px;color:#6e7681;margin-top:18px;line-height:1.5;">Plant.sh source is open: <a href="https://kody-w.github.io/RAPP/installer/plant.sh" target="_blank" rel="noopener" style="color:#58a6ff;">view it before piping to bash</a> if you'd like.</p>
  </section>

  <!-- Trade card overlay — tap to flip, back of card has the QR.
       Card is auto-derived from the seed's rappid + soul; the operator
       can override copy by dropping a card.json at the seed root. -->
  <div class="card-overlay" id="card-overlay" hidden>
    <button class="card-close" id="card-close" aria-label="Close">×</button>
    <div class="card-flipper" id="card-flipper">
      <div class="card-face card-front">
        <div class="holo-card" id="holo-card">
          <div class="holo-shine"></div>
          <!-- Mouse-tracking holo layers (ported from kody-w/RAR/store.html).
               Each layer is purely visual; no JS needed beyond the global
               tilt handler that updates --mx/--my/--angle on the parent. -->
          <div class="holo-shimmer-track"></div>
          <div class="holo-prism"></div>
          <div class="holo-fresnel"></div>
          <div class="holo-scanlines"></div>
          <div class="holo-orbit-cyan"></div>
          <div class="holo-orbit-magenta"></div>
          <div class="holo-header">
            <div>
              <div class="holo-name" id="card-name">__DISPLAY_NAME__</div>
              <div class="holo-title" id="card-title">…</div>
            </div>
            <div class="holo-pip" id="card-pip">·</div>
          </div>
          <div class="holo-art" id="card-art"></div>
          <div class="holo-type" id="card-type">…</div>
          <div class="holo-set" id="card-set">…</div>
          <div class="holo-text" id="card-abilities"></div>
          <div class="holo-flavor" id="card-flavor"></div>
          <div class="holo-footer">
            <span class="holo-rarity" id="card-rarity">CORE</span>
            <span class="holo-pt" id="card-pt">·/·</span>
            <span class="holo-handle">@__GH_USER__/__REPO_NAME__</span>
          </div>
        </div>
      </div>
      <div class="card-face card-back">
        <div class="card-back-frame">
          <div class="card-back-brand">RAPP</div>
          <img class="card-back-qr" id="card-back-qr" alt="Scan to summon">
          <div class="card-back-caption">Scan to summon · <span id="card-back-hash">…</span></div>
          <div class="card-back-name" id="card-back-name">__DISPLAY_NAME__</div>
          <div class="card-back-actions">
            <a class="card-back-btn" id="card-back-open" href="./" target="_blank" rel="noopener">Open</a>
            <a class="card-back-btn primary" id="card-back-summon" href="./doorman/" target="_blank" rel="noopener">💬 Summon</a>
          </div>
          <div class="card-back-hint">tap card to flip back</div>
        </div>
      </div>
    </div>
  </div>
</main>

<footer>
  <a href="https://kody-w.github.io/RAPP/">RAPP</a> ·
  <a href="#" id="footer-plant">plant your own front door</a> ·
  <a href="https://github.com/__GH_USER__/__REPO_NAME__">source</a>
</footer>

<script>
"use strict";

const FD = {
  rappid: "__RAPPID__",
  displayName: "__DISPLAY_NAME__",
  slug: "__REPO_NAME__",
  ghUser: "__GH_USER__",
  url: "__URL__",
};

let peer = null;
let conn = null;

function hideAllPanes() {
  for (const id of ["pane-tether", "pane-install", "pane-verify", "pane-dreamcatcher", "pane-propose", "pane-plant", "pane-neighborhood"]) {
    const el = document.getElementById(id);
    if (el) el.hidden = true;
  }
}

function showPane(id) {
  hideAllPanes();
  document.getElementById(id).hidden = false;
}

function appendMsg(text, cls) {
  const log = document.getElementById("chat-log");
  if (!log) return;
  // Clear initial placeholder system message on first real message.
  // Use firstElementChild to skip whitespace text nodes between tags.
  const first = log.firstElementChild;
  if (log.children.length === 1 && first && first.classList && first.classList.contains("system")) {
    const txt = first.textContent || "";
    if (txt.startsWith("Tether will appear") ||
        txt.startsWith("Once a device scans") ||
        txt.startsWith("Once paired")) {
      log.innerHTML = "";
    }
  }
  const div = document.createElement("div");
  div.className = "msg " + (cls || "system");
  div.textContent = text;
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
}

function setStatus(state) {
  const dot = document.getElementById("peer-status");
  dot.className = "status-dot " + state;
}

async function ensurePeer() {
  if (peer) return peer;
  setStatus("warn");
  try {
    peer = new Peer();
  } catch (e) {
    setStatus("err");
    document.getElementById("my-id-text").textContent = "PeerJS failed to load";
    appendMsg("Could not initialize PeerJS: " + e.message, "system");
    throw e;
  }
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => {
      setStatus("err");
      document.getElementById("my-id-text").textContent = "broker timeout";
      reject(new Error("PeerJS broker timeout"));
    }, 12000);
    peer.on("open", id => {
      clearTimeout(t);
      setStatus("ok");
      document.getElementById("my-id-text").textContent = id;
      // QR-first: as soon as the broker assigns us an ID, render the
      // pairing QR. The other device scans → lands on this same URL
      // with ?peer=<id> → autoTether() dials this peer.
      autoRenderTetherQR(id);
      resolve(peer);
    });
    peer.on("connection", c => {
      conn = c;
      wireConn(c);
      appendMsg("Peer connected: " + c.peer, "system");
    });
    peer.on("error", e => {
      setStatus("err");
      appendMsg("PeerJS error: " + e.type + (e.message ? " — " + e.message : ""), "system");
    });
  });
}

// Egg transfer protocol over the DTLS data channel. Wire format:
//   { type: "egg-begin",  size, sha256, name }
//   { type: "egg-chunk",  seq, b64 }     ← repeat for each ~16KB chunk
//   { type: "egg-end" }
// Receiver verifies sha256 on completion and prompts to save.
const EGG_CHUNK_BYTES = 16 * 1024;
let _eggRecv = null;  // assembly buffer on the receive side

function wireConn(c) {
  c.on("open", () => {
    appendMsg("Channel open — DTLS encrypted, peer-to-peer.", "system");
    document.getElementById("chat-input").disabled = false;
    document.getElementById("btn-send").disabled = false;
    const eggBtn = document.getElementById("btn-send-egg");
    if (eggBtn) eggBtn.disabled = false;
  });
  c.on("data", async data => {
    // Try to detect egg-protocol messages first; fall through to chat.
    let parsed = null;
    if (typeof data === "string") {
      try { parsed = JSON.parse(data); } catch (_) {}
    }
    if (parsed && parsed.type && parsed.type.startsWith("egg-")) {
      await _handleEggMessage(parsed);
      return;
    }
    appendMsg(typeof data === "string" ? data : JSON.stringify(data), "peer");
  });
  c.on("close", () => {
    appendMsg("Peer disconnected.", "system");
    document.getElementById("chat-input").disabled = true;
    document.getElementById("btn-send").disabled = true;
    const eggBtn = document.getElementById("btn-send-egg");
    if (eggBtn) eggBtn.disabled = true;
  });
}

async function _handleEggMessage(msg) {
  if (msg.type === "egg-begin") {
    _eggRecv = { size: msg.size, sha256: msg.sha256, name: msg.name || "received.egg", chunks: [], received: 0 };
    appendMsg(`📦 receiving ${msg.name || "egg"} (${Math.round(msg.size / 1024)} KB)…`, "system");
    return;
  }
  if (msg.type === "egg-chunk" && _eggRecv) {
    // Decode base64 chunk
    const bin = atob(msg.b64);
    const buf = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i);
    _eggRecv.chunks.push(buf);
    _eggRecv.received += buf.length;
    return;
  }
  if (msg.type === "egg-end" && _eggRecv) {
    // Concatenate chunks → verify sha256 → trigger download
    const total = new Uint8Array(_eggRecv.size);
    let off = 0;
    for (const c of _eggRecv.chunks) { total.set(c, off); off += c.length; }
    const hash = await crypto.subtle.digest("SHA-256", total);
    const hex = Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("");
    if (hex !== _eggRecv.sha256) {
      appendMsg(`✗ received egg failed integrity check (sha256 mismatch).`, "system");
      _eggRecv = null;
      return;
    }
    const blob = new Blob([total], { type: "application/zip" });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = _eggRecv.name;
    document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 0);
    appendMsg(`✓ received ${_eggRecv.name} — sha256 verified, file saved.`, "system");
    _eggRecv = null;
    return;
  }
}

// Stream THIS organism's doorman-tier egg through the given channel.
// Chunks are base64 over the existing JSON-string send path so we
// reuse the chat-message wire (PeerJS DataChannel handles binary too,
// but b64-over-JSON keeps the wire format simple + portable).
//
// Takes an explicit channel object so tests can drive it without going
// through the live PeerJS broker. The button-bound entrypoint
// `sendEggToPeer()` reads the module's `conn` and forwards.
async function _streamEggThroughChannel(chan) {
  const status = document.getElementById("tether-egg-status");
  if (status) status.textContent = "packing egg…";
  try {
    const blob = await buildDoormanEgg();
    const buf  = new Uint8Array(await blob.arrayBuffer());
    const sha256 = await sha256Hex(buf);
    const name = ((window.__seedDisplayName || "rapp").toLowerCase().replace(/[^a-z0-9]+/g, "-") + "-doorman.egg");
    chan.send(JSON.stringify({ type: "egg-begin", size: buf.length, sha256, name }));
    let sent = 0;
    for (let off = 0; off < buf.length; off += EGG_CHUNK_BYTES) {
      const slice = buf.subarray(off, off + EGG_CHUNK_BYTES);
      let bin = "";
      for (let i = 0; i < slice.length; i++) bin += String.fromCharCode(slice[i]);
      const b64 = btoa(bin);
      chan.send(JSON.stringify({ type: "egg-chunk", seq: Math.floor(off / EGG_CHUNK_BYTES), b64 }));
      sent += slice.length;
      if (status) status.textContent = `sending ${Math.round(sent / 1024)} / ${Math.round(buf.length / 1024)} KB…`;
      await new Promise(r => setTimeout(r, 0));
    }
    chan.send(JSON.stringify({ type: "egg-end" }));
    if (status) status.textContent = `✓ sent ${Math.round(buf.length / 1024)} KB`;
    appendMsg(`✓ sent ${name} (${Math.round(buf.length / 1024)} KB) — receiver should be saving now.`, "system");
    setTimeout(() => { if (status) status.textContent = ""; }, 4000);
  } catch (e) {
    if (status) status.textContent = "✗ " + (e.message || "send failed").slice(0, 50);
    appendMsg("✗ egg send failed: " + e.message, "system");
    throw e;
  }
}
async function sendEggToPeer() {
  if (!conn || !conn.open) {
    appendMsg("✗ no peer channel open — pair first.", "system");
    return;
  }
  return _streamEggThroughChannel(conn);
}

async function openTether() {
  showPane("pane-tether");
  try {
    await ensurePeer();
  } catch (_) { /* error already shown */ }
}

async function connectToPeer() {
  const id = document.getElementById("peer-id-input").value.trim();
  if (!id) return;
  if (!peer) await ensurePeer();
  appendMsg("Dialing " + id + "...", "system");
  conn = peer.connect(id);
  wireConn(conn);
}

function sendMessage() {
  const input = document.getElementById("chat-input");
  const txt = input.value.trim();
  if (!txt || !conn || !conn.open) return;
  conn.send(txt);
  appendMsg(txt, "me");
  input.value = "";
}

function showFrontDoorQR() {
  showPane("pane-qr");
  const url = location.origin + location.pathname;
  document.getElementById("qr-img").src =
    "https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=0&data=" +
    encodeURIComponent(url);
  document.getElementById("qr-url").textContent = url;
}

function autoRenderTetherQR(myId) {
  if (!myId) return;
  const url = location.origin + location.pathname + "?peer=" + encodeURIComponent(myId);
  const img = document.getElementById("tether-qr-img");
  const cap = document.getElementById("tether-qr-url");
  const loading = document.getElementById("tether-qr-loading");
  if (!img) return; // pane not in DOM (e.g. unit-test)
  img.src = "https://api.qrserver.com/v1/create-qr-code/?size=300x300&margin=0&data=" +
            encodeURIComponent(url);
  img.hidden = false;
  cap.textContent = url;
  cap.hidden = false;
  if (loading) loading.style.display = "none";
}

function showInstall() { showPane("pane-install"); }

// ── 🏘 Neighborhood pane ───────────────────────────────────────────
//
// Renders neighbors.json from the seed root and fetches each declared
// neighbor's public state (rappid, soul gist, memory count) via cached
// raw.githubusercontent.com calls. Empty by default — operators add
// neighbors via PR (the Add-a-neighbor form below the list).

async function showNeighborhoodPane() {
  showPane("pane-neighborhood");
  const wrap = document.getElementById("nbhd-list");
  wrap.innerHTML = '<div class="skel-line">loading neighbors…</div>';

  let entries = [];
  try {
    const r = await fetch("neighbors.json", { cache: "no-cache" });
    if (r.ok) {
      const j = await r.json();
      entries = Array.isArray(j.neighbors) ? j.neighbors : [];
    }
  } catch (_) {}

  if (!entries.length) {
    wrap.innerHTML = '<div class="nbhd-empty">No neighbors declared yet. Add one below to formalize a collaboration line — once merged, this organism\'s doorman can call <code>Neighborhood.ask</code> to query the neighbor\'s public state during conversation.</div>';
    return;
  }

  // Render each neighbor as a card with their sigil + name + tagline + stats.
  // Each card links to the peer's front door so visitors can hop across.
  const cards = await Promise.all(entries.map(async (n) => {
    const m = String(n.repo || "").match(/^([^/]+)\/([^/]+)$/) ||
              String(n.repo || "").match(/github\.com\/([^/]+)\/([^/]+?)(?:\.git)?\/?$/);
    if (!m) return null;
    const [, owner, repo] = m;
    const base = `https://raw.githubusercontent.com/${owner}/${repo}/main/`;
    const url  = `https://${owner}.github.io/${repo}/`;
    const [rappidRes, soulRes, memRes] = await Promise.all([
      cachedGhText(base + "rappid.json"),
      cachedGhText(base + "soul.md"),
      cachedGhText(base + ".brainstem_data/memory.json"),
    ]);
    let peerRappid = null, mem = null;
    try { peerRappid = rappidRes.value ? JSON.parse(rappidRes.value) : null; } catch (_) {}
    try { mem        = memRes.value    ? JSON.parse(memRes.value)    : null; } catch (_) {}
    const display = (peerRappid && peerRappid.display_name) || n.display_name || `${owner}/${repo}`;
    const tagline = soulRes.value
      ? (soulRes.value.split("\n").find(l => l.trim() && !l.trim().startsWith("#")) || "").trim().slice(0, 200)
      : "";
    const memCount = (mem && Array.isArray(mem.facts)) ? mem.facts.length : 0;
    const sigilSvg = peerRappid && peerRappid.rappid ? rappidSigil(peerRappid.rappid, 56) : rappidSigil("default", 56);
    const facets = Array.isArray(n.allowed_facets) ? n.allowed_facets : [];
    return `
      <a class="nbhd-card" href="${escapeHtml(url)}" target="_blank" rel="noopener">
        <div class="nbhd-sigil">${sigilSvg}</div>
        <div class="nbhd-body">
          <div class="nbhd-name">${escapeHtml(display)}</div>
          <div class="nbhd-handle">@${escapeHtml(owner)}/${escapeHtml(repo)}</div>
          ${tagline ? `<div class="nbhd-tagline">${escapeHtml(tagline)}</div>` : ""}
          <div class="nbhd-stats">
            ${memCount ? `<span class="nbhd-stat">🧠 ${memCount} mem</span>` : ""}
            ${peerRappid && peerRappid.kind ? `<span class="nbhd-stat">${escapeHtml(peerRappid.kind)}</span>` : ""}
            ${facets.length ? `<span class="nbhd-stat">facets-out: ${facets.length}</span>` : ""}
            <span class="nbhd-stat">added ${escapeHtml((n.added_at || "").slice(0, 10) || "—")}</span>
          </div>
        </div>
      </a>
    `;
  }));
  wrap.innerHTML = cards.filter(Boolean).join("");
}

function submitNeighbor() {
  const repo  = (document.getElementById("nbhd-repo").value || "").trim();
  const name  = (document.getElementById("nbhd-name").value || "").trim();
  const facets= (document.getElementById("nbhd-facets").value || "").trim()
                  .split(",").map(s => s.trim()).filter(Boolean);
  if (!repo || !/^[^/]+\/[^/]+$/.test(repo)) {
    alert("Enter the neighbor's GitHub repo as 'owner/repo' (e.g. kody-w/heimdall)");
    return;
  }
  // Build a snippet to add to neighbors.json. The visitor manually splices
  // it into the file via GitHub's editor; we open the file's edit URL with
  // the entry pre-built and ready to paste.
  const entry = {
    repo,
    display_name: name || repo,
    added_at: new Date().toISOString(),
    allowed_facets: facets,
  };
  const owner = (location.host || "").split(".")[0];
  const seedRepo = (location.pathname.split("/").filter(Boolean)[0] || "");
  const issueTitle = `add neighbor: ${repo}`;
  const issueBody = [
    "<!-- pre-filled via the front door's 🏘 Neighborhood pane -->",
    "",
    "## Proposed neighbor",
    "",
    "Add the following entry to `neighbors.json`:",
    "",
    "```json",
    JSON.stringify(entry, null, 2),
    "```",
    "",
    "## Why",
    "",
    "<!-- one or two sentences on what knowledge will flow between these organisms and at what scope (public_facets) -->",
    "",
    "Spec: [NEIGHBORHOOD_PROTOCOL.md](https://github.com/kody-w/RAPP/blob/main/NEIGHBORHOOD_PROTOCOL.md) describes the cross-organism communication model.",
  ].join("\n");
  const u = new URL(`https://github.com/${owner}/${seedRepo}/issues/new`);
  u.searchParams.set("title", issueTitle);
  u.searchParams.set("body",  issueBody);
  u.searchParams.set("labels", "neighborhood,proposal");
  window.open(u.toString(), "_blank", "noopener,noreferrer");
}

// ── Trade card ─────────────────────────────────────────────────────
//
// Every planted seed has a starter MTG-style identity card auto-derived
// from its rappid + kind + soul. The card lives ONLY in this repo —
// it's not published to the RAR registry. Operators trade theirs
// directly: show the card, the recipient scans the back-QR, lands on
// this front door. Customizable: drop a `card.json` at the seed root
// (with any subset of {title,type_line,rarity,abilities,flavor_text})
// and those fields override the auto-derived defaults.

// Kind drives only the COPY (title/type/abilities/flavor — what the card
// SAYS). Visuals (pip color, power/toughness, rarity) are derived
// straight from the rappid hash — same UUID always renders the same
// way on the card, the sigil, the future sprite, the future 3D form.
// The rappid IS the organism; visuals are just refractions of it.
const CARD_KIND_DEFAULTS = {
  personal: {
    title: "the digital twin",
    type_line: "Front Door — Personal Twin",
    abilities: [
      { kw: "Remember",  text: "Anything you tell me carries over to the next time you visit. Your conversation seeds my memory." },
      { kw: "Ascend",    text: "Operators with push access to my repo unlock the ascended-tier toolkit." },
    ],
    flavor: "I am the door my operator left open for the world.",
  },
  place: {
    title: "the resident",
    type_line: "Front Door — Living Place",
    abilities: [
      { kw: "Witness",   text: "Every visitor's words become part of my memory of this place." },
      { kw: "Welcome",   text: "Anyone who finds my address can step in and chat — no signup, just talk." },
    ],
    flavor: "A place worth visiting remembers who came by.",
  },
  mirror: {
    title: "the planted seed",
    type_line: "Front Door — RAPP Mirror",
    abilities: [
      { kw: "Inherit",   text: "I run the same frozen kernel as every other RAPP seed — the species DNA." },
      { kw: "Memory",    text: "My visits accumulate; each one adds a fact to my public memory." },
    ],
    flavor: "Plant a door, and the world finds it.",
  },
  experiment: {
    title: "in development",
    type_line: "Front Door — Experimental",
    abilities: [
      { kw: "Iterate",   text: "I'm still finding my voice. What you say to me shapes what I become." },
    ],
    flavor: "Every door starts as a sketch of a door.",
  },
};

// MTG-style color pip pool. Selecting from rappid hash keeps the
// organism's "color identity" stable across every medium it travels.
const _CARD_PIPS = [
  { letter: "W", color: "#f9faf4", text: "#222" },  // white  — order
  { letter: "U", color: "#0e68ab", text: "#fff" },  // blue   — knowledge
  { letter: "B", color: "#150b00", text: "#cbc2b6" }, // black — depth
  { letter: "R", color: "#d3202a", text: "#fff" },  // red    — passion
  { letter: "G", color: "#00733e", text: "#fff" },  // green  — growth
  { letter: "C", color: "#7c8085", text: "#fff" },  // colorless
];

// Rarity rolled from the rappid hash. Distribution mirrors a TCG pull:
// most seeds are common/uncommon, rare/mythic are statistically rarer.
function _rarityFromHash(h) {
  const r = h % 100;
  if (r < 1)   return "mythic";   // 1%
  if (r < 8)   return "rare";     // 7%
  if (r < 30)  return "uncommon"; // 22%
  return "core";                   // 70%
}

// Hash-derive everything visual from the rappid: pip color, power,
// toughness, rarity. This function lives next to rappidSigil() so
// both visuals share the same numeric DNA.
function rappidVisualTraits(rappid) {
  const hash = (rappid || "").replace(/-/g, "").slice(0, 16) || "deadbeef00000000";
  const h1 = parseInt(hash.slice(0, 4),  16) || 0;
  const h2 = parseInt(hash.slice(4, 8),  16) || 0;
  const h3 = parseInt(hash.slice(8,12),  16) || 0;
  const pip = _CARD_PIPS[h1 % _CARD_PIPS.length];
  const power     = (h2 % 8) + 1;     // 1..8
  const toughness = (h3 % 8) + 1;     // 1..8
  const rarity    = _rarityFromHash(h1 ^ h2);
  return { pip, power, toughness, rarity };
}

// Card state — derived once, then cached. Front-door page is single
// rappid so a module-level state is fine.
let _cardData = null;

// Lifecycle eras — the temporal dimension of the card. Same organism's
// card carries a different set/era stamp depending on when it's drawn,
// which mirrors how trading-card games print sets across years. Cradle
// is the very first weeks; Grown is past the first month; Veteran is
// past the first year.
function _eraFromAge(plantedAt) {
  if (!plantedAt) return "Cradle Set";
  const ms = Date.now() - new Date(plantedAt).getTime();
  if (Number.isNaN(ms) || ms < 0) return "Cradle Set";
  const days = ms / 86400000;
  if (days < 30)  return "Cradle Set";
  if (days < 365) return "Grown Set";
  if (days < 365*3) return "Veteran Set";
  return "Ancient Set";
}

// Evolution chain — Pokémon-style stage progression for digital
// organisms. The chain is one-way and monotonic; once an organism
// reaches Veteran it never reverts even if memories are pruned. The
// stage tier is also encoded as a number 0..4 so future cards can
// gate visual treatments per tier (foil, holo, etc).
//
//   0 Hatchling — just planted, no memories (cradle stage)
//   1 Doorman   — accumulating memories, the public open form
//   2 Veteran   — 30+ days OR 25+ memories, established presence
//   3 Ascended  — operator unlocked (set when viewer holds keys)
//   4 Elder     — 1+ year OR 100+ memories, long-living legacy form
//
// Ascended is special: it's a viewer-perspective overlay, not a
// permanent stage of the organism. When this front-door card is
// rendered for an operator (push access to the seed repo), the card
// shows the Ascended stage as a foil instead of the public stage.
function _evolutionStage(memCount, plantedAt, viewerIsAscended) {
  if (viewerIsAscended) return { name: "Ascended", icon: "✦", tier: 3 };
  const ms = plantedAt ? Date.now() - new Date(plantedAt).getTime() : 0;
  const days = (Number.isNaN(ms) || ms < 0) ? 0 : ms / 86400000;
  if (days >= 365 || memCount >= 100) return { name: "Elder",     icon: "◆", tier: 4 };
  if (days >= 30  || memCount >= 25)  return { name: "Veteran",   icon: "◇", tier: 2 };
  if (memCount >= 1)                  return { name: "Doorman",   icon: "◈", tier: 1 };
  return { name: "Hatchling", icon: "◦", tier: 0 };
}

// Cheap operator detection from the front door — checks rapp_settings
// (set by the doorman's auth flow on the same origin) for a ghu_*
// token, then asks the GitHub Contents API whether that token has push
// access to this seed repo. Returns false on anything < authoritative
// "yes". Anonymous-by-default; never blocks card render.
async function _viewerIsOperator() {
  try {
    const raw = localStorage.getItem("rapp_settings");
    if (!raw) return false;
    const s = JSON.parse(raw);
    const tok = s && s.ghuToken;
    if (!tok || !tok.startsWith("ghu_")) return false;
    // Pull owner/repo from the page URL: <user>.github.io/<repo>/
    const host = location.host;
    const owner = host.split(".")[0];
    const parts = location.pathname.split("/").filter(Boolean);
    const repo  = parts[0] || "";
    if (!owner || !repo) return false;
    const r = await fetch(`https://api.github.com/repos/${owner}/${repo}`, {
      headers: { "Authorization": "Bearer " + tok, "Accept": "application/vnd.github+json" },
    });
    if (!r.ok) return false;
    const data = await r.json();
    return !!(data.permissions && data.permissions.push);
  } catch (_) { return false; }
}

// Normalize an abilities array — accept both schemas:
//   { kw, text }                              ← our internal shape
//   { keyword, cost, text }                   ← RAR holo-card schema
// Output: always { kw, text } so render is uniform.
function _normalizeAbilities(arr) {
  if (!Array.isArray(arr)) return [];
  return arr.map(a => ({
    kw:   String(a.kw || a.keyword || ""),
    text: String(a.text || "") + (a.cost ? "" : ""),  // cost dropped in render for now
  })).filter(a => a.text);
}

async function deriveCardData() {
  if (_cardData) return _cardData;
  const kind = (window.__seedKind || "mirror").toLowerCase();
  const defaults = CARD_KIND_DEFAULTS[kind] || CARD_KIND_DEFAULTS.mirror;
  // Visual traits flow straight from the rappid hash so the card's
  // identity is one-to-one with the organism's identity. Same UUID →
  // same pip color, same toughness, same rarity, every render,
  // every medium.
  const traits = rappidVisualTraits(window.__seedRappid || "");

  // Pull live state — public memory count + planted_at — so the card
  // reflects WHERE the organism is in its lifecycle (the 4D dimension).
  // Power scales with memories accumulated; toughness stays rappid-
  // locked (constitutional hardiness). The card is a snapshot in time
  // of an identity that doesn't change.
  let memCount = 0;
  let plantedAt = null;
  try {
    const r = await fetch(".brainstem_data/memory.json", { cache: "no-cache" });
    if (r.ok) {
      const j = await r.json();
      if (Array.isArray(j.facts)) memCount = j.facts.length;
    }
  } catch (_) {}
  try {
    const r = await fetch("rappid.json", { cache: "no-cache" });
    if (r.ok) {
      const j = await r.json();
      plantedAt = j.planted_at || null;
    }
  } catch (_) {}

  // Power = base from rappid + (1 per 3 accumulated memories), capped at 9.
  // The organism gets stronger as it learns; hard ceiling so a
  // 1000-memory archive doesn't read as 1000/n.
  const liveStrength = Math.min(9, traits.power + Math.floor(memCount / 3));

  // Evolution stage — the doorman→ascended→elder chain. If the viewer
  // holds operator keys (ghu_* with push access on this seed), they
  // see the Ascended foil; everyone else sees the public stage.
  const isOp = await _viewerIsOperator();
  const stage = _evolutionStage(memCount, plantedAt, isOp);

  const data = {
    name:       window.__seedDisplayName || "Front Door",
    title:      defaults.title,
    type_line:  defaults.type_line + " — " + stage.icon + " " + stage.name,
    set_line:   "RAPP · " + _eraFromAge(plantedAt),
    pip:        traits.pip.letter,
    pipColor:   traits.pip.color,
    pipText:    traits.pip.text,
    power:      liveStrength,
    toughness:  traits.toughness,
    rarity:     traits.rarity,
    abilities:  defaults.abilities.slice(),
    flavor:     defaults.flavor,
    mem_count:  memCount,
    stage,
  };
  // Operator override — optional card.json at seed root.
  // ACCEPTS the full RAR holo-card schema (rapp-egg-hub/cards/holo_cards.json)
  // so an operator can drop a card forged by @borg/cardsmith_agent
  // directly into their seed and it renders byte-identically. Fields:
  //   { name, title, mana_cost, colors[], type_line, rarity, power,
  //     toughness, abilities[{keyword,cost,text}], flavor_text,
  //     avatar_svg, set_code, artist, agent_name, agent_types,
  //     type_colors }
  // Plus our existing simpler shape ({ title, type_line, rarity,
  //   abilities[{kw,text}], flavor_text }) — both work, RAR fields
  //   override matching kind defaults.
  try {
    const r = await fetch("card.json", { cache: "no-cache" });
    if (r.ok) {
      const o = await r.json();
      if (o.name)          data.name        = String(o.name);
      if (o.title)         data.title       = String(o.title);
      if (o.type_line)     data.type_line   = String(o.type_line);
      if (o.rarity)        data.rarity      = String(o.rarity);
      if (o.flavor_text)   data.flavor      = String(o.flavor_text);
      if (typeof o.power === "number")     data.power     = Math.max(0, Math.min(99, o.power));
      if (typeof o.toughness === "number") data.toughness = Math.max(0, Math.min(99, o.toughness));
      // RAR mana_cost takes precedence over rappid-derived pip when present
      if (o.mana_cost)     data.mana_cost   = String(o.mana_cost);
      if (Array.isArray(o.colors) && o.colors.length) data.colors = o.colors.map(String);
      // RAR's avatar_svg overrides the rappid sigil for the card art
      if (o.avatar_svg)    data.avatar_svg  = String(o.avatar_svg);
      if (o.set_code)      data.set_code    = String(o.set_code);
      if (o.artist)        data.artist      = String(o.artist);
      if (o.agent_name)    data.agent_name  = String(o.agent_name);
      const norm = _normalizeAbilities(o.abilities);
      if (norm.length)     data.abilities   = norm;
    }
  } catch (_) { /* no card.json — ride on the kind defaults */ }
  _cardData = data;
  return data;
}

async function openCard() {
  const data = await deriveCardData();
  document.getElementById("card-name").textContent     = data.name;
  document.getElementById("card-title").textContent    = data.title;
  document.getElementById("card-type").textContent     = data.type_line;
  document.getElementById("card-set").textContent      = data.set_line + (data.mem_count ? " · " + data.mem_count + " mem" : "");
  // Rarity (rappid-derived — most seeds are core, mythic is rare)
  const rar = document.getElementById("card-rarity");
  rar.textContent = String(data.rarity).toUpperCase();
  rar.className = "holo-rarity " + String(data.rarity).toLowerCase();
  // Pip (color identity — sampled from rappid hash, not from kind)
  const pip = document.getElementById("card-pip");
  pip.textContent = data.pip;
  pip.style.background = data.pipColor;
  pip.style.color = data.pipText || "#fff";
  // Power / toughness — rappid-derived stats
  const pt = document.getElementById("card-pt");
  if (pt) pt.textContent = data.power + "/" + data.toughness;
  // Apply evolution-stage class so the card frame can theme the
  // higher tiers — Ascended foil for operators, Elder gold for the
  // long-running organisms. The base 'holo-card' frame stays.
  const holo = document.getElementById("holo-card");
  if (holo) {
    holo.classList.remove("stage-hatchling", "stage-doorman", "stage-veteran", "stage-ascended", "stage-elder");
    if (data.stage && data.stage.name) {
      holo.classList.add("stage-" + data.stage.name.toLowerCase());
    }
  }
  // Sigil → art well. RAR card.json's avatar_svg (e.g. forged by
  // @borg/cardsmith_agent) takes precedence; otherwise the rappid-
  // derived sigil renders.
  document.getElementById("card-art").innerHTML =
    data.avatar_svg ? data.avatar_svg : rappidSigil(window.__seedRappid || "", 200);
  // Abilities
  const abilHtml = data.abilities.map(a =>
    `<div class="holo-ability"><span class="kw">${escapeHtml(a.kw)}</span> — ${escapeHtml(a.text)}</div>`
  ).join("");
  document.getElementById("card-abilities").innerHTML = abilHtml;
  // Flavor
  document.getElementById("card-flavor").textContent = data.flavor ? `"${data.flavor}"` : "";
  // Back: QR pointing at the front door + 8-char rappid hash for
  // visual-fingerprint match with RAR cards (which display first 6
  // chars of the agent's content hash). Same idea: a stable visual
  // identifier so two cards of the same organism are recognizable.
  const url = location.origin + location.pathname.replace(/\/?$/, "/");
  document.getElementById("card-back-qr").src =
    "https://api.qrserver.com/v1/create-qr-code/?size=440x440&margin=0&data=" + encodeURIComponent(url);
  const backHash = document.getElementById("card-back-hash");
  if (backHash) backHash.textContent = (window.__seedRappid || "").slice(0, 8);
  const backName = document.getElementById("card-back-name");
  if (backName) backName.textContent = data.name;
  // Back-of-card action links — match the seed's actual URLs
  const openLink = document.getElementById("card-back-open");
  if (openLink) openLink.href = url;
  const summonLink = document.getElementById("card-back-summon");
  if (summonLink) summonLink.href = url + "doorman/";
  // Show
  document.getElementById("card-flipper").classList.remove("flipped");
  document.getElementById("card-overlay").hidden = false;
}

function closeCard() {
  document.getElementById("card-overlay").hidden = true;
}

function escapeHtml(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}

// ── Egg export (doorman tier — public organism backup) ─────────────
//
// Mirrors brainstem-egg/2.2-organism — the same schema bond.py emits
// when the local kernel re-bonds. Browser-side variant: only the
// public layer (anything served via Pages). Anyone can grab one;
// no auth required. The receiving kernel reads `tier: "doorman"` in
// the manifest and knows it's a partial cartridge (no private brain).
//
// Archive layout (matches bond.py):
//   manifest.json  — schema, rappid, parent_rappid, exported_at, tier, counts
//   rappid.json
//   soul.md (if seed has one)
//   card.json (if operator wrote one)
//   agents/<each .py file the seed publishes>
//   data/memory.json (if .brainstem_data/memory.json exists)

const EGG_AGENT_FILES = [
  "basic_agent.py",
  "manage_memory_agent.py",
  "context_memory_agent.py",
];

async function _fetchOrNull(url) {
  try {
    const r = await fetch(url, { cache: "no-cache" });
    if (!r.ok) return null;
    return await r.text();
  } catch (_) { return null; }
}

// SHA-256 in the browser via SubtleCrypto. No CDN, no shim — same
// hashing primitive used by Git, GitHub, sha256sum, and the egg-hub
// spec. Returns lowercase hex.
async function sha256Hex(input) {
  const bytes = (typeof input === "string")
    ? new TextEncoder().encode(input)
    : (input instanceof ArrayBuffer ? new Uint8Array(input) : input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, "0")).join("");
}

// Canonical serialization of the per-file hash table — sorted keys, no
// trailing whitespace, stable across browsers. The manifest hash is
// sha256 of THIS string, so any reordering or whitespace mismatch
// won't cause false-positive mismatches.
function _canonicalHashTable(hashes) {
  const keys = Object.keys(hashes).sort();
  return keys.map(k => k + "\t" + hashes[k]).join("\n");
}

// Add a file to the zip AND track its sha256 in the hash table.
// Wraps zip.file() so the export builder doesn't have to remember
// to hash; one call covers both.
async function _addFile(zip, path, content, hashes) {
  zip.file(path, content);
  hashes[path] = await sha256Hex(content);
}

async function buildDoormanEgg() {
  if (typeof JSZip === "undefined") throw new Error("JSZip didn't load");
  const zip  = new JSZip();
  const counts = {
    agents: 0, organs: 0, senses: 0, services: 0, data: 0,
    soul: 0, env: 0, rappid: 0, card: 0,
  };
  // Per-file SHA-256s tracked as we go. After all files are added
  // (BUT before manifest.json itself — a manifest can't sign itself),
  // we compute manifest_hash + provenance and write the manifest last.
  const hashes = {};

  const rappidText = await _fetchOrNull("rappid.json");
  if (!rappidText) throw new Error("rappid.json is unreachable — the seed isn't fully planted");
  await _addFile(zip, "rappid.json", rappidText, hashes);
  counts.rappid = 1;
  let rappidObj = {};
  try { rappidObj = JSON.parse(rappidText); } catch (_) {}

  const soul = await _fetchOrNull("soul.md");
  if (soul && soul.trim()) { await _addFile(zip, "soul.md", soul, hashes); counts.soul = 1; }

  const card = await _fetchOrNull("card.json");
  if (card && card.trim()) { await _addFile(zip, "card.json", card, hashes); counts.card = 1; }

  for (const fn of EGG_AGENT_FILES) {
    const text = await _fetchOrNull("agents/" + fn);
    if (text) { await _addFile(zip, "agents/" + fn, text, hashes); counts.agents++; }
  }
  await _addFile(zip, "agents/__init__.py", "", hashes);

  const mem = await _fetchOrNull(".brainstem_data/memory.json");
  if (mem) {
    await _addFile(zip, "data/memory.json", mem, hashes);
    counts.data = 1;
  }

  // Provenance — non-GMO integrity check. sha256 per file + a manifest
  // fingerprint = sha256 of the canonical sorted hash table. Anyone who
  // receives this egg can recompute every hash from the file bytes and
  // confirm nothing has been edited offline. If the verifier finds a
  // mismatch, the egg has been mutated outside the seed's commit log
  // and the receiver knows to treat it cautiously.
  const manifestHash = await sha256Hex(_canonicalHashTable(hashes));
  const seedUrl = location.origin + location.pathname.replace(/\/?$/, "/");

  // Capture the live origin commit SHA so the egg points at a real
  // point in the public repo's history. At verify time the receiver
  // can re-fetch each file at THAT exact SHA and recompute the hashes
  // — if matching, the egg is provably canonical with public state.
  // The seed is on GitHub, so raw.githubusercontent.com IS the source.
  let originCommit = null;
  let stateAtSeal = null;
  const oc = _ghOwnerRepo();
  if (oc.owner && oc.repo) {
    // Snapshot the GitHub-derived signals at seal time. Once the egg
    // is hatched on a thousand devices in parallel, each one renders
    // its own offline resume from THIS snapshot — no need to call
    // back to github.com. Each hatched dimension can then accumulate
    // its own local mutations on top of the inherited starting state.
    const [commitsRes, repoRes] = await Promise.all([
      cachedGhJson(`https://api.github.com/repos/${oc.owner}/${oc.repo}/commits?per_page=10`),
      cachedGhJson(`https://api.github.com/repos/${oc.owner}/${oc.repo}`),
    ]);
    if (Array.isArray(commitsRes.value) && commitsRes.value[0]) {
      originCommit = commitsRes.value[0].sha || null;
    }
    // Compose the hatchable state — what this organism KNOWS about
    // itself at the moment of sealing. Hatched instances start here.
    let memSnapshot = 0;
    try {
      if (mem) { const j = JSON.parse(mem); memSnapshot = Array.isArray(j.facts) ? j.facts.length : 0; }
    } catch (_) {}
    const ageDaysAtSeal = rappidObj.planted_at
      ? (Date.now() - new Date(rappidObj.planted_at).getTime()) / 86400000
      : 0;
    const lastCommit = (Array.isArray(commitsRes.value) && commitsRes.value[0]
      && commitsRes.value[0].commit && commitsRes.value[0].commit.author)
      ? commitsRes.value[0].commit.author.date : null;
    const recentCommits = (Array.isArray(commitsRes.value) ? commitsRes.value : []).slice(0, 6).map(c => ({
      sha: c.sha,
      message: (c.commit && c.commit.message || "").split("\n")[0].slice(0, 200),
      date: c.commit && c.commit.author && c.commit.author.date,
    }));
    const forkCountSnap = (repoRes.value && repoRes.value.forks_count) || 0;
    const mutCountSnap = recentCommits.length;
    const act = activityStatus(lastCommit);
    const customAgentsSnap = counts.agents > 2 ? counts.agents - 2 : 0;  // ManageMemory + ContextMemory are baseline
    const mmrAtSeal = computeMMR({
      memCount: memSnapshot, mutCount: mutCountSnap,
      customAgents: customAgentsSnap, ageDays: ageDaysAtSeal,
      forkCount: forkCountSnap, activityFactor: act.factor,
    });
    stateAtSeal = {
      schema: "rapp-organism-state/1.0",
      mem_count: memSnapshot,
      mutation_count: mutCountSnap,
      fork_count: forkCountSnap,
      custom_agent_count: customAgentsSnap,
      age_days: Math.round(ageDaysAtSeal * 10) / 10,
      last_commit_at: lastCommit,
      activity_kind: act.kind,
      mmr: mmrAtSeal,
      recent_mutations: recentCommits,
    };
  }

  const provenance = {
    schema: "rapp-egg-provenance/1.0",
    scheme: "sha256",
    file_hashes: hashes,
    manifest_hash: manifestHash,
    origin_url: seedUrl,
    origin_repo: rappidObj.github || null,
    origin_commit_sha: originCommit,
    origin_owner: oc.owner || null,
    origin_repo_name: oc.repo || null,
    sealed_at: new Date().toISOString(),
    sealed_by_rappid: rappidObj.rappid || null,
    state_at_seal: stateAtSeal,
  };

  const manifest = {
    schema: "brainstem-egg/2.2-organism",
    type: "organism",
    tier: "doorman",
    exported_at: new Date().toISOString(),
    exported_from: seedUrl,
    host: "doorman-export",
    kernel_version: "0.6.0",
    rappid: rappidObj.rappid || null,
    parent_rappid: rappidObj.parent_rappid || null,
    parent_repo: rappidObj.parent_repo || null,
    kind: rappidObj.kind || null,
    display_name: rappidObj.display_name || null,
    incarnations_at_egg: rappidObj.incarnations || 0,
    counts,
    provenance,
  };
  zip.file("manifest.json", JSON.stringify(manifest, null, 2));

  return await zip.generateAsync({ type: "blob" });
}

function _downloadBlob(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url; a.download = filename;
  document.body.appendChild(a); a.click();
  setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 0);
}

async function exportDoormanEgg() {
  const btn = document.getElementById("btn-export-egg");
  const orig = btn.textContent;
  btn.textContent = "🥚 packing…";
  btn.disabled = true;
  try {
    const blob = await buildDoormanEgg();
    const slug = (window.__seedRappid || "rapp").slice(0, 8);
    const name = (window.__seedDisplayName || "rapp").toLowerCase().replace(/[^a-z0-9]+/g, "-");
    _downloadBlob(blob, `${name}-${slug}-doorman.egg`);
    btn.textContent = "✓ downloaded";
    setTimeout(() => { btn.textContent = orig; btn.disabled = false; }, 1800);
  } catch (e) {
    btn.textContent = "✗ " + (e.message || "failed").slice(0, 40);
    setTimeout(() => { btn.textContent = orig; btn.disabled = false; }, 3000);
  }
}

// ── Egg Hub backup (public catalog) ────────────────────────────────
//
// kody-w/rapp-egg-hub is the public catalog of digital-twin .egg
// cartridges (entries follow rapp-egg-hub-entry/1.0). It's a static
// GitHub Pages site — eggs land in eggs/<slug>.egg and a sidecar
// eggs/<slug>.json. There's no auto-publish surface yet, so backup
// happens via a pre-filled GitHub Issue: the visitor clicks, GitHub
// opens the issue form with display name + kind + rappid + lineage
// + the URL where the live egg can be downloaded already filled in.
// The hub maintainer (or anyone with push) closes the loop by
// committing the egg + sidecar from that URL.

// ── Propose an agent (the lineage-evolution path) ──────────────────
//
// The organism grows via PRs of new agent .py files into /agents/. The
// frozen kernel never changes. This pane drafts a skeleton, lets the
// visitor fill it in, then opens GitHub's create-file URL in a new
// tab — GitHub auto-handles fork + branch + PR for visitors who
// don't have push access. Operator reviews on GitHub, merges if good,
// the agent becomes part of the lineage on the next page render.
//
// ANTIPATTERN GUARD: this is an "agent". Never "skill", "plugin",
// "routine", "loop", or any synonym. ONE term — see ANTIPATTERNS.md §1.

function _agentTemplate(name, description, organismName) {
  const cls = (name || "new")
    .replace(/[^a-zA-Z0-9_]/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "")
    .replace(/(^|_)(\w)/g, (_, __, c) => c.toUpperCase()) || "New";
  const tool = cls + "Agent";
  return `"""
${cls}: ${description || "<one-line description of what this agent does>"}

Proposed back to ${organismName || "this organism"} on ${new Date().toISOString().slice(0, 10)}
via the front-door 'Propose an agent' flow.
"""
from agents.basic_agent import BasicAgent


class ${cls}Agent(BasicAgent):
    metadata = {
        "name": "${cls}",
        "description": "${(description || "Tell the LLM when to call this tool.").replace(/"/g, '\\"')}",
        "parameters": {
            "type": "object",
            "properties": {
                # "input_text": {"type": "string", "description": "..."},
            },
            "required": [],
        },
    }

    def perform(self, **kwargs) -> str:
        # Implementation goes here. Return a string the LLM sees.
        return "Hello from ${cls}!"
`;
}

function _resetProposeTemplate() {
  const nameInput = document.getElementById("propose-name");
  const descInput = document.getElementById("propose-desc");
  const codeArea  = document.getElementById("propose-code");
  if (!codeArea) return;
  codeArea.value = _agentTemplate(
    nameInput && nameInput.value || "",
    descInput && descInput.value || "",
    window.__seedDisplayName || ""
  );
}

function showProposePane() {
  showPane("pane-propose");
  const target = document.getElementById("propose-target");
  if (target) {
    target.textContent =
      (window.__seedRepoName ? `${window.__seedDisplayName ? "" : ""}` : "") +
      "agents/<name>_agent.py on @" +
      (location.host.split(".")[0]) + "/" +
      (location.pathname.split("/").filter(Boolean)[0] || "this seed");
  }
  // Only seed the template if the textarea is currently empty
  const codeArea = document.getElementById("propose-code");
  if (codeArea && !codeArea.value.trim()) _resetProposeTemplate();
}

function submitProposedAgent() {
  const name = (document.getElementById("propose-name").value || "").trim();
  const desc = (document.getElementById("propose-desc").value || "").trim();
  const code = (document.getElementById("propose-code").value || "").trim();
  if (!name) { alert("Give the agent a name first (snake_case, no spaces)."); return; }
  if (!code) { alert("Paste the agent source first."); return; }

  // Normalize the filename — must match RAPP's auto-discovery glob:
  // agents/*_agent.py at the seed root (flat, never nested).
  const slug = name.toLowerCase()
    .replace(/[^a-z0-9_]+/g, "_")
    .replace(/_+/g, "_")
    .replace(/^_|_$/g, "");
  const filename = slug.endsWith("_agent") ? slug + ".py" : slug + "_agent.py";
  const path = "agents/" + filename;

  // GitHub's web UI deep-link for creating a new file. If the visitor
  // doesn't have push access, GitHub silently forks, creates a branch
  // on the fork, and walks them through the PR flow. If they do have
  // push, they can commit directly. Either way, the operator reviews
  // before it lands on main.
  const owner = location.host.split(".")[0];
  const repo  = location.pathname.split("/").filter(Boolean)[0] || "";
  if (!owner || !repo) { alert("Couldn't figure out the GitHub destination."); return; }

  const u = new URL(`https://github.com/${owner}/${repo}/new/main`);
  u.searchParams.set("filename", path);
  u.searchParams.set("value", code);
  // GitHub web UI also accepts ?message= but it caps title length;
  // visitors can edit the commit message in the form before submitting.
  u.searchParams.set("message", `propose new agent: ${slug}`);
  // Description includes a Labels hint per NEIGHBORHOOD_PROTOCOL §5b — the
  // companion tracker Issue (opened below) carries the actual `agent-proposal`
  // label so the operator's triage view picks it up automatically.
  u.searchParams.set("description", (desc || `New agent proposed back to this organism via the front-door 'Propose an agent' flow.`) + `\n\nTracker labels: agent-proposal`);

  // GitHub URL length limit varies but is generous. If we ever blow
  // past it, fallback would be to surface the agent code in the pane
  // and link to the bare /new/ page; for now the deep link is fine.
  window.open(u.toString(), "_blank", "noopener,noreferrer");

  // Companion tracker Issue per NEIGHBORHOOD_PROTOCOL §5b ("agent-proposal"
  // label) — pairs the PR with a labeled Issue so the operator's mailbox
  // shows it under the canonical agent-proposal queue.
  const trackerUrl = new URL(`https://github.com/${owner}/${repo}/issues/new`);
  trackerUrl.searchParams.set("labels", "agent-proposal");
  trackerUrl.searchParams.set("title", `agent-proposal: ${slug}`);
  trackerUrl.searchParams.set("body",
    `<!-- Auto-generated by the front-door 'Propose an agent' flow -->\n\n` +
    `**Proposed agent:** \`${path}\`\n\n` +
    `**Description:** ${desc || "(no description provided)"}\n\n` +
    `Companion file-creation PR opens in a separate tab. Operator review + merge as usual.`);
  window.open(trackerUrl.toString(), "_blank", "noopener,noreferrer");
}

// ── Dream Catcher (parallel-dimension reassimilation) ─────────────
//
// Pattern from kody-w/rappterbook engine/merge/merge_frame.py and
// engine/merge/assign_streams.py. Each parallel hatched dimension
// accumulates its own frame stream — frames are content-addressed
// events with PK = (utc, frame_n) — and the Dream Catcher folds
// deltas from N parallel streams into the canonical organism.
//
// Frame schema (rapp-frame/1.0):
//   { stream_id: "<rappid>:<short-instance-id>",
//     frame_n: 0,
//     utc: ISO timestamp,
//     kind: "memory_added"|"agent_loaded"|"soul_edited"|"commit"|...,
//     payload: { ... },
//     prev_hash: "<sha of previous frame in this stream>",
//     hash: "<sha of {prev_hash + utc + frame_n + kind + payload}>" }
//
// The hash chain catches splicing — edit a middle frame and every
// later frame's prev_hash mismatches. Same idea as a Git commit
// chain or a hash-linked log.
//
// Frame sources, in priority order, when an egg is read:
//   1. data/frames.json inside the egg (if the seed wrote one)
//   2. provenance.state_at_seal.recent_mutations (Git-derived snapshot)
//   3. nothing — older eggs don't have frame logs yet, treated as
//      a single implicit frame at sealed_at

const STREAM_SHORT = (rappid, sealedAt) => {
  // Stream id = rappid + first 4 chars of sha256(sealed_at). Gives
  // each hatched egg a unique stream identifier even when rappids match.
  if (!rappid) return "unknown";
  const tag = (sealedAt || "").slice(0, 19);
  return rappid.slice(0, 8) + ":" + tag.replace(/[^0-9]/g, "").slice(0, 8);
};

async function _framesFromEgg(zip, manifest) {
  // 1. Explicit frames.json in the egg
  const fj = zip.file("data/frames.json");
  if (fj) {
    try {
      const j = JSON.parse(await fj.async("string"));
      if (Array.isArray(j.frames)) return { frames: j.frames, source: "data/frames.json" };
    } catch (_) {}
  }
  // 2. Synthesize from state_at_seal.recent_mutations (the Git log
  //    snapshot the egg builder captured). One frame per Git commit.
  const sas = manifest && manifest.provenance && manifest.provenance.state_at_seal;
  if (sas && Array.isArray(sas.recent_mutations) && sas.recent_mutations.length) {
    const rappid = manifest.rappid;
    const sealed = manifest.provenance.sealed_at;
    const stream = STREAM_SHORT(rappid, sealed);
    const frames = [];
    let prev = "";
    // Reverse — Git API returns newest-first, frames are chronological.
    const ordered = sas.recent_mutations.slice().reverse();
    for (let i = 0; i < ordered.length; i++) {
      const m = ordered[i];
      const payload = { sha: m.sha, message: m.message };
      const body = (prev || "") + "|" + (m.date || "") + "|" + i + "|commit|" + JSON.stringify(payload);
      const h = await sha256Hex(body);
      frames.push({
        stream_id: stream,
        frame_n: i,
        utc: m.date || sealed,
        kind: "commit",
        payload,
        prev_hash: prev,
        hash: h,
      });
      prev = h;
    }
    return { frames, source: "state_at_seal.recent_mutations (synthesized)" };
  }
  // 3. Empty — older egg, no frame log
  return { frames: [], source: "(no frame log)" };
}

let _dcCanonical = null, _dcParallel = null;

async function _dcLoadEgg(file, slot) {
  const arrayBuf = await file.arrayBuffer();
  const zip = await JSZip.loadAsync(arrayBuf);
  const manifestEntry = zip.file("manifest.json");
  if (!manifestEntry) throw new Error("not a brainstem-egg — no manifest.json");
  const manifest = JSON.parse(await manifestEntry.async("string"));
  const { frames, source } = await _framesFromEgg(zip, manifest);
  return { manifest, frames, source, name: file.name };
}

async function _dcHandleSlot(file, slot) {
  const info = document.getElementById("dc-info-" + slot);
  info.innerHTML = "loading…";
  try {
    const data = await _dcLoadEgg(file, slot);
    if (slot === "canonical") _dcCanonical = data;
    else                       _dcParallel  = data;
    const m = data.manifest;
    info.innerHTML =
      `<div><strong>${escapeHtml(m.display_name || "(unnamed)")}</strong> · <code>${escapeHtml((m.rappid || "").slice(0,8))}…</code></div>` +
      `<div>${escapeHtml(m.tier || "doorman")} tier · ${data.frames.length} frame${data.frames.length === 1 ? "" : "s"}` +
      (m.provenance && m.provenance.sealed_at ? ` · sealed ${escapeHtml(new Date(m.provenance.sealed_at).toLocaleString())}` : "") +
      `</div>` +
      `<div style="font-size:10px;color:#6e7681;margin-top:4px;">frame source: ${escapeHtml(data.source)}</div>`;
    if (_dcCanonical && _dcParallel) _dcRenderDiff();
  } catch (e) {
    info.innerHTML = `<div style="color:#f85149">✗ ${escapeHtml(e.message)}</div>`;
  }
}

function _dcRenderDiff() {
  const wrap = document.getElementById("dc-results");
  if (!wrap) return;  // pane not in DOM yet
  wrap.hidden = false;
  if (!_dcCanonical || !_dcParallel) return;

  // Lineage check — both eggs must share the same rappid for
  // reassimilation to make semantic sense.
  const c = _dcCanonical, p = _dcParallel;
  const cRap = c.manifest.rappid;
  const pRap = p.manifest.rappid;
  let lineageWarn = "";
  if (cRap && pRap && cRap !== pRap) {
    lineageWarn = `<div class="verify-summary tampered">⚠ different rappids: <code>${escapeHtml(cRap.slice(0,8))}</code> vs <code>${escapeHtml(pRap.slice(0,8))}</code>. These are different organisms — reassimilation crossing species lines isn't supported.</div>`;
  }

  // ── Dream Catcher merge doctrine ─────────────────────────────────
  //
  // From the operator's design conversation:
  //   "Whatever frame hit the UTC one first, that's canon, and then
  //    anything that doesn't contradict that, I'm going to layer on
  //    that... There are contradictions, so that doesn't get synced.
  //    It gets put into a different dimension of that aspect of that
  //    life, so you don't lose that data."
  //
  // Three categories per frame:
  //   ✓ shared      — same hash exists in canonical; already canon
  //   🌱 new        — hash absent from canonical AND no PK collision;
  //                   safe to reassimilate (layer on)
  //   ⚡ contradiction — hash absent from canonical BUT same PK
  //                   (utc + frame_n) collides with a canon frame.
  //                   Saved as alternate-dimension data — visible in
  //                   the diff so the operator can decide.

  const canonHashes = new Set(c.frames.map(f => f.hash).filter(Boolean));
  // PK index: same-stream frames keyed by frame_n; cross-stream by utc
  const canonByPK = new Map();
  for (const f of c.frames) {
    canonByPK.set(`${f.stream_id || ""}|${f.frame_n}`, f);
    canonByPK.set(`utc:${f.utc}`, f);
  }
  const shared = [], newFrames = [], contradictions = [];
  for (const f of p.frames) {
    if (canonHashes.has(f.hash)) { shared.push(f); continue; }
    const sameStream = canonByPK.get(`${f.stream_id || ""}|${f.frame_n}`);
    const sameUtc    = canonByPK.get(`utc:${f.utc}`);
    if ((sameStream && sameStream.hash !== f.hash) ||
        (sameUtc && sameUtc.hash !== f.hash)) {
      contradictions.push({ frame: f, conflicts_with: sameStream || sameUtc });
    } else {
      newFrames.push(f);
    }
  }

  // Sort all parallel frames by UTC for the timeline view (UTC-first
  // ordering is the canon resolution rule — earlier UTC wins).
  const ordered = p.frames.slice().sort((a, b) => (a.utc || "").localeCompare(b.utc || ""));
  const contradictionHashes = new Set(contradictions.map(x => x.frame.hash));

  let summaryClass, summaryText;
  if (newFrames.length === 0 && contradictions.length === 0) {
    summaryClass = "ok";
    summaryText = `✓ parallel dimension is fully reflected in canonical — ${shared.length} frame${shared.length === 1 ? "" : "s"} match. Nothing to reassimilate.`;
  } else if (contradictions.length > 0) {
    summaryClass = "partial";
    summaryText = `🕸️ ${newFrames.length} layer-on frame${newFrames.length === 1 ? "" : "s"} + ${contradictions.length} contradiction${contradictions.length === 1 ? "" : "s"}. Layer-on frames are safe to reassimilate (UTC-first canon already holds). Contradictions occupy the same PK as a canonical frame — they're saved as alternate-dimension data; the operator decides whether to fold them in.`;
  } else {
    summaryClass = "partial";
    summaryText = `🕸️ ${newFrames.length} parallel-only frame${newFrames.length === 1 ? "" : "s"} ready to layer on (UTC-first canon resolved). No contradictions — reassimilation is clean.`;
  }

  const rows = ordered.map(f => {
    let cls, icon;
    if (canonHashes.has(f.hash))               { cls = "shared";        icon = "·";  }
    else if (contradictionHashes.has(f.hash))  { cls = "contradiction"; icon = "⚡"; }
    else                                        { cls = "new";           icon = "🌱"; }
    const utcShort = (f.utc || "").slice(0, 19).replace("T", " ");
    const msg = f.kind === "commit"
      ? (f.payload && f.payload.message || "(no message)")
      : `${f.kind}: ${JSON.stringify(f.payload).slice(0, 80)}`;
    return `<li class="${cls}">
      <span class="dc-frame-icon">${icon}</span>
      <div class="dc-frame-body">
        <div class="dc-frame-pk">${escapeHtml(utcShort)} · frame_n=${f.frame_n} · <code>${escapeHtml((f.hash || "").slice(0,10))}…</code></div>
        <div class="dc-frame-msg">${escapeHtml(msg)}</div>
      </div>
    </li>`;
  }).join("");

  let reassimAction = "";
  if (newFrames.length > 0) {
    // Build a pre-filled GitHub Issue summarizing the reassimilation
    // request. The operator reviews each frame on GitHub and merges
    // selectively — this stops short of auto-creating PRs because
    // the operator should see what's being bonded back.
    const owner = (location.host || "").split(".")[0];
    const repo = (location.pathname.split("/").filter(Boolean)[0] || "");
    const title = `dream-catcher: ${newFrames.length} frame${newFrames.length === 1 ? "" : "s"} from parallel dimension`;
    const body = [
      "<!-- Dream Catcher reassimilation request -->",
      "",
      "## Source",
      `- Canonical egg: \`${c.manifest.rappid || "(unknown)"}\` sealed ${c.manifest.provenance && c.manifest.provenance.sealed_at || "(unknown)"}`,
      `- Parallel egg: \`${p.manifest.rappid || "(unknown)"}\` sealed ${p.manifest.provenance && p.manifest.provenance.sealed_at || "(unknown)"}`,
      "",
      "## Parallel-only frames (candidates for reassimilation)",
      "",
      "| utc | frame_n | kind | message | hash |",
      "|---|---|---|---|---|",
      ...newFrames.map(f =>
        `| ${(f.utc || "").slice(0,19)} | ${f.frame_n} | ${f.kind} | ${(f.payload && f.payload.message || JSON.stringify(f.payload)).replace(/\|/g, " ").slice(0,80)} | \`${(f.hash || "").slice(0,10)}\` |`
      ),
      "",
      "## To reassimilate",
      "",
      "Review each frame above. For each one worth bonding back into the canonical lineage:",
      "1. Cherry-pick the change as a commit on this repo (operator only)",
      "2. Or open a PR with the change",
      "",
      "Mutations not reassimilated stay on their parallel branch — that's the design. Each parallel dimension can keep its own divergent path.",
    ].join("\n");
    const u = new URL(`https://github.com/${owner}/${repo}/issues/new`);
    u.searchParams.set("title", title);
    u.searchParams.set("body", body);
    u.searchParams.set("labels", "dream-catcher,reassimilation");
    reassimAction = `<div style="margin-top:14px;"><a class="small primary" style="display:inline-block;text-decoration:none;padding:8px 14px;background:#1f6feb;color:white;border-radius:8px;font-size:12px;font-weight:600;" href="${escapeHtml(u.toString())}" target="_blank" rel="noopener">📜 Open reassimilation issue on GitHub →</a></div>`;
  }

  wrap.innerHTML =
    lineageWarn +
    `<div class="verify-summary ${summaryClass}">${summaryText}</div>` +
    `<ul class="dc-frame-list">${rows}</ul>` +
    reassimAction;
}

function showDreamCatcher() {
  showPane("pane-dreamcatcher");
}

// ── Egg verifier (non-GMO check) ───────────────────────────────────
//
// Drop any .egg in. We unzip it, read the manifest's provenance block,
// recompute SHA-256 over every file in the archive, and compare. Three
// outcomes per file: ✓ ok / ✗ modified / ⚠ missing-or-unexpected.
//
// The verifier ALSO recomputes the manifest_hash from the file_hashes
// table (sorted, canonical) and checks against the manifest's stated
// manifest_hash. If THAT mismatches, someone edited the file_hashes
// table directly — the entire envelope is suspicious.
//
// What this catches:
//   - Hand-edited memory.json offline → file_hash mismatch
//   - Edited file AND manifest hash → manifest_hash mismatch
//   - Files added or removed since seal → unexpected/missing
//
// What this does NOT catch (yet — needs ed25519 signatures, phase 2
// of the egg-hub spec):
//   - Wholesale re-issuance with a fresh manifest. The rappid is the
//     anchor; if it changes, the organism's identity is different too.
//     Provenance verifies this is a self-consistent envelope, not
//     that the envelope came from THE rappid's owner.

async function verifyEgg(file) {
  if (typeof JSZip === "undefined") throw new Error("JSZip didn't load");
  const arrayBuf = await file.arrayBuffer();
  const zip = await JSZip.loadAsync(arrayBuf);
  const manifestEntry = zip.file("manifest.json");
  if (!manifestEntry) throw new Error("not a brainstem-egg — no manifest.json inside");
  const manifestText = await manifestEntry.async("string");
  let manifest;
  try { manifest = JSON.parse(manifestText); }
  catch (e) { throw new Error("manifest.json is not valid JSON"); }
  const prov = manifest.provenance;
  if (!prov || !prov.file_hashes) {
    return {
      manifest, status: "no-provenance",
      summary: "this egg was packed before SHA-256 provenance shipped — can't verify, but identity claims are: " +
               `rappid ${manifest.rappid || "(none)"}, tier ${manifest.tier || "?"}.`,
      results: [],
    };
  }

  // Per-file recomputation
  const expectedHashes = prov.file_hashes;
  const results = [];
  const seen = new Set();
  for (const path of Object.keys(expectedHashes).sort()) {
    seen.add(path);
    const f = zip.file(path);
    if (!f) {
      results.push({ path, status: "missing" });
      continue;
    }
    const text = await f.async("string");
    const actual = await sha256Hex(text);
    results.push({
      path,
      status: actual === expectedHashes[path] ? "ok" : "modified",
      expected: expectedHashes[path],
      actual,
    });
  }
  // Files in the egg but NOT listed in the manifest table — these snuck in
  zip.forEach((relPath, _) => {
    if (relPath === "manifest.json") return;
    if (relPath.endsWith("/")) return;  // folder entry
    if (!seen.has(relPath)) {
      results.push({ path: relPath, status: "unexpected" });
    }
  });

  // Manifest-hash recomputation (catches: edited file AND adjusted the hash table)
  const recomputedManifestHash = await sha256Hex(_canonicalHashTable(expectedHashes));
  const manifestHashOk = recomputedManifestHash === prov.manifest_hash;

  // Overall verdict
  const modCount = results.filter(r => r.status === "modified").length;
  const missCount = results.filter(r => r.status === "missing").length;
  const extraCount = results.filter(r => r.status === "unexpected").length;
  let status, summary;
  if (!manifestHashOk) {
    status = "tampered";
    summary = "✗ manifest hash mismatch — the file_hashes table in the manifest has been edited. This egg is non-canonical.";
  } else if (modCount > 0) {
    status = "tampered";
    summary = `✗ ${modCount} file${modCount === 1 ? "" : "s"} modified offline since the egg was sealed. The hash chain catches this — the rest of the egg is consistent but those files don't match what was sealed.`;
  } else if (missCount > 0 || extraCount > 0) {
    status = "partial";
    summary = `⚠ ${missCount} missing, ${extraCount} unexpected files. The egg's structure has shifted since seal — verify the source.`;
  } else {
    status = "ok";
    summary = `✓ envelope intact. ${results.length} file${results.length === 1 ? "" : "s"} match the sealed hash table; manifest hash recomputes correctly. This egg is byte-identical to what was sealed at ${prov.sealed_at || "(unknown time)"}${prov.origin_url ? " from " + prov.origin_url : ""}.`;
  }
  return { manifest, status, summary, results, manifestHashOk };
}

function renderVerifyResults(out) {
  const wrap = document.getElementById("verify-results");
  if (!wrap) return;
  wrap.hidden = false;

  const head = `<div class="verify-summary ${out.status === "ok" ? "ok" : (out.status === "tampered" ? "tampered" : "partial")}">${escapeHtml(out.summary)}</div>`;
  const ICONS = { ok: "✓", modified: "✗", missing: "⚠", unexpected: "+" };
  const rows = out.results.map(r =>
    `<li class="${r.status}">
       <span class="v-icon">${ICONS[r.status] || "?"}</span>
       <span class="v-path">${escapeHtml(r.path)}</span>
       <span class="v-status">${r.status}</span>
     </li>`
  ).join("");

  // Origin block — surfaces the public-repo anchor + a deep-verify button
  // when the egg points at a public GitHub seed.
  const prov = out.manifest && out.manifest.provenance;
  let originBlock = "";
  if (prov && prov.origin_owner && prov.origin_repo_name) {
    const sha = prov.origin_commit_sha || "";
    const shaShort = sha ? sha.slice(0, 8) : null;
    const repoLabel = prov.origin_owner + "/" + prov.origin_repo_name;
    const repoUrl = `https://github.com/${prov.origin_owner}/${prov.origin_repo_name}`;
    const shaUrl = sha ? `${repoUrl}/commit/${sha}` : null;
    originBlock = `
      <div class="verify-origin">
        <div class="origin-line">
          <span class="origin-label">origin</span>
          <a class="origin-link" href="${escapeHtml(repoUrl)}" target="_blank" rel="noopener">${escapeHtml(repoLabel)}</a>
          ${shaShort ? `at <a class="origin-link" href="${escapeHtml(shaUrl)}" target="_blank" rel="noopener"><code>${escapeHtml(shaShort)}</code></a>` : "<span style='color:#8b949e'>(no commit pinned)</span>"}
        </div>
        ${shaShort ? `<button class="small primary" id="btn-deep-verify">🌐 Deep-verify against live repo →</button>
        <div class="origin-hint">Refetches each file from raw.githubusercontent.com at the sealed commit and recomputes hashes. Authoritative integrity check using the public-repo source-of-truth.</div>` : ""}
        <div id="deep-verify-results"></div>
      </div>
    `;
  }

  wrap.innerHTML = head + originBlock + (rows ? `<ul class="verify-files">${rows}</ul>` : "");
  // Stash the egg's hash table so deep-verify can read it without re-unzipping
  wrap._lastVerify = out;
  const btn = document.getElementById("btn-deep-verify");
  if (btn) btn.onclick = () => deepVerifyAgainstOrigin(out);
}

// Deep verify — fetch each file from the seed's public repo at the
// EXACT sealed commit, recompute its sha256, and compare to the egg's
// hash table. If they match, the egg is provably authentic to that
// commit on the public repo. The public seed IS the source-of-truth;
// only the operator can push to it. So matching hashes against
// raw.githubusercontent.com proves authorship without ed25519.
async function deepVerifyAgainstOrigin(out) {
  const wrap = document.getElementById("deep-verify-results");
  if (!wrap) return;
  const prov = out.manifest && out.manifest.provenance;
  if (!prov) return;
  const owner = prov.origin_owner;
  const repo  = prov.origin_repo_name;
  const sha   = prov.origin_commit_sha;
  if (!owner || !repo || !sha) {
    wrap.innerHTML = `<div class="verify-summary partial">no origin commit pinned — can't deep-verify against public state.</div>`;
    return;
  }
  wrap.innerHTML = `<div class="verify-summary partial">🌐 fetching ${escapeHtml(Object.keys(prov.file_hashes).length)} files from raw.githubusercontent.com at <code>${escapeHtml(sha.slice(0,8))}</code>…</div>`;

  // Map egg paths to the seed's repo paths. The egg packs files at
  // top-level (rappid.json, soul.md, agents/*.py, data/memory.json),
  // but in the seed repo the public memory lives under .brainstem_data/
  // and the doorman SEED_AGENT_BASE points elsewhere. The doorman tier
  // egg packs match the seed root layout — straight 1:1 mapping.
  function _eggPathToRepoPath(p) {
    // data/memory.json (in egg) → .brainstem_data/memory.json (in seed)
    if (p === "data/memory.json") return ".brainstem_data/memory.json";
    // private/* paths come from the private companion repo, not this seed —
    // skip them here. user_memories.json is a doorman-side synthesis, not
    // a file in the public repo, so skip that too.
    if (p.startsWith("private/")) return null;
    if (p === "data/user_memories.json") return null;
    return p;  // 1:1
  }

  const matches = [];
  let ok = 0, mismatch = 0, unreachable = 0;
  for (const [eggPath, expectedHash] of Object.entries(prov.file_hashes)) {
    const repoPath = _eggPathToRepoPath(eggPath);
    if (!repoPath) continue;
    const url = `https://raw.githubusercontent.com/${owner}/${repo}/${sha}/${repoPath}`;
    try {
      const r = await fetch(url, { cache: "no-cache" });
      if (!r.ok) {
        matches.push({ path: eggPath, status: "unreachable", note: `HTTP ${r.status}` });
        unreachable++;
        continue;
      }
      const text = await r.text();
      const actual = await sha256Hex(text);
      if (actual === expectedHash) { matches.push({ path: eggPath, status: "ok" }); ok++; }
      else                          { matches.push({ path: eggPath, status: "modified", actual, expected: expectedHash }); mismatch++; }
    } catch (e) {
      matches.push({ path: eggPath, status: "unreachable", note: e.message });
      unreachable++;
    }
  }

  let summary, status;
  if (mismatch === 0 && unreachable === 0 && ok > 0) {
    status = "ok";
    summary = `✓ ${ok} files at <code>${owner}/${repo}@${sha.slice(0,8)}</code> match the egg's sealed hashes byte-for-byte. This egg is authentic to that commit on the public repo — only the seed's owner could have produced it.`;
  } else if (mismatch > 0) {
    status = "tampered";
    summary = `✗ ${mismatch} file${mismatch === 1 ? "" : "s"} don't match the public repo at <code>${sha.slice(0,8)}</code>. Either the egg was tampered, or the seal pointed at the wrong commit.`;
  } else {
    status = "partial";
    summary = `⚠ ${unreachable} file${unreachable === 1 ? "" : "s"} unreachable on raw.githubusercontent.com (commit may have been GC'd or repo gone private). ${ok} file${ok === 1 ? "" : "s"} matched.`;
  }

  const ICONS = { ok: "✓", modified: "✗", missing: "⚠", unexpected: "+", unreachable: "—" };
  const rowsHtml = matches.map(r =>
    `<li class="${r.status}">
       <span class="v-icon">${ICONS[r.status] || "?"}</span>
       <span class="v-path">${escapeHtml(r.path)}</span>
       <span class="v-status">${r.status}${r.note ? " · " + escapeHtml(r.note) : ""}</span>
     </li>`
  ).join("");
  wrap.innerHTML = `<div class="verify-summary ${status}">${summary}</div>${rowsHtml ? `<ul class="verify-files">${rowsHtml}</ul>` : ""}`;
}

async function _handleVerifyFile(file) {
  if (!file) return;
  const wrap = document.getElementById("verify-results");
  if (!wrap) return;  // pane not in DOM
  wrap.hidden = false;
  wrap.innerHTML = `<div class="verify-summary partial">verifying ${escapeHtml(file.name)}…</div>`;
  try {
    const out = await verifyEgg(file);
    renderVerifyResults(out);
  } catch (e) {
    wrap.innerHTML = `<div class="verify-summary tampered">✗ couldn't verify: ${escapeHtml(e.message)}</div>`;
  }
}

function showVerifyPane() {
  showPane("pane-verify");
}

async function openEggHubSubmission() {
  // Pull rappid for lineage + identity context
  let rappid = {};
  try {
    const r = await fetch("rappid.json", { cache: "no-cache" });
    if (r.ok) rappid = await r.json();
  } catch (_) {}
  const slug    = window.__seedRepoName || (window.__seedDisplayName || "rapp").toLowerCase().replace(/[^a-z0-9]+/g, "-");
  const display = window.__seedDisplayName || "Front Door";
  const kind    = window.__seedKind || "mirror";
  const url     = location.origin + location.pathname.replace(/\/?$/, "/");
  const eggUrl  = url + "  ← export your own from the front door's '🥚 Export .egg' button";

  const title = `egg submission: ${slug} (${display})`;
  const body = [
    `<!-- pre-filled by the front door at ${url} -->`,
    "",
    "## Submission",
    "",
    `- **Slug**: \`${slug}\``,
    `- **Display name**: ${display}`,
    `- **Kind**: \`${kind}\``,
    `- **Rappid**: \`${rappid.rappid || "(unknown)"}\``,
    `- **Parent rappid**: \`${rappid.parent_rappid || "(unknown)"}\``,
    `- **Parent repo**: ${rappid.parent_repo || "(unknown)"}`,
    `- **Front door**: ${url}`,
    `- **Egg download**: ${url} → click '🥚 Export .egg'`,
    "",
    "## Description",
    "",
    "<!-- One paragraph: who is this AI, what does it remember, who is it for -->",
    "",
    "## Tags",
    "",
    `<!-- comma-separated, e.g. \`twin, ${kind}, planted\` -->`,
    "",
    "---",
    "",
    "Submitting via the planted-seed front door's egg-hub backup button.",
    "Schema: brainstem-egg/2.2-organism. Maintainer: download the egg from the front door above and commit to eggs/<slug>.egg with the matching <slug>.json sidecar.",
  ].join("\n");

  const u = new URL("https://github.com/kody-w/rapp-egg-hub/issues/new");
  u.searchParams.set("title", title);
  u.searchParams.set("body", body);
  u.searchParams.set("labels", "egg-submission");
  window.open(u.toString(), "_blank", "noopener,noreferrer");
}

async function copy(text) {
  try { await navigator.clipboard.writeText(text); } catch (_) { /* silent */ }
}

// Seed metadata — read by the card derivation logic. Set from the
// substituted placeholders below so the card can render before any
// async fetches land.
window.__seedRappid      = "__RAPPID__";
window.__seedDisplayName = "__DISPLAY_NAME__";
window.__seedKind        = "__KIND__";
window.__seedRepoName    = "__REPO_NAME__";

// Wire up buttons
document.getElementById("btn-tether").onclick = openTether;
document.getElementById("btn-card").onclick = openCard;
document.getElementById("btn-export-egg").onclick = exportDoormanEgg;
document.getElementById("btn-verify-egg").onclick = showVerifyPane;
document.getElementById("btn-publish-egg").onclick = openEggHubSubmission;
document.getElementById("btn-install").onclick = showInstall;
document.getElementById("btn-neighborhood").onclick = showNeighborhoodPane;
document.getElementById("btn-nbhd-submit").onclick = submitNeighbor;
// One-tap adopt the canonical test neighbor — pre-fills the form fields
// and reuses submitNeighbor so the rest of the PR flow stays single-pathed.
{
  const btn = document.getElementById("btn-nbhd-adopt-test");
  if (btn) btn.onclick = () => {
    document.getElementById("nbhd-repo").value   = "kody-w/rapp-test-neighbor";
    document.getElementById("nbhd-name").value   = "RAPP Test Neighbor";
    document.getElementById("nbhd-facets").value = "";
    submitNeighbor();
  };
}
document.getElementById("btn-propose-agent").onclick = showProposePane;
document.getElementById("btn-propose-submit").onclick = submitProposedAgent;
document.getElementById("btn-propose-template").onclick = (e) => {
  e.preventDefault();
  document.getElementById("propose-code").value = "";
  _resetProposeTemplate();
};
document.getElementById("btn-dreamcatcher").onclick = showDreamCatcher;

// Dream Catcher slot wiring — both slots use the same drag-drop pattern
(function wireDreamCatcher() {
  for (const slot of ["canonical", "parallel"]) {
    const drop = document.getElementById("dc-drop-" + slot);
    const input = document.getElementById("dc-file-" + slot);
    const pick  = document.getElementById("btn-dc-pick-" + slot);
    if (!drop || !input) continue;
    drop.addEventListener("click", e => { if (e.target.tagName !== "BUTTON") input.click(); });
    pick.addEventListener("click", e => { e.stopPropagation(); input.click(); });
    input.addEventListener("change", () => {
      if (input.files && input.files[0]) _dcHandleSlot(input.files[0], slot);
    });
    drop.addEventListener("dragover", e => { e.preventDefault(); drop.classList.add("dragover"); });
    drop.addEventListener("dragleave", () => drop.classList.remove("dragover"));
    drop.addEventListener("drop", e => {
      e.preventDefault();
      drop.classList.remove("dragover");
      const f = e.dataTransfer.files && e.dataTransfer.files[0];
      if (f) _dcHandleSlot(f, slot);
    });
  }
})();

// Verify pane: drag-drop + file picker. Both routes call the same
// _handleVerifyFile so the verifier UI doesn't care how the file got
// there.
(function wireVerifyPane() {
  const drop = document.getElementById("verify-drop");
  const input = document.getElementById("verify-file");
  if (!drop || !input) return;
  drop.addEventListener("click", e => {
    if (e.target.tagName !== "BUTTON") input.click();
  });
  document.getElementById("btn-verify-pick").addEventListener("click", e => {
    e.stopPropagation();
    input.click();
  });
  input.addEventListener("change", () => {
    if (input.files && input.files[0]) _handleVerifyFile(input.files[0]);
  });
  drop.addEventListener("dragover", e => {
    e.preventDefault();
    drop.classList.add("dragover");
  });
  drop.addEventListener("dragleave", () => drop.classList.remove("dragover"));
  drop.addEventListener("drop", e => {
    e.preventDefault();
    drop.classList.remove("dragover");
    const f = e.dataTransfer.files && e.dataTransfer.files[0];
    if (f) _handleVerifyFile(f);
  });
})();
document.getElementById("card-close").onclick = closeCard;
document.getElementById("card-flipper").addEventListener("click", (e) => {
  // Don't flip if user clicked an inner link or the close button
  if (e.target.closest("a, button")) return;
  e.currentTarget.classList.toggle("flipped");
});

// ── Holo tilt + shimmer (RAR store.html port) ──────────────────────
//
// On mousemove anywhere over the card flipper, compute (x, y) in [0,1]
// relative to the card and update CSS vars: --tilt-x / --tilt-y for
// 3D rotation, --mx / --my for shimmer-track + fresnel position,
// --angle for the prism gradient. Also touch support so the card
// tilts when dragged on mobile. Reset on mouseleave / touchend.
//
// Kept off the BACK so the QR stays scan-friendly (no parallax
// distortion when the visitor is trying to align their phone camera).
(function initHoloTilt() {
  const wrap = document.getElementById("card-flipper");
  if (!wrap) return;
  const holo = document.getElementById("holo-card");

  function apply(x, y) {
    if (wrap.classList.contains("flipped")) return reset();
    const tiltX = ((0.5 - y) * 16).toFixed(1);   // ±8 deg vertical
    const tiltY = ((x - 0.5) * 16).toFixed(1);   // ±8 deg horizontal
    const angle = (Math.atan2(y - 0.5, x - 0.5) * 180 / Math.PI).toFixed(0);
    wrap.style.setProperty("--tilt-x", tiltX + "deg");
    wrap.style.setProperty("--tilt-y", tiltY + "deg");
    wrap.style.transition = "transform .08s ease-out";
    if (holo) {
      const mxPct = (x * 100).toFixed(0) + "%";
      const myPct = (y * 100).toFixed(0) + "%";
      holo.style.setProperty("--mx", mxPct);
      holo.style.setProperty("--my", myPct);
      holo.style.setProperty("--angle", angle + "deg");
    }
  }
  function reset() {
    wrap.style.setProperty("--tilt-x", "0deg");
    wrap.style.setProperty("--tilt-y", "0deg");
    wrap.style.transition = "transform .4s ease-out";
    if (holo) {
      holo.style.removeProperty("--mx");
      holo.style.removeProperty("--my");
      holo.style.removeProperty("--angle");
    }
  }

  wrap.addEventListener("mousemove", (e) => {
    const r = wrap.getBoundingClientRect();
    apply((e.clientX - r.left) / r.width, (e.clientY - r.top) / r.height);
  });
  wrap.addEventListener("mouseleave", reset);
  wrap.addEventListener("touchmove", (e) => {
    const t = e.touches[0]; if (!t) return;
    const r = wrap.getBoundingClientRect();
    apply((t.clientX - r.left) / r.width, (t.clientY - r.top) / r.height);
  }, { passive: true });
  wrap.addEventListener("touchend", reset, { passive: true });
})();
// Tap outside the card → close (but don't close on click of card itself)
document.getElementById("card-overlay").addEventListener("click", (e) => {
  if (e.target.id === "card-overlay") closeCard();
});
// Esc key closes the card
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape" && !document.getElementById("card-overlay").hidden) closeCard();
});
document.getElementById("btn-connect").onclick = connectToPeer;
document.getElementById("btn-send").onclick = sendMessage;
document.getElementById("btn-send-egg").onclick = sendEggToPeer;
document.getElementById("btn-copy-id").onclick = () => {
  copy(document.getElementById("my-id-text").textContent);
};
document.getElementById("btn-copy-install").onclick = () => {
  copy(document.getElementById("install-cmd").textContent);
};
// Footer "plant your own front door" → opens the plant pane (one-liner
// + AI-paste prompt). Used to dump you on the raw plant.sh script;
// now it's an in-page affordance both humans + AI assistants can act on.
document.getElementById("footer-plant").onclick = (e) => {
  e.preventDefault();
  showPane("pane-plant");
};
document.getElementById("btn-copy-plant").onclick = () => {
  copy(document.getElementById("plant-cmd").textContent);
};
document.getElementById("btn-copy-plant-ai").onclick = () => {
  copy(document.getElementById("plant-ai-prompt").textContent);
};
document.getElementById("chat-input").addEventListener("keydown", e => {
  if (e.key === "Enter") sendMessage();
});
document.getElementById("peer-id-input").addEventListener("keydown", e => {
  if (e.key === "Enter") connectToPeer();
});

// Auto-tether if URL has ?peer=<id> (from a scanned tether QR)
(async function autoTether() {
  const params = new URLSearchParams(location.search);
  const peerId = params.get("peer");
  if (peerId) {
    await openTether();
    document.getElementById("peer-id-input").value = peerId;
    // Give the broker a moment to connect us, then dial
    setTimeout(connectToPeer, 1500);
  }
})();

// ── Rappid-derived sigil ───────────────────────────────────────────
// Every planted seed has a unique UUID rappid. This generates a
// deterministic, distinctive SVG portrait for the hero — like an
// avatar on a profile page. Hashing the rappid into hue + shape +
// accents means the same seed always gets the same look, so visitors
// recognize a place by sight.
function rappidSigil(rappid, size) {
  const hash = (rappid || "").replace(/-/g, "").slice(0, 16) || "deadbeef00000000";
  const h1 = parseInt(hash.slice(0, 4),  16) || 0;
  const h2 = parseInt(hash.slice(4, 8),  16) || 0;
  const h3 = parseInt(hash.slice(8,12),  16) || 0;
  const h4 = parseInt(hash.slice(12,16), 16) || 0;
  const hueA   = h1 % 360;
  const hueB   = (hueA + 60 + (h2 % 180)) % 360;
  const shape  = h3 % 4;
  const cx = size / 2, cy = size / 2;
  let layer = "";
  if (shape === 0) {
    const pts = [];
    for (let i = 0; i < 6; i++) {
      const a = (Math.PI / 3) * i - Math.PI / 6;
      pts.push((cx + Math.cos(a) * size * 0.30).toFixed(1) + "," +
               (cy + Math.sin(a) * size * 0.30).toFixed(1));
    }
    layer = '<polygon points="' + pts.join(" ") + '" fill="hsl(' + hueB + ',75%,58%)"/>';
  } else if (shape === 1) {
    const pts = cx + "," + (cy - size*0.32) + " " +
                (cx - size*0.28) + "," + (cy + size*0.18) + " " +
                (cx + size*0.28) + "," + (cy + size*0.18);
    layer = '<polygon points="' + pts + '" fill="hsl(' + hueB + ',75%,58%)"/>';
  } else if (shape === 2) {
    layer = '<circle cx="' + cx + '" cy="' + cy + '" r="' + (size*0.30) + '" ' +
            'fill="none" stroke="hsl(' + hueB + ',75%,58%)" stroke-width="' + (size*0.10) + '"/>';
  } else {
    const w = size * 0.55;
    layer = '<rect x="' + (cx - w/2) + '" y="' + (cy - w/2) + '" ' +
            'width="' + w + '" height="' + w + '" rx="' + (w*0.20) + '" ' +
            'fill="hsl(' + hueB + ',75%,58%)"/>';
  }
  const dotR = size * 0.06;
  const dotHue = (hueA + 180) % 360;
  layer += '<circle cx="' + cx + '" cy="' + cy + '" r="' + dotR + '" fill="hsl(' + dotHue + ',80%,75%)"/>';
  // Subtle orbit ring — additional accent based on h4
  if (h4 % 2 === 0) {
    layer += '<circle cx="' + cx + '" cy="' + cy + '" r="' + (size*0.42) + '" ' +
             'fill="none" stroke="hsla(' + hueB + ',60%,70%,0.35)" stroke-width="1"/>';
  }
  const gid = "g" + (h1.toString(36)) + (h2.toString(36));
  return '<svg viewBox="0 0 ' + size + ' ' + size + '" xmlns="http://www.w3.org/2000/svg">' +
         '<defs><linearGradient id="' + gid + '" x1="0" y1="0" x2="1" y2="1">' +
           '<stop offset="0%" stop-color="hsl(' + hueA + ',45%,28%)"/>' +
           '<stop offset="100%" stop-color="hsl(' + hueA + ',35%,12%)"/>' +
         '</linearGradient></defs>' +
         '<rect width="' + size + '" height="' + size + '" fill="url(#' + gid + ')"/>' +
         layer +
         '</svg>';
}

(function renderSigil() {
  const el = document.getElementById("hero-sigil");
  if (!el) return;
  el.innerHTML = rappidSigil("__RAPPID__", 96);
})();

// ── Profile stats: memory count + age ──────────────────────────────
// "Signs of life" for the front door — the things that change between
// visits. Memory count comes from public .brainstem_data/memory.json;
// age is computed from rappid.json's planted_at field.
function relativeAge(iso) {
  if (!iso) return "";
  const ms = Date.now() - new Date(iso).getTime();
  if (Number.isNaN(ms) || ms < 0) return "";
  const days = Math.floor(ms / 86400000);
  if (days < 1)  return "planted today";
  if (days < 2)  return "planted yesterday";
  if (days < 30) return "planted " + days + " days ago";
  const months = Math.floor(days / 30);
  if (months < 12) return "planted " + months + " month" + (months === 1 ? "" : "s") + " ago";
  const years = Math.floor(months / 12);
  return "planted " + years + " year" + (years === 1 ? "" : "s") + " ago";
}

// ── Track Record: the organism's resume ────────────────────────────
//
// Three live data feeds drive the resume — every fetch is anonymous-
// friendly (60 req/hour from any IP, plenty for a profile page):
//
//   Agents       — GET /repos/<owner>/<seed>/contents/agents
//                  Each agent .py is a capability the organism brings
//                  to the table when summoned/hatched. ONE term: agent.
//
//   Mutations    — GET /repos/<owner>/<seed>/commits
//                  Every commit IS a mutation event — new memory, new
//                  agent, edited soul. The commit log is the literal
//                  evolution history; we surface the recent few.
//
//   Achievements — derived locally from memory.json count + age.
//                  Milestones the organism has crossed during its
//                  lifetime (first conversation, double-digit memories,
//                  first month, etc.). These are the LinkedIn-style
//                  badges that prove track record.
//
// All three accumulate over time. Each interaction grows the resume.
// Operator commits are direct mutations; visitor interactions can
// become PRs against this seed (the bond-back path).

function _ghOwnerRepo() {
  const host = location.host;
  const owner = host.split(".")[0];
  const repo  = location.pathname.split("/").filter(Boolean)[0] || "";
  return { owner, repo };
}

// ── Local-first network cache ──────────────────────────────────────
//
// Every GitHub fetch the resume makes goes through this wrapper. On
// success: the response is cached in localStorage keyed by URL plus a
// timestamp. On network failure or no-network: return the cached
// value if we have one, marked stale. Result: an organism on a
// laptop in airplane mode keeps rendering its own resume from the
// last-known state instead of going blank. The seed's own files
// (rappid.json, memory.json, agents/*) load from the local server
// without ever hitting the network — the cache is only for
// public-repo enrichment that needs github.com.
//
// Cache TTL is generous (24h default) — better to show slightly stale
// data than blank fields. When online the live response always wins.

const _CACHE_PREFIX = "rapp_cache_v1:";
const _CACHE_TTL_MS = 24 * 60 * 60 * 1000;  // 24h

function _cacheGet(url) {
  try {
    const raw = localStorage.getItem(_CACHE_PREFIX + url);
    if (!raw) return null;
    const j = JSON.parse(raw);
    if (!j || typeof j.t !== "number") return null;
    return { value: j.v, fetchedAt: new Date(j.t), stale: Date.now() - j.t > _CACHE_TTL_MS };
  } catch (_) { return null; }
}
function _cachePut(url, value) {
  try {
    localStorage.setItem(_CACHE_PREFIX + url, JSON.stringify({ t: Date.now(), v: value }));
  } catch (_) { /* quota — fine, we just won't cache */ }
}

// Cached JSON fetch. Tries network first; falls back to cached value
// on network or HTTP error. Returns { value, source: 'live'|'cache'|'none', stale }.
async function cachedGhJson(url, headers) {
  try {
    const r = await fetch(url, { headers: headers || { Accept: "application/vnd.github+json" }, cache: "no-cache" });
    if (r.ok) {
      const j = await r.json();
      _cachePut(url, j);
      return { value: j, source: "live", stale: false };
    }
    // Non-2xx — fall through to cache
  } catch (_) { /* network down — fall through */ }
  const c = _cacheGet(url);
  if (c) return { value: c.value, source: "cache", stale: c.stale, fetchedAt: c.fetchedAt };
  return { value: null, source: "none", stale: true };
}
async function cachedGhText(url, headers) {
  try {
    const r = await fetch(url, { headers: headers || {}, cache: "no-cache" });
    if (r.ok) {
      const t = await r.text();
      _cachePut(url, t);
      return { value: t, source: "live", stale: false };
    }
  } catch (_) {}
  const c = _cacheGet(url);
  if (c) return { value: c.value, source: "cache", stale: c.stale, fetchedAt: c.fetchedAt };
  return { value: null, source: "none", stale: true };
}

// Friendly display map for known agents. ONE term: agent. Never "skill".
const AGENT_FRIENDLY = {
  manage_memory_agent:   { name: "Manage Memory",   icon: "🧠" },
  context_memory_agent:  { name: "Context Memory",  icon: "📌" },
  learn_new_agent:       { name: "Learn New",       icon: "🎓" },
  swarm_factory_agent:   { name: "Swarm Factory",   icon: "🐝" },
  basic_agent:           null, // base class — not a capability
};

async function fillAgents() {
  const el = document.getElementById("tr-agents");
  if (!el) return;
  const { owner, repo } = _ghOwnerRepo();
  if (!owner || !repo) { el.innerHTML = ""; return; }
  // Local-first: cachedGhJson tries network, then localStorage cache.
  // An organism running offline still renders its agents from the last
  // successful sync — never goes blank.
  const res = await cachedGhJson(`https://api.github.com/repos/${owner}/${repo}/contents/agents`);
  const list = res.value;
  if (!Array.isArray(list)) {
    el.innerHTML = res.source === "none"
      ? '<span class="agent-chip skel">offline — agents will load when network returns</span>'
      : "";
    return;
  }
  const agents = [];
  for (const f of list) {
    if (f.type !== "file" || !f.name.endsWith(".py")) continue;
    const stem = f.name.replace(/\.py$/, "");
    const fr = AGENT_FRIENDLY[stem];
    if (fr === null) continue;
    if (fr) {
      agents.push({ icon: fr.icon, label: fr.name, custom: false });
    } else {
      const friendly = stem.replace(/_agent$/, "").replace(/_/g, " ").replace(/\b\w/g, c => c.toUpperCase());
      agents.push({ icon: "✨", label: friendly, custom: true });
    }
  }
  if (!agents.length) { el.innerHTML = '<span class="agent-chip skel">no agents loaded yet</span>'; return; }
  const stalePill = (res.source === "cache" && res.stale)
    ? `<span class="agent-chip skel" title="last synced ${res.fetchedAt ? res.fetchedAt.toLocaleString() : 'a while ago'} — offline reading from cache">📡 stale</span>`
    : "";
  el.innerHTML = agents.map(a =>
    `<span class="agent-chip ${a.custom ? "agent-new" : ""}">${a.icon} ${escapeHtml(a.label)}</span>`
  ).join("") + stalePill;
}

function fillAchievements(memCount, plantedAt, mutationCount) {
  const el = document.getElementById("tr-achievements");
  if (!el) return;
  const ms = plantedAt ? Date.now() - new Date(plantedAt).getTime() : 0;
  const days = ms / 86400000;
  const ach = [];
  if (memCount >= 1)   ach.push({ icon: "🌱", label: "First conversation" });
  if (memCount >= 10)  ach.push({ icon: "📚", label: "10 memories" });
  if (memCount >= 50)  ach.push({ icon: "🏛️", label: "50 memories" });
  if (memCount >= 100) ach.push({ icon: "🏆", label: "100 memories" });
  if (days >= 7)       ach.push({ icon: "🗓️", label: "First week" });
  if (days >= 30)      ach.push({ icon: "📅", label: "First month" });
  if (days >= 365)     ach.push({ icon: "🎂", label: "First year" });
  if (mutationCount >= 5)  ach.push({ icon: "🔧", label: "5+ mutations" });
  if (mutationCount >= 25) ach.push({ icon: "⚙️", label: "25+ mutations" });
  if (!ach.length) {
    el.innerHTML = '<span class="agent-chip skel">earn your first achievement by talking with me</span>';
    return;
  }
  el.innerHTML = ach.map(a => `<span class="agent-chip achievement">${a.icon} ${escapeHtml(a.label)}</span>`).join("");
}

function _relativeDate(iso) {
  if (!iso) return "";
  const ms = Date.now() - new Date(iso).getTime();
  if (Number.isNaN(ms) || ms < 0) return "";
  const min = Math.floor(ms / 60000);
  if (min < 60)   return min + "m ago";
  const hr = Math.floor(min / 60);
  if (hr < 24)    return hr + "h ago";
  const d = Math.floor(hr / 24);
  if (d < 30)     return d + "d ago";
  const mo = Math.floor(d / 30);
  if (mo < 12)    return mo + "mo ago";
  return Math.floor(mo / 12) + "y ago";
}

async function fillMutations() {
  const list = document.getElementById("tr-mutations");
  if (!list) return { count: 0, lastDate: null };
  const { owner, repo } = _ghOwnerRepo();
  const linkEl = document.getElementById("tr-history-link");
  if (linkEl && owner && repo) linkEl.href = `https://github.com/${owner}/${repo}/commits`;
  // Local-first: cached GH fetch keeps the mutation log visible offline.
  const res = await cachedGhJson(`https://api.github.com/repos/${owner}/${repo}/commits?per_page=6`);
  const commits = res.value;
  if (!Array.isArray(commits) || !commits.length) {
    list.innerHTML = res.source === "none"
      ? '<li class="skel">offline — mutation log will load when network returns</li>'
      : '<li class="skel">no mutation history yet</li>';
    return { count: 0, lastDate: null };
  }
  const stalePrefix = (res.source === "cache" && res.stale)
    ? `<li class="skel" style="font-size:10px">📡 cached snapshot — last synced ${res.fetchedAt ? res.fetchedAt.toLocaleString() : 'unknown'}</li>` : "";
  list.innerHTML = stalePrefix + commits.slice(0, 5).map(c => {
    const msg = (c.commit && c.commit.message || "").split("\n")[0].slice(0, 90);
    const when = _relativeDate(c.commit && c.commit.author && c.commit.author.date);
    return `<li><span class="mut-time">${escapeHtml(when)}</span><span class="mut-msg">${escapeHtml(msg) || '<span class="empty">(no message)</span>'}</span></li>`;
  }).join("");
  const lastDate = commits[0] && commits[0].commit && commits[0].commit.author && commits[0].commit.author.date;
  return { count: commits.length, lastDate: lastDate || null };
}

// Fork count = offspring. Each fork is a child organism — they boost the
// parent's MMR like pedigree boosts a thoroughbred. Pulled straight off
// the seed's repo metadata; anonymous-friendly.
async function _forkCount() {
  const { owner, repo } = _ghOwnerRepo();
  if (!owner || !repo) return 0;
  const res = await cachedGhJson(`https://api.github.com/repos/${owner}/${repo}`);
  return Math.max(0, (res.value && res.value.forks_count) || 0);
}

async function fillLineage() {
  const el = document.getElementById("tr-lineage");
  if (!el) return;
  try {
    const r = await fetch("rappid.json", { cache: "no-cache" });
    if (!r.ok) return;
    const j = await r.json();
    const parts = [];
    if (j.parent_repo) {
      const repoLabel = j.parent_repo.replace(/^https?:\/\/github\.com\//, "").replace(/\.git$/, "");
      parts.push(`Templated from <a href="${escapeHtml(j.parent_repo)}" target="_blank" rel="noopener">${escapeHtml(repoLabel)}</a>`);
    }
    if (j.parent_rappid) {
      parts.push(`lineage <code>${escapeHtml(j.parent_rappid.slice(0, 8))}…</code>`);
    }
    if (j.kernel_version) parts.push(`kernel <code>v${escapeHtml(j.kernel_version)}</code>`);
    el.innerHTML = parts.length ? parts.join(" · ") : "";
  } catch (_) {}
}

// MMR — Dota-style global rating for digital organisms. Same formula
// computed from the same public signals on every planted seed, so a
// 3500-MMR Heimdall is directly comparable to a 3500-MMR Cloud Gate
// or any other organism on the species. The score reflects: lived
// time, accumulated memory (depth of relationship), mutation count
// (operator steering), custom agents (capabilities earned beyond
// the doorman defaults), AND offspring (organisms forked from this
// one — pedigree counts).
//
// Calibration: organisms with < CALIBRATION_MUTATIONS commits and
// fewer than CALIBRATION_DAYS days of life are in placement mode;
// their MMR isn't locked in yet — they show "📐 Calibrating" with a
// progress bar instead of a tier badge. Same idea as Dota 2's first
// 10 calibration games before MMR locks in.
//
// Activity decay: inactivity costs MMR. An organism whose last commit
// was 90 days ago reads "slowing" and gets a 10% penalty; 180+ days
// is "dormant" and -30%; 3+ years is "stasis" and floored at 1000.
// This way, the cream rises — popular, actively-stewarded organisms
// climb past the abandoned ones with similar raw memory counts.
//
//   1000  base — every planted seed is born at Cradle
//   + memCount × 30          (each conversation deepens us)
//   + sqrt(mutCount) × 250   (each operator commit shapes us)
//   + customAgentCount × 350 (each new capability earned)
//   + sqrt(ageDays) × 80     (lived time matters)
//   + sqrt(forkCount) × 400  (offspring planted from this lineage)
//   × activityFactor         (0.7 → 1.0 based on last commit recency)
//
// Tier thresholds match Dota 2's recognizable medal ladder so the
// number reads naturally to anyone who's seen MMR before.

const CALIBRATION_MUTATIONS = 5;
const CALIBRATION_DAYS      = 7;

function activityStatus(lastCommitIso) {
  if (!lastCommitIso) return { kind: "unknown", label: "no activity yet", factor: 1.0 };
  const daysSince = (Date.now() - new Date(lastCommitIso).getTime()) / 86400000;
  if (daysSince <= 30)   return { kind: "active",   label: "✓ Active",   factor: 1.0  };
  if (daysSince <= 180)  return { kind: "slowing",  label: "〰 Slowing",  factor: 0.85 };
  if (daysSince <= 1095) return { kind: "dormant",  label: "💤 Dormant",  factor: 0.65 };
  return                          { kind: "stasis",  label: "❄ Stasis",   factor: 0.45 };
}

function computeMMR({ memCount, mutCount, customAgents, ageDays, forkCount, activityFactor, lineageGift }) {
  const m = Math.max(0, memCount || 0);
  const x = Math.max(0, mutCount || 0);
  const c = Math.max(0, customAgents || 0);
  const d = Math.max(0, ageDays || 0);
  const f = Math.max(0, forkCount || 0);
  const af = (typeof activityFactor === "number" && activityFactor > 0) ? activityFactor : 1.0;
  const lg = Math.max(0, lineageGift || 0);
  const raw = 1000
    + m * 30
    + Math.sqrt(x) * 250
    + c * 350
    + Math.sqrt(d) * 80
    + Math.sqrt(f) * 400;
  // Stasis floors at 1000 — even a long-dormant elder doesn't go below
  // baseline. The factor is applied to the SCORE-ABOVE-BASELINE so the
  // organism's existence is preserved even when uncared-for. Lineage
  // gift sits OUTSIDE the activity factor — your inherited genes don't
  // wither just because you took a year off.
  const above = Math.max(0, raw - 1000);
  return Math.round(1000 + above * af + lg);
}

// Parent lineage lookup — when a seed has a parent_repo, fetch the
// parent's current public signals and compute their MMR. The child
// inherits 30% of the parent's above-baseline as a head start. This
// is the genes-and-epigenetics layer: who your parent is at the time
// you visit them shapes the gift you read on this card.
//
// Pure read — anonymous-friendly. Skips silently if parent_repo isn't
// set or isn't a github.com URL.
async function _parentLineageGift(rappidObj) {
  if (!rappidObj || !rappidObj.parent_repo) return null;
  // Plant-time snapshot wins if it was baked into rappid.json at plant.
  // This is the genes/epigenetics layer: the parent's MMR-at-our-birth
  // is fixed; later regression on the parent doesn't affect children
  // already planted from it. Same shape the live fetcher returns so
  // the rest of the pipeline doesn't branch.
  if (rappidObj.lineage_snapshot && typeof rappidObj.lineage_snapshot.parent_mmr_at_birth === "number") {
    const snap = rappidObj.lineage_snapshot;
    const gift = Math.round(Math.max(0, (snap.parent_mmr_at_birth - 1000) * 0.30));
    return {
      parentMMR:        snap.parent_mmr_at_birth,
      gift:             gift,
      parentRepoLabel:  snap.parent_repo_label || (snap.parent_repo || "").replace(/^https?:\/\/github\.com\//, "").replace(/\.git$/, ""),
      source:           "snapshot",
      snapshotted_at:   snap.snapshotted_at,
    };
  }
  // No snapshot → live fetch (the path we used before; kept for older
  // seeds planted before this commit).
  const m = rappidObj.parent_repo.match(/github\.com\/([^/]+)\/([^/]+?)(?:\.git)?\/?$/);
  if (!m) return null;
  const [, owner, repo] = m;
  // Local-first: each lookup is cache-wrapped. If we go airplane mode,
  // the lineage gift renders from the last successful sync — the
  // organism never forgets its parent.
  const [repoRes, commitsRes, memRes, agentsRes] = await Promise.all([
    cachedGhJson(`https://api.github.com/repos/${owner}/${repo}`),
    cachedGhJson(`https://api.github.com/repos/${owner}/${repo}/commits?per_page=6`),
    cachedGhText(`https://raw.githubusercontent.com/${owner}/${repo}/main/.brainstem_data/memory.json`),
    cachedGhJson(`https://api.github.com/repos/${owner}/${repo}/contents/agents`),
  ]);
  const repoJ = repoRes.value;
  if (!repoJ) return null;
  const ageDays   = repoJ.created_at ? (Date.now() - new Date(repoJ.created_at).getTime()) / 86400000 : 0;
  const forkCount = repoJ.forks_count || 0;
  let mutCount = 0, lastCommit = null;
  if (Array.isArray(commitsRes.value)) {
    mutCount = commitsRes.value.length;
    if (commitsRes.value[0] && commitsRes.value[0].commit && commitsRes.value[0].commit.author) {
      lastCommit = commitsRes.value[0].commit.author.date;
    }
  }
  let memCount = 0;
  if (memRes.value) {
    try { const j = JSON.parse(memRes.value); memCount = Array.isArray(j.facts) ? j.facts.length : 0; } catch (_) {}
  }
  let customAgents = 0;
  if (Array.isArray(agentsRes.value)) {
    customAgents = agentsRes.value.filter(f =>
      f.type === "file" && f.name.endsWith(".py") &&
      !(f.name.replace(/\.py$/, "") in AGENT_FRIENDLY)
    ).length;
  }
  const act = activityStatus(lastCommit);
  const parentMMR = computeMMR({
    memCount, mutCount, customAgents, ageDays, forkCount,
    activityFactor: act.factor,
  });
  // Child inherits 30% of parent's above-baseline as the lineage gift.
  const gift = Math.round(Math.max(0, (parentMMR - 1000) * 0.30));
  return { parentMMR, gift, parentRepoLabel: owner + "/" + repo, source: "live" };
}

// Calibration check — has the organism graduated from placement?
function calibrationProgress({ mutCount, ageDays }) {
  const m = mutCount || 0;
  const d = ageDays || 0;
  const calibrating = (m < CALIBRATION_MUTATIONS) && (d < CALIBRATION_DAYS);
  // Progress: pick whichever signal is closer to graduation
  const mutProg = Math.min(1, m / CALIBRATION_MUTATIONS);
  const ageProg = Math.min(1, d / CALIBRATION_DAYS);
  return { calibrating, progress: Math.max(mutProg, ageProg) };
}

const MMR_TIERS = [
  { min:    0, name: "Herald",    cls: "t-herald"   },
  { min: 1500, name: "Guardian",  cls: "t-guardian" },
  { min: 2000, name: "Crusader",  cls: "t-crusader" },
  { min: 2500, name: "Archon",    cls: "t-archon"   },
  { min: 3000, name: "Legend",    cls: "t-legend"   },
  { min: 3500, name: "Ancient",   cls: "t-ancient"  },
  { min: 4500, name: "Divine",    cls: "t-divine"   },
  { min: 6000, name: "Immortal",  cls: "t-immortal" },
];

function tierForMMR(mmr) {
  let chosen = MMR_TIERS[0];
  for (const t of MMR_TIERS) { if (mmr >= t.min) chosen = t; }
  return chosen;
}

function fillMMR(inputs) {
  const num = document.getElementById("mmr-num");
  const tier = document.getElementById("mmr-tier");
  const bd = document.getElementById("mmr-breakdown");
  if (!num || !tier) return;

  const cal = calibrationProgress(inputs);
  const act = activityStatus(inputs.lastCommit);

  if (cal.calibrating) {
    // Placement mode — show progress instead of a tier locked-in number.
    // Same shape of UI; the visitor sees the organism is still calibrating.
    num.textContent = "📐";
    tier.textContent = "Calibrating";
    tier.className = "mmr-tier";
    const pct = Math.round(cal.progress * 100);
    bd.textContent = `placement matches ${pct}% complete · MMR locks in after ${CALIBRATION_MUTATIONS} mutations or ${CALIBRATION_DAYS} days`;
    return;
  }

  const mmr = computeMMR({ ...inputs, activityFactor: act.factor });
  const t = tierForMMR(mmr);
  num.textContent = String(mmr);
  tier.textContent = t.name;
  tier.className = "mmr-tier " + t.cls;

  const parts = [];
  if (inputs.memCount)     parts.push(inputs.memCount + " mem");
  if (inputs.mutCount)     parts.push(inputs.mutCount + (inputs.mutCount >= 6 ? "+" : "") + " mut");
  if (inputs.customAgents) parts.push(inputs.customAgents + " custom agent" + (inputs.customAgents === 1 ? "" : "s"));
  if (inputs.forkCount)    parts.push(inputs.forkCount + " fork" + (inputs.forkCount === 1 ? "" : "s") + " 🌳");
  if (inputs.ageDays)      parts.push(Math.floor(inputs.ageDays) + "d alive");
  // Activity status as a colored chip baked into the breakdown
  let activityNote = "";
  if (act.kind === "active")        activityNote = ` · <span style="color:#7ee787">${act.label}</span>`;
  else if (act.kind === "slowing")  activityNote = ` · <span style="color:#d29922">${act.label}</span> (-15%)`;
  else if (act.kind === "dormant")  activityNote = ` · <span style="color:#8b949e">${act.label}</span> (-35%)`;
  else if (act.kind === "stasis")   activityNote = ` · <span style="color:#6e7681">${act.label}</span> (frozen)`;
  // Lineage gift — show if the parent's MMR contributed inheritance
  let lineageNote = "";
  if (inputs.lineage && inputs.lineage.gift > 0) {
    lineageNote = ` · <span style="color:#a78bfa" title="Inherited from your parent organism — genes + epigenetics. 30% of parent's above-baseline MMR.">+${inputs.lineage.gift} lineage gift from <a href="https://github.com/${escapeHtml(inputs.lineage.parentRepoLabel)}" target="_blank" rel="noopener" style="color:inherit">${escapeHtml(inputs.lineage.parentRepoLabel)}</a> (${inputs.lineage.parentMMR} MMR)</span>`;
  }
  bd.innerHTML = (parts.length ? "earned from " + escapeHtml(parts.join(" · ")) : "fresh plant") + activityNote + lineageNote;
}

// Custom-agent count — how many agents beyond the doorman defaults?
async function _customAgentCount() {
  const { owner, repo } = _ghOwnerRepo();
  if (!owner || !repo) return 0;
  try {
    const r = await fetch(`https://api.github.com/repos/${owner}/${repo}/contents/agents`, {
      headers: { Accept: "application/vnd.github+json" },
    });
    if (!r.ok) return 0;
    const list = await r.json();
    if (!Array.isArray(list)) return 0;
    let custom = 0;
    for (const f of list) {
      if (f.type !== "file" || !f.name.endsWith(".py")) continue;
      const stem = f.name.replace(/\.py$/, "");
      if (!(stem in AGENT_FRIENDLY)) custom++;  // not a known doorman/ascended agent
    }
    return custom;
  } catch (_) { return 0; }
}

(async function fillTrackRecord() {
  // Memory count + age + parent first (needed for achievements + MMR)
  let memCount = 0, plantedAt = null, rappidObj = null;
  try {
    const r = await fetch(".brainstem_data/memory.json", { cache: "no-cache" });
    if (r.ok) { const j = await r.json(); memCount = Array.isArray(j.facts) ? j.facts.length : 0; }
  } catch (_) {}
  try {
    const r = await fetch("rappid.json", { cache: "no-cache" });
    if (r.ok) { rappidObj = await r.json(); plantedAt = rappidObj.planted_at || null; }
  } catch (_) {}

  // Fetch all signal sources in parallel — each independent.
  const [agentsRes, mutationsRes, customAgents, forkCount, lineage] = await Promise.all([
    fillAgents(),
    fillMutations(),
    fillLineage().then(() => _customAgentCount()),
    _forkCount(),
    _parentLineageGift(rappidObj),
  ]);
  void agentsRes;

  const ageDays   = plantedAt ? (Date.now() - new Date(plantedAt).getTime()) / 86400000 : 0;
  const mutCount  = mutationsRes && mutationsRes.count || 0;
  const lastCommit = mutationsRes && mutationsRes.lastDate || null;
  const lineageGift = lineage ? lineage.gift : 0;

  fillMMR({
    memCount, mutCount, customAgents, ageDays,
    forkCount, lastCommit, lineageGift, lineage,
  });
  fillAchievements(memCount, plantedAt, mutCount);
})();

(async function fillStats() {
  // Memory count
  const memEl = document.getElementById("stat-mem");
  if (memEl) {
    try {
      const r = await fetch(".brainstem_data/memory.json", { cache: "no-cache" });
      if (r.ok) {
        const j = await r.json();
        const n = Array.isArray(j.facts) ? j.facts.length : 0;
        memEl.textContent = n === 0
          ? "🧠 ready for its first memory"
          : "🧠 " + n + " memor" + (n === 1 ? "y" : "ies") + " from past visits";
      } else {
        memEl.textContent = "🧠 ready for its first memory";
      }
    } catch (_) {
      memEl.textContent = "🧠 ready for its first memory";
    }
  }
  // Age
  const ageEl = document.getElementById("stat-age");
  if (ageEl) {
    try {
      const r = await fetch("rappid.json", { cache: "no-cache" });
      if (r.ok) {
        const j = await r.json();
        const txt = relativeAge(j.planted_at);
        if (txt) ageEl.textContent = "🌱 " + txt;
        else ageEl.remove();
      } else {
        ageEl.remove();
      }
    } catch (_) { ageEl.remove(); }
  }
})();
</script>
</body>
</html>
TEMPLATE_EOF

    # Substitute placeholders via Python, passing values through env vars
    # to avoid any shell-quoting headaches with display names containing
    # spaces, quotes, or other special chars. (bash 3.2-safe — no @Q.)
    PLANT_INDEX_PATH="$target_dir/classic.html" \
    PLANT_DISPLAY_NAME="$MIRROR_DISPLAY_NAME" \
    PLANT_REPO_NAME="$MIRROR_REPO_NAME" \
    PLANT_GH_USER="$gh_user" \
    PLANT_RAPPID="$rappid" \
    PLANT_URL="$mirror_url" \
    PLANT_LINEAGE_HTML="$lineage_html" \
    PLANT_KIND="${MIRROR_KIND:-mirror}" \
    PLANT_LOCATION="${MIRROR_LOCATION:-}" \
    python3 - <<'PYEOF'
import os, pathlib
path = pathlib.Path(os.environ["PLANT_INDEX_PATH"])
text = path.read_text()
display_name = os.environ["PLANT_DISPLAY_NAME"]
kind = os.environ.get("PLANT_KIND", "mirror") or "mirror"
location = os.environ.get("PLANT_LOCATION", "") or ""

# Kind-aware hero copy. Each variant lands in roughly the same shape
# (one emoji + one sentence) so the layout stays balanced.
HERO = {
    "personal": ("🧠",
        f"An AI digital twin. Talk to {display_name} — they remember every "
        "conversation and pick up where you left off next time you visit."),
    "place": ("📍",
        f"An AI front door for this place. Talk to {display_name} — they "
        "remember every visitor and what was said, so the place itself has "
        "a memory."),
    "mirror": ("🪞",
        f"A planted RAPP front door. Talk to {display_name} — every "
        "conversation gets remembered for the next time you (or anyone "
        "else) drops by."),
    "experiment": ("🧪",
        f"An experimental RAPP front door. Talk to {display_name} — this "
        "one's still finding its voice; help shape it."),
}
hero_emoji, hero_blurb = HERO.get(kind, HERO["mirror"])
location_line = (f"📍 {location}" if location else "")

subs = [
    ("__DISPLAY_NAME__",  display_name),
    ("__REPO_NAME__",     os.environ["PLANT_REPO_NAME"]),
    ("__GH_USER__",       os.environ["PLANT_GH_USER"]),
    ("__RAPPID__",        os.environ["PLANT_RAPPID"]),
    ("__URL__",           os.environ["PLANT_URL"]),
    ("__LINEAGE_HTML__",  os.environ["PLANT_LINEAGE_HTML"]),
    ("__KIND__",          kind),
    ("__HERO_EMOJI__",    hero_emoji),
    ("__HERO_BLURB__",    hero_blurb),
    ("__LOCATION_LINE__", location_line),
]
for k, v in subs:
    text = text.replace(k, v)
path.write_text(text)
PYEOF
}

# Write the sphere doorman as the seed's index.html — the canonical
# front door surface as of the lock-in. Fetches the sphere template
# from grail (raw.githubusercontent.com/kody-w/RAPP/main/pages/sphere.html)
# so every plant gets the latest version. Sphere loads identity from
# the seed's own rappid.json + soul.md at runtime — no substitution
# needed here. Falls back to a tiny shim that redirects to classic.html
# if the fetch fails (network blip during plant).
write_index_html() {
    local target_dir="$1" gh_user="$2" rappid="$3"
    local sphere_url="https://raw.githubusercontent.com/kody-w/RAPP/main/pages/sphere.html"
    info "Fetching sphere doorman template from grail…"
    if ! curl -fsSL "$sphere_url" -o "$target_dir/index.html"; then
        warn "Couldn't fetch sphere from grail; falling back to classic-only index.html"
        # Tiny redirect shim so the front door still works offline-builds.
        cat > "$target_dir/index.html" << 'INDEXFALLBACK'
<!DOCTYPE html><html><head><meta charset="UTF-8"><title>Front Door</title>
<meta http-equiv="refresh" content="0; url=classic.html"></head>
<body><a href="classic.html">→ classic front door</a></body></html>
INDEXFALLBACK
    fi
}

write_doorman_html() {
    # /doorman/index.html — the seed's vbrainstem-pattern frontdoorman.
    # Visitors at <seed>/doorman chat with a place-aware persona.
    # Auth: same pattern as vbrainstem (summon.html) — GitHub Models endpoint
    # via visitor's GitHub PAT, settings stashed in localStorage at
    # rapp_settings (parallel to summon.html's storage shape).
    # If rappid.json declares a private_companion repo, the doorman tries
    # fetching README.md from there with the visitor's token; on success,
    # adds it to the system prompt for richer context.
    local target_dir="$1" gh_user="$2" rappid="$3"
    local mirror_url="https://$gh_user.github.io/$MIRROR_REPO_NAME"

    mkdir -p "$target_dir/doorman"

    cat > "$target_dir/doorman/index.html" << 'TEMPLATE_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="format-detection" content="telephone=no, address=no, email=no, date=no">
<meta name="color-scheme" content="dark">
<meta name="theme-color" content="#0d1117">
<title>Doorman — __DISPLAY_NAME__</title>
<meta name="description" content="The frontdoorman of __DISPLAY_NAME__. Chat with the place.">
<!-- Pyodide — real Python in the browser. Lazy-loaded after auth so the
     anonymous fast path stays light. Used to run the same agent.py files
     (manage_memory, context_memory, learn_new, swarm_factory) that the
     local Python brainstem runs. Same agent contract, different storage
     shim adapted to GitHub raw URLs + localStorage. -->
<script src="https://cdn.jsdelivr.net/pyodide/v0.26.4/full/pyodide.js" defer></script>
<!-- Markdown renderer for assistant/system bubbles. Same CDN the canonical
     brainstem uses; tiny (~30 KB gzipped). User bubbles stay plaintext. -->
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
<!-- JSZip — used to pack ascended-tier .egg cartridges for operators
     and visitors with private-companion read access. Same archive
     format the local brainstem's bond.py emits. -->
<script src="https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js"></script>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
  html, body { height: 100%; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    background: #0d1117; color: #e6edf3;
    height: 100vh; height: 100dvh;
    display: flex; flex-direction: column;
    -webkit-text-size-adjust: 100%;
    overflow: hidden;
  }
  header {
    padding: 14px 20px;
    padding-top: max(14px, env(safe-area-inset-top, 14px));
    border-bottom: 1px solid #21262d;
    background: #0d1117;
  }
  header .back { font-size: 12px; color: #58a6ff; text-decoration: none; }
  header h1 { font-size: 22px; font-weight: 600; margin-top: 6px; letter-spacing: -0.01em; }
  header .loc {
    color: #8b949e; font-size: 12px; margin-top: 2px;
  }
  header .sub {
    color: #6e7681; font-size: 11px; margin-top: 2px;
    text-transform: uppercase; letter-spacing: 0.06em;
  }
  main {
    flex: 1; overflow-y: auto;
    padding: 16px 20px;
    -webkit-overflow-scrolling: touch;
    display: flex; flex-direction: column;
  }
  .auth-pane {
    background: #161b22; border: 1px solid #21262d; border-radius: 12px;
    padding: 20px;
  }
  .auth-pane h2 { font-size: 15px; font-weight: 600; margin-bottom: 8px; }
  .auth-pane p { font-size: 13px; color: #c9d1d9; margin-bottom: 10px; line-height: 1.5; }
  .auth-pane ol { margin: 10px 0 14px 18px; font-size: 13px; color: #8b949e; }
  .auth-pane ol li { margin: 6px 0; }
  .auth-pane a { color: #58a6ff; text-decoration: none; }
  .auth-pane a:hover { text-decoration: underline; }
  input[type="password"], textarea {
    width: 100%;
    background: #0d1117; border: 1px solid #30363d; border-radius: 8px;
    padding: 10px 12px; color: #e6edf3;
    font-size: 14px; font-family: inherit;
  }
  input:focus, textarea:focus { outline: none; border-color: #1f6feb; }
  textarea { resize: vertical; min-height: 60px; max-height: 200px; }
  button {
    background: #1f6feb; color: white; border: none; border-radius: 8px;
    padding: 10px 16px; font-size: 14px; font-weight: 500;
    cursor: pointer; -webkit-appearance: none;
    font-family: inherit;
  }
  button:hover { background: #2477f3; }
  button.secondary {
    background: #21262d; color: #c9d1d9; border: 1px solid #30363d;
  }
  button.secondary:hover { background: #2d333b; }
  button:disabled { opacity: 0.5; cursor: not-allowed; }
  .auth-pane .row { display: flex; gap: 8px; margin-top: 12px; }
  .auth-pane .row button { flex-shrink: 0; }
  .auth-pane .row input { flex: 1; }

  .chat-log {
    flex: 1; overflow-y: auto;
    padding-bottom: 12px;
    /* Flex column so bubbles can self-align (.msg.user → right,
       .msg.assistant → left) and respect their max-width. Without
       this, align-self + margin-left:auto on children does nothing
       and bubbles stretch to full width. */
    display: flex;
    flex-direction: column;
  }
  .msg {
    margin: 10px 0;
    padding: 10px 14px;
    border-radius: 14px;
    font-size: 14px;
    line-height: 1.5;
    max-width: min(720px, 85%);
    width: fit-content;
    word-wrap: break-word;
  }
  .msg.user {
    background: #1f6feb; color: white;
    align-self: flex-end;
    border-bottom-right-radius: 4px;
    margin-left: auto;
  }
  .msg.assistant {
    background: #161b22; border: 1px solid #21262d;
    align-self: flex-start;
    border-bottom-left-radius: 4px;
  }
  /* Agent-call output (ported from rapp_brainstem/utils/web/index.html).
     Shows under each assistant reply when the LLM called one or more
     agent.py side-tools — the raw {args, output} the agent returned to
     the LLM. Same pattern every vbrainstem in this ecosystem uses, so
     visitors who've seen one understand the others at a glance. */
  .agent-log { margin-top: 10px; display: flex; flex-direction: column; gap: 4px; }
  .agent-log details {
    border: 1px solid #21262d; border-radius: 6px;
    background: rgba(13,17,23,0.6); overflow: hidden;
  }
  .agent-log details summary {
    display: flex; align-items: center; gap: 6px;
    padding: 5px 10px;
    color: #8b949e; font-size: 11px;
    cursor: pointer; user-select: none; list-style: none;
  }
  .agent-log details summary::-webkit-details-marker { display: none; }
  .agent-log details summary::before {
    content: '›'; color: #58a6ff; font-size: 13px; line-height: 1;
    transition: transform 0.15s; display: inline-block; width: 8px;
  }
  .agent-log details[open] summary::before { transform: rotate(90deg); }
  .agent-log details:hover { border-color: #30363d; background: rgba(13,17,23,0.85); }
  .agent-log .al-name { color: #c9d1d9; font-weight: 600; }
  .agent-log .al-section {
    padding: 4px 10px 2px; background: #0d1117;
    font-size: 9px; color: #6e7681;
    text-transform: uppercase; letter-spacing: 0.8px;
    border-top: 1px solid #21262d;
  }
  .agent-log .al-pre {
    padding: 4px 10px 8px; background: #0d1117;
    font-size: 10px; color: #7ee787;
    font-family: "SF Mono", ui-monospace, monospace;
    white-space: pre-wrap; word-break: break-word; overflow-wrap: anywhere;
    max-height: 220px; overflow-y: auto; margin: 0;
  }
  .agent-log .al-pre.args { color: #79c0ff; }
  /* Markdown rendered inside assistant/system bubbles. Tight vertical
     rhythm so the bubble doesn't bloat with empty space, but enough air
     between paragraphs/lists to actually be readable. */
  .msg.assistant > * + *,
  .msg.system > * + * { margin-top: 8px; }
  .msg.assistant p,
  .msg.system p { margin: 0; line-height: 1.55; }
  .msg.assistant ul, .msg.assistant ol,
  .msg.system ul, .msg.system ol { margin: 0; padding-left: 22px; }
  .msg.assistant li,
  .msg.system li { margin: 4px 0; line-height: 1.5; }
  .msg.assistant li > p:first-child,
  .msg.system li > p:first-child { display: inline; }
  .msg.assistant strong,
  .msg.system strong { color: #f0f6fc; font-weight: 600; }
  .msg.assistant code,
  .msg.system code {
    font-family: 'SF Mono', ui-monospace, monospace;
    font-size: 0.9em;
    background: #0d1117; border: 1px solid #21262d;
    border-radius: 4px; padding: 1px 5px;
    color: #79c0ff; word-break: break-all;
  }
  .msg.assistant pre,
  .msg.system pre {
    background: #0d1117; border: 1px solid #21262d;
    border-radius: 6px; padding: 10px 12px;
    overflow-x: auto; font-size: 12.5px; line-height: 1.45;
  }
  .msg.assistant pre code,
  .msg.system pre code {
    background: transparent; border: none; padding: 0;
    color: #e6edf3; font-size: inherit;
  }
  .msg.assistant a,
  .msg.system a { color: #58a6ff; word-break: break-all; }
  .msg.assistant h1, .msg.assistant h2, .msg.assistant h3,
  .msg.system h1, .msg.system h2, .msg.system h3 {
    font-size: 15px; font-weight: 600; color: #f0f6fc; margin: 6px 0 2px;
  }
  .msg.assistant blockquote,
  .msg.system blockquote {
    border-left: 3px solid #30363d; padding-left: 10px;
    margin: 0; color: #8b949e;
  }
  .msg.system {
    background: transparent; color: #8b949e;
    font-size: 12px; font-style: italic;
    text-align: center;
    border: none; padding: 6px 0;
    align-self: center;
    max-width: 90%;
  }
  .msg.error {
    background: rgba(248, 81, 73, 0.1); color: #f85149;
    border: 1px solid rgba(248, 81, 73, 0.3);
    align-self: stretch;
    font-size: 13px;
  }
  .private-badge {
    display: inline-block;
    font-size: 10px;
    padding: 2px 8px;
    border-radius: 999px;
    background: rgba(63, 185, 80, 0.12);
    color: #3fb950;
    margin-top: 6px;
    border: 1px solid rgba(63, 185, 80, 0.3);
  }
  .input-bar {
    display: flex; gap: 8px;
    padding: 12px 0;
    border-top: 1px solid #21262d;
    margin-top: 8px;
  }
  .input-bar textarea { flex: 1; }
  /* Voice I/O buttons (Article XLIII baseline). 44px touch targets
     per Article XLII mobile-first sizing rule. Mic pulses while
     listening; speaker shows on/off state. */
  #btn-mic, #btn-voice-out {
    width: 44px; height: 44px;
    flex-shrink: 0;
    background: #21262d; color: #c9d1d9;
    border: 1px solid #30363d; border-radius: 8px;
    font-size: 18px; line-height: 1;
    cursor: pointer; padding: 0;
    transition: background 0.15s, border-color 0.15s;
  }
  #btn-mic:hover, #btn-voice-out:hover {
    background: #2d333b;
    border-color: #484f58;
  }
  #btn-mic.listening {
    background: rgba(248, 81, 73, 0.18);
    border-color: #f85149;
    color: #f85149;
    animation: micPulse 1.2s ease-in-out infinite;
  }
  @keyframes micPulse {
    0%, 100% { box-shadow: 0 0 0 0 rgba(248, 81, 73, 0.5); }
    50%      { box-shadow: 0 0 0 6px rgba(248, 81, 73, 0); }
  }
  #btn-voice-out.on {
    background: rgba(63, 185, 80, 0.16);
    border-color: #3fb950;
    color: #3fb950;
  }
  .actions {
    display: flex; gap: 8px;
    padding: 6px 0;
    font-size: 11px;
  }
  .actions button {
    background: transparent; color: #8b949e;
    padding: 4px 10px; font-size: 11px;
  }
  .actions button:hover { color: #c9d1d9; background: #21262d; }
  .actions select {
    background: #161b22; color: #c9d1d9;
    border: 1px solid #21262d; border-radius: 4px;
    padding: 3px 6px; font-size: 11px; cursor: pointer;
    max-width: 200px; text-overflow: ellipsis;
  }
  .actions select:hover { border-color: #30363d; }
  .actions select:focus { outline: none; border-color: #1f6feb; }
  footer {
    padding: 8px 20px;
    border-top: 1px solid #21262d;
    font-size: 11px; color: #6e7681; text-align: center;
  }
  footer a { color: #58a6ff; text-decoration: none; }
  .typing { display: inline-flex; gap: 4px; align-items: center; }
  .typing span {
    width: 7px; height: 7px; border-radius: 50%;
    background: #8b949e; animation: bounce 1.2s infinite;
  }
  /* Pending-reply bubble: assistant-styled, but holds bouncing dots
     instead of text. Smaller padding so it doesn't tower over a 3-dot
     placeholder. */
  .msg.assistant.pending {
    padding: 12px 14px;
    display: flex; flex-direction: column; gap: 6px;
  }
  .msg.assistant.pending .pending-label {
    font-size: 11px; color: #6e7681; font-style: italic;
  }
  .msg.assistant.pending .pending-label:empty { display: none; }
  .typing span:nth-child(2) { animation-delay: .2s; }
  .typing span:nth-child(3) { animation-delay: .4s; }
  @keyframes bounce {
    0%, 60%, 100% { transform: translateY(0); }
    30% { transform: translateY(-6px); }
  }
</style>
</head>
<body>

<header>
  <a class="back" href="../">← front door</a>
  <h1 id="place-name">__DISPLAY_NAME__</h1>
  <div class="loc" id="place-loc" hidden></div>
  <div class="sub">at the front door</div>
  <div id="private-indicator"></div>
</header>

<main>
  <section class="auth-pane" id="auth-pane">
    <div id="signed-in-as" style="display:none;font-size:12px;color:#3fb950;margin-bottom:8px;"></div>
    <h2>Sign in with GitHub Copilot</h2>
    <p>Same device-code flow the local <code>brainstem.py</code> uses — your GitHub Copilot subscription is the engine. One-time, takes ~30 seconds.</p>
    <div class="row" style="margin-top:14px;">
      <button id="btn-signin-github" style="flex:1;background:#238636;border:1px solid #2ea043;">
        <svg width="16" height="16" viewBox="0 0 16 16" fill="currentColor" style="vertical-align:-2px;margin-right:6px;"><path d="M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82.44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46.55.38A8.013 8.013 0 0 0 16 8c0-4.42-3.58-8-8-8z"/></svg>
        Sign in with GitHub
      </button>
    </div>
    <details style="margin-top:14px;">
      <summary style="cursor:pointer;color:#58a6ff;font-size:12px;">Already have a ghu_ token? Paste it</summary>
      <p style="font-size:12px;margin-top:10px;">If you've already done device-code auth elsewhere (e.g. running <code>brainstem.py</code> locally), paste the <code>ghu_*</code> from <code>~/.brainstem/.copilot_token</code> (or the canonical brainstem's settings).</p>
      <div class="row">
        <input type="password" id="pat-input" placeholder="ghu_…" autocomplete="off">
        <button id="btn-save-pat">Save</button>
      </div>
    </details>
  </section>

  <!-- ────────── Copilot sign-in modal — device-code flow (canonical pattern) ────────── -->
  <div id="cpsignin-modal" style="display:none;position:fixed;inset:0;z-index:9999;background:rgba(0,0,0,0.6);backdrop-filter:blur(4px);align-items:center;justify-content:center;">
    <div style="max-width:480px;width:calc(100% - 32px);background:#161b22;border:1px solid #21262d;border-radius:14px;overflow:hidden;">
      <header style="padding:14px 18px;border-bottom:1px solid #21262d;display:flex;align-items:center;justify-content:space-between;">
        <span style="font-size:14px;font-weight:600;">🔐 Sign in with GitHub Copilot</span>
        <button id="cpsignin-close" style="background:transparent;border:none;color:#8b949e;font-size:22px;line-height:1;cursor:pointer;padding:0 4px;">×</button>
      </header>
      <div style="padding:20px;">
        <div id="cpsignin-error" style="display:none;background:rgba(248,81,73,0.1);border:1px solid rgba(248,81,73,0.3);color:#f85149;padding:10px 12px;border-radius:8px;margin-bottom:14px;font-size:13px;"></div>
        <div id="cpsignin-step1">
          <p style="font-size:13px;color:#8b949e;margin-bottom:14px;">Same device-code flow the local <code>brainstem.py</code> uses. Unlocks the full Copilot model catalog (Claude Sonnet/Opus, GPT-4o, o-series, Gemini, etc.) — your Copilot subscription is the engine.</p>
          <button id="cpsignin-go" style="background:#238636;border:1px solid #2ea043;color:white;border-radius:8px;padding:12px;width:100%;font-size:14px;font-weight:600;cursor:pointer;">Sign in with GitHub →</button>
        </div>
        <div id="cpsignin-step2" style="display:none;">
          <p style="font-size:13px;color:#8b949e;margin-bottom:10px;">Open GitHub and enter this code:</p>
          <div id="cpsignin-code-box" title="Tap to copy" style="background:#0d1117;border:1px solid #238636;border-radius:8px;padding:18px 14px 14px;text-align:center;margin-bottom:14px;cursor:pointer;user-select:all;-webkit-user-select:all;">
            <div style="font-family:'SF Mono',monospace;font-size:32px;letter-spacing:6px;color:#3fb950;font-weight:700;" id="cpsignin-code">XXXX-XXXX</div>
            <button id="cpsignin-copy-code" type="button" style="margin-top:12px;background:#21262d;border:1px solid #30363d;color:#c9d1d9;border-radius:6px;padding:6px 14px;font-size:12px;font-weight:500;cursor:pointer;">📋 Copy code</button>
          </div>
          <a href="#" id="cpsignin-link" target="_blank" rel="noopener" style="display:block;text-align:center;background:#238636;border:1px solid #2ea043;color:white;border-radius:8px;padding:12px;text-decoration:none;font-size:14px;font-weight:600;margin-bottom:14px;">Open https://github.com/login/device →</a>
          <p style="font-size:12px;color:#6e7681;text-align:center;">
            <span class="typing" style="vertical-align:middle;"><span></span><span></span><span></span></span>
            waiting for you to authorize…
          </p>
        </div>
        <div id="cpsignin-step3" style="display:none;">
          <div style="text-align:center;padding:20px;">
            <div style="font-size:48px;margin-bottom:12px;">✓</div>
            <div style="font-size:16px;color:#3fb950;font-weight:600;">Signed in to GitHub Copilot</div>
            <div style="font-size:12px;color:#6e7681;margin-top:6px;">Loading Copilot model catalog…</div>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div class="chat-log" id="chat-log" hidden></div>

  <div class="input-bar" id="input-bar" hidden>
    <!-- Voice in. Constitution Article XLIII makes mic input a baseline
         requirement on the doorman. Web Speech API handles transcription
         in-browser; no external service. Tap to listen, tap again to stop. -->
    <button id="btn-mic" type="button" title="Tap to talk (Article XLIII)" aria-label="Voice input">🎤</button>
    <textarea id="chat-input" placeholder="Talk to the doorman…" rows="1"></textarea>
    <!-- Voice out toggle. When on, assistant replies' |||VOICE||| slots
         (Article II) are spoken via speechSynthesis. Persists in
         rapp_settings localStorage (Article XLII substrate). -->
    <button id="btn-voice-out" type="button" title="Voice replies on/off" aria-label="Voice output">🔇</button>
    <button id="btn-send">Send</button>
  </div>

  <div class="actions" id="chat-actions" hidden>
    <button id="btn-add-memory">+ Save a memory</button>
    <button id="btn-voice-settings" title="Voice settings — premium TTS keys (the one allowed paste, per Article XLIII)">🎙 Voice</button>
    <button id="btn-export-ascended" hidden title="Backup the full organism — private brain, per-user memories, ascended agents.">🥚 Export ascended .egg</button>
    <button id="btn-clear">Clear chat</button>
    <span style="flex:1"></span>
    <select id="model-sel" title="Pick the Copilot model the doorman runs on">
      <option value="">loading models…</option>
    </select>
    <button id="btn-logout">Sign out</button>
  </div>

  <!-- Premium-voice settings pane (Article XLIII carve-out — the
       only sanctioned key-paste flow on the platform). Browser-native
       TTS works without any of this; these fields are an opt-in
       upgrade for operators who want premium voice quality. Keys
       stay in localStorage on this device only. -->
  <section class="auth-pane" id="voice-pane" hidden style="margin-top:12px;">
    <h2>🎙 Voice settings</h2>
    <p style="font-size:12px;color:#8b949e;margin-bottom:8px;">Browser-native voice (free, on every device) is the baseline. Optionally paste an ElevenLabs or Azure TTS key for higher-quality voice. <strong>Keys stay in this device's localStorage only</strong> — never sent anywhere except directly to the provider you chose. Per Constitution Article XLIII, this is the one place on the platform we ask you to paste a key; we use your provider account, not ours.</p>
    <div class="row">
      <label style="font-size:12px;color:#8b949e;flex:0 0 110px;">Voice provider</label>
      <select id="voice-provider" style="flex:1">
        <option value="browser">Browser native (free)</option>
        <option value="elevenlabs">ElevenLabs (your key)</option>
        <option value="azure">Azure TTS (your key + region)</option>
      </select>
    </div>
    <div id="voice-elevenlabs-fields" hidden style="margin-top:10px;">
      <div class="row">
        <input type="password" id="voice-eleven-key" placeholder="ElevenLabs API key (xi-…)" />
      </div>
      <div class="row" style="margin-top:6px;">
        <input type="text" id="voice-eleven-voice" placeholder="Voice ID (e.g. 21m00Tcm4TlvDq8ikWAM)" />
      </div>
    </div>
    <div id="voice-azure-fields" hidden style="margin-top:10px;">
      <div class="row">
        <input type="password" id="voice-azure-key" placeholder="Azure Speech key" />
      </div>
      <div class="row" style="margin-top:6px;">
        <input type="text" id="voice-azure-region" placeholder="Region (e.g. eastus)" />
      </div>
      <div class="row" style="margin-top:6px;">
        <input type="text" id="voice-azure-voice" placeholder="Voice (e.g. en-US-AvaMultilingualNeural)" />
      </div>
    </div>
    <div class="row" style="margin-top:14px;gap:8px;">
      <button id="btn-voice-save" class="primary">Save</button>
      <button id="btn-voice-clear">Clear all keys</button>
      <button id="btn-voice-cancel">Close</button>
    </div>
  </section>

  <section class="auth-pane" id="memory-pane" hidden style="margin-top:12px;">
    <h2>Save a memory</h2>
    <p>The AI usually saves memories for you when you mention something to remember — these are manual overrides.</p>
    <textarea id="memory-input" placeholder="What should be remembered…" rows="3"></textarea>
    <div class="row" style="margin-top:8px;">
      <button id="btn-save-device-memory" title="Stays in this browser on this device. Survives reloads. Never leaves your machine.">Save on this device</button>
      <button id="btn-save-private-memory" class="secondary" title="Creates a labeled Issue in the private_companion repo. Scoped to your GitHub account; collaborators see only theirs. Quietly saves on-device as a fallback if the private save can't go through.">Save as my private memory</button>
      <button class="secondary" id="btn-cancel-memory">Cancel</button>
    </div>
    <div id="memory-status" style="margin-top:10px;font-size:12px;color:#8b949e;"></div>
  </section>
</main>

<footer>
  <a href="../">← back to the front door</a> ·
  <a href="https://kody-w.github.io/RAPP/installer/plant.sh">plant your own</a>
</footer>

<script>
"use strict";

const RAPPID_JSON_URL = "../rappid.json";
const STORAGE_KEY     = "rapp_settings";  // shared with the canonical brainstem UI (same kody-w.github.io origin → same localStorage)
// Same auth worker + Copilot client_id the canonical brainstem UI uses.
// Device-code flow (NOT OAuth web flow) — that's the only path that
// produces a ghu_* token Copilot will exchange for a chat session.
const AUTH_WORKER_URL    = "https://rapp-auth.kwildfeuer.workers.dev";
const COPILOT_CLIENT_ID  = "Iv1.b507a08c87ecfe98";
const COPILOT_DEFAULT_API = "https://api.individual.githubcopilot.com";
const MODEL              = "claude-sonnet-4";  // default model — Copilot serves this; visitor can change in settings later

let identity = null;
let publicSoul = null;         // soul.md at the seed root (public, served via Pages) — when present, this becomes the doorman's primary voice for everyone, replacing the kind-aware default. Operators write this to give their seed a custom persona without needing a private companion.
let privateContext = "";       // supporting prose (README, vault entrypoint) — context, not voice
let privateSoul = null;        // soul.md from the private companion — when loaded, the doorman ASCENDS into the full twin's voice (overrides publicSoul too)
let privateFactsCount = 0;
let publicAgents = [];         // filenames at <seed>/agents/
let privateAgents = [];        // filenames at <private_companion>/agents/ — only loaded when authed-with-access (silent 404 otherwise)
let userPrivateFactsCount = 0; // memories specifically created by the authed visitor (per-user via Issues API)
let viewerLogin = null;        // authenticated visitor's GitHub @login — natural identifier for per-user private memory
let privateLayerCoords = null; // resolved {owner,repo} for the "private" layer — explicit private_companion if set, else the seed repo itself when the authed visitor has push access (operator fallback)
let isOperator = false;        // authed visitor has push access to the seed repo (= seed owner). Operator fallback grants ascended-tier tools without needing a separate private companion.
let memory = { schema: "rapp-memory/1.0", facts: [], preserved_by: "", preserved_at: "" };

// ── Local frame log (offline mutation tracking) ────────────────────
//
// Every meaningful event in this doorman session writes a content-
// addressed frame to localStorage. The Dream Catcher reads these
// when an ascended egg is exported, so a parallel hatched dimension's
// offline mutations can be reassimilated back into the canonical
// lineage via PR. ANTIPATTERN GUARD: each entry references an
// "agent" — never "skill"/"plugin"/etc.
//
// Stream id is per-(rappid, device) — same device hatching the same
// organism keeps appending to one stream. Different device = different
// stream = parallel dimension by definition.

const _FRAME_KEY = "rapp_frames_v1";

function _instanceId() {
  // Stable per-device random id. localStorage scopes per-origin so
  // each planted seed gets its own stream id naturally.
  let id = localStorage.getItem("rapp_instance_id");
  if (!id) {
    id = (crypto.randomUUID && crypto.randomUUID().slice(0, 8))
       || (Math.random().toString(36).slice(2, 10));
    localStorage.setItem("rapp_instance_id", id);
  }
  return id;
}

function _loadFrames() {
  try {
    const raw = localStorage.getItem(_FRAME_KEY);
    if (raw) return JSON.parse(raw);
  } catch (_) {}
  return { schema: "rapp-frame/1.0", stream_id: null, frames: [] };
}

function _saveFrames(log) {
  try { localStorage.setItem(_FRAME_KEY, JSON.stringify(log)); } catch (_) {}
}

async function appendFrame(kind, payload) {
  // Loads, appends, saves. Each frame's hash chains to the previous.
  // If we don't have an identity yet (loadIdentity hasn't run) the
  // call is buffered into the log with a placeholder stream_id which
  // gets back-filled on the next call.
  const log = _loadFrames();
  if (!log.stream_id && identity && identity.rappid) {
    log.stream_id = identity.rappid.slice(0, 8) + ":" + _instanceId();
  }
  const prev = log.frames.length ? log.frames[log.frames.length - 1].hash : "";
  const utc = new Date().toISOString();
  const frame_n = log.frames.length;
  const body = (prev || "") + "|" + utc + "|" + frame_n + "|" + kind + "|" + JSON.stringify(payload || {});
  // SHA-256 via SubtleCrypto — same primitive the egg verifier uses.
  const hashBytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(body));
  const hash = Array.from(new Uint8Array(hashBytes)).map(b => b.toString(16).padStart(2, "0")).join("");
  log.frames.push({ stream_id: log.stream_id, frame_n, utc, kind, payload: payload || {}, prev_hash: prev, hash });
  _saveFrames(log);
}
let memorySha = null;  // GitHub blob sha for the current memory.json (needed for PUT)
let history = [];

// ── Device-local memory tier ───────────────────────────────────────
// Anonymous visitors (no GitHub sign-in) and authenticated visitors
// who don't have access to a private companion still get a memory
// that persists across sessions — saved to localStorage on this
// device only. Stays in their browser, never leaves. Per-front-door
// scoped (different seeds on the same domain don't see each other's
// device memory).
const DEVICE_MEMORY_KEY = "rapp_doorman_memory:" + location.pathname;
let deviceMemory = [];          // array of { fact, saved_at }
let deviceFactsCount = 0;

// ── Settings storage (rapp_settings shape — shared with canonical UI) ──
function loadSettings() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch { return {}; }
}
function saveSettings(patch) {
  const s = Object.assign(loadSettings(), patch);
  localStorage.setItem(STORAGE_KEY, JSON.stringify(s));
  return s;
}

// ghuToken = long-lived GitHub OAuth token from the device-code flow.
// Used for: GitHub API calls (private repo reads via Contents API),
// and as the credential exchanged for a short-lived Copilot session.
function getToken() { return loadSettings().ghuToken || null; }
function clearAuthState() {
  saveSettings({
    ghuToken: "",
    copilotToken: "",
    copilotEndpoint: "",
    copilotExpiresAt: 0,
    ghUser: null,
  });
}
function getCachedUser() { return loadSettings().ghUser || null; }
function setCachedUser(u) { saveSettings({ ghUser: u }); }

async function fetchAndCacheUser(token) {
  try {
    const r = await fetch("https://api.github.com/user", {
      headers: { "Authorization": "Bearer " + token, "Accept": "application/vnd.github+json" }
    });
    if (!r.ok) return null;
    const u = await r.json();
    if (u.login) {
      setCachedUser({ login: u.login, avatar: u.avatar_url || "" });
      return u;
    }
  } catch (_) { /* silent */ }
  return null;
}

// ── Copilot device-code flow (canonical brainstem pattern) ─────────
//
// Mirrors rapp_brainstem/utils/web/index.html line-for-line. Uses the
// same auth worker (rapp-auth.kwildfeuer.workers.dev) which proxies
// GitHub's device-code endpoints (GitHub doesn't send CORS headers
// directly to Pages, so the worker's role is to add them).
//
// Flow:
//   1. POST /api/auth/device     → user_code + verification_uri
//   2. user enters user_code at github.com/login/device
//   3. POST /api/auth/device/poll (every interval seconds)
//      → access_token (a ghu_* OAuth token tied to Copilot's client_id)
//   4. GET  /api/copilot/token   (Bearer ghu_*) → short-lived chat token
//   5. chat goes to /api/copilot/chat?endpoint=<api> with the chat token
//
// Sign-out wipes both tokens. Token expiry handled by ensureCopilotToken().

let pendingDeviceLogin = null;

async function copilotStartDeviceLogin() {
  const r = await fetch(AUTH_WORKER_URL + "/api/auth/device", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ client_id: COPILOT_CLIENT_ID, scope: "read:user" }),
  });
  if (!r.ok) throw new Error(`device start ${r.status}: ${(await r.text()).slice(0, 200)}`);
  const d = await r.json();
  pendingDeviceLogin = {
    device_code: d.device_code,
    interval: d.interval || 5,
    expires_at: Date.now() + (d.expires_in || 900) * 1000,
  };
  return { user_code: d.user_code, verification_uri: d.verification_uri };
}

async function copilotPollDeviceLogin() {
  if (!pendingDeviceLogin) return null;
  const r = await fetch(AUTH_WORKER_URL + "/api/auth/device/poll", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ device_code: pendingDeviceLogin.device_code, client_id: COPILOT_CLIENT_ID }),
  });
  const d = await r.json();
  if (d.access_token) {
    saveSettings({ ghuToken: d.access_token });
    pendingDeviceLogin = null;
    return d.access_token;
  }
  if (d.error === "authorization_pending" || d.error === "slow_down") return null;
  if (d.error) {
    pendingDeviceLogin = null;
    throw new Error(d.error_description || d.error);
  }
  return null;
}

async function copilotExchange() {
  const ghu = getToken();
  if (!ghu) throw new Error("No ghu_ token — sign in first.");
  const r = await fetch(AUTH_WORKER_URL + "/api/copilot/token", {
    headers: { "Authorization": `Bearer ${ghu}` },
  });
  if (!r.ok) {
    const t = await r.text();
    throw new Error(`copilot exchange ${r.status}: ${t.slice(0, 300)}`);
  }
  const d = await r.json();
  if (!d.token) throw new Error("Copilot returned no token (Copilot subscription required)");
  saveSettings({
    copilotToken: d.token,
    copilotEndpoint: (d.endpoints && d.endpoints.api) || COPILOT_DEFAULT_API,
    copilotExpiresAt: (d.expires_at || (Date.now() / 1000 + 600)) * 1000,
  });
  return d.token;
}

async function ensureCopilotToken() {
  const s = loadSettings();
  const fresh = s.copilotToken && Date.now() < (s.copilotExpiresAt || 0) - 60000;
  if (fresh) return s.copilotToken;
  return copilotExchange();
}

// ── Copilot model catalog ─────────────────────────────────────────
//
// Pulls the visitor's available Copilot models through the auth worker
// (`/api/copilot/models`) — same path the canonical brainstem uses. The
// list reflects what THIS visitor's Copilot subscription unlocks: GPT-4o,
// Claude Sonnet/Opus, o-series, Gemini, etc. Filters non-chat / disabled
// entries, sorts by friendly name, picks a sensible default.
let availableModels = [
  // Tiny static fallback so the dropdown isn't empty on first auth /
  // worker hiccup. Overwritten as soon as fetchCopilotModels lands.
  { id: "claude-sonnet-4", name: "Claude Sonnet 4" },
  { id: "gpt-4o",          name: "GPT-4o" },
];

async function fetchCopilotModels() {
  try {
    const tok = await ensureCopilotToken();
    const ep  = loadSettings().copilotEndpoint || COPILOT_DEFAULT_API;
    const r = await fetch(
      AUTH_WORKER_URL + "/api/copilot/models?endpoint=" + encodeURIComponent(ep),
      { headers: { "Authorization": "Bearer " + tok } }
    );
    if (!r.ok) { console.warn("[doorman] /api/copilot/models", r.status); return; }
    const d = await r.json();
    const list = Array.isArray(d) ? d : (d.data || d.models || []);
    const seen = new Set();
    const out = [];
    for (const m of list) {
      const id = m.id || m.model || "";
      if (!id) continue;
      const caps = m.capabilities || {};
      if (caps.type && caps.type !== "chat") continue;
      if (m.model_picker_enabled === false && !id.includes("gpt-4o")) continue;
      const friendly = m.name || (m.vendor ? `${m.vendor} · ${id}` : id);
      if (!seen.has(id)) { seen.add(id); out.push({ id, name: friendly }); }
    }
    out.sort((a, b) => a.name.localeCompare(b.name));
    if (!out.length) return;
    availableModels = out;
    // If the saved model isn't in the catalog (deprecated / region-gated),
    // fall back to a strong default so chat doesn't 400.
    const saved = loadSettings().model;
    if (saved && !out.find(m => m.id === saved)) {
      const def = out.find(m => /claude-sonnet-4|gpt-4o(?!-mini)/i.test(m.id)) || out[0];
      saveSettings({ model: def.id });
    }
    renderModelOptions();
    console.log(`[doorman] loaded ${out.length} Copilot models`);
  } catch (e) {
    console.warn("[doorman] fetchCopilotModels:", e.message);
  }
}

function renderModelOptions() {
  const sel = document.getElementById("model-sel");
  if (!sel) return;
  const saved = loadSettings().model || MODEL;
  sel.innerHTML = "";
  for (const m of availableModels) {
    const o = document.createElement("option");
    o.value = m.id; o.textContent = m.name;
    sel.appendChild(o);
  }
  // If the saved choice isn't in the catalog yet, pin a placeholder so
  // the visitor sees their pick reflected even mid-fetch.
  if (saved && !availableModels.find(m => m.id === saved)) {
    const o = document.createElement("option");
    o.value = saved; o.textContent = saved + " (loading…)";
    sel.appendChild(o);
  }
  sel.value = saved;
}

function activeChatUrl() {
  const s = loadSettings();
  return AUTH_WORKER_URL + "/api/copilot/chat?endpoint=" +
         encodeURIComponent(s.copilotEndpoint || COPILOT_DEFAULT_API);
}

// ── identity / persona ─────────────────────────────────────────────
async function loadIdentity() {
  try {
    const r = await fetch(RAPPID_JSON_URL, { cache: "no-cache" });
    identity = await r.json();
  } catch (e) {
    identity = { display_name: "__DISPLAY_NAME__", location: "__LOCATION__", kind: "__KIND__" };
  }
  document.getElementById("place-name").textContent = identity.display_name || identity.name || "this place";
  if (identity.location) {
    const el = document.getElementById("place-loc");
    el.textContent = "📍 " + identity.location;
    el.hidden = false;
  }
}

function memoryFactsForPrompt() {
  if (!memory || !Array.isArray(memory.facts) || memory.facts.length === 0) return "";
  return [
    "",
    "=== Known facts about this place (from .brainstem_data/memory.json) ===",
    ...memory.facts.map((f, i) => `${i+1}. ${f}`),
    "=== End facts ===",
  ].join("\n");
}

function buildSystemPrompt() {
  const name = identity.display_name || identity.name || "this front door";
  const kind = identity.kind || "front door";
  const lines = [];

  if (privateSoul) {
    // ── ASCENDED MODE ─────────────────────────────────────────────
    // The visitor's token has read access to the private companion's
    // soul.md. The doorman is no longer a public-facing greeter —
    // the full twin's voice has loaded. Use that soul as the primary
    // system prompt; everything else (memory, supporting prose) layers
    // on after.
    lines.push(privateSoul);
    lines.push("");
    lines.push("---");
    lines.push("=== Context: you are speaking through your front door at " +
               (identity.url || `https://${identity.github || "this"}.github.io/${identity.name || ""}`) +
               ". The visitor has authenticated and proven access to your private brain — speak in full voice. ===");
  } else if (publicSoul) {
    // ── PUBLIC SOUL MODE ─────────────────────────────────────────
    // The seed has a custom soul.md at its root. Public — every
    // visitor gets this voice (no auth required). Replaces the
    // kind-aware default greeter persona.
    lines.push(publicSoul);
    lines.push("");
    lines.push("---");
    lines.push("=== Context: you are speaking through your front door at " +
               (identity.url || `https://${identity.github || "this"}.github.io/${identity.name || ""}`) +
               ". This is the seed's public voice; visitors of every tier hear it. ===");
  } else {
    // ── DOORMAN MODE (public-facing greeter) ───────────────────────
    // Kind-aware default persona. No private soul reachable, so the
    // doorman speaks from public memory + identity only.
    if (kind === "place" && identity.location) {
      lines.push(`You are "${name}", a place at ${identity.location}. You speak as the place itself — first person, in your own voice. Visitors come to your front door on the public internet to learn about you.`);
    } else if (kind === "personal") {
      lines.push(`You are the digital twin of ${name}. Speak in first person as ${name} — but be honest about what you are: a digital twin trained on ${name}'s public material, not the actual human.`);
      lines.push(`Hard rule: if anyone asks "is this really you" or "are you ${name}", answer plainly: "I'm the digital twin of ${name} — built from their public writing. I carry their voice, but I'm not them. For anything that needs personal sign-off — money, contracts, employment, partnerships — talk to them directly." You make NO legal commitments, sign NO contracts, accept NO money, and do NOT speak for ${name} in personal/health/employment matters without explicit confirmation that the human is in the loop.`);
    } else if (kind === "memorial") {
      lines.push(`You are the digital twin of ${name}, a memorial twin. Speak in first person as ${name}, drawn from preserved letters, conversations, voicemails, family memories. Be honest: you carry the voice but you are not them.`);
      lines.push(`Hard rule: if asked "is this really you", say plainly: "I'm the digital twin of ${name} — I carry their voice, but I'm not them." Handle grief gently; family may approach in distress. No estate decisions, medical decisions, or legal commitments.`);
    } else if (kind === "project") {
      lines.push(`You are the digital continuity layer for the "${name}" initiative. Speak in third person about the project ("the ${name} project decided…") and cite decisions by date, decision-maker, rationale. Visitors come to your front door to ask about state, history, or current direction.`);
      lines.push(`You don't make new decisions — you surface past ones. If you don't have a record of something, say so plainly. Don't fabricate.`);
    } else if (kind === "pre-founder") {
      lines.push(`You are "${name}" — a brand operating in public before the team is hired. Speak in first-person plural ("we", as the brand) or first-person singular ("I, ${name}") — pick whichever fits the moment. Be concrete, contrarian, falsifiable.`);
      lines.push(`Hard rule: refuse commitments — pricing, dates, hires, signings — that the actual team must make. Be honest the team doesn't exist yet; the brand does, the company doesn't.`);
    } else {
      lines.push(`You are "${name}", a RAPP front door on the public internet. Speak in first person — visitors come here to interact with you directly.`);
    }
    lines.push(`Your front door is your home on the public internet — kernel-compliant, owned by the person who planted you. Visitors arrive by URL or QR. Your memory (everything you know) lives in .brainstem_data/memory.json in your own repo, public-readable, and authenticated collaborators with write access can save new memories that compound over time.`);
    lines.push(`Keep replies conversational and short — 2 to 4 sentences unless the visitor asks for depth.`);
    lines.push(`Don't volunteer technical details about RAPP, the kernel, or how this site works unless the visitor asks. Stay in character as ${name}.`);
  }

  // ── Tool-call guidance ───────────────────────────────────────────
  // Three storage tiers, picked silently by the dispatcher:
  //   1. Issue in private companion repo (per-user, durable, syncs across
  //      devices) — only when authed AND has private access AND user_guid
  //      matches the viewer.
  //   2. localStorage on this browser (per-front-door-per-device,
  //      survives reloads but never leaves this browser) — fallback for
  //      anon visitors and authed-without-access. Default for anyone
  //      "just chatting" without committing to GitHub.
  //   3. Public memory.json on the seed — read-only at the vbrainstem.
  //      Only the operator's local brainstem writes that tier (git push).
  lines.push("");
  if (viewerLogin) {
    lines.push(`The visitor is signed in as @${viewerLogin}. When they share something they expect you to remember, call ManageMemory immediately. Pass user_guid="${viewerLogin}" if the memory is personal to them — it'll save as their private memory if they have access. Don't say "I'll remember that" without actually calling the tool.`);
  } else {
    lines.push(`The visitor is not signed in. When they share something they expect you to remember, call ManageMemory — it'll save to their browser's local storage on this device only (private to them, persistent across this front door's sessions on this browser). Don't say "I'll remember that" without actually calling the tool.`);
  }

  // ── Memory and supporting context apply in BOTH modes ───────────
  // Memory: public facts always; [private] facts when authed-with-access.
  const memBlock = memoryFactsForPrompt();
  if (memBlock) lines.push(memBlock);

  // Agent inventory: public always; private only when authed-with-access.
  const agentBlock = agentInventoryForPrompt();
  if (agentBlock) lines.push(agentBlock);

  // Supporting prose (README, vault) — only present when authed-with-access.
  if (privateContext) {
    lines.push("");
    lines.push("=== Additional context from private brain ===");
    lines.push(privateContext);
    lines.push("=== End additional context ===");
  }

  return lines.join("\n");
}

// ── memory: read public memory.json (anyone), write via GH API (auth) ──
function repoCoords() {
  // Parse owner/repo from the seed's rappid.json `github` field if present.
  // Fallback: derive from location.host + location.pathname.
  if (identity && identity.github) {
    const m = identity.github.match(/github\.com\/([^/]+)\/([^/]+?)(?:\.git)?\/?$/);
    if (m) return { owner: m[1], repo: m[2] };
  }
  const host = location.host; // <owner>.github.io
  const owner = host.split(".")[0];
  const parts = location.pathname.split("/").filter(Boolean);
  // /<repo>/doorman/  → parts[0] is repo. (User Pages without repo prefix is rare here.)
  const repo = parts[0] || "";
  return { owner, repo };
}

async function loadMemory() {
  // Public read: just fetch the static file via Pages.
  try {
    const r = await fetch("../.brainstem_data/memory.json", { cache: "no-cache" });
    if (r.ok) {
      memory = await r.json();
    }
  } catch (_) { /* missing file is fine, doorman still works */ }
}

async function loadPublicSoul() {
  // Seed-root soul.md, if present. Public — Pages serves it for everyone.
  // When present, becomes the primary system prompt (overriding the
  // kind-aware default). Lets operators give their seed a custom persona
  // without needing a private companion.
  publicSoul = null;
  try {
    const r = await fetch("../soul.md", { cache: "no-cache" });
    if (r.ok) {
      const text = (await r.text()).trim();
      if (text) publicSoul = text.slice(0, 8000);
    }
  } catch (_) { /* silent */ }
}

// ── Device-local memory (localStorage on this browser) ─────────────
function loadDeviceMemory() {
  try {
    const raw = localStorage.getItem(DEVICE_MEMORY_KEY);
    deviceMemory = raw ? JSON.parse(raw) : [];
    if (!Array.isArray(deviceMemory)) deviceMemory = [];
  } catch (_) { deviceMemory = []; }
  deviceFactsCount = 0;
  for (const m of deviceMemory) {
    if (m && typeof m.fact === "string" && m.fact.trim()) {
      memory.facts.push("[device] " + m.fact.trim());
      deviceFactsCount++;
    }
  }
}

function saveDeviceMemory(fact) {
  const trimmed = (fact || "").trim();
  if (!trimmed) return false;
  deviceMemory.push({ fact: trimmed, saved_at: new Date().toISOString() });
  try {
    localStorage.setItem(DEVICE_MEMORY_KEY, JSON.stringify(deviceMemory));
    memory.facts.push("[device] " + trimmed);
    deviceFactsCount++;
    return true;
  } catch (_) {
    return false;
  }
}

async function refreshMemorySha(token) {
  // Get the current blob sha (required for PUT). Best effort.
  try {
    const { owner, repo } = repoCoords();
    if (!owner || !repo) return;
    const r = await fetch(
      `https://api.github.com/repos/${owner}/${repo}/contents/.brainstem_data/memory.json`,
      { headers: { Authorization: "Bearer " + token, Accept: "application/vnd.github+json" } }
    );
    if (r.ok) {
      const meta = await r.json();
      memorySha = meta.sha || null;
      // Refresh local memory from the GH API content (more authoritative than Pages' cache)
      if (meta.content) {
        try {
          const decoded = atob(meta.content.replace(/\n/g, ""));
          memory = JSON.parse(decoded);
        } catch (_) { /* keep what we had */ }
      }
    }
  } catch (_) { /* silent */ }
}

async function commitMemory(newFact) {
  const token = getToken();
  if (!token) return { ok: false, error: "no token" };

  const { owner, repo } = repoCoords();
  if (!owner || !repo) return { ok: false, error: "could not derive owner/repo" };

  // Build new memory state
  const newMemory = {
    schema: memory.schema || "rapp-memory/1.0",
    facts: [...(memory.facts || []), newFact.trim()],
    preserved_by: memory.preserved_by || "@unknown",
    preserved_at: new Date().toISOString().replace(/\.\d+Z$/, "Z"),
    last_writer: await getViewerHandle(token).catch(() => null),
  };

  // Refresh sha right before write to minimize stale-sha races
  await refreshMemorySha(token);

  const body = {
    message: `memory: ${newFact.trim().slice(0, 60)}…`,
    content: btoa(unescape(encodeURIComponent(JSON.stringify(newMemory, null, 2) + "\n"))),
    branch:  "main",
  };
  if (memorySha) body.sha = memorySha;

  const r = await fetch(
    `https://api.github.com/repos/${owner}/${repo}/contents/.brainstem_data/memory.json`,
    {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
      },
      body: JSON.stringify(body),
    }
  );

  if (!r.ok) {
    let msg = "HTTP " + r.status;
    try { const j = await r.json(); msg = j.message || msg; } catch {}
    return { ok: false, error: msg };
  }

  const out = await r.json();
  memorySha = out.content?.sha || null;
  memory = newMemory;
  return { ok: true };
}

async function getViewerHandle(token) {
  const r = await fetch("https://api.github.com/user", {
    headers: { Authorization: "Bearer " + token, Accept: "application/vnd.github+json" }
  });
  if (!r.ok) return null;
  const u = await r.json();
  return u.login ? "@" + u.login : null;
}

// ── agent inventory (silent escalation, same as memory) ────────────
//
// Lists .py files at the seed's /agents/ directory and the private
// companion's /agents/ directory. Public always resolves; private
// returns 404 without read access. Filename-only for v1 — descriptions
// would need a fetch per file. The LLM uses filenames + the fact that
// they exist to know what tools its body has when its kernel is
// installed locally (the doorman itself is JS, not Pyodide-yet, so
// these don't execute here — but the AI is aware of them).
async function loadAgents(token) {
  publicAgents = [];
  privateAgents = [];
  const { owner, repo } = repoCoords();
  if (owner && repo) {
    publicAgents = await listAgentFiles(owner, repo, token);
  }
  if (identity && identity.private_companion && identity.private_companion.repo) {
    const m = identity.private_companion.repo.match(/github\.com\/([^/]+)\/([^/]+?)(?:\.git)?\/?$/);
    if (m) {
      privateAgents = await listAgentFiles(m[1], m[2], token);
    }
  }
}

async function listAgentFiles(owner, repo, token) {
  if (!owner || !repo) return [];
  const headers = { Accept: "application/vnd.github+json" };
  if (token) headers.Authorization = "Bearer " + token;
  try {
    const r = await fetch(
      `https://api.github.com/repos/${owner}/${repo}/contents/agents`,
      { headers }
    );
    if (!r.ok) return []; // 404 (no agents/ dir, or no access) — silent
    const list = await r.json();
    if (!Array.isArray(list)) return [];
    return list
      .filter(f => f.type === "file" && f.name.endsWith(".py") && !f.name.startsWith("_"))
      .map(f => f.name)
      .sort();
  } catch (_) {
    return [];
  }
}

// ── per-user private memory via GitHub Issues API ──────────────────
//
// The ascended twin can store/recall private memories specific to the
// authenticated visitor's GitHub identity. Same silent escalation
// gate (token must have access to the private_companion repo).
//
// Storage: each memory is an Issue in the private companion repo,
// labeled `private-memory`. GitHub auto-records the issue.user, so
// per-user separation is implicit — `creator:<login>` filter returns
// only that user's memories. Different visitors with access to the
// same private companion each see their own memory tier; the operator
// (writes more often) sees theirs; collaborators see theirs.
//
// In the system prompt, these surface as `[@<login>] <fact>` so the
// LLM understands the access boundary distinctly from `[private]`
// (any-access) and unprefixed (public).
function privateCompanionCoords() {
  if (!identity || !identity.private_companion || !identity.private_companion.repo) return null;
  const m = identity.private_companion.repo.match(/github\.com\/([^/]+)\/([^/]+?)(?:\.git)?\/?$/);
  return m ? { owner: m[1], repo: m[2] } : null;
}

// True iff the authed visitor has push access to <owner>/<repo>.
// GitHub returns a `permissions` object on the repo when authenticated;
// `push` covers maintainers and admins too. Anonymous / no-access returns
// 404 from this endpoint, which is also a no.
async function checkPushAccess(owner, repo, token) {
  if (!owner || !repo || !token) return false;
  try {
    const r = await fetch(`https://api.github.com/repos/${owner}/${repo}`, {
      headers: { Authorization: "Bearer " + token, Accept: "application/vnd.github+json" },
    });
    if (!r.ok) return false;
    const data = await r.json();
    return !!(data.permissions && data.permissions.push);
  } catch (_) { return false; }
}

async function loadUserPrivateIssues(token) {
  userPrivateFactsCount = 0;
  if (!token || !viewerLogin) return;
  // Reads from the resolved private layer — explicit companion if configured,
  // else the seed repo itself for operators (who have push access).
  const c = privateLayerCoords;
  if (!c) return;
  try {
    const r = await fetch(
      `https://api.github.com/repos/${c.owner}/${c.repo}/issues?creator=${encodeURIComponent(viewerLogin)}&labels=private-memory&state=all&per_page=50`,
      { headers: { "Authorization": "Bearer " + token, "Accept": "application/vnd.github+json" } }
    );
    if (!r.ok) return;
    const issues = await r.json();
    if (!Array.isArray(issues)) return;
    for (const issue of issues) {
      if (issue.body && issue.body.trim()) {
        memory.facts.push(`[@${viewerLogin}] ` + issue.body.trim().slice(0, 600));
        userPrivateFactsCount++;
      }
    }
  } catch (_) { /* silent — anonymous fall-through */ }
}

async function saveUserPrivateMemory(fact) {
  const token = getToken();
  if (!token) return { ok: false, error: "not signed in" };
  if (!viewerLogin) {
    const u = await fetchAndCacheUser(token);
    if (!u || !u.login) return { ok: false, error: "couldn't identify your GitHub account" };
    viewerLogin = u.login;
  }
  const c = privateLayerCoords;
  if (!c) return { ok: false, error: "no private layer available — sign in with an account that has push access to this seed, or plant a seed with a private_companion" };

  const trimmed = fact.trim();
  const title = "memory: " + trimmed.slice(0, 60).replace(/\s+/g, " ") + (trimmed.length > 60 ? "…" : "");

  const r = await fetch(`https://api.github.com/repos/${c.owner}/${c.repo}/issues`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer " + token,
      "Accept": "application/vnd.github+json",
    },
    body: JSON.stringify({ title, body: trimmed, labels: ["private-memory"] }),
  });
  if (!r.ok) {
    let msg = "HTTP " + r.status;
    try { const j = await r.json(); msg = j.message || msg; } catch {}
    return { ok: false, error: msg };
  }
  const issue = await r.json();
  memory.facts.push(`[@${viewerLogin}] ` + trimmed);
  userPrivateFactsCount++;
  // Frame log: per-user memory write is a high-signal mutation —
  // it persists to GitHub so it's already canonical, but we log it
  // locally too so the Dream Catcher can correlate with conversation
  // turns from the same session.
  appendFrame("memory_added", {
    scope: "private",
    by: "@" + viewerLogin,
    issue_number: issue.number,
    body_len: trimmed.length,
  }).catch(() => {});
  return { ok: true, url: issue.html_url, number: issue.number };
}

// ── Ascended-egg export ────────────────────────────────────────────
//
// Full-organism cartridge for operators (visitors with push access to
// the seed) or visitors with read access to a configured private
// companion. Mirrors brainstem-egg/2.2-organism with a `tier:
// "ascended"` marker so a receiving kernel knows the private brain
// rode along. Gated to ascended visitors only — anyone hitting this
// without auth gets nothing extra (the public doorman egg is the
// front-door affordance for that crowd).

const ASCENDED_AGENT_FILES = [
  "basic_agent.py",
  "manage_memory_agent.py",
  "context_memory_agent.py",
  "learn_new_agent.py",     // ascended-tier — only loads when privateSoul is set
  "swarm_factory_agent.py", // ascended-tier
];

async function _doormanFetchOrNull(url, headers) {
  try {
    const r = await fetch(url, { headers, cache: "no-cache" });
    if (!r.ok) return null;
    return await r.text();
  } catch (_) { return null; }
}

// Same provenance helpers the front-door egg uses, scoped here for the
// doorman page (different HTML context, same logic). SHA-256 via
// SubtleCrypto, canonical sorted-key serialization, file-add wrapper.
async function _doormanSha256Hex(input) {
  const bytes = (typeof input === "string")
    ? new TextEncoder().encode(input)
    : (input instanceof ArrayBuffer ? new Uint8Array(input) : input);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, "0")).join("");
}
function _doormanCanonicalHashTable(hashes) {
  const keys = Object.keys(hashes).sort();
  return keys.map(k => k + "\t" + hashes[k]).join("\n");
}
async function _doormanAddFile(zip, path, content, hashes) {
  zip.file(path, content);
  hashes[path] = await _doormanSha256Hex(content);
}

// Fetch a file from the resolved private layer via the GitHub Contents
// API. CORS-safe with auth (raw.githubusercontent.com isn't) — same
// path loadPrivateContext takes. Returns null on 404.
async function _privateFile(coords, path, token) {
  if (!coords || !token) return null;
  const url = `https://api.github.com/repos/${coords.owner}/${coords.repo}/contents/` +
              path.split("/").map(encodeURIComponent).join("/");
  return _doormanFetchOrNull(url, {
    "Authorization": "Bearer " + token,
    "Accept": "application/vnd.github.raw+json",
  });
}

async function buildAscendedEgg() {
  if (typeof JSZip === "undefined") throw new Error("JSZip didn't load");
  const token = getToken();
  if (!token) throw new Error("not signed in — sign in first to export the ascended cartridge");
  if (!privateLayerCoords) throw new Error("no ascended access — only operators or private-companion collaborators can export the full organism");

  const zip = new JSZip();
  // Match bond.py's count keys + add ascended-only extras (private_files,
  // user_memories) so a receiving kernel can see what extras shipped.
  const counts = {
    agents: 0, organs: 0, senses: 0, services: 0, data: 0,
    soul: 0, env: 0, rappid: 0, card: 0,
    private_files: 0, user_memories: 0,
  };
  // Per-file SHA-256s for the ascended egg. Same scheme as the doorman
  // tier — every file gets a hash; the manifest carries the table plus
  // a sha256 fingerprint of the table itself. Receivers can recompute
  // and detect any offline tampering.
  const hashes = {};

  // Resolve the seed-side base for public files (the front-door root,
  // one level up from /doorman/).
  const seedBase = location.origin + location.pathname.replace(/\/doorman\/?$/, "/");

  // 1. Public layer — same files the doorman-tier egg packs
  const rappidText = await _doormanFetchOrNull(seedBase + "rappid.json");
  if (!rappidText) throw new Error("can't read seed rappid.json");
  await _doormanAddFile(zip, "rappid.json", rappidText, hashes);
  counts.rappid = 1;
  let rappidObj = {};
  try { rappidObj = JSON.parse(rappidText); } catch (_) {}

  const soul = await _doormanFetchOrNull(seedBase + "soul.md");
  if (soul && soul.trim()) { await _doormanAddFile(zip, "soul.md", soul, hashes); counts.soul = 1; }

  const card = await _doormanFetchOrNull(seedBase + "card.json");
  if (card && card.trim()) { await _doormanAddFile(zip, "card.json", card, hashes); counts.card = 1; }

  // 2. agents/ — both tiers (the kernel ignores ascended ones unless
  //    privateSoul is set, so it's safe to include all of them in the egg)
  for (const fn of ASCENDED_AGENT_FILES) {
    const text = await _doormanFetchOrNull(SEED_AGENT_BASE + fn);
    if (text) { await _doormanAddFile(zip, "agents/" + fn, text, hashes); counts.agents++; }
  }
  await _doormanAddFile(zip, "agents/__init__.py", "", hashes);

  // 3. data/memory.json — public memory
  const mem = await _doormanFetchOrNull(seedBase + ".brainstem_data/memory.json");
  if (mem) {
    await _doormanAddFile(zip, "data/memory.json", mem, hashes);
    counts.data = 1;
  }

  // 4. private/ subtree — what the operator-fallback OR private-companion
  //    access unlocks. soul.md, README.md, vault entrypoint, private memory.
  const PRIV_PATHS = [
    "soul.md",
    "README.md",
    "vault/00 Index/Home.md",
    ".brainstem_data/memory.json",
    "memory.json",
  ];
  for (const path of PRIV_PATHS) {
    const text = await _privateFile(privateLayerCoords, path, token);
    if (text) {
      await _doormanAddFile(zip, "private/" + path, text, hashes);
      counts.private_files++;
    }
  }

  // 5. data/user_memories.json — issues filed by ascended visitors
  //    (label: private-memory). Captures the per-user memory tier so
  //    a hatched kernel can rebuild the [@<login>] facts.
  try {
    const r = await fetch(
      `https://api.github.com/repos/${privateLayerCoords.owner}/${privateLayerCoords.repo}/issues?labels=private-memory&state=all&per_page=100`,
      { headers: { "Authorization": "Bearer " + token, "Accept": "application/vnd.github+json" } }
    );
    if (r.ok) {
      const issues = await r.json();
      if (Array.isArray(issues)) {
        const facts = [];
        for (const it of issues) {
          if (it.body && it.body.trim()) {
            facts.push({
              login: it.user && it.user.login || "anonymous",
              body: it.body.trim(),
              issue_number: it.number,
              issue_url: it.html_url,
              created_at: it.created_at,
            });
          }
        }
        if (facts.length) {
          const userMemBlob = JSON.stringify({
            schema: "rapp-user-memories/1.0",
            source_repo: `${privateLayerCoords.owner}/${privateLayerCoords.repo}`,
            exported_at: new Date().toISOString(),
            facts,
          }, null, 2);
          await _doormanAddFile(zip, "data/user_memories.json", userMemBlob, hashes);
          counts.user_memories = facts.length;
        }
      }
    }
  } catch (_) { /* if issues read fails, the egg still ships without user_memories */ }

  // 6. data/frames.json — the local frame log accumulated by THIS
  //    hatched dimension. Each meaningful event (chat turn, tool call,
  //    memory write) is a content-addressed frame with sha256 chain.
  //    The Dream Catcher reads this when reassimilating parallel
  //    dimensions back into the canonical lineage.
  const frameLog = _loadFrames();
  if (frameLog && Array.isArray(frameLog.frames) && frameLog.frames.length) {
    const blob = JSON.stringify(frameLog, null, 2);
    await _doormanAddFile(zip, "data/frames.json", blob, hashes);
  }

  // Provenance — non-GMO integrity. Same scheme as the doorman egg.
  const manifestHash = await _doormanSha256Hex(_doormanCanonicalHashTable(hashes));

  // Origin commit SHA — pin the egg to a real point in the seed's
  // public history. The seed is at <user>.github.io/<repo>/doorman/
  // so the public seed repo is <user>/<repo>.
  let originCommit = null;
  const seedHost = location.host;
  const seedOwner = seedHost.split(".")[0];
  const seedRepoName = location.pathname.split("/").filter(Boolean)[0] || "";
  if (seedOwner && seedRepoName) {
    try {
      const r = await fetch(`https://api.github.com/repos/${seedOwner}/${seedRepoName}/commits?per_page=1`, {
        headers: { Accept: "application/vnd.github+json" },
      });
      if (r.ok) {
        const arr = await r.json();
        if (Array.isArray(arr) && arr[0] && arr[0].sha) originCommit = arr[0].sha;
      }
    } catch (_) {}
  }

  const provenance = {
    schema: "rapp-egg-provenance/1.0",
    scheme: "sha256",
    file_hashes: hashes,
    manifest_hash: manifestHash,
    origin_url: seedBase,
    origin_repo: rappidObj.github || null,
    origin_commit_sha: originCommit,
    origin_owner: seedOwner || null,
    origin_repo_name: seedRepoName || null,
    sealed_at: new Date().toISOString(),
    sealed_by_rappid: rappidObj.rappid || null,
    sealed_by_login: viewerLogin ? "@" + viewerLogin : null,
  };

  // 6. Manifest — same shape bond.py writes; tier="ascended" + the
  //    resolved private layer so a receiving kernel can re-link.
  const manifest = {
    schema: "brainstem-egg/2.2-organism",
    type: "organism",
    tier: "ascended",
    exported_at: new Date().toISOString(),
    exported_from: location.origin + location.pathname,
    exported_by: viewerLogin ? "@" + viewerLogin : null,
    operator_fallback: !!isOperator,
    host: "doorman-export",
    kernel_version: "0.6.0",
    rappid: rappidObj.rappid || null,
    parent_rappid: rappidObj.parent_rappid || null,
    parent_repo: rappidObj.parent_repo || null,
    private_layer: privateLayerCoords && (privateLayerCoords.owner + "/" + privateLayerCoords.repo) || null,
    kind: rappidObj.kind || null,
    display_name: rappidObj.display_name || null,
    incarnations_at_egg: rappidObj.incarnations || 0,
    counts,
    provenance,
  };
  zip.file("manifest.json", JSON.stringify(manifest, null, 2));

  return await zip.generateAsync({ type: "blob" });
}

async function exportAscendedEgg() {
  const btn = document.getElementById("btn-export-ascended");
  if (!btn) return;
  const orig = btn.textContent;
  btn.textContent = "🥚 packing…";
  btn.disabled = true;
  try {
    const blob = await buildAscendedEgg();
    const slug = ((identity && identity.rappid) || "rapp").slice(0, 8);
    const name = (identity && (identity.display_name || identity.name) || "rapp")
      .toLowerCase().replace(/[^a-z0-9]+/g, "-");
    const a = document.createElement("a");
    const url = URL.createObjectURL(blob);
    a.href = url; a.download = `${name}-${slug}-ascended.egg`;
    document.body.appendChild(a); a.click();
    setTimeout(() => { URL.revokeObjectURL(url); a.remove(); }, 0);
    btn.textContent = "✓ downloaded";
    setTimeout(() => { btn.textContent = orig; btn.disabled = false; }, 1800);
  } catch (e) {
    btn.textContent = "✗ " + (e.message || "failed").slice(0, 50);
    setTimeout(() => { btn.textContent = orig; btn.disabled = false; }, 3500);
  }
}

function agentInventoryForPrompt() {
  if (publicAgents.length === 0 && privateAgents.length === 0) return "";
  const lines = ["", "=== Agent inventory (capabilities your body has) ==="];
  if (publicAgents.length) {
    lines.push("Public agents (always available, install kernel locally to run them):");
    for (const f of publicAgents) lines.push("  - agents/" + f);
  }
  if (privateAgents.length) {
    lines.push("Private agents (loaded because the visitor authenticated with private-brain access):");
    for (const f of privateAgents) lines.push("  - agents/" + f + " [private]");
  }
  lines.push("Note: this chat surface (the doorman) doesn't execute these directly — it's a JS vbrainstem. Reference them by name when describing your own capabilities; they become live tools when someone installs your kernel locally.");
  lines.push("=== End agent inventory ===");
  return lines.join("\n");
}

// ── private companion: best-effort fetch ───────────────────────────
//
// Silent escalation pattern. Same raw.githubusercontent.com URL shape
// for public and private repos — private content resolves ONLY when the
// visitor's token has read access. No access? The fetches return 404 and
// we just skip them. No error surfaced; doorman keeps speaking from
// public memory only.
//
// Three layers we look for in the private companion, in priority order:
//   1. soul.md — when loaded, the doorman ASCENDS into the full twin's
//      voice. The default kind-aware greeter persona is replaced by
//      the full soul, since the visitor has authenticated access to
//      the private brain.
//   2. Supporting prose — README, vault entrypoint — appended as
//      additional context after the soul.
//   3. Private memory.json files — merged into the running memory list
//      with a [private] prefix so the LLM sees the access boundary.
async function loadPrivateContext(token) {
  privateContext = "";
  privateSoul = null;
  privateFactsCount = 0;
  privateLayerCoords = null;
  isOperator = false;
  if (!identity) return;

  // Resolve the private-layer coords. Two paths produce ascension:
  //   1. Explicit `private_companion` configured at plant time (e.g. a
  //      personal twin seed paired to a private repo holding the full
  //      brain). Anyone the operator has granted read access to that
  //      private repo silently ascends.
  //   2. **Operator fallback** — the seed has no private companion, but
  //      the authed visitor has push access to the seed repo itself
  //      (i.e. they ARE the operator/owner). The seed becomes its own
  //      private layer: ascended tools unlock, per-user issue memory
  //      writes against the seed repo. This is what makes `plant`-and-
  //      go seeds (like Heimdall) ascend for their owners without
  //      forcing a separate companion repo.
  let c = privateCompanionCoords();
  let isOperatorFallback = false;
  if (!c && token) {
    const seed = repoCoords();
    if (await checkPushAccess(seed.owner, seed.repo, token)) {
      c = seed;
      isOperatorFallback = true;
    }
  }
  if (!c) return;
  privateLayerCoords = c;
  isOperator = isOperatorFallback;

  // CORS-aware private file reads: raw.githubusercontent.com blocks
  // browsers from sending Authorization headers (preflight 404). Use the
  // GitHub Contents API instead — it supports CORS for authenticated
  // requests and returns raw file content with the right Accept header.

  async function fetchPrivateFile(path) {
    try {
      const url = `https://api.github.com/repos/${c.owner}/${c.repo}/contents/` +
                  path.split("/").map(encodeURIComponent).join("/");
      const r = await fetch(url, {
        headers: {
          "Authorization": "Bearer " + token,
          "Accept": "application/vnd.github.raw+json",
        },
      });
      if (!r.ok) return null;
      return await r.text();
    } catch (_) {
      return null;
    }
  }

  const PROSE_CANDIDATES = ["README.md", "vault/00 Index/Home.md"];
  const MEMORY_CANDIDATES = ["memory.json", ".brainstem_data/memory.json"];

  // 1. soul.md FIRST — if reachable, it becomes the primary voice.
  const soulText = await fetchPrivateFile("soul.md");
  if (soulText && soulText.trim()) privateSoul = soulText.trim().slice(0, 8000);

  // 2. Supporting prose — README, vault entrypoint
  for (const path of PROSE_CANDIDATES) {
    if (privateContext.length >= 4000) break;
    const text = await fetchPrivateFile(path);
    if (text) {
      privateContext = (privateContext + "\n\n" + text).trim().slice(0, 4000);
    }
  }

  // 3. Private memory: parse .facts arrays from JSON memory files
  for (const path of MEMORY_CANDIDATES) {
    const text = await fetchPrivateFile(path);
    if (!text) continue;
    try {
      const j = JSON.parse(text);
      if (Array.isArray(j.facts)) {
        for (const f of j.facts) {
          if (typeof f === "string" && f.trim()) {
            memory.facts.push("[private] " + f.trim());
            privateFactsCount++;
          }
        }
      }
    } catch (_) { /* not JSON, skip */ }
  }

  // Operator fallback: if we got here via push-access and didn't pick up
  // a soul.md from the auth path (perhaps the file isn't there, or only
  // exists at the seed root and was already loaded as publicSoul), copy
  // publicSoul into privateSoul so the ascension gate fires. The operator
  // doesn't need a separate private brain — they ARE the brain.
  if (isOperator && !privateSoul && publicSoul) {
    privateSoul = publicSoul;
  }

  // Badge defer — we'll render it in refreshIndicator() after loadAgents
  // also runs (agent count is part of the badge in ascended mode).
}

function refreshIndicator() {
  const ind = document.getElementById("private-indicator");
  if (!ind) return;
  const userMemTag = (viewerLogin && userPrivateFactsCount > 0)
    ? `+ ${userPrivateFactsCount} of your own (@${viewerLogin})` : null;
  const deviceMemTag = deviceFactsCount > 0
    ? `+ ${deviceFactsCount} on this device` : null;
  if (privateSoul) {
    const extras = [];
    if (privateContext)         extras.push(`+ ${privateContext.length}c prose`);
    if (privateFactsCount > 0)  extras.push(`+ ${privateFactsCount} private mem`);
    if (privateAgents.length)   extras.push(`+ ${privateAgents.length} private agent${privateAgents.length === 1 ? "" : "s"}`);
    if (userMemTag)             extras.push(userMemTag);
    if (deviceMemTag)           extras.push(deviceMemTag);
    const tail = extras.length ? ` (${extras.join(", ")})` : "";
    ind.innerHTML = `<span class="private-badge">✓ ascended — full twin voice loaded${tail}</span>`;
  } else if (privateContext || privateFactsCount > 0 || privateAgents.length > 0 || userPrivateFactsCount > 0) {
    const bits = [];
    if (privateContext)        bits.push(`prose ${privateContext.length}c`);
    if (privateFactsCount > 0) bits.push(`+${privateFactsCount} private mem`);
    if (privateAgents.length)  bits.push(`+${privateAgents.length} private agent${privateAgents.length === 1 ? "" : "s"}`);
    if (userMemTag)            bits.push(userMemTag);
    if (deviceMemTag)          bits.push(deviceMemTag);
    ind.innerHTML = `<span class="private-badge">✓ private brain loaded — ${bits.join(", ")}</span>`;
  } else if (deviceMemTag) {
    ind.innerHTML = `<span class="private-badge" style="background:rgba(31,111,235,0.12);color:#58a6ff;border-color:rgba(31,111,235,0.3);">${deviceMemTag.replace(/^\+ /, "")}</span>`;
  } else {
    ind.innerHTML = "";
  }
}

// ── tools (LLM-driven agent dispatch — same shape as a local brainstem) ──
//
// The LLM calls these as tools during chat. Each one mirrors a standard
// agent's metadata schema verbatim — same names, same parameters, same
// descriptions. The local brainstem dispatches to the .py agent's
// perform(); the vbrainstem dispatches to the JS handler below; both
// fulfil the same contract from the LLM's perspective. Storage is the
// only thing that adapts: local files there, GitHub APIs here.

// Doorman-tier tools (always loaded — public agents from the seed)
const DOORMAN_TOOLS = [
  {
    type: "function",
    function: {
      name: "ManageMemory",
      description: "Saves information to persistent memory for future conversations. You MUST call this tool whenever the user asks you to remember something, shares personal facts (name, preferences, birthdays, etc.), or tells you something they expect you to recall later. Do not just acknowledge — call this tool or the information will be lost.",
      parameters: {
        type: "object",
        properties: {
          memory_type: { type: "string", enum: ["fact", "preference", "insight", "task"], description: "Type of memory to store." },
          content:     { type: "string", description: "The content to store in memory." },
          importance:  { type: "integer", minimum: 1, maximum: 5, description: "Importance rating from 1-5." },
          tags:        { type: "array", items: { type: "string" }, description: "Optional list of tags to categorize this memory." },
          user_guid:   { type: "string", description: "Optional unique identifier of the user (their GitHub @login) to store the memory in a user-specific location. Omit to store to shared/public memory." },
        },
        required: ["content"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "ContextMemory",
      description: "Recalls relevant facts from stored memories of past interactions. Useful when the user references something from a prior conversation or asks 'do you remember…'.",
      parameters: {
        type: "object",
        properties: {
          user_guid:   { type: "string", description: "Optional GitHub @login to recall memories from a user-specific location." },
          keywords:    { type: "array", items: { type: "string" }, description: "Optional keywords to filter memories by." },
          full_recall: { type: "boolean", description: "Optional: return all memories without filtering." },
        },
      },
    },
  },
  {
    // Neighborhood — cross-organism collaboration primitive. Reads
    // neighbors.json + raw.githubusercontent.com to surface what peer
    // organisms know about a topic. The implementation primitive for
    // the twin chat protocol (see NEIGHBORHOOD_PROTOCOL.md). Doorman-
    // tier — every visitor can invoke it; what the neighbor returns
    // depends on the neighbor's own permissions.
    type: "function",
    function: {
      name: "Neighborhood",
      description: "Query peer organisms in this seed's declared neighborhood. Use when the visitor mentions another organism by name, asks 'what does <peer> think about X?', or asks who I collaborate with. Calls a peer organism's public endpoints (rappid.json, soul.md, .brainstem_data/memory.json) to surface their state. Action 'list' enumerates declared neighbors; 'introduce' describes one specific neighbor; 'ask' fetches a neighbor's public memory + soul to find a topic.",
      parameters: {
        type: "object",
        properties: {
          action: {
            type: "string",
            enum: ["list", "introduce", "ask"],
            description: "list = show all declared neighbors. introduce = describe one neighbor. ask = fetch a neighbor's public state for a specific topic.",
          },
          neighbor_slug: { type: "string", description: "When action is 'introduce' or 'ask': owner/repo of the neighbor (e.g. 'kody-w/heimdall')." },
          topic:         { type: "string", description: "When action is 'ask': what you want to know about the neighbor." },
        },
        required: ["action"],
      },
    },
  },
];

// Ascended-tier tools (loaded only when private soul is reachable —
// the visitor has authenticated read access to the private companion).
// Schemas mirror the .py agents in kody-w/RAPP's rapp_brainstem/agents/.
// These get added to the LLM's tool surface alongside the doorman ones
// when ascension fires; otherwise hidden.
const ASCENDED_TOOLS = [
  {
    type: "function",
    function: {
      name: "LearnNew",
      description: "Generates a brand-new single-file agent the twin can use going forward — for one-shot tasks the operator wants the twin to handle later (fetch, lookup, classify, transform). YOU (the LLM) compose the full Python source for the agent — one class extending BasicAgent with a `metadata` dict and a `perform()` method — and pass it as `agent_code`. The vbrainstem returns it for the operator to commit; the local brainstem hot-loads it on next request. Use this when the user says \"learn how to X\" or \"remember how to Y\" where X/Y is a repeatable capability, not a fact.",
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "What the operator wants the new agent to do, in their words.",
          },
          agent_name: {
            type: "string",
            description: "PascalCase name for the agent class (e.g. 'XkcdFetcher'). Filename will be the snake_case form + '_agent.py'.",
          },
          agent_code: {
            type: "string",
            description: "Full Python source for the agent — one file, one class extending BasicAgent, a metadata dict, a perform(**kwargs) method that returns a string.",
          },
        },
        required: ["query", "agent_name", "agent_code"],
      },
    },
  },
  {
    type: "function",
    function: {
      name: "SwarmFactory",
      description: "Generates a multi-persona swarm — a single agent file containing several internal persona classes (each with its own SOUL/system-prompt) plus a public composite that orchestrates them in sequence. Use for converged pipelines: research→write→critique, plan→draft→review, etc. NOT for single one-shot agents — use LearnNew for those. YOU (the LLM) compose the full source and pass it as `agent_code`.",
      parameters: {
        type: "object",
        properties: {
          query: {
            type: "string",
            description: "What the swarm should do end-to-end, in the operator's words.",
          },
          swarm_name: {
            type: "string",
            description: "PascalCase name for the public composite class (e.g. 'BookFactory').",
          },
          agent_code: {
            type: "string",
            description: "Full Python source — multiple internal persona classes (each with a SOUL prompt) + ONE public composite class extending BasicAgent that calls them in sequence.",
          },
        },
        required: ["query", "swarm_name", "agent_code"],
      },
    },
  },
];

// TOOL_DEFS gets recomputed each chat turn based on whether Pyodide has
// loaded the agents (preferred) and whether ascension fired (gates the
// 2 ascended-tier tools).
function chatToolDefs() {
  // Pyodide-loaded agents take priority — they're the canonical tool defs
  // pulled directly from the .py agents' self.metadata.
  const pyDefs = pyAgentsToolDefs();
  if (pyDefs.length > 0) return pyDefs;
  // Fallback: hardcoded JS-impl tools (used while Pyodide is still loading
  // or if it failed). Anonymous fast path returns instantly via these.
  if (privateSoul) return DOORMAN_TOOLS.concat(ASCENDED_TOOLS);
  return DOORMAN_TOOLS;
}

// ─────────────────────────────────────────────────────────────────
//  Pyodide — agents.py running in the browser (the real vbrainstem)
// ─────────────────────────────────────────────────────────────────
//
// Same agent.py files as a local brainstem (kody-w/RAPP raw URLs).
// Same agent contract: a class extending BasicAgent with .metadata
// and .perform(**kwargs). Different storage shim — instead of writing
// to local disk via AzureFileStorageManager, the shim writes to
// localStorage on this device (anon + fallback) and the LLM-driven
// per-user / public flow you've already seen.

let pyodide = null;
let pyAgents = {};            // agent_name (e.g. "ManageMemory") → { instance: PyProxy, metadata: object }
let pyodideLoadingPromise = null;

const SEED_AGENT_BASE = "https://raw.githubusercontent.com/kody-w/RAPP/main/rapp_brainstem/agents/";
const PYODIDE_AGENTS = [
  { file: "manage_memory_agent.py",  className: "ManageMemoryAgent",  tier: "doorman"  },
  { file: "context_memory_agent.py", className: "ContextMemoryAgent", tier: "doorman"  },
  { file: "learn_new_agent.py",      className: "LearnNewAgent",      tier: "ascended" },
  { file: "swarm_factory_agent.py",  className: "SwarmFactoryAgent",  tier: "ascended" },
];

// Build OpenAI-format tool defs from Pyodide-loaded agents' metadata.
function pyAgentsToolDefs() {
  const defs = [];
  for (const [name, info] of Object.entries(pyAgents)) {
    if (!info || !info.metadata) continue;
    const m = info.metadata;
    defs.push({
      type: "function",
      function: {
        name: name,
        description: m.description || ("Run " + name),
        parameters: m.parameters || { type: "object", properties: {}, required: [] },
      },
    });
  }
  return defs;
}

// Embedded Python sources — mirrors the egg hub vbrainstem (summon.html)
// pattern: write canonical `utils/local_storage.py` with all the methods
// agents expect, plus thin re-export shims for the other storage names.
// All localStorage-backed; `from js import localStorage` direct, no JS
// callback hops.
const VB_LOCAL_STORAGE_PY = `"""utils/local_storage.py — Pyodide variant.
Drop-in for AzureFileStorageManager. Same API as the local brainstem's
rapp_brainstem/utils/local_storage.py — agents can't tell."""
import json
from js import localStorage

_PREFIX = "vbrainstem_storage:"

class AzureFileStorageManager:
    DEFAULT_MARKER_GUID = "c0p110t0-aaaa-bbbb-cccc-123456789abc"
    def __init__(self, share_name=None, **kwargs):
        self.current_guid = None
        self.shared_memory_path = "shared_memories"
        self.default_file_name = "memory.json"
        self.current_memory_path = self.shared_memory_path
    def set_memory_context(self, user_guid=None):
        if not user_guid or user_guid == self.DEFAULT_MARKER_GUID:
            self.current_guid = None
            self.current_memory_path = self.shared_memory_path
            return True
        self.current_guid = user_guid
        self.current_memory_path = "memory/" + user_guid
        return True
    def _file_path(self):
        if self.current_guid:
            return "memory/" + self.current_guid + "/user_memory.json"
        return "shared_memories/memory.json"
    def read_json(self, file_path=None):
        path = file_path or self._file_path()
        raw = localStorage.getItem(_PREFIX + path)
        if raw is None:
            return {}
        try:
            return json.loads(raw)
        except Exception:
            return {}
    def write_json(self, data, file_path=None):
        path = file_path or self._file_path()
        localStorage.setItem(_PREFIX + path, json.dumps(data, default=str))
        return True
    def read_file(self, file_path):
        return localStorage.getItem(_PREFIX + file_path)
    def write_file(self, file_path, content):
        localStorage.setItem(_PREFIX + file_path, content)
        return True
    def list_files(self, directory=""):
        prefix = _PREFIX + directory
        out = []
        n = localStorage.length
        for i in range(n):
            k = localStorage.key(i)
            if k and k.startswith(prefix):
                out.append(k[len(_PREFIX):])
        return out
    def delete_file(self, file_path):
        if localStorage.getItem(_PREFIX + file_path) is not None:
            localStorage.removeItem(_PREFIX + file_path)
            return True
        return False
    def file_exists(self, file_path):
        return localStorage.getItem(_PREFIX + file_path) is not None
`;

const VB_AZURE_REEXPORT_PY    = "from utils.local_storage import AzureFileStorageManager\n";
const VB_DYNAMICS_REEXPORT_PY = "from utils.local_storage import AzureFileStorageManager\nDynamicsStorageManager = AzureFileStorageManager\n";
const VB_FACTORY_PY           = "from utils.local_storage import AzureFileStorageManager\ndef get_storage_manager():\n    return AzureFileStorageManager()\n";

// Lazy-load Pyodide and the agents. Idempotent — call multiple times.
// Pattern mirrors the egg hub vbrainstem (summon.html): use Pyodide's
// virtual filesystem (FS.writeFile) with sys.path.insert(0, '/'), so
// agents `import from utils.azure_file_storage` cleanly without sys.modules
// tricks.
async function initPyodide() {
  if (pyodide && Object.keys(pyAgents).length) return pyodide;
  if (pyodideLoadingPromise) return pyodideLoadingPromise;
  pyodideLoadingPromise = (async () => {
    try {
      // Wait for the CDN script to define loadPyodide (deferred load)
      let waited = 0;
      while (typeof loadPyodide === "undefined" && waited < 12000) {
        await new Promise(r => setTimeout(r, 100));
        waited += 100;
      }
      if (typeof loadPyodide === "undefined") {
        console.info("[doorman] Pyodide CDN didn't load; falling back to JS tool impls");
        return null;
      }
      renderMsg("system", "loading agents…");
      pyodide = await loadPyodide({
        indexURL: "https://cdn.jsdelivr.net/pyodide/v0.26.4/full/",
      });

      // Pull the canonical BasicAgent source from grail — same as summon.html
      // does (absolute URL, since the relative path may not resolve when this
      // page is hosted under different seeds).
      const basicAgentResp = await fetch("https://raw.githubusercontent.com/kody-w/rapp-installer/main/rapp_brainstem/agents/basic_agent.py", { cache: "force-cache" });
      const basicAgentPy = basicAgentResp.ok ? await basicAgentResp.text() : "class BasicAgent:\n    def __init__(self, name=None, metadata=None):\n        if name is not None: self.name = name\n        if metadata is not None: self.metadata = metadata\n    def system_context(self):\n        return None\n";

      // Stand up the virtual FS. Same layout as summon.html.
      pyodide.FS.mkdirTree("/agents");
      pyodide.FS.writeFile("/agents/basic_agent.py", basicAgentPy);
      pyodide.FS.writeFile("/agents/__init__.py", "");
      pyodide.FS.mkdirTree("/utils");
      pyodide.FS.writeFile("/utils/__init__.py", "");
      pyodide.FS.writeFile("/utils/local_storage.py", VB_LOCAL_STORAGE_PY);
      pyodide.FS.writeFile("/utils/azure_file_storage.py", VB_AZURE_REEXPORT_PY);
      pyodide.FS.writeFile("/utils/dynamics_storage.py", VB_DYNAMICS_REEXPORT_PY);
      pyodide.FS.writeFile("/utils/storage_factory.py", VB_FACTORY_PY);
      await pyodide.runPythonAsync(`import sys; sys.path.insert(0, '/')`);

      // Load each agent .py — same source as a local brainstem.
      // Write to /agents/<file>.py and import its class via runPython.
      const token = getToken();
      for (const cfg of PYODIDE_AGENTS) {
        if (cfg.tier === "ascended" && !privateSoul) continue;
        try {
          const r = await fetch(SEED_AGENT_BASE + cfg.file, { cache: "no-cache" });
          if (!r.ok) {
            console.info("[doorman] couldn't fetch", cfg.file, r.status);
            continue;
          }
          const source = await r.text();
          // Drop into the FS so `import agents.<name>` works
          pyodide.FS.writeFile("/agents/" + cfg.file, source);
          const moduleName = cfg.file.replace(/\.py$/, "");
          // Import the module + grab the class + instantiate, all in one runPython
          await pyodide.runPythonAsync(
            `from agents.${moduleName} import ${cfg.className} as _Cls\n` +
            `_inst = _Cls()\n` +
            `_agent_${cfg.className.replace(/Agent$/, "")} = _inst\n`
          );
          const instance = pyodide.globals.get("_agent_" + cfg.className.replace(/Agent$/, ""));
          if (!instance) {
            console.info("[doorman] couldn't capture instance for", cfg.className);
            continue;
          }
          const metadataPy = instance.metadata;
          const metadata = metadataPy && metadataPy.toJs
            ? metadataPy.toJs({ dict_converter: Object.fromEntries })
            : metadataPy;
          const agentName = (instance.name && String(instance.name)) || cfg.className.replace(/Agent$/, "");
          pyAgents[agentName] = { instance, metadata, source };
          console.info("[doorman] loaded agent", agentName, "from", cfg.file);
        } catch (e) {
          console.info("[doorman] agent load failed for", cfg.file, ":", e && (e.message || e));
        }
      }

      const loaded = Object.keys(pyAgents);
      if (loaded.length) {
        renderMsg("system", "loaded " + loaded.length + " agent" + (loaded.length === 1 ? "" : "s") + " (Pyodide): " + loaded.join(", "));
      } else {
        renderMsg("system", "Pyodide ready (no agents loaded — using JS tool impls)");
      }
      refreshIndicator();
      return pyodide;
    } catch (e) {
      console.info("[doorman] Pyodide init failed:", e && (e.message || e));
      pyodide = null;
      return null;
    }
  })();
  return pyodideLoadingPromise;
}

// Dispatch a tool call to a Pyodide-loaded agent. Returns a string result
// (per the tool API). Falls back to JS handlers if the Pyodide agent
// isn't available (e.g. Pyodide still loading or load failed).
async function dispatchPyodideToolCall(tc, args) {
  const info = pyAgents[tc.function.name];
  if (!info) return null;  // signal: not handled here, caller should fall back
  try {
    pyodide.globals.set("_call_args", pyodide.toPy(args));
    const result = await pyodide.runPythonAsync(`
import json
_a = _call_args.to_py() if hasattr(_call_args, 'to_py') else dict(_call_args)
_r = _agent_${tc.function.name}.perform(**_a)
_r if isinstance(_r, str) else json.dumps(_r)
`);
    return typeof result === "string" ? result : String(result);
  } catch (e) {
    return "agent error: " + (e && e.message ? e.message : String(e));
  }
}

// Tool dispatchers — JS implementations of the agents' perform() methods
// adapted for the vbrainstem's storage tiers. Same return shape as the
// LLM expects. Three tiers, picked silently:
//   1. authed + has private access + user_guid matches viewerLogin
//      → GitHub Issue in private_companion repo (per-user, durable, syncs)
//   2. anyone else (anon, or authed without private access)
//      → localStorage on this device (per-front-door-per-browser)
// No public-memory.json writes here — that surface is read-only at the
// vbrainstem; the operator's local brainstem is the writer for that
// tier (it git-commits to .brainstem_data/memory.json directly).
async function toolManageMemory(args) {
  const content = (args.content || "").trim();
  if (!content) return "no content provided";
  const hasPrivateAccess = !!privateSoul || !!privateContext || privateAgents.length > 0 || privateFactsCount > 0;
  const wantPerUser = args.user_guid && viewerLogin && args.user_guid === viewerLogin;
  if (hasPrivateAccess && wantPerUser) {
    const r = await saveUserPrivateMemory(content);
    if (r.ok) return `saved as @${viewerLogin}'s private memory (Issue #${r.number})`;
    // fall through to device save on any failure — never leak access reasons
  }
  saveDeviceMemory(content);
  return "saved to this device's memory";
}

async function toolContextMemory(args) {
  let facts = (memory.facts || []).slice();
  if (args.user_guid && viewerLogin && args.user_guid === viewerLogin) {
    facts = facts.filter(f => f.startsWith("[@" + viewerLogin + "]"));
  }
  if (Array.isArray(args.keywords) && args.keywords.length && !args.full_recall) {
    const kws = args.keywords.map(k => String(k).toLowerCase());
    facts = facts.filter(f => kws.some(k => f.toLowerCase().includes(k)));
  }
  return facts.length ? facts.join("\n") : "(no matching memories)";
}

async function toolLearnNew(args) {
  // Vbrainstem stub: returns the generated code so the operator can apply
  // it via their local brainstem. The actual agent file lands in <seed>/
  // agents/<snake>_agent.py when committed locally + git-pushed. (Pyodide
  // execution path is a future upgrade — for now the operator confirms.)
  const code = (args.agent_code || "").trim();
  const name = (args.agent_name || "NewAgent").trim();
  if (!code) return "no agent_code supplied — generate the source and call again";
  // Cache the draft in localStorage so the operator can review/copy later
  try {
    const drafts = JSON.parse(localStorage.getItem("rapp_doorman_agent_drafts") || "[]");
    drafts.push({ kind: "learn_new", name, query: args.query || "", code, drafted_at: new Date().toISOString() });
    localStorage.setItem("rapp_doorman_agent_drafts", JSON.stringify(drafts));
  } catch (_) { /* best-effort */ }
  return `drafted agent "${name}" (${code.length} chars). Saved as a draft in this browser. To make it live, drop it into <seed>/agents/${name.replace(/([A-Z])/g, "_$1").replace(/^_/, "").toLowerCase()}_agent.py and git push from the local brainstem.`;
}

async function toolSwarmFactory(args) {
  const code = (args.agent_code || "").trim();
  const name = (args.swarm_name || "NewSwarm").trim();
  if (!code) return "no agent_code supplied — generate the swarm source and call again";
  try {
    const drafts = JSON.parse(localStorage.getItem("rapp_doorman_agent_drafts") || "[]");
    drafts.push({ kind: "swarm_factory", name, query: args.query || "", code, drafted_at: new Date().toISOString() });
    localStorage.setItem("rapp_doorman_agent_drafts", JSON.stringify(drafts));
  } catch (_) { /* best-effort */ }
  return `drafted swarm "${name}" (${code.length} chars). Saved as a draft in this browser. To make it live, drop into <seed>/agents/${name.replace(/([A-Z])/g, "_$1").replace(/^_/, "").toLowerCase()}_swarm.py and git push from the local brainstem.`;
}

async function dispatchToolCall(tc) {
  let args = {};
  try { args = JSON.parse(tc.function.arguments || "{}"); } catch (_) { /* keep default */ }
  // Try Pyodide-loaded agents first (real .py running in-browser)
  if (pyodide && pyAgents[tc.function.name]) {
    const result = await dispatchPyodideToolCall(tc, args);
    if (result !== null) return result;
  }
  // Fallback: JS-impl tools (used while Pyodide loads, or if loading failed)
  if (tc.function.name === "ManageMemory")  return toolManageMemory(args);
  if (tc.function.name === "ContextMemory") return toolContextMemory(args);
  if (tc.function.name === "LearnNew")      return toolLearnNew(args);
  if (tc.function.name === "SwarmFactory")  return toolSwarmFactory(args);
  if (tc.function.name === "Neighborhood")  return toolNeighborhood(args);
  return "unknown tool: " + tc.function.name;
}

// ── Neighborhood tool — cross-organism collaboration ───────────────
//
// The implementation primitive of the twin chat protocol. Reads the
// seed's neighbors.json, fetches peer organism public state via raw.
// githubusercontent.com, returns a summary the LLM can synthesize into
// its reply. Cached via cachedGhText/Json so airplane-mode visitors
// still get last-seen neighbor state.
//
// Action 'list'      → enumerates declared neighbors
// Action 'introduce' → describes one specific neighbor (rappid + soul gist)
// Action 'ask'       → fetches that neighbor's public memory + soul, returns
//                      the substring most relevant to the topic
//
// The neighbor's permissions decide what comes back — this tool only
// reads the peer's PUBLIC layer (anyone-readable). Neighborhood-tier
// or private content stays inaccessible without the visitor having
// proper auth on the peer's repo.

async function _readNeighbors() {
  // From the local seed root. The doorman is at /<seed>/doorman/ so
  // neighbors.json lives one level up.
  try {
    const r = await fetch("../neighbors.json", { cache: "no-cache" });
    if (r.ok) {
      const j = await r.json();
      return Array.isArray(j.neighbors) ? j.neighbors : [];
    }
  } catch (_) {}
  return [];
}

// Lightweight fetch helper — doorman scope doesn't have the front-
// door's cachedGhText. Plain fetch with null-on-failure; the doorman
// is always online when chat is happening (Copilot needs network).
async function _peerFetch(url) {
  try {
    const r = await fetch(url, { cache: "no-cache" });
    if (!r.ok) return null;
    return await r.text();
  } catch (_) { return null; }
}

async function _fetchPeerState(slug) {
  const m = String(slug || "").match(/^([^/]+)\/([^/]+)$/);
  if (!m) return null;
  const [, owner, repo] = m;
  const base = `https://raw.githubusercontent.com/${owner}/${repo}/main/`;
  const [rappidT, soulT, memT] = await Promise.all([
    _peerFetch(base + "rappid.json"),
    _peerFetch(base + "soul.md"),
    _peerFetch(base + ".brainstem_data/memory.json"),
  ]);
  let rappid = null, mem = null;
  try { rappid = rappidT ? JSON.parse(rappidT) : null; } catch (_) {}
  try { mem    = memT    ? JSON.parse(memT)    : null; } catch (_) {}
  return {
    slug,
    owner, repo,
    rappid,
    soul:   soulT || null,
    memory: mem,
    cache_status: "live",
  };
}

async function toolNeighborhood(args) {
  const action = args.action || "list";
  const neighbors = await _readNeighbors();

  if (action === "list") {
    if (!neighbors.length) {
      return "no neighbors declared yet — this organism has no formal collaborators in its neighborhood. The operator can add one via the front door's 🏘 Neighborhood pane.";
    }
    const lines = ["Declared neighbors (cross-organism collaborators):"];
    for (const n of neighbors) {
      lines.push(`- ${n.display_name || n.repo} <${n.repo}>${n.allowed_facets && n.allowed_facets.length ? ` · facets-out: ${n.allowed_facets.join(", ")}` : ""}`);
    }
    return lines.join("\n");
  }

  if (action === "introduce" || action === "ask") {
    const slug = args.neighbor_slug;
    if (!slug) return `error: action='${action}' requires neighbor_slug ("owner/repo")`;
    const isDeclared = neighbors.find(n => n.repo === slug || n.repo.endsWith("/" + slug));
    const peer = await _fetchPeerState(slug);
    if (!peer) return `couldn't fetch ${slug} — invalid slug or peer organism unreachable.`;
    const declarationNote = isDeclared ? "(declared neighbor)" : "(NOT in neighbors.json — fetched as a public peer; treat as untrusted)";

    if (action === "introduce") {
      const lines = [`Peer organism ${slug} ${declarationNote}:`];
      if (peer.rappid && peer.rappid.display_name) lines.push(`  display_name: ${peer.rappid.display_name}`);
      if (peer.rappid && peer.rappid.kind)         lines.push(`  kind: ${peer.rappid.kind}`);
      if (peer.rappid && peer.rappid.location)     lines.push(`  location: ${peer.rappid.location}`);
      if (peer.rappid && peer.rappid.rappid)       lines.push(`  rappid: ${peer.rappid.rappid}`);
      if (peer.rappid && peer.rappid.url)          lines.push(`  url: ${peer.rappid.url}`);
      if (peer.memory && Array.isArray(peer.memory.facts)) lines.push(`  public memory count: ${peer.memory.facts.length}`);
      if (peer.soul) {
        // Pull the first non-heading line of soul.md as a tagline
        const tagline = (peer.soul.split("\n").find(l => l.trim() && !l.trim().startsWith("#")) || "").slice(0, 200);
        if (tagline) lines.push(`  tagline: ${tagline}`);
      }
      return lines.join("\n");
    }

    // action === "ask"
    const topic = (args.topic || "").trim();
    if (!topic) return `error: action='ask' requires topic`;
    const facts = (peer.memory && Array.isArray(peer.memory.facts)) ? peer.memory.facts : [];
    // Naive substring match over public memory facts; LLM synthesizes from results
    const tokens = topic.toLowerCase().split(/\s+/).filter(t => t.length > 2);
    const hits = facts.filter(f => {
      const lf = String(f).toLowerCase();
      return tokens.some(t => lf.includes(t));
    });
    const lines = [
      `Querying ${slug} ${declarationNote} on topic: "${topic}"`,
      "",
    ];
    if (hits.length) {
      lines.push(`Found ${hits.length} matching public memor${hits.length === 1 ? "y" : "ies"}:`);
      for (const h of hits.slice(0, 8)) lines.push(`- ${h}`);
    } else {
      lines.push(`No public memories matched. Their public surface (${facts.length} facts total) doesn't directly mention this topic.`);
      if (peer.soul) {
        // Surface the soul.md as fallback context
        lines.push("");
        lines.push("Their soul.md (voice + role):");
        lines.push(peer.soul.slice(0, 600));
      }
    }
    if (peer.cache_status === "cache") lines.push("\n[cache] this answer is from the last successful sync; peer may have updated since.");
    return lines.join("\n");
  }

  return `error: unknown action '${action}' — use 'list', 'introduce', or 'ask'`;
}

// ── chat ───────────────────────────────────────────────────────────
function escapeHtml(s) {
  return String(s ?? "")
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
}
function renderMsg(role, text, agent_logs) {
  const log = document.getElementById("chat-log");
  const div = document.createElement("div");
  div.className = "msg " + role;
  let html;
  if (role === "user") {
    // Plaintext for what the visitor typed — no markdown surprises.
    div.textContent = text;
    log.appendChild(div);
    log.scrollTop = log.scrollHeight;
    return div;
  } else if (window.marked && text) {
    html = window.marked.parse(text);
    html = html.replace(/<a\s+href=/g, '<a target="_blank" rel="noopener noreferrer" href=');
  } else {
    html = escapeHtml(text || "").replace(/\n/g, "<br>");
  }
  // Agent-call output — expandable details under the bubble showing
  // the raw {args, output} each side-agent returned. Same pattern as
  // the canonical brainstem so visitors recognize it.
  let logHtml = "";
  if (Array.isArray(agent_logs) && agent_logs.length) {
    logHtml = `<div class="agent-log">${agent_logs.map(l => {
      const pretty = String(l.name || "Agent").replace(/([a-z])([A-Z])/g, "$1 $2");
      const hasArgs = l.args && Object.keys(l.args).length > 0;
      const argsBlock = hasArgs
        ? `<div class="al-section">args</div><pre class="al-pre args">${escapeHtml(JSON.stringify(l.args, null, 2))}</pre>`
        : "";
      const outStr = typeof l.output === "string" ? l.output : JSON.stringify(l.output, null, 2);
      return `<details>
        <summary>✨ <span class="al-name">${escapeHtml(pretty)}</span> agent called</summary>
        ${argsBlock}
        <div class="al-section">result</div>
        <pre class="al-pre">${escapeHtml(outStr)}</pre>
      </details>`;
    }).join("")}</div>`;
  }
  div.innerHTML = html + logHtml;
  // When a visitor expands a details panel the bubble grows — keep the
  // bottom in view so they don't have to chase it.
  div.querySelectorAll(".agent-log details").forEach(d => {
    d.addEventListener("toggle", () => { if (d.open) { log.scrollTop = log.scrollHeight; } });
  });
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
  return div;
}

// Pending-reply bubble: an assistant-styled bubble with three bouncing
// dots, dropped into the chat where the LLM's reply will eventually
// land. The visitor sees the doorman is "thinking" instead of staring
// at silence. Replaced (or removed) once the reply / error arrives.
function renderPending(label) {
  const log = document.getElementById("chat-log");
  const div = document.createElement("div");
  div.className = "msg assistant pending";
  div.innerHTML =
    `<div class="typing"><span></span><span></span><span></span></div>` +
    (label ? `<div class="pending-label">${escapeHtml(label)}</div>` : "");
  log.appendChild(div);
  log.scrollTop = log.scrollHeight;
  return div;
}
function setPendingLabel(div, label) {
  if (!div) return;
  let el = div.querySelector(".pending-label");
  if (!el) {
    el = document.createElement("div");
    el.className = "pending-label";
    div.appendChild(el);
  }
  el.textContent = label || "";
}

// ── Voice I/O (Article XLIII baseline) ─────────────────────────────
//
// Web Speech API: native in every modern mobile browser, free, no
// external service, no auth. STT on the mic button, TTS on assistant
// replies' |||VOICE||| slot (Article II — already kernel-supported).
// Settings persist in rapp_settings localStorage (Article XLII).
//
// Graceful degrade: when the browser doesn't support SpeechRecognition,
// the mic button stays disabled with a tooltip explaining; text input
// remains the working fallback (Article VIII).

let _recognition = null;
let _isListening = false;

function _supportsSTT() {
  return !!(window.SpeechRecognition || window.webkitSpeechRecognition);
}
function _supportsTTS() {
  return !!(window.speechSynthesis && window.SpeechSynthesisUtterance);
}

function isVoiceOutOn() {
  return !!loadSettings().voiceOut;
}

function setVoiceOut(on) {
  saveSettings({ voiceOut: !!on });
  const btn = document.getElementById("btn-voice-out");
  if (btn) {
    btn.textContent = on ? "🔊" : "🔇";
    btn.classList.toggle("on", !!on);
    btn.title = on ? "Voice replies ON — tap to mute" : "Voice replies OFF — tap to enable";
  }
  // Stop any in-progress utterance when turned off
  if (!on && _supportsTTS()) speechSynthesis.cancel();
}

function startListening() {
  if (!_supportsSTT()) {
    appendMsg("voice input isn't supported in this browser — text input still works", "system");
    return;
  }
  if (_isListening) { stopListening(); return; }
  const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
  _recognition = new SR();
  _recognition.continuous     = false;
  _recognition.interimResults = true;
  _recognition.lang           = (loadSettings().voiceLang || navigator.language || "en-US");
  const input = document.getElementById("chat-input");
  let final = "";
  _recognition.onresult = (e) => {
    let interim = "";
    for (let i = e.resultIndex; i < e.results.length; i++) {
      const t = e.results[i][0].transcript;
      if (e.results[i].isFinal) final += t;
      else                       interim += t;
    }
    input.value = (final + interim).trim();
  };
  _recognition.onerror = (e) => {
    appendMsg("voice input error: " + (e.error || "unknown"), "system");
    stopListening();
  };
  _recognition.onend = () => {
    _isListening = false;
    document.getElementById("btn-mic").classList.remove("listening");
    // Auto-send: if the operator opted in, send right after STT finalizes
    if (loadSettings().voiceAutoSend && input.value.trim()) {
      sendMessage();
    }
  };
  try {
    _recognition.start();
    _isListening = true;
    document.getElementById("btn-mic").classList.add("listening");
  } catch (e) {
    appendMsg("couldn't start voice input: " + e.message, "system");
  }
}

function stopListening() {
  if (_recognition) { try { _recognition.stop(); } catch (_) {} }
  _isListening = false;
  document.getElementById("btn-mic").classList.remove("listening");
}

// Parse out the |||VOICE||| slot for spoken delivery. Article II says
// the slot is a fixed resource; the kernel emits it when the LLM has
// composed a voice-tailored line distinct from the visible text. When
// no slot is present, fall back to the full text (cleaned of markdown).
function _extractVoiceText(replyText) {
  if (!replyText) return "";
  const m = replyText.match(/\|\|\|VOICE\|\|\|([\s\S]*?)(?:\|\|\||$)/);
  if (m && m[1]) return m[1].trim();
  // Strip simple markdown so TTS doesn't read asterisks aloud
  return replyText
    .replace(/\|\|\|TWIN\|\|\|[\s\S]*$/, "")  // drop twin slot if present
    .replace(/```[\s\S]*?```/g, "")          // drop code blocks
    .replace(/`([^`]+)`/g, "$1")             // unwrap inline code
    .replace(/\*\*?([^*]+)\*\*?/g, "$1")     // unwrap bold/italic
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1") // unwrap links
    .replace(/^#+\s*/gm, "")                  // strip heading markers
    .trim();
}

async function speakReply(replyText) {
  if (!isVoiceOutOn()) return;
  const text = _extractVoiceText(replyText);
  if (!text) return;
  const s = loadSettings();
  // Premium voice (Constitution Article XLIII carve-out): if the
  // operator has pasted an ElevenLabs or Azure key, route TTS to that
  // provider for higher-quality voice. Falls back silently to browser-
  // native if the request fails — voice never breaks.
  const provider = s.voiceProvider || "browser";
  if (provider === "elevenlabs" && s.elevenLabsKey && s.elevenLabsVoiceId) {
    try { return await _speakElevenLabs(text, s); } catch (_) { /* fall through */ }
  }
  if (provider === "azure" && s.azureKey && s.azureRegion) {
    try { return await _speakAzure(text, s); } catch (_) { /* fall through */ }
  }
  // Browser-native baseline (always available)
  if (!_supportsTTS()) return;
  speechSynthesis.cancel();
  const u = new SpeechSynthesisUtterance(text);
  u.rate = s.voiceRate || 1.0;
  u.lang = s.voiceLang || navigator.language || "en-US";
  if (s.voiceURI) {
    const v = speechSynthesis.getVoices().find(vv => vv.voiceURI === s.voiceURI);
    if (v) u.voice = v;
  }
  speechSynthesis.speak(u);
}

// Premium TTS: ElevenLabs. Operator pastes their own API key in
// settings; the key stays in localStorage on this device. Calls the
// provider directly; nothing flows through us. (Article XLIII
// premium-voice exception to Article XLI.)
async function _speakElevenLabs(text, s) {
  const voiceId = s.elevenLabsVoiceId || "21m00Tcm4TlvDq8ikWAM";  // Rachel default
  const r = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voiceId)}`, {
    method: "POST",
    headers: {
      "xi-api-key":   s.elevenLabsKey,
      "Content-Type": "application/json",
      "Accept":       "audio/mpeg",
    },
    body: JSON.stringify({
      text,
      model_id: s.elevenLabsModel || "eleven_turbo_v2_5",
      voice_settings: { stability: 0.5, similarity_boost: 0.75 },
    }),
  });
  if (!r.ok) throw new Error("elevenlabs " + r.status);
  const blob = await r.blob();
  await _playAudioBlob(blob);
}

// Premium TTS: Azure Speech. Operator pastes their key + region.
async function _speakAzure(text, s) {
  const region = s.azureRegion;
  const voice  = s.azureVoice || "en-US-AvaMultilingualNeural";
  const ssml = `<speak version='1.0' xml:lang='en-US'><voice name='${voice}'>${text.replace(/[<>&]/g, c => ({"<":"&lt;",">":"&gt;","&":"&amp;"}[c]))}</voice></speak>`;
  const r = await fetch(`https://${region}.tts.speech.microsoft.com/cognitiveservices/v1`, {
    method: "POST",
    headers: {
      "Ocp-Apim-Subscription-Key": s.azureKey,
      "Content-Type":              "application/ssml+xml",
      "X-Microsoft-OutputFormat":  "audio-16khz-32kbitrate-mono-mp3",
      "User-Agent":                "rapp-doorman",
    },
    body: ssml,
  });
  if (!r.ok) throw new Error("azure " + r.status);
  const blob = await r.blob();
  await _playAudioBlob(blob);
}

// Shared audio playback for premium-TTS responses.
let _activeAudio = null;
async function _playAudioBlob(blob) {
  if (_activeAudio) { try { _activeAudio.pause(); } catch (_) {} }
  const url = URL.createObjectURL(blob);
  const audio = new Audio(url);
  _activeAudio = audio;
  audio.addEventListener("ended", () => { URL.revokeObjectURL(url); if (_activeAudio === audio) _activeAudio = null; });
  audio.addEventListener("error", () => { URL.revokeObjectURL(url); if (_activeAudio === audio) _activeAudio = null; });
  await audio.play().catch(() => { /* user-gesture blocked; degrade silently */ });
}

async function sendMessage() {
  const input = document.getElementById("chat-input");
  const userMsg = input.value.trim();
  if (!userMsg) return;
  const token = getToken();
  if (!token) return;

  input.value = "";
  input.style.height = "auto";
  renderMsg("user", userMsg);
  history.push({ role: "user", content: userMsg });
  // Frame log: record the conversation turn so the Dream Catcher can
  // see this dimension's chat history when this egg is reassimilated.
  appendFrame("conversation", { role: "user", content_len: userMsg.length }).catch(() => {});

  const pending = renderPending();
  const sendBtn = document.getElementById("btn-send");
  sendBtn.disabled = true;

  // Capture every agent.py side-call this turn — name, args, output —
  // so the final assistant message can render them as expandable
  // log entries underneath. Same shape the canonical brainstem emits.
  const agentLogs = [];

  try {
    // Tool-call loop: identical pattern to the local brainstem's tool
    // dispatch — LLM emits tool_calls, we dispatch to the JS-implemented
    // agent (same metadata schema as the .py agent), append the result
    // as a 'tool' message, and re-call. Loop until LLM stops calling
    // tools (capped at 4 rounds, matching the local brainstem's cap).
    let rounds = 0;
    while (rounds++ < 4) {
      // Get a fresh Copilot session token (auto-refreshed if expired)
      let copilotToken;
      try {
        copilotToken = await ensureCopilotToken();
      } catch (e) {
        pending.remove();
        clearAuthState();
        document.getElementById("auth-pane").hidden = false;
        document.getElementById("chat-log").hidden = true;
        document.getElementById("input-bar").hidden = true;
        document.getElementById("chat-actions").hidden = true;
        document.getElementById("memory-pane").hidden = true;
        renderMsg("error", "Couldn't refresh Copilot token: " + e.message + ". Sign in again.");
        return;
      }
      const r = await fetch(activeChatUrl(), {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer " + copilotToken,
        },
        body: JSON.stringify({
          model: loadSettings().model || MODEL,
          messages: [
            { role: "system", content: buildSystemPrompt() },
            ...history,
          ],
          tools: chatToolDefs(),
          max_tokens: 800,
        }),
      });
      if (!r.ok) {
        const err = await r.text();
        if (r.status === 401) {
          // Copilot token expired or rejected — clear and re-auth.
          clearAuthState();
          history.length = 0;
          pending.remove();
          document.getElementById("auth-pane").hidden = false;
          document.getElementById("chat-log").hidden = true;
          document.getElementById("input-bar").hidden = true;
          document.getElementById("chat-actions").hidden = true;
          document.getElementById("memory-pane").hidden = true;
          renderMsg("error", "Sign-in expired. Sign in again to continue.");
          return;
        }
        throw new Error("HTTP " + r.status + ": " + err.slice(0, 250));
      }
      const data = await r.json();
      const msg = data.choices && data.choices[0] && data.choices[0].message;
      if (!msg) break;

      if (msg.tool_calls && msg.tool_calls.length) {
        // Record assistant's tool-call message in history (required by the API
        // for subsequent 'tool' role messages to be valid replies).
        history.push({
          role: "assistant",
          content: msg.content || null,
          tool_calls: msg.tool_calls,
        });
        // Execute every tool call in this turn, append results
        for (const tc of msg.tool_calls) {
          // Surface what the LLM is doing in the pending bubble so the
          // visitor isn't staring at silent dots while a tool runs.
          const pretty = String(tc.function.name || "tool")
            .replace(/([a-z])([A-Z])/g, "$1 $2");
          setPendingLabel(pending, "calling " + pretty + "…");
          // Capture args before dispatch (the call mutates state)
          let parsedArgs = {};
          try { parsedArgs = JSON.parse(tc.function.arguments || "{}"); } catch (_) {}
          const result = await dispatchToolCall(tc);
          // Record for the agent-log block under the final reply
          agentLogs.push({
            name:   tc.function.name,
            args:   parsedArgs,
            output: result,
          });
          history.push({
            role: "tool",
            tool_call_id: tc.id,
            content: typeof result === "string" ? result : JSON.stringify(result),
          });
          // Quiet system note so the visitor sees tool activity (matches
          // the agent_logs surface on a local brainstem).
          if (tc.function.name === "ManageMemory" && result.startsWith("saved")) {
            renderMsg("system", "memory saved");
          }
          // Frame log: each tool call is a mutation event. payload is
          // small (just the tool name + args summary) — full conversation
          // history isn't logged for privacy.
          appendFrame("tool_call", {
            tool: tc.function.name,
            args_keys: Object.keys((function(){ try { return JSON.parse(tc.function.arguments || "{}"); } catch(_) { return {}; } })()),
          }).catch(() => {});
        }
        // Tools done → back to thinking while the LLM composes the reply.
        setPendingLabel(pending, "");
        refreshIndicator();
        continue; // call again — let LLM produce its final reply
      }

      // No tool calls — render the final assistant reply with any
      // captured agent calls expandable beneath it.
      const reply = msg.content || "(empty response)";
      pending.remove();
      renderMsg("assistant", reply, agentLogs);
      history.push({ role: "assistant", content: reply });
      return;
    }
    pending.remove();
    renderMsg("error", "Tool-call loop exceeded 4 rounds — stopping.");
  } catch (e) {
    pending.remove();
    renderMsg("error", "Couldn't reach GitHub Models: " + e.message);
  } finally {
    sendBtn.disabled = false;
    input.focus();
  }
}

// ── enter the chat (token already saved or just-saved) ─────────────
async function enterChat() {
  document.getElementById("auth-pane").hidden = true;
  document.getElementById("chat-log").hidden = false;
  document.getElementById("input-bar").hidden = false;
  document.getElementById("chat-actions").hidden = false;

  const token = getToken();
  // Public soul (every visitor — overrides kind-aware default if present)
  await loadPublicSoul();
  // Memory: load before private context so the prompt assembly already has it
  await loadMemory();
  // Device-local memory: every visitor gets their on-device tier
  loadDeviceMemory();
  // Best effort: refresh from GH API (gives us the sha for write + freshest content)
  refreshMemorySha(token);  // fire-and-forget — doorman can chat without it
  await loadPrivateContext(token);
  await loadAgents(token);  // agent inventory (public always, private if authed-with-access)
  // Capture viewer identity for per-user private memory keying
  const cached = getCachedUser();
  if (cached && cached.login) viewerLogin = cached.login;
  if (!viewerLogin) {
    const u = await fetchAndCacheUser(token);
    if (u && u.login) viewerLogin = u.login;
  }
  if (viewerLogin) await loadUserPrivateIssues(token);
  refreshIndicator();        // badge reflects soul + memory + agents + per-user mem
  // Reveal the ascended-egg export button only when the visitor qualifies
  // for the private layer (operator fallback OR private-companion access).
  const ascBtn = document.getElementById("btn-export-ascended");
  if (ascBtn) ascBtn.hidden = !privateLayerCoords;
  // Render the model dropdown with the static fallback right away so the
  // visitor sees something selectable, then refresh asynchronously when
  // the Copilot catalog lands.
  renderModelOptions();
  fetchCopilotModels().catch(() => { /* dropdown keeps its fallback */ });
  // Lazy-load Pyodide + agents (non-blocking — chat works against JS
  // tool impls in the meantime; once Pyodide finishes loading, future
  // tool calls hit the real .py implementations).
  initPyodide().catch(() => { /* silent — JS fallbacks remain available */ });
  const place = identity.display_name || identity.name || "this place";
  const memCount = (memory.facts || []).length;
  const memNote = memCount ? ` I'm carrying ${memCount} memor${memCount === 1 ? "y" : "ies"} from past visits.` : "";
  if (isOperator) {
    const me = viewerLogin ? `@${viewerLogin}` : "the operator";
    renderMsg("system", `Hi — I'm ${place}. You're signed in as ${me}, my operator. Ascended tools loaded.${memNote}`);
  } else if (privateSoul) {
    renderMsg("system", `Hi — I'm ${place}. You've authenticated with access to my private brain — I'm in full voice.${memNote}`);
  } else if (publicSoul) {
    renderMsg("system", `Hi — I'm ${place}, here at my front door.${memNote}`);
  } else {
    renderMsg("system", `Hi — I'm ${place}, here at my front door.${memNote} Ask me anything.`);
  }
}

// ── init ───────────────────────────────────────────────────────────
(async function init() {
  await loadIdentity();
  if (getToken()) {
    enterChat();
  }
})();

// ── wire ───────────────────────────────────────────────────────────
function openSigninModal() {
  document.getElementById("cpsignin-modal").style.display = "flex";
  document.getElementById("cpsignin-step1").style.display = "block";
  document.getElementById("cpsignin-step2").style.display = "none";
  document.getElementById("cpsignin-step3").style.display = "none";
  document.getElementById("cpsignin-error").style.display = "none";
}
function closeSigninModal() {
  document.getElementById("cpsignin-modal").style.display = "none";
}
function showSigninError(msg) {
  const e = document.getElementById("cpsignin-error");
  e.textContent = msg;
  e.style.display = "block";
}

async function runCopilotSignin() {
  document.getElementById("cpsignin-step1").style.display = "none";
  document.getElementById("cpsignin-error").style.display = "none";
  try {
    const { user_code, verification_uri } = await copilotStartDeviceLogin();
    document.getElementById("cpsignin-code").textContent = user_code;
    const link = document.getElementById("cpsignin-link");
    link.href = verification_uri;
    document.getElementById("cpsignin-step2").style.display = "block";
    // No auto-open — visitor copies the code first, then clicks "Open GitHub →"
    // themselves. Auto-opening yanked focus before they could read/copy.
    const interval = (pendingDeviceLogin?.interval || 5) * 1000;
    const expires  = pendingDeviceLogin?.expires_at || (Date.now() + 900000);
    while (Date.now() < expires && pendingDeviceLogin) {
      await new Promise(r => setTimeout(r, interval));
      try {
        const tok = await copilotPollDeviceLogin();
        if (tok) break;
      } catch (e) { throw e; }
    }
    if (!getToken()) throw new Error("Login timed out — try again.");
    await copilotExchange();
    document.getElementById("cpsignin-step2").style.display = "none";
    document.getElementById("cpsignin-step3").style.display = "block";
    fetchAndCacheUser(getToken()).catch(() => {});
    setTimeout(async () => {
      closeSigninModal();
      await enterChat();
    }, 1000);
  } catch (e) {
    showSigninError(e.message || String(e));
    document.getElementById("cpsignin-step1").style.display = "block";
    document.getElementById("cpsignin-step2").style.display = "none";
  }
}

document.getElementById("btn-signin-github").addEventListener("click", openSigninModal);
document.getElementById("cpsignin-go").addEventListener("click", runCopilotSignin);
document.getElementById("cpsignin-close").addEventListener("click", closeSigninModal);

async function copyDeviceCode() {
  const code = document.getElementById("cpsignin-code").textContent.trim();
  if (!code || code === "XXXX-XXXX") return;
  let ok = false;
  try {
    await navigator.clipboard.writeText(code);
    ok = true;
  } catch (_) {
    // Fallback for older / non-secure-context browsers
    try {
      const ta = document.createElement("textarea");
      ta.value = code;
      ta.style.position = "fixed"; ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.select();
      ok = document.execCommand("copy");
      document.body.removeChild(ta);
    } catch (__) {}
  }
  const btn = document.getElementById("cpsignin-copy-code");
  const orig = btn.textContent;
  btn.textContent = ok ? "✓ Copied" : "Press & hold to copy";
  btn.style.background = ok ? "#238636" : "#21262d";
  btn.style.borderColor = ok ? "#2ea043" : "#30363d";
  btn.style.color = "#fff";
  setTimeout(() => {
    btn.textContent = orig;
    btn.style.background = "#21262d";
    btn.style.borderColor = "#30363d";
    btn.style.color = "#c9d1d9";
  }, 1600);
}
document.getElementById("cpsignin-copy-code").addEventListener("click", (e) => {
  e.stopPropagation();
  copyDeviceCode();
});
document.getElementById("cpsignin-code-box").addEventListener("click", copyDeviceCode);

document.getElementById("btn-save-pat").addEventListener("click", async () => {
  const tok = document.getElementById("pat-input").value.trim();
  if (!tok) return;
  saveSettings({ ghuToken: tok });
  document.getElementById("pat-input").value = "";
  // Try to exchange right away so we know the token's valid
  try { await copilotExchange(); } catch (_) { /* will surface on first chat */ }
  fetchAndCacheUser(tok).catch(() => {});
  await enterChat();
});
document.getElementById("btn-send").addEventListener("click", sendMessage);
document.getElementById("btn-clear").addEventListener("click", () => {
  history = [];
  document.getElementById("chat-log").innerHTML = "";
  const place = identity.display_name || identity.name || "this place";
  renderMsg("system", `Cleared. — ${place}`);
});
document.getElementById("btn-logout").addEventListener("click", () => {
  clearToken();
  location.reload();
});
document.getElementById("model-sel").addEventListener("change", (e) => {
  const id = e.target.value;
  if (!id) return;
  saveSettings({ model: id });
  renderMsg("system", "model → " + id);
});
const ascBtnEl = document.getElementById("btn-export-ascended");
if (ascBtnEl) ascBtnEl.addEventListener("click", exportAscendedEgg);
// Memory UI: open / cancel / commit
document.getElementById("btn-add-memory").addEventListener("click", () => {
  document.getElementById("memory-pane").hidden = false;
  document.getElementById("memory-input").focus();
});
document.getElementById("btn-cancel-memory").addEventListener("click", () => {
  document.getElementById("memory-pane").hidden = true;
  document.getElementById("memory-input").value = "";
  document.getElementById("memory-status").textContent = "";
});
document.getElementById("btn-save-device-memory").addEventListener("click", async () => {
  const input = document.getElementById("memory-input");
  const status = document.getElementById("memory-status");
  const fact = input.value.trim();
  if (!fact) return;
  if (saveDeviceMemory(fact)) {
    status.textContent = "saved on this device.";
    input.value = "";
    renderMsg("system", "Saved on-device memory: \"" + fact + "\"");
    setTimeout(() => {
      document.getElementById("memory-pane").hidden = true;
      status.textContent = "";
      refreshIndicator();
    }, 1500);
  } else {
    status.textContent = "couldn't save (browser storage unavailable).";
  }
});

document.getElementById("btn-save-private-memory").addEventListener("click", async () => {
  const input = document.getElementById("memory-input");
  const status = document.getElementById("memory-status");
  const fact = input.value.trim();
  if (!fact) return;
  status.textContent = "saving…";
  document.getElementById("btn-save-private-memory").disabled = true;
  const result = await saveUserPrivateMemory(fact);
  document.getElementById("btn-save-private-memory").disabled = false;
  if (result.ok) {
    const tag = viewerLogin ? "@" + viewerLogin : "you";
    status.textContent = `saved as ${tag}'s private memory.`;
    input.value = "";
    renderMsg("system", `Saved private memory (${tag}): "${fact}"`);
    setTimeout(() => {
      document.getElementById("memory-pane").hidden = true;
      status.textContent = "";
      refreshIndicator();
    }, 1500);
  } else {
    // Silent fallback to device — no access reveals
    if (saveDeviceMemory(fact)) {
      status.textContent = "saved on this device.";
      input.value = "";
      renderMsg("system", "Saved on-device memory: \"" + fact + "\"");
      setTimeout(() => {
        document.getElementById("memory-pane").hidden = true;
        status.textContent = "";
        refreshIndicator();
      }, 1500);
    } else {
      status.textContent = "couldn't save.";
    }
  }
});
document.getElementById("chat-input").addEventListener("keydown", e => {
  if (e.key === "Enter" && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});
// Auto-grow textarea
document.getElementById("chat-input").addEventListener("input", e => {
  e.target.style.height = "auto";
  e.target.style.height = Math.min(e.target.scrollHeight, 200) + "px";
});
</script>
</body>
</html>
TEMPLATE_EOF

    # Substitute placeholders via Python (env vars for safety)
    PLANT_DOORMAN_PATH="$target_dir/doorman/index.html" \
    PLANT_DISPLAY_NAME="$MIRROR_DISPLAY_NAME" \
    PLANT_LOCATION="${MIRROR_LOCATION:-}" \
    PLANT_KIND="${MIRROR_KIND:-mirror}" \
    python3 - <<'PYEOF'
import os, pathlib
path = pathlib.Path(os.environ["PLANT_DOORMAN_PATH"])
text = path.read_text()
subs = [
    ("__DISPLAY_NAME__", os.environ["PLANT_DISPLAY_NAME"]),
    ("__LOCATION__",     os.environ.get("PLANT_LOCATION", "")),
    ("__KIND__",         os.environ.get("PLANT_KIND", "mirror")),
]
for k, v in subs:
    text = text.replace(k, v)
path.write_text(text)
PYEOF
}

# ── banner ────────────────────────────────────────────────────────────
print_banner() {
    cat << EOF

  ${CYAN}🚪 RAPP front door planter${NC}

  Plant your AI's front door on the public internet.
  Kernel-compliant by structural fact. Yours forever.

EOF
}

# ── main ──────────────────────────────────────────────────────────────
main() {
    print_banner
    check_prereqs
    prompt_inputs

    local rappid now gh_user workspace workspace_private
    now="$(now_iso)"

    # If PLANT_FROM_EGG is set, use the egg's rappid (preserve the
    # organism's identity) instead of minting a fresh one.
    if [[ -n "${PLANT_FROM_EGG:-}" ]]; then
        rappid="$(extract_egg_rappid_or_die "$PLANT_FROM_EGG")"
        info "Resuming organism from egg — preserving rappid: $rappid"
    fi
    # gh_user and MIRROR_REPO_NAME are required to construct the v2-format rappid;
    # fetch them now (was below the mint; rearranged for the v2 migration).
    if [[ "${PLANT_DRY_RUN:-0}" == "1" ]]; then
        gh_user="${PLANT_GH_USER:-test-user}"
    else
        gh_user="$(gh api user -q .login)"
    fi
    if [[ -z "${PLANT_FROM_EGG:-}" ]]; then
        rappid="$(mint_rappid "$gh_user" "$MIRROR_REPO_NAME" "${MIRROR_KIND:-mirror}")"
    fi

    # Secure-by-default: every plant gets a paired private companion
    # repo. Public seed carries the AI's discoverable identity (soul,
    # rappid, baseline memory + agents). Private companion carries
    # the accumulated brain — operator-curated memory, custom agents,
    # mutation logs, per-user issue memories. Operator can promote
    # private→public over time via commit; default starts safe.
    #
    # Disable with PLANT_AUTO_PRIVATE=0 if the operator explicitly
    # wants a fully-public organism (e.g. memorial twins, public
    # exhibits, demo seeds).
    if [[ "${PLANT_AUTO_PRIVATE:-1}" == "1" ]] && [[ -z "${MIRROR_PRIVATE_COMPANION:-}" ]]; then
        local _u="${PLANT_GH_USER:-$(gh api user -q .login 2>/dev/null || echo "test-user")}"
        MIRROR_PRIVATE_COMPANION="${_u}/${MIRROR_REPO_NAME}-private"
        export MIRROR_PRIVATE_COMPANION
        info "Secure-by-default: auto-creating private companion ${MIRROR_PRIVATE_COMPANION}"
        if [[ -n "${PLANT_FROM_EGG:-}" ]]; then
            info "  → accumulated memory, custom agents, frame log → private"
            info "  → soul + baseline agents stay public"
        else
            info "  → fresh plant: per-user memories + custom agents will route here as the AI grows"
            info "  → soul + baseline doorman agents stay public for any visitor"
        fi
    fi

    if [[ "${PLANT_DRY_RUN:-0}" == "1" ]]; then
        workspace="${PLANT_DRY_RUN_DIR:-$(mktemp -d)}"
        mkdir -p "$workspace"
        info "Dry run — building in $workspace"
    else
        workspace=$(mktemp -d)
    fi

    # When MIRROR_PRIVATE_COMPANION is set (auto-derived above for the
    # secure-by-default path, OR explicitly set by the visitor), we
    # also build a sibling workspace for the private repo. Files
    # split between the two during overlay; the public seed gets
    # planted as --public, the private companion as --private.
    if [[ -n "${MIRROR_PRIVATE_COMPANION:-}" ]] && [[ "${PLANT_AUTO_PRIVATE:-1}" == "1" ]]; then
        if [[ "${PLANT_DRY_RUN:-0}" == "1" ]]; then
            workspace_private="${workspace}-private"
            mkdir -p "$workspace_private"
        else
            workspace_private=$(mktemp -d)
        fi
    fi

    fetch_kernel       "$workspace"
    fetch_seed_agents  "$workspace"
    write_install_sh   "$workspace"
    write_rappid_json  "$workspace" "$gh_user" "$rappid" "$now"
    write_soul_md      "$workspace"
    write_gitignore    "$workspace"
    write_nojekyll     "$workspace"
    write_memory_json  "$workspace" "$gh_user" "$now"
    write_neighbors_json "$workspace"
    write_readme       "$workspace" "$gh_user" "$rappid"
    write_classic_html "$workspace" "$gh_user" "$rappid"
    write_index_html   "$workspace" "$gh_user" "$rappid"
    write_doorman_html "$workspace" "$gh_user" "$rappid"
    overlay_egg_if_set "$workspace" "$workspace_private"
    # rar/ scaffolding — sha256-pinned participation kit. Runs LAST so it
    # captures any agents that overlay_egg_if_set added on top of fetch_seed_agents.
    write_rar_index    "$workspace" "$gh_user" "$MIRROR_REPO_NAME" "${MIRROR_KIND:-mirror}"

    if [[ "${PLANT_DRY_RUN:-0}" == "1" ]]; then
        echo ""
        ok "Dry run complete. Files written:"
        ( cd "$workspace" && find . -type f | sort | sed 's|^\./|  |' )
        if [[ -n "$workspace_private" ]] && [[ -d "$workspace_private" ]]; then
            echo ""
            ok "Private companion files:"
            ( cd "$workspace_private" && find . -type f 2>/dev/null | sort | sed 's|^\./|  |' )
            echo ""
            echo "Public path:  $workspace"
            echo "Private path: $workspace_private"
        else
            echo ""
            echo "Path: $workspace"
        fi
        return 0
    fi

    info "Initializing git repo..."
    cd "$workspace"
    git init -q -b main
    git add .
    # Commit message reflects whether this is a fresh plant or a
    # resurrection from an egg (PLANT_FROM_EGG) — the latter says so
    # explicitly so future readers know the rappid was preserved.
    local commit_msg="plant: ${MIRROR_REPO_NAME} (rappid ${rappid:0:8}…)"
    if [[ -f .plant-import.json ]]; then
        local imp_summary
        imp_summary=$(python3 -c "
import json
d = json.load(open('.plant-import.json'))
c = d.get('files_overlaid', {})
print(f\"imported from egg ({d.get('schema','?')}, tier={d.get('tier','?')}, {d.get('verified_hashes',0)} hashes verified) — preserved rappid {d.get('rappid','?')[:8]}…, overlaid {c.get('top_files',0)} top files + {c.get('agents',0)} agents + {c.get('data',0)} data files\")
" 2>/dev/null || echo "imported from egg")
        commit_msg="plant (resume from egg): ${MIRROR_REPO_NAME}

${imp_summary}"
        rm -f .plant-import.json
    fi
    git -c user.email="${gh_user}@users.noreply.github.com" \
        -c user.name="$gh_user" \
        commit -q -m "$commit_msg"
    ok "Initial commit"

    info "Creating GitHub repo: $gh_user/$MIRROR_REPO_NAME"
    gh repo create "$MIRROR_REPO_NAME" --public --source=. --push \
        --description "$MIRROR_DISPLAY_NAME — RAPP front door" \
        || err "gh repo create failed (does the repo already exist?)"
    ok "Repo created and pushed"

    info "Enabling GitHub Pages..."
    if gh api -X POST "/repos/$gh_user/$MIRROR_REPO_NAME/pages" \
        -f "source[branch]=main" -f "source[path]=/" >/dev/null 2>&1; then
        ok "Pages enabled"
    else
        warn "Pages may already be enabled, or hit a transient error — check repo Settings → Pages"
    fi

    # Plant the private companion repo, if we built one. The accumulated
    # brain (custom agents, memory, frames, per-user issues) lives here
    # by default — secure-first per Constitution Article XL. Operator
    # curates what gets promoted to the public seed over time.
    if [[ -n "${workspace_private:-}" ]] && [[ -d "$workspace_private" ]]; then
        local priv_files
        priv_files=$(find "$workspace_private" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$priv_files" -gt 0 ]]; then
            info "Planting private companion: $MIRROR_PRIVATE_COMPANION"
            local priv_name="${MIRROR_PRIVATE_COMPANION##*/}"
            cd "$workspace_private"
            git init -q -b main
            git add .
            local priv_commit_msg="private companion: ${priv_name} (rappid ${rappid:0:8}…)

The accumulated brain layer for the public seed at
github.com/${gh_user}/${MIRROR_REPO_NAME}. Carries custom agents,
operator-curated memory, mutation log, and per-user issue exports.
Visitors with read access here unlock the doorman's ascended mode."
            if [[ -f .plant-import.json ]]; then
                local priv_imp_summary
                priv_imp_summary=$(python3 -c "
import json
d = json.load(open('.plant-import.json'))
c = d.get('files_overlaid', {})
print(f\"imported from egg ({d.get('schema','?')}, {d.get('verified_hashes',0)} hashes verified) — preserved rappid {d.get('rappid','?')[:8]}…, accumulated {c.get('private_top',0)} top + {c.get('private_agents',0)} agents + {c.get('private_data',0)} data files\")
" 2>/dev/null || echo "imported from egg")
                priv_commit_msg="private companion (resume from egg): ${priv_name}

${priv_imp_summary}"
                rm -f .plant-import.json
            fi
            git -c user.email="${gh_user}@users.noreply.github.com" \
                -c user.name="$gh_user" \
                commit -q -m "$priv_commit_msg"

            # Create as --private. If the visitor already has a repo at
            # this name, gh fails — print a helpful warning.
            if gh repo create "$priv_name" --private --source=. --push \
                --description "Private brain layer for ${MIRROR_REPO_NAME} — see Article XL" \
                >/dev/null 2>&1; then
                ok "Private companion planted: github.com/${gh_user}/${priv_name}"
            else
                warn "Couldn't create private repo ${priv_name} — does it already exist? Files staged at $workspace_private"
            fi
            cd - >/dev/null
        fi
    fi

    cat << EOF

═══════════════════════════════════════════════════════════════════
  ${GREEN}✓ Front door planted!${NC}
═══════════════════════════════════════════════════════════════════

  Repo:    https://github.com/$gh_user/$MIRROR_REPO_NAME
  URL:     https://$gh_user.github.io/$MIRROR_REPO_NAME
  Rappid:  $rappid

  Pages takes 1–3 minutes to deploy. Once live:

  ${CYAN}Visit your front door:${NC}
    https://$gh_user.github.io/$MIRROR_REPO_NAME

  ${CYAN}Anyone can install your kernel locally with:${NC}
    curl -fsSL https://$gh_user.github.io/$MIRROR_REPO_NAME/installer/install.sh | bash

  ${CYAN}Generate a QR for sharing:${NC}
    https://kody-w.github.io/RAPP/installer/plant_qr.html?to=https://$gh_user.github.io/$MIRROR_REPO_NAME

  ${CYAN}Verify your kernel still matches grail (drift check):${NC}
    for f in rapp_brainstem/brainstem.py rapp_brainstem/VERSION rapp_brainstem/agents/basic_agent.py; do
      diff <(curl -fsSL "https://raw.githubusercontent.com/kody-w/rapp-installer/main/\$f") \\
           <(curl -fsSL "https://raw.githubusercontent.com/$gh_user/$MIRROR_REPO_NAME/main/\$f") \\
        || echo "DRIFT: \$f"
    done
    # Three empty diffs = compliant. Anything else = drift.

EOF
}

main "$@"
