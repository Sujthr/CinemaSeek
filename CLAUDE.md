# Solution 1 — CinemaSeek: Semantic Movie Knowledge Base

## What This Is

A RAG application that answers questions about films by reasoning across a
corpus of 55 movie knowledge documents. Users can ask about themes, directorial
styles, narrative techniques, and emotional tones **without knowing movie titles**.
The application must retrieve from the index to answer; without the index, the
agent has no corpus knowledge at all.

## Why This Domain

Film knowledge is a strong test for semantic retrieval: the words a user reaches
for ("melancholy road movie", "found-family story") rarely appear in the plot
summaries that answer the question. Keyword search returns nothing; the vector
path must carry the retrieval load. This makes all five custom queries genuinely
dependent on the embedding layer.

---

## Corpus

**55 documents** stored as Markdown files under `sandbox/corpus/`.

| File pattern | Count | Content |
|---|---|---|
| `bollywood_*.md` | 20 | Wikipedia-derived summaries: plot, director, themes, critical reception for Bollywood films (e.g. Dil Chahta Hai, Lagaan, Gangs of Wasseypur, Dil Dhadakne Do) |
| `hollywood_*.md` | 20 | Same structure for Hollywood films (e.g. Eternal Sunshine, Her, Arrival, Moonlight, Parasite) |
| `director_*.md` | 10 | Director profiles: recurring themes, signature styles, filmography overview (Anurag Kashyap, Zoya Akhtar, Christopher Nolan, Bong Joon-ho, etc.) |
| `genre_notes_*.md` | 5 | Genre primers: what defines road movies, neo-noir, coming-of-age films, dystopian sci-fi, and ensemble dramas |

Each document is **400–800 words**. Total indexed chunks after 400-word sliding window
with 80-word overlap: approximately **160–180 chunks**.

### Corpus Manifest (top-level README will list all 55 filenames)

The 20 Bollywood titles are drawn from IMDb Top-250 India list (public data).
The 20 Hollywood titles are drawn from IMDb Top-250 worldwide.
Director profiles are synthesised from Wikipedia public-domain text.
Genre notes are original writing.

---

## Architecture

### Reuse from S7

- **agent7.py** — orchestrator loop, unchanged
- **memory.py** — FAISS-backed hybrid retrieval (vector first, keyword fallback)
- **perception.py** — goal decomposition, attach hints, zero MCP tool names in SYSTEM
- **decision.py** — tool dispatch or answer, unchanged
- **action.py** — MCP call executor, unchanged
- **gateway.py** — `ensure_gateway()` pointing at LLMGatewayV7 on port 8107
- **vector_index.py** — FAISS IndexFlatIP, 768-dim, persisted to `state/`
- **schemas.py** — unchanged Pydantic contracts
- **LLMGatewayV7** — `POST /v1/embed` with nomic-embed-text / gemini-embedding-001 fallback

### New MCP Tool: `index_url(url)`

The corpus includes some documents fetched live from Wikipedia rather than
pre-written. A new MCP tool `index_url(url)` is added to `mcp_server.py`:

```
Tool name:   index_url
Description: Fetch the page at <url>, extract its main text, chunk it with
             a 400-word sliding window and 80-word overlap, embed each chunk
             via the gateway's /v1/embed endpoint, and store the chunks as
             fact items in Memory. Returns the number of chunks written.
             Use this when the user wants to index an online article or
             Wikipedia page into the knowledge base.
Arguments:   { "url": "<string>" }
```

**Architectural constraint respected:** The tool name `index_url` never appears
inside Perception's SYSTEM prompt. Decision learns about it exclusively through
the MCP tool descriptor (name + description + input_schema). The grep gate passes.

### FAISS Index

- Dimension: 768 (fixed, nomic-embed-text / gemini-embedding-001)
- Index type: IndexFlatIP (inner product on L2-normalised vectors = cosine similarity)
- Persistence: `state/index.faiss`, `state/index_ids.json`, `state/memory.json`
- Chunk metadata stored in MemoryItem.descriptor: `[corpus:bollywood_dil_chahta_hai.md chunk 3/7]`

---

## Five Custom Queries

All five are designed to **answer correctly with the indexed corpus** and **fail
without it** (the agent has no prior knowledge of these films loaded in context).

### Query 1 — Semantic: Tone/mood without film title

```
I want to watch something that feels like a lazy Sunday afternoon —
nostalgic, warm, about old friendships reconnecting after years apart.
What would you recommend from the indexed films and why?
```

**Why it requires the index:** The words "lazy Sunday", "nostalgic", "warm"
do not appear in any chunk. Chunks about Dil Chahta Hai use words like
"friendship", "Goa trip", "carefree youth". The vector path bridges the
semantic gap; keyword search returns nothing.

**Without index:** Agent can only offer generic recommendations from training
data, not from the indexed 55 documents.

### Query 2 — Semantic: Directorial signature without naming the director

