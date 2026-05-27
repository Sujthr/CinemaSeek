"""index_corpus.py — Index all .md files in sandbox/corpus/ into the FAISS memory store.

Run once before querying:
    uv run index_corpus.py

Reads every .md file directly, chunks with 400-word sliding window / 80-word
overlap, embeds via LLMGatewayV7, and stores in the FAISS index. The state/
directory persists across agent runs — this script only needs to run once
unless the corpus changes.

Architectural constraint: this script never appears inside perception.py's
SYSTEM prompt. The index_document and search_knowledge tool names do not
appear here either (we call memory.add_fact directly).
"""

from __future__ import annotations

import logging
import sys
from datetime import datetime
from pathlib import Path

# ── Logging setup ─────────────────────────────────────────────────────────────

LOG_PATH = Path(__file__).parent / "index_corpus.log"
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(str(LOG_PATH), encoding="utf-8"),
    ],
)
logger = logging.getLogger("index_corpus")

# Add project dir to path before local imports
sys.path.insert(0, str(Path(__file__).parent))

from gateway import ensure_gateway  # noqa: E402
import memory  # noqa: E402

CORPUS_DIR = Path(__file__).parent / "sandbox" / "corpus"
CHUNK_SIZE = 400
OVERLAP = 80


def chunk_text(text: str, size: int = CHUNK_SIZE, overlap: int = OVERLAP) -> list[str]:
    """Sliding-window chunker by word count — identical to MCP server's chunker."""
    words = text.split()
    if not words:
        return []
    chunks: list[str] = []
    stride = max(1, size - overlap)
    i = 0
    while i < len(words):
        chunks.append(" ".join(words[i : i + size]))
        if i + size >= len(words):
            break
        i += stride
    return chunks


def _keywords_for(stem: str) -> list[str]:
    """Extract search keywords from a filename stem like 'bollywood_dil_chahta_hai'."""
    parts = stem.replace("_", " ").split()
    return [p.lower() for p in parts if len(p) > 2]


def index_file(md_path: Path, run_id: str) -> int:
    """Index one .md file. Returns number of chunks indexed, 0 on failure."""
    try:
        text = md_path.read_text(encoding="utf-8")
    except OSError as e:
        logger.error(f"Cannot read {md_path.name}: {e}")
        return 0

    if not text.strip():
        logger.warning(f"Empty file skipped: {md_path.name}")
        return 0

    chunks = chunk_text(text)
    source = f"corpus:{md_path.name}"
    keywords = _keywords_for(md_path.stem)
    indexed = 0

    for i, chunk in enumerate(chunks):
        preview = chunk[:120].replace("\n", " ")
        descriptor = f"[{source} chunk {i+1}/{len(chunks)}] {preview}"
        try:
            memory.add_fact(
                descriptor=descriptor,
                value={
                    "chunk": chunk,
                    "chunk_index": i,
                    "total_chunks": len(chunks),
                    "source": source,
                    "filename": md_path.name,
                },
                keywords=keywords + [f"chunk_{i+1}"],
                source=source,
                run_id=run_id,
            )
            indexed += 1
        except Exception as e:
            logger.error(f"Failed to index chunk {i+1}/{len(chunks)} of {md_path.name}: {e!r}")

    return indexed


def main() -> int:
    """Entry point. Returns exit code."""
    logger.info("=" * 60)
    logger.info("CinemaSeek corpus indexer starting")
    logger.info("=" * 60)

    # Verify gateway is available (embeddings require it)
    try:
        ensure_gateway()
        logger.info("LLMGatewayV7 is up and accepting requests")
    except RuntimeError as e:
        logger.error(f"Gateway not available: {e}")
        logger.warning(
            "Continuing without gateway — fact items will be stored WITHOUT embeddings.\n"
            "Vector search will be empty; keyword fallback only.\n"
            "Start LLMGatewayV7 and re-run to get full vector search."
        )

    if not CORPUS_DIR.exists():
        logger.error(f"Corpus directory not found: {CORPUS_DIR}")
        logger.error("Create sandbox/corpus/ and populate it with .md files first.")
        return 1

    md_files = sorted(CORPUS_DIR.glob("*.md"))
    if not md_files:
        logger.error(f"No .md files found in {CORPUS_DIR}")
        return 1

    logger.info(f"Found {len(md_files)} corpus files in {CORPUS_DIR}")

    # Group by type for reporting
    bollywood = [f for f in md_files if f.name.startswith("bollywood_")]
    hollywood = [f for f in md_files if f.name.startswith("hollywood_")]
    directors = [f for f in md_files if f.name.startswith("director_")]
    genres = [f for f in md_files if f.name.startswith("genre_notes_")]
    other = [
        f for f in md_files
        if not any(f.name.startswith(p) for p in ("bollywood_", "hollywood_", "director_", "genre_notes_"))
    ]
    logger.info(
        f"Corpus breakdown: {len(bollywood)} Bollywood, {len(hollywood)} Hollywood, "
        f"{len(directors)} director profiles, {len(genres)} genre notes"
        + (f", {len(other)} other" if other else "")
    )

    run_id = f"corpus-index-{datetime.now().strftime('%Y%m%d%H%M%S')}"
    logger.info(f"Run ID: {run_id}")

    total_chunks = 0
    failed_files: list[str] = []

    for i, md_path in enumerate(md_files, 1):
        logger.info(f"[{i:02d}/{len(md_files)}] {md_path.name}")
        n = index_file(md_path, run_id)
        if n > 0:
            logger.info(f"        → {n} chunks indexed")
            total_chunks += n
        else:
            logger.warning(f"        → 0 chunks (file skipped or empty)")
            failed_files.append(md_path.name)

    logger.info("=" * 60)
    logger.info("Corpus indexing complete!")
    logger.info(f"  Files processed : {len(md_files)}")
    logger.info(f"  Files with 0 chunks: {len(failed_files)}")
    logger.info(f"  Total chunks indexed: {total_chunks}")
    logger.info(f"  Run ID: {run_id}")
    if failed_files:
        logger.warning(f"  Skipped files: {failed_files}")
    logger.info("=" * 60)
    logger.info(
        f"The index is persisted in state/. "
        "Run queries via: uv run agent7.py \"<your question>\""
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
