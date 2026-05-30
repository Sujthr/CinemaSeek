"""Bridge to LLMGatewayV7 — CinemaSeek edition.

Points to the LLMGatewayV7 at its absolute location under the EAG tree.
Auto-starts the gateway on port 8107 if it is not already up, then
re-exports the V7 `LLM` client and a module-level `embed()` helper.
"""

from __future__ import annotations

import logging
import subprocess
import sys
import time
from pathlib import Path

import httpx

logger = logging.getLogger(__name__)

# Absolute path to the LLMGatewayV7 directory.
GATEWAY_V7_DIR = Path("D:/EAG/EAG/Class 23 May/LLMGateway/llm_gatewayV7")
GATEWAY_URL = "http://localhost:8107"


def _is_up() -> bool:
    try:
        httpx.get(f"{GATEWAY_URL}/v1/routers", timeout=2.0)
        return True
    except Exception:
        return False


def ensure_gateway() -> None:
    """Start V7 if it is not already running. Idempotent."""
    if _is_up():
        return
    if not GATEWAY_V7_DIR.exists():
        raise RuntimeError(
            f"Gateway V7 directory not found at {GATEWAY_V7_DIR}. "
            "Ensure LLMGatewayV7 exists at the expected path before running."
        )
    logger.info(f"[gateway] launching LLMGatewayV7 from {GATEWAY_V7_DIR}")
    print(f"[gateway] launching LLMGatewayV7 from {GATEWAY_V7_DIR}")
    subprocess.Popen(
        ["uv", "run", "main.py"],
        cwd=str(GATEWAY_V7_DIR),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    for _ in range(45):
        time.sleep(1)
        if _is_up():
            logger.info(f"[gateway] up on {GATEWAY_URL}")
            print(f"[gateway] up on {GATEWAY_URL}")
            return
    raise RuntimeError(f"Gateway V7 failed to start within 45s. Check {GATEWAY_V7_DIR}")


# Load V7's client.py without polluting sys.path.
import importlib.util as _importlib_util

_client_path = GATEWAY_V7_DIR / "client.py"
if _client_path.exists():
    _spec = _importlib_util.spec_from_file_location("llm_gatewayV7_client", _client_path)
    _mod = _importlib_util.module_from_spec(_spec)
    _spec.loader.exec_module(_mod)
    _BaseLLM = _mod.LLM
else:
    _BaseLLM = None


class LLM:
    """Thin wrapper around the gateway LLM client that retries on 502/503."""

    def __init__(self, *args, **kwargs):
        self._inner = _BaseLLM(*args, **kwargs) if _BaseLLM else None

    def _retry(self, fn, *args, retries=5, **kwargs):
        import httpx as _httpx
        for attempt in range(retries):
            try:
                return fn(*args, **kwargs)
            except _httpx.HTTPStatusError as e:
                if e.response.status_code in (429, 502, 503) and attempt < retries - 1:
                    # Waits: 20, 40, 60, 80s — covers 1-min TPM rate-limit windows
                    wait = 20 * (attempt + 1)
                    print(f"[gateway] {e.response.status_code} on attempt {attempt+1}, retrying in {wait}s…")
                    time.sleep(wait)
                else:
                    raise

    def chat(self, *args, **kwargs):
        return self._retry(self._inner.chat, *args, **kwargs)

    def embed(self, *args, **kwargs):
        return self._retry(self._inner.embed, *args, **kwargs)

    def stream(self, *args, **kwargs):
        return self._inner.stream(*args, **kwargs)

    def capabilities(self):
        return self._inner.capabilities()


def embed(text: str, task_type: str = "retrieval_document") -> dict:
    """Compute an embedding for `text` via the gateway's V7 embed endpoint.

    Returns the full response dict: `{embedding, dim, model, provider,
    latency_ms, ...}`. The chosen embedding model is fixed at the gateway
    level. Changing it invalidates every FAISS index built against the old
    vectors.
    """
    ensure_gateway()
    if LLM is None:
        raise RuntimeError(
            "Gateway V7 client unavailable. Confirm LLMGatewayV7/client.py exists."
        )
    return LLM().embed(text, task_type=task_type)


__all__ = ["ensure_gateway", "LLM", "GATEWAY_URL", "GATEWAY_V7_DIR", "embed"]
