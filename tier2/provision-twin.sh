#!/bin/bash
# rapp_swarm/provision-twin.sh — one-shot Azure provisioner for a
# Twin Stack cloud estate (Kody's, Molly's, or any named human).
#
# What it does:
#   1. az login (if not logged in)
#   2. Set subscription to the Visual Studio Enterprise subscription
#   3. Create a fully isolated resource group rg-twin-<name>
#   4. ARM-deploy the azuredeploy.json template (in installer/) into it (Function App + Storage
#      + Azure OpenAI + RBAC), wiring outputs into the function app
#   5. Layer the root .env keys on top as Function App settings (overrides
#      the freshly-created OpenAI with any pre-existing keys you want to
#      use — useful if you already have quota in another RG)
#   6. Run rapp_swarm/build.sh to vendor the swarm core
#   7. func azure functionapp publish — deploys function_app.py
#   8. Print the function URL and the bootstrap instructions
#
# Usage:
#     bash rapp_swarm/provision-twin.sh kody
#     bash rapp_swarm/provision-twin.sh molly
#     bash rapp_swarm/provision-twin.sh anyone-else
#
# Defaults (override with env vars):
#     SUBSCRIPTION_ID  = 3d0e6986-1b31-4189-a394-b3289d54efb0
#                        (Visual Studio Enterprise — wildfeueroutlook)
#     LOCATION         = eastus2  (colocated with existing rappter OpenAI)
#     OPENAI_LOCATION  = eastus2
#     OPENAI_MODEL     = gpt-4o   (change with OPENAI_MODEL=gpt-5.2-chat …)
#
# Real-money warning: this script CREATES Azure resources. Per-twin cost
# at idle: ~$0/mo (Flex Consumption + pay-per-call OpenAI). Verify your
# subscription has quota in the chosen region before running.

set -e
set -o pipefail

# ── Args + defaults ────────────────────────────────────────────────────

NAME="${1:-}"
if [ -z "$NAME" ]; then
    echo "usage: $0 <twin-name>      (e.g., kody | molly | anyone)"
    exit 2
fi
NAME=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
if [ -z "$NAME" ]; then
    echo "Error: twin-name must contain at least one [a-z0-9-] char."
    exit 2
fi

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-3d0e6986-1b31-4189-a394-b3289d54efb0}"
LOCATION="${LOCATION:-eastus2}"
OPENAI_LOCATION="${OPENAI_LOCATION:-eastus2}"
OPENAI_MODEL="${OPENAI_MODEL:-gpt-4o}"
OPENAI_DEPLOYMENT="${OPENAI_DEPLOYMENT:-${OPENAI_MODEL}}"
OPENAI_CAPACITY="${OPENAI_CAPACITY:-10}"

# Stable, name-spaced identifiers
RG="rg-twin-${NAME}"
APP_NAME="twin-${NAME}-$(printf '%s' "$NAME" | shasum | cut -c1-8)"
ASSISTANT_NAME="${NAME^} Twin"
DESC="The Twin Stack — ${NAME}'s digital twin cloud estate."

cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
TEMPLATE="$ROOT/installer/azuredeploy.json"

# ── Sanity checks ──────────────────────────────────────────────────────

command -v az >/dev/null || {
    echo "✗ Azure CLI not found. Install: brew install azure-cli"
    exit 1
}
command -v func >/dev/null || {
    echo "⚠  Azure Functions Core Tools not found. The publish step will be skipped."
    echo "    Install:  brew tap azure/functions && brew install azure-functions-core-tools@4"
    SKIP_FUNC_PUBLISH=1
}
[ -f "$TEMPLATE" ] || { echo "✗ template missing: $TEMPLATE"; exit 1; }

# ── 1. Login + subscription ────────────────────────────────────────────

echo "▶ Checking Azure login…"
if ! az account show >/dev/null 2>&1; then
    az login
fi

CURRENT_SUB=$(az account show --query id -o tsv)
if [ "$CURRENT_SUB" != "$SUBSCRIPTION_ID" ]; then
    echo "▶ Switching subscription → $SUBSCRIPTION_ID"
    az account set --subscription "$SUBSCRIPTION_ID"
fi
echo "  Using subscription:  $(az account show --query name -o tsv)"
echo "  Tenant:              $(az account show --query tenantId -o tsv)"

# ── 2. Resource group (isolated per twin) ──────────────────────────────

echo "▶ Ensuring resource group $RG in $LOCATION"
az group create --name "$RG" --location "$LOCATION" \
    --tags "twin=$NAME" "stack=TwinStack" "owner=wildhaven-ai-homes" \
    --output none

