#!/bin/bash
# rapp_swarm/build.sh — vendor brainstem core dependencies → _vendored/
# so the Function App is a self-contained deploy unit.
#
# Run before `func azure functionapp publish` (or before `func start`
# inside this directory):
#
#     bash rapp_swarm/build.sh
#
# function_app.py imports from the vendor tree: llm.py (provider
# dispatch), twin.py (calibration helpers), _basic_agent_shim.py (so
# agents can `from agents.basic_agent import BasicAgent` unmodified).
# Starter + swarm-management agents are also copied so Tier 2 has the
# same default agent surface as Tier 1.

set -e
cd "$(dirname "$0")"

ROOT="$(cd .. && pwd)"
DEST=_vendored

echo "▶ Vendoring rapp_brainstem core into rapp_swarm/$DEST/"
rm -rf "$DEST"
mkdir -p "$DEST"
mkdir -p "$DEST/agents"

# Support modules live under utils/ (Article XVI — root stays minimal).
# Vendor the utils/ tree so function_app.py's `from utils.llm import …`
# and `from utils import twin` resolve inside _vendored/.
mkdir -p "$DEST/utils"
for src in llm.py twin.py _basic_agent_shim.py; do
    if [ -f "$ROOT/rapp_brainstem/utils/$src" ]; then
        cp "$ROOT/rapp_brainstem/utils/$src" "$DEST/utils/$src"
        echo "  ✓ utils/$src (brainstem)"
    else
        echo "  ⚠ missing: utils/$src"
    fi
done

# Tier-2 cloud-specific utils (Azure File Storage, Azure OpenAI error
# types, Result[T,E] types, local filesystem fallback). Live in
# rapp_swarm/utils/ because they are NOT Tier 1 concerns — brainstem
# has no Azure-SDK dependencies.
if [ -d utils ]; then
    for src in utils/*.py; do
        [ -f "$src" ] || continue
        base=$(basename "$src")
        cp "$src" "$DEST/utils/$base"
        echo "  ✓ utils/$base (tier-2)"
    done
fi

# Package markers for the vendor tree.
[ -f "$DEST/__init__.py" ]       || touch "$DEST/__init__.py"
[ -f "$DEST/utils/__init__.py" ] || touch "$DEST/utils/__init__.py"

# Agent tree — per CONSTITUTION Article XVII / XII, agents/ is a
# user-organized tree. Vendor it recursively, mirroring Tier 1's shape,
# but skip the two subdirs that never auto-load in either tier:
# experimental_agents/ and disabled_agents/. __pycache__ is also skipped.
if command -v rsync &>/dev/null; then
    rsync -a \
        --exclude='__pycache__' \
        --exclude='experimental_agents' \
        --exclude='disabled_agents' \
        "$ROOT/rapp_brainstem/agents/" "$DEST/agents/"
else
    # Fallback for systems without rsync (Windows/Git Bash)
    cp -R "$ROOT/rapp_brainstem/agents/"* "$DEST/agents/" 2>/dev/null || true
    rm -rf "$DEST/agents/__pycache__" "$DEST/agents/experimental_agents" "$DEST/agents/disabled_agents" 2>/dev/null || true
fi
echo "  ✓ agents/ tree ($(find "$DEST/agents" -name '*_agent.py' | wc -l | tr -d ' ') agent files)"

# Services tree — drop-in HTTP endpoints (swarms, binder, etc.)
# Same discovery pattern as agents: services/*_service.py.
if [ -d "$ROOT/rapp_brainstem/services" ]; then
    mkdir -p "$DEST/services"
    cp "$ROOT/rapp_brainstem/services"/*_service.py "$DEST/services/" 2>/dev/null || true
    echo "  ✓ services/ tree ($(find "$DEST/services" -name '*_service.py' 2>/dev/null | wc -l | tr -d ' ') service files)"
fi

# function_app.py's load_agents_from_folder() does `os.listdir("./agents")`
# relative to function_app.py's directory. Copy (not symlink) the
# vendored agent tree to that sibling path — `func azure functionapp
# publish` zips the deploy tree and symlinks don't always survive.
rm -rf agents
cp -R _vendored/agents agents
echo "  ✓ agents/ (copy for function_app.py lookup + Azure deploy zip)"

# Same for services — copy to root for function_app.py lookup.
if [ -d _vendored/services ]; then
    rm -rf services
    cp -R _vendored/services services
    echo "  ✓ services/ (copy for function_app.py lookup + Azure deploy zip)"
fi

echo "▶ Done. Function App is ready to publish."
echo "    cd rapp_swarm && func azure functionapp publish <APP_NAME> --build remote"
