#!/usr/bin/env bash
# ============================================================
#  CinemaSeek — Query Wrapper (Linux / macOS / WSL)
#  Usage:  ./query.sh "your question here"
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -eq 0 ]]; then
    echo
    echo " Usage:  ./query.sh \"your question here\""
    echo
    echo " Examples:"
    echo "   ./query.sh \"I want to watch something nostalgic and warm...\""
    echo "   ./query.sh \"Which films deal with non-linear time?\""
    echo "   ./query.sh \"Compare Bollywood and Hollywood class-conflict films\""
    echo
    exit 1
fi

cd "$SCRIPT_DIR"
uv run agent7.py "$@"
