#!/usr/bin/env bash
# Post-provision: enable system-assigned managed identity on the twin
# function app and grant it `Cognitive Services OpenAI User` on the
# shared Azure OpenAI resource. Idempotent.
#
# Usage:
#   APP_NAME=twin-e2etest-<hash> RG=rg-twin-e2etest \
#     bash tests/e2e/enable-mi-on-twin.sh
set -euo pipefail

: "${APP_NAME:?APP_NAME required (e.g. twin-e2etest-abc123)}"
: "${RG:?RG required (e.g. rg-twin-e2etest)}"

# Resolve the Azure OpenAI resource the twin will call. Use what's in
# the repo-root local.settings.json to stay in sync with local dev.
OPENAI_ENDPOINT=$(python3 -c "import json; print(json.load(open('local.settings.json'))['Values'].get('AZURE_OPENAI_ENDPOINT',''))")
OPENAI_HOST=$(echo "$OPENAI_ENDPOINT" | sed -E 's|^https?://([^/]+).*|\1|')
OPENAI_RES_NAME=$(echo "$OPENAI_HOST" | cut -d. -f1)
echo "▶ Target Azure OpenAI resource: $OPENAI_RES_NAME (from $OPENAI_ENDPOINT)"

# Enable system-assigned identity on the function app
echo "▶ Enabling system-assigned managed identity on $APP_NAME..."
PRINCIPAL_ID=$(az functionapp identity assign \
    --name "$APP_NAME" --resource-group "$RG" \
    --query principalId -o tsv)
echo "  principalId=$PRINCIPAL_ID"

# Resolve the Azure OpenAI resource ID across the subscription
OPENAI_RES_ID=$(az cognitiveservices account list \
    --query "[?name=='$OPENAI_RES_NAME'].id | [0]" -o tsv)
if [ -z "$OPENAI_RES_ID" ]; then
    echo "FAIL: could not locate Azure OpenAI resource '$OPENAI_RES_NAME' in current subscription."
    exit 1
fi
echo "  openai resource id: $OPENAI_RES_ID"

# Grant `Cognitive Services OpenAI User` role
echo "▶ Granting 'Cognitive Services OpenAI User' on the OpenAI resource..."
az role assignment create \
    --assignee-object-id "$PRINCIPAL_ID" \
    --assignee-principal-type ServicePrincipal \
    --role "Cognitive Services OpenAI User" \
    --scope "$OPENAI_RES_ID" \
    --output none 2>&1 | grep -v "already exists" || true

# Restart the app so new identity token is picked up
echo "▶ Restarting $APP_NAME to pick up identity..."
az functionapp restart --name "$APP_NAME" --resource-group "$RG" --output none

# Wait for the function app to recover
echo "▶ Waiting for app to come back up..."
URL="https://${APP_NAME}.azurewebsites.net/api/health"
for i in $(seq 1 30); do
    if curl -sf "$URL" >/dev/null 2>&1; then
        echo "PASS: $URL responds"
        break
    fi
    sleep 5
done

echo "✅ MI enabled + role granted. Function app:"
echo "    https://${APP_NAME}.azurewebsites.net"
