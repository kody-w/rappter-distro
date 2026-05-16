#!/usr/bin/env bash
set -e

# rappter-distro installer
# Hatches the Rappter distro onto an existing grail brainstem install.
#
#   curl -fsSL https://raw.githubusercontent.com/kody-w/rappter-distro/main/install.sh | bash
#
# Requires a brainstem already installed (run the grail one-liner first):
#   curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash

BRAINSTEM_HOME="${BRAINSTEM_HOME:-$HOME/.brainstem}"
DISTRO_REPO="https://github.com/kody-w/rappter-distro.git"
DISTRO_BRANCH="${RAPPTER_DISTRO_BRANCH:-main}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo ""
echo -e "${CYAN}🦖 rappter-distro${NC}"
echo "   The full-bodied Rappter organism distro"
echo ""

if [ ! -f "$BRAINSTEM_HOME/brainstem.py" ]; then
    echo -e "${RED}✗${NC} No grail brainstem found at $BRAINSTEM_HOME"
    echo ""
    echo "  Install grail first:"
    echo "    curl -fsSL https://kody-w.github.io/RAPP/installer/install.sh | bash"
    exit 1
fi

KERNEL_VERSION=$(cat "$BRAINSTEM_HOME/VERSION" 2>/dev/null || echo "unknown")
echo -e "${GREEN}✓${NC} Found grail brainstem at $BRAINSTEM_HOME (v$KERNEL_VERSION)"

# Stage distro source (clone or use local checkout if invoked from there)
if [ -f "./distro.json" ] && [ -d "./lib" ] && [ -d "./organs" ]; then
    SRC="$(pwd)"
    echo -e "${GREEN}✓${NC} Using local distro checkout at $SRC"
else
    SRC="$(mktemp -d)/rappter-distro"
    echo "   Cloning distro into $SRC..."
    git clone --depth=1 --branch="$DISTRO_BRANCH" "$DISTRO_REPO" "$SRC" >/dev/null 2>&1
    echo -e "${GREEN}✓${NC} Cloned"
fi

# Hatch layout per distro.json mapping
echo "   Hatching distro onto kernel..."
mkdir -p "$BRAINSTEM_HOME/utils/organs" \
         "$BRAINSTEM_HOME/utils/senses" \
         "$BRAINSTEM_HOME/utils/web" \
         "$BRAINSTEM_HOME/agents/@rappter"

# lib/*.py → utils/
cp "$SRC/lib"/*.py "$BRAINSTEM_HOME/utils/" 2>/dev/null || true
# organs/*.py → utils/organs/
cp "$SRC/organs"/*.py "$BRAINSTEM_HOME/utils/organs/" 2>/dev/null || true
# senses/*.py → utils/senses/
cp "$SRC/senses"/*.py "$BRAINSTEM_HOME/utils/senses/" 2>/dev/null || true
# ui/web/* → utils/web/
[ -d "$SRC/ui/web" ] && cp -R "$SRC/ui/web/." "$BRAINSTEM_HOME/utils/web/" 2>/dev/null || true
# ui/index.html → replaces kernel's index.html (Mirror Spec lists index.html as free-to-change)
[ -f "$SRC/ui/index.html" ] && cp "$SRC/ui/index.html" "$BRAINSTEM_HOME/index.html"
# ui/tls_proxy.py → sibling
[ -f "$SRC/ui/tls_proxy.py" ] && cp "$SRC/ui/tls_proxy.py" "$BRAINSTEM_HOME/"
# agents/@rappter/ → agents/@rappter/
cp "$SRC/agents/@rappter"/*.py "$BRAINSTEM_HOME/agents/@rappter/" 2>/dev/null || true

echo -e "${GREEN}✓${NC} Distro hatched"
echo ""
echo "   Launcher: ${CYAN}python $BRAINSTEM_HOME/utils/boot.py${NC}"
echo "   (boot.py monkey-patches Flask.run to compose organs + senses; kernel is untouched.)"
echo ""
echo "   Bare kernel still works: ${CYAN}python $BRAINSTEM_HOME/brainstem.py${NC}"
echo ""
echo -e "${GREEN}🦖 rappter-distro ready.${NC}"
