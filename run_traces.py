"""run_traces.py — Execute base queries A-H and custom queries, save traces.

Usage:
    uv run run_traces.py base        # run queries A-H
    uv run run_traces.py custom      # run 5 custom queries (with + without corpus)
    uv run run_traces.py all         # run everything
    uv run run_traces.py single A    # run single query by label
"""

from __future__ import annotations

import asyncio
import json
import sys
import time
from pathlib import Path
from io import StringIO
import contextlib

TRACES_DIR = Path("traces")
BASE_DIR = TRACES_DIR / "base"
CUSTOM_DIR = TRACES_DIR / "custom"
BASE_DIR.mkdir(parents=True, exist_ok=True)
CUSTOM_DIR.mkdir(parents=True, exist_ok=True)

# ── Base Queries A-H (verbatim from PDF) ─────────────────────────────────────

BASE_QUERIES = {
    "A": "Fetch https://en.wikipedia.org/wiki/Claude_Shannon and tell me his birth date, death date, and three key contributions to information theory.",
    "B": "Find 3 family-friendly things to do in Tokyo this weekend. Check Saturday's weather forecast there and tell me which one is most appropriate.",
    "C1": "My mom's birthday is 15 May 2026. Remember that and create reminders for two weeks before and on the day.",
    "C2": "When is mom's birthday?",
    "D": "Search for 'Python asyncio best practices', read the top 3 results, and give me a short numbered list of the advice they agree on.",
    "E": "Index the file papers/attention.md and tell me what the three key contributions of the Transformer architecture are according to this paper.",
    "F1": "Index every .md file under papers/. Confirm how many chunks were indexed in total.",
    "F2": "Across the papers I have indexed, what do they say about chain-of-thought reasoning?",
    "G": "Across these papers, how do they handle the credit assignment problem?",
    "H": "Compare how the ReAct paper and the Chain-of-Thought paper differ in their treatment of intermediate reasoning.",
}

# ── Custom Queries (CinemaSeek corpus) ───────────────────────────────────────

CUSTOM_QUERIES = {
    "1": "I want to watch something that feels like a lazy Sunday afternoon — nostalgic, warm, about old friendships reconnecting after years apart. What would you recommend from the indexed films and why?",
    "2": "Which films in the indexed corpus show a director obsessed with non-linear time and how memory shapes identity?",
    "3": "Which Bollywood films in the corpus deal with class conflict, and how do they compare to the Hollywood films that handle the same theme?",
    "4": "Across all indexed films, what narrative techniques do ensemble-cast stories use to give each character a complete arc within a single film?",
    "5_pref": "I generally prefer films that end ambiguously rather than with a resolved ending. Remember that preference.",
    "5_query": "Given my preference, which films in the indexed corpus would I enjoy most?",
}


async def run_query(query: str) -> tuple[str, str]:
    """Run a query and return (stdout_trace, final_answer)."""
    import agent7

    buf = StringIO()
    with contextlib.redirect_stdout(buf):
        result = await agent7.run(query)
    return buf.getvalue(), result


def save_trace(path: Path, query: str, trace: str, answer: str, duration_s: float) -> None:
    data = {
        "query": query,
        "duration_seconds": round(duration_s, 2),
        "final_answer": answer,
        "trace": trace,
    }
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"  saved → {path}  ({len(trace)} chars, {duration_s:.1f}s)")


async def run_base_queries(labels: list[str] | None = None) -> None:
    """Run base queries A-H in the correct order."""
    order = ["A", "B", "C1", "C2", "D", "E", "F1", "F2", "G", "H"]
    if labels:
        order = [l for l in order if l in labels]

    # C2, F2, G, H depend on state from prior runs — warn if running out of order
    state_dependent = {"C2", "F2", "G", "H"}
    for label in order:
        if label in state_dependent and "F1" not in order and label in {"F2", "G", "H"}:
            print(f"[warn] {label} depends on F1 indexing papers — ensure F1 ran first")

    for label in order:
        q = BASE_QUERIES[label]
        print(f"\n{'━'*70}")
        print(f"[base/{label}] {q[:80]}...")
        t0 = time.time()
        trace, answer = await run_query(q)
        elapsed = time.time() - t0
        save_trace(BASE_DIR / f"{label}.json", q, trace, answer, elapsed)


async def run_custom_queries() -> None:
    """Run 5 custom queries, each with corpus (correct answer) and without."""
    # Build corpus index first if not done
    print("\n[custom] Ensuring corpus is indexed...")
    import index_corpus  # noqa: F401 — runs at import
    # Actually index_corpus needs to be run as a script; call it
    import subprocess, sys as _sys
    result = subprocess.run(
        [_sys.executable, "index_corpus.py"],
        capture_output=True, text=True, cwd=Path(__file__).parent
    )
    if result.returncode != 0:
        print(f"[warn] index_corpus.py failed:\n{result.stderr[:500]}")
    else:
        print(f"[corpus] {result.stdout.strip()[-200:]}")

    for label, q in [("1", CUSTOM_QUERIES["1"]),
                      ("2", CUSTOM_QUERIES["2"]),
                      ("3", CUSTOM_QUERIES["3"]),
                      ("4", CUSTOM_QUERIES["4"])]:
        print(f"\n{'━'*70}")
        print(f"[custom/{label}] {q[:80]}...")
        t0 = time.time()
        trace, answer = await run_query(q)
        elapsed = time.time() - t0
        save_trace(CUSTOM_DIR / f"{label}_with_corpus.json", q, trace, answer, elapsed)

    # Query 5: two runs
    print(f"\n{'━'*70}")
    print("[custom/5] Run 1 — store preference...")
    t0 = time.time()
    trace1, ans1 = await run_query(CUSTOM_QUERIES["5_pref"])
    elapsed1 = time.time() - t0
    save_trace(CUSTOM_DIR / "5_run1_store_preference.json", CUSTOM_QUERIES["5_pref"], trace1, ans1, elapsed1)

    print("[custom/5] Run 2 — query with preference...")
    t0 = time.time()
    trace2, ans2 = await run_query(CUSTOM_QUERIES["5_query"])
    elapsed2 = time.time() - t0
    save_trace(CUSTOM_DIR / "5_run2_query.json", CUSTOM_QUERIES["5_query"], trace2, ans2, elapsed2)


async def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "all"
    label = sys.argv[2].upper() if len(sys.argv) > 2 else None

    if mode == "single" and label:
        q = BASE_QUERIES.get(label) or CUSTOM_QUERIES.get(label.lower())
        if not q:
            print(f"Unknown label: {label}")
            sys.exit(1)
        t0 = time.time()
        trace, answer = await run_query(q)
        elapsed = time.time() - t0
        out = BASE_DIR if label in BASE_QUERIES else CUSTOM_DIR
        save_trace(out / f"{label}.json", q, trace, answer, elapsed)
    elif mode == "base":
        await run_base_queries()
    elif mode == "custom":
        await run_custom_queries()
    else:
        await run_base_queries()
        await run_custom_queries()


if __name__ == "__main__":
    asyncio.run(main())
