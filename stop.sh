#!/usr/bin/env bash
# ============================================================
#  CinemaSeek — Stop Script (Linux / macOS / WSL)
#  Kills LLMGatewayV7 (port 8107) if running.
# ============================================================
set -euo pipefail

GATEWAY_URL="http://localhost:8107"

echo
echo " ========================================"
echo "  CinemaSeek | Stop"
echo " ========================================"
echo

# Check if gateway is running
GW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/v1/routers" 2>/dev/null || echo "000")

if [[ "$GW_STATUS" != "200" ]]; then
    echo " [INFO] LLMGatewayV7 is not running on port 8107."
else
    echo " [INFO] Stopping LLMGatewayV7 on port 8107 ..."

    # Find and kill the process listening on port 8107
    PID=$(lsof -ti tcp:8107 2>/dev/null || true)
    if [[ -n "$PID" ]]; then
        echo " [INFO] Killing PID(s): $PID"
        echo "$PID" | xargs kill -TERM 2>/dev/null || true
        sleep 2
        # Force kill if still alive
        PID=$(lsof -ti tcp:8107 2>/dev/null || true)
        [[ -n "$PID" ]] && echo "$PID" | xargs kill -KILL 2>/dev/null || true
    fi

    GW_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/v1/routers" 2>/dev/null || echo "000")
    if [[ "$GW_STATUS" == "200" ]]; then
        echo " [WARN] Gateway may still be running. Check processes manually."
    else
        echo " [OK] LLMGatewayV7 stopped."
    fi
fi

echo
echo " ========================================"
echo "  CinemaSeek stopped."
echo " ========================================"
echo