# ── 3. ARM-deploy azuredeploy.json ─────────────────────────────────────

echo "▶ Deploying azuredeploy.json (this takes ~5 min — Function App + Storage + OpenAI)"
DEPLOY_NAME="twin-${NAME}-$(date +%s)"
az deployment group create \
    --resource-group "$RG" \
    --name "$DEPLOY_NAME" \
    --template-file "$TEMPLATE" \
    --parameters \
        functionAppName="$APP_NAME" \
        openAILocation="$OPENAI_LOCATION" \
        openAIModelName="$OPENAI_MODEL" \
        openAIDeploymentName="$OPENAI_DEPLOYMENT" \
        openAIDeploymentCapacity="$OPENAI_CAPACITY" \
        assistantName="$ASSISTANT_NAME" \
        characteristicDescription="$DESC" \
    --output none

FUNCTION_URL=$(az deployment group show -g "$RG" -n "$DEPLOY_NAME" \
                  --query properties.outputs.functionAppUrl.value -o tsv)
OPENAI_ENDPOINT=$(az deployment group show -g "$RG" -n "$DEPLOY_NAME" \
                     --query properties.outputs.openAIEndpoint.value -o tsv)
echo "  Function App URL:    $FUNCTION_URL"
echo "  OpenAI endpoint:     $OPENAI_ENDPOINT"

# ── 4. Layer .env onto app settings (optional override) ────────────────

ENV_FILE="$ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    echo "▶ Applying root .env to Function App settings (override-style)"
    SETTINGS=()
    while IFS='=' read -r k v; do
        [ -z "$k" ] && continue
        case "$k" in '#'*) continue;; esac
        # Strip optional surrounding quotes
        v="${v%\"}"; v="${v#\"}"; v="${v%\'}"; v="${v#\'}"
        case "$k" in
            AZURE_OPENAI_API_KEY|AZURE_OPENAI_ENDPOINT|AZURE_OPENAI_DEPLOYMENT|AZURE_OPENAI_API_VERSION| \
            OPENAI_API_KEY|ANTHROPIC_API_KEY)
                SETTINGS+=("$k=$v")
                ;;
        esac
    done < "$ENV_FILE"
    if [ ${#SETTINGS[@]} -gt 0 ]; then
        az functionapp config appsettings set \
            --name "$APP_NAME" --resource-group "$RG" \
            --settings "${SETTINGS[@]}" \
            --output none
        echo "  Applied ${#SETTINGS[@]} env-derived setting(s)."
    fi
fi

# Always set the BRAINSTEM_HOME to a writable scratch path
az functionapp config appsettings set \
    --name "$APP_NAME" --resource-group "$RG" \
    --settings "BRAINSTEM_HOME=/tmp/.rapp-swarm" "TWIN_NAME=$NAME" \
    --output none

# ── 5. Vendor swarm core ───────────────────────────────────────────────

echo "▶ Vendoring swarm core (rapp_swarm/build.sh)"
bash "$(pwd)/build.sh"

# ── 6. Publish function code ───────────────────────────────────────────

if [ -z "${SKIP_FUNC_PUBLISH:-}" ]; then
    echo "▶ Publishing function_app.py to $APP_NAME"
    func azure functionapp publish "$APP_NAME" --build remote
fi

# ── 7. Final report ────────────────────────────────────────────────────

cat <<EOF

════════════════════════════════════════════════════════════════════
  ✓ Twin provisioned: $NAME
════════════════════════════════════════════════════════════════════

  Resource group:    $RG
  Function App:      $APP_NAME
  Function URL:      $FUNCTION_URL
  OpenAI endpoint:   $OPENAI_ENDPOINT
  Region:            $LOCATION

  Health check:
    curl $FUNCTION_URL/api/swarm/healthz

  LLM provider check:
    curl $FUNCTION_URL/api/llm/status

  Hatch ${NAME^}'s cloud into this twin:
    1. Open https://kody-w.github.io/RAPP/rapp_brainstem/web/onboard/
    2. Set endpoint = $FUNCTION_URL
    3. Click "${NAME^}'s cloud" → "🚀 Push to endpoint"

  Test a chat after hatching:
    curl -X POST "$FUNCTION_URL/api/chat" \\
      -H 'Content-Type: application/json' \\
      -d '{"user_input":"Hello, who are you?"}'

  Tear down (when you're done):
    az group delete --name $RG --yes --no-wait

════════════════════════════════════════════════════════════════════
EOF
