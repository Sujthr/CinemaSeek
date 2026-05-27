#!/usr/bin/env bash
# ============================================================
#  CinemaSeek — Start Script (Linux / macOS / WSL)
#  Starts LLMGatewayV7, then optionally indexes the corpus.
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATEWAY_DIR="${GATEWAY_DIR:-D:/EAG/EAG/Class 23 May/LLMGateway/llm_gatewayV7}"
GATEWAY_URL="http://localhost:8107"
STATE_DIR="$SCRIPT_DIR/state"
ENV_FILE="$SCRIPT_DIR/.env"

echo
echo " ========================================"
echo "  CinemaSeek | Start"
echo " ========================================"

# ── 1. Check .env ────────────────────────────────────────────
if [[ ! -f "$ENV_FILE" ]]; then
    echo " [WARN] .env not found. Copying from .env.example ..."
    cp "$SCRIPT_DIR/.env.example" "$ENV_FILE"
    echo " [WARN] Open .env and fill in your GEMINI_API_KEY before continuing."
    read -r -p " Press Enter to continue anyway, or Ctrl+C to abort ..." _
fi

# ── 2. Check if gateway is already running ───────────────────
GW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/v1/routers" 2>/dev/null || echo "000")
if [[ "$GW_STATUS" == "200" ]]; then
    echo " [OK] LLMGatewayV7 already running on $GATEWAY_URL"
else
    # ── 3. Start LLMGatewayV7 ────────────────────────────────────
    echo
    echo " [INFO] Starting LLMGatewayV7 from:"
    echo "        $GATEWAY_DIR"
    echo

    if [[ ! -d "$GATEWAY_DIR" ]]; then
        echo " [ERROR] Gateway directory not found: $GATEWAY_DIR"
        echo " [ERROR] Set GATEWAY_DIR env var to the correct path."
        exit 1
    fi

    # Copy .env to gateway dir so it picks up keys
    [[ -f "$ENV_FILE" ]] && cp -f "$ENV_FILE" "$GATEWAY_DIR/.env"

    # Start gateway in background
    (cd "$GATEWAY_DIR" && uv run main.py) &
    GATEWAY_PID=$!
    echo " [INFO] Gateway PID: $GATEWAY_PID"

    # Wait up to 45 seconds for gateway to be ready
    echo " [INFO] Waiting for gateway to be ready ..."
    WAIT=0
    while true; do
        sleep 2
        WAIT=$((WAIT + 2))
        GW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/v1/routers" 2>/dev/null || echo "000")
        if [[ "$GW_STATUS" == "200" ]]; then
            echo " [OK] Gateway is up! (${WAIT}s)"
            break
        fi
        if [[ $WAIT -ge 45 ]]; then
            echo " [ERROR] Gateway failed to start within 45s."
            echo " [ERROR] Check gateway logs for errors."
            exit 1
        fi
    done
fi

# ── 4. Index corpus if state/ is empty ───────────────────────
echo
if [[ ! -f "$STATE_DIR/index.faiss" ]]; then
    echo " [INFO] No FAISS index found. Running corpus indexer ..."
    echo " [INFO] This will take 5-15 minutes on first run."
    echo
    cd "$SCRIPT_DIR"
    uv run index_corpus.py
    echo
    echo " [OK] Corpus indexed. Index saved to state/"
else
    echo " [OK] FAISS index already exists — skipping re-index."
    echo "      (Delete state/ to force a full re-index)"
fi

# ── 5. Done ──────────────────────────────────────────────────
echo
echo " ========================================"
echo "  CinemaSeek is ready!"
echo " ========================================"
echo
echo " Run a query:"
echo "   uv run agent7.py \"I want to watch something nostalgic...\""
echo
echo " Or use query.bat / query.sh:"
echo "   ./query.sh \"Which films deal with non-linear time?\""
echo
echo " Gateway dashboard: $GATEWAY_URL"
echo