```
Which films in the indexed corpus show a director obsessed with
non-linear time and how memory shapes identity?
```

**Why it requires the index:** Director profile chunks use "non-linear narrative",
"temporal fragmentation", "subjective memory" — not the user's phrasing
"obsessed with non-linear time". Semantic retrieval connects the query to
Nolan's profile and to Eternal Sunshine's description.

**Without index:** Agent cannot answer from indexed documents at all.

### Query 3 — Keyword-possible but richer with vector: Genre cross-reference

```
Which Bollywood films in the corpus deal with class conflict, and how
do they compare to the Hollywood films that handle the same theme?
```

**Why it requires the index:** "Class conflict" appears in some chunks but
not uniformly — e.g. Gangs of Wasseypur uses "power", "hierarchy", "feudal".
The vector path retrieves semantically related chunks the keyword path misses,
enabling a fuller cross-document synthesis.

**Without index:** Agent has no corpus to compare across.

### Query 4 — Cross-document synthesis: Ensemble films

```
Across all indexed films, what narrative techniques do ensemble-cast
stories use to give each character a complete arc within a single film?
```

**Why it requires the index:** The answer requires synthesising chunks from
at least 5–6 different film documents (Dil Dhadakne Do, Gangs of Wasseypur,
Parasite, etc.) plus the ensemble-drama genre note. No single chunk answers
this; synthesis across the persisted index is mandatory.

**Without index:** Agent cannot synthesise across the indexed corpus.

### Query 5 — Durable memory + retrieval: Preference carry-over

```
Run 1:  I generally prefer films that end ambiguously rather than with
        a resolved ending. Remember that preference.

Run 2:  Given my preference, which films in the indexed corpus would
        I enjoy most?
```

**Why it requires the index:** Run 2 requires (a) recalling the stored
preference via FAISS and (b) querying the film corpus for ambiguous endings.
Both retrieval paths — preference memory and document corpus — are exercised.

**Without index:** Run 2 cannot match the preference to any indexed film knowledge.

---

## Architectural Constraints

1. **Perception SYSTEM grep gate:** zero MCP tool names inside Perception's
   SYSTEM prompt. `index_url` and `search_knowledge` live only in Decision's
   tool descriptor list.

2. **Embedding model is fixed:** nomic-embed-text at 768 dim via LLMGatewayV7.
   `EMBED_OLLAMA_MODEL` must not change after first index build.

3. **FAISS index persists across runs:** `state/` directory survives between
   agent invocations. Query 5 Run 2 depends on this.

4. **No MCP tool name leakage into Perception SYSTEM:** enforced by grep
   `grep -n "index_url\|index_document\|search_knowledge\|fetch_url" perception.py`
   must return zero matches inside the SYSTEM string.

---

## File Layout (to be created during development)

```
Solution1_CinemaSeek/
├── CLAUDE.md               ← this file
├── agent7.py               ← copied from S7, unchanged
├── perception.py           ← copied from S7, unchanged
├── decision.py             ← copied from S7, unchanged
├── action.py               ← copied from S7, unchanged
├── memory.py               ← copied from S7, unchanged
├── vector_index.py         ← copied from S7, unchanged
├── artifacts.py            ← copied from S7, unchanged
├── schemas.py              ← copied from S7, unchanged
├── gateway.py              ← copied from S7, unchanged
├── mcp_server.py           ← S7 base + new index_url tool
├── requirements.txt
├── pyproject.toml
├── sandbox/
│   └── corpus/
│       ├── bollywood_dil_chahta_hai.md
│       ├── bollywood_lagaan.md
│       ├── ... (18 more bollywood_*.md)
│       ├── hollywood_eternal_sunshine.md
│       ├── hollywood_arrival.md
│       ├── ... (18 more hollywood_*.md)
│       ├── director_nolan.md
│       ├── director_kashyap.md
│       ├── ... (8 more director_*.md)
│       ├── genre_notes_road_movie.md
│       └── ... (4 more genre_notes_*.md)
└── state/                  ← FAISS index + memory (created at runtime)
```

---

## How to Run (once developed)

```bash
# 1. Start LLMGatewayV7
cd /path/to/LLMGateway/llm_gatewayV7
./run.sh

# 2. Index the corpus (first time only — state/ persists)
uv run agent7.py "Index every .md file under corpus/. Confirm total chunks indexed."

# 3. Run custom queries
uv run agent7.py "I want to watch something that feels like a lazy Sunday afternoon..."

# 4. Run base queries A-H
uv run agent7.py "Fetch https://en.wikipedia.org/wiki/Claude_Shannon and tell me his birth date..."
```

---

## Submission Checklist

- [ ] 55 corpus documents committed under `sandbox/corpus/`
- [ ] 8 base query traces (A–H) in `traces/base/`
- [ ] 5 custom query traces + no-corpus comparisons in `traces/custom/`
- [ ] README with corpus manifest
- [ ] Short demo video
