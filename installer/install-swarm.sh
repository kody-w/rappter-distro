#!/bin/bash
set -e

# RAPP Swarm Server Installer
# Usage: curl -fsSL https://kody-w.github.io/RAPP/installer/install-swarm.sh | bash
#
# Hosts many RAPP swarms behind one local endpoint, routed by swarm_guid +
# user_guid. Stdlib-only Python; no venv, no pip, no Azure runtime needed
# locally. Deploy from the brainstem's "Deploy as Swarm" action.

SWARM_HOME="$HOME/.rapp-swarm"
SWARM_BIN="$HOME/.local/bin"
REPO_URL="https://github.com/kody-w/RAPP.git"

GREEN='\033[0;32m'; CYAN='\033[0;36m'; RED='\033[0;31m'; NC='\033[0m'

print_banner() {
    echo ""
    echo -e "${CYAN}  🐝 RAPP Swarm Server${NC}"
    echo "  Host many RAPP swarms behind one endpoint, routed by GUID."
    echo ""
}

find_python() {
    for cmd in python3 python3.13 python3.12 python3.11 python3.10 python3.9 python3.8; do
        if command -v "$cmd" &> /dev/null; then
            ver=$("$cmd" -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor:02d}")' 2>/dev/null) || continue
            if [ -n "$ver" ] && [ "$ver" -ge 308 ] 2>/dev/null; then
                echo "$cmd"; return 0
            fi
        fi
    done
    return 1
}

ensure_repo() {
    SRC="$SWARM_HOME/_repo"
    if [ -d "$SRC/.git" ]; then
        echo "  Updating $SRC..."
        git -C "$SRC" fetch --quiet origin main 2>/dev/null || true
        git -C "$SRC" reset --hard --quiet origin/main 2>/dev/null || true
    else
        echo "  Cloning $REPO_URL → $SRC..."
        rm -rf "$SRC"
        git clone --quiet --depth 1 "$REPO_URL" "$SRC"
    fi
}

install_cli() {
    mkdir -p "$SWARM_BIN"
    local python_cmd="$1"
    cat > "$SWARM_BIN/brainstem-swarm" << WRAPPER
#!/bin/bash
# RAPP Swarm Server launcher.
# Persists swarms to ~/.rapp-swarm/swarms/{guid}/.
exec "$python_cmd" "$SWARM_HOME/_repo/rapp_brainstem/brainstem.py" \\
    --root "$SWARM_HOME" \\
    "\$@"
WRAPPER
    chmod +x "$SWARM_BIN/brainstem-swarm"

    add_to_path() {
        local f="$1"; touch "$f"
        if ! grep -q '\.local/bin' "$f" 2>/dev/null; then
            echo '' >> "$f"
            echo '# RAPP' >> "$f"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$f"
        fi
    }
    add_to_path "$HOME/.bashrc"
    add_to_path "$HOME/.zshrc"
    add_to_path "$HOME/.bash_profile"
}

main() {
    print_banner

    command -v git &>/dev/null || {
        echo -e "  ${RED}git is required.${NC} https://git-scm.com/"
        exit 1
    }
    PYTHON_CMD=$(find_python) || {
        echo -e "  ${RED}Python 3.8+ required.${NC} https://python.org"
        exit 1
    }
    echo "  Python: $PYTHON_CMD ($($PYTHON_CMD --version 2>&1))"

    mkdir -p "$SWARM_HOME"
    ensure_repo
    install_cli "$PYTHON_CMD"
    export PATH="$SWARM_BIN:$PATH"

    echo ""
    echo "═══════════════════════════════════════════════════"
    echo -e "  ${GREEN}✓ RAPP Swarm Server installed!${NC}"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "  CLI:    brainstem-swarm"
    echo "  Repo:   $SWARM_HOME/_repo"
    echo "  Swarms: $SWARM_HOME/swarms/"
    echo ""
    echo -e "  ${CYAN}Launching swarm server now…${NC}"
    echo ""
    exec "$SWARM_BIN/brainstem-swarm"
}

main
