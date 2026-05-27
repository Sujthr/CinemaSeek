# CinemaSeek

A semantic movie knowledge base powered by RAG (Retrieval-Augmented Generation). Ask about films by theme, mood, directorial style, or emotional tone — without knowing titles. The system retrieves answers from a corpus of 55 curated movie documents using FAISS vector search.

---

## Quick Start

### Windows

```bat
REM 1. Set up your API key
copy .env.example .env
REM Edit .env and add your GEMINI_API_KEY

REM 2. Start the gateway + index corpus (first run only, ~5-15 min)
start.bat

REM 3. Ask a question
query.bat "I want to watch something nostalgic and warm about old friendships"
```

### Linux / macOS / WSL

```bash
chmod +x start.sh stop.sh query.sh

# 1. Set up your API key
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY

# 2. Start the gateway + index corpus (first run only)
./start.sh

# 3. Ask a question
./query.sh "Which films deal with non-linear time and memory?"
```

---

## Multi-Key Gemini Support

The gateway pools all Gemini keys you provide and rotates through them automatically:
- **Round-robin** across all keys for every request
- **429 cooldown**: if a key hits a quota limit, it is cooled down for 60 seconds and the next key is tried immediately
- Works for both **chat requests** and **embeddings**

```env
GEMINI_API_KEY=your_primary_key
GEMINI_API_KEY_1=your_second_key
GEMINI_API_KEY_2=your_third_key
GEMINI_API_KEY_3=your_fourth_key
GEMINI_API_KEY_4=your_fifth_key
GEMINI_API_KEY_5=your_sixth_key
```

Get free Gemini keys at [aistudio.google.com/apikey](https://aistudio.google.com/apikey) (sign in with different Google accounts for up to 6 free keys).

### Other Providers (optional fallback)

```env
OPENAI_API_KEY=...
OPEN_ROUTER_API_KEY=...
GROQ_API_KEY=...
CEREBRAS_API_KEY=...
NVIDIA_API_KEY=...
GITHUB_ACCESS_TOKEN=...
```

---

## Architecture

```
User Query
    │
    ▼
agent7.py  ─── orchestration loop
    │
    ├── perception.py   ← goal decomposition (no MCP tool names in SYSTEM)
    ├── decision.py     ← choose tool or generate answer
    ├── action.py       ← execute MCP tool calls
    └── memory.py       ← FAISS hybrid retrieval + keyword fallback
            │
            ▼
        vector_index.py  ← IndexFlatIP, 768-dim, persisted to state/
            │
            ▼
        LLMGatewayV7  ← POST /v1/embed  (port 8107)
        nomic-embed-text (Ollama) / gemini-embedding-001 (fallback)
```

Built on the Session 7 agent architecture:
```
memory.read → perception.observe → decision.next_step → action.execute → memory.record_outcome
```

### MCP Tools (`mcp_server.py`)

| Tool | Description |
|---|---|
| `search_knowledge` | Semantic + keyword search over the FAISS index |
| `add_fact` | Store a new fact into the memory store |
| `index_url` | Fetch a URL, chunk its text, embed and store in memory |
| `read_file` | Read a file from the sandbox |
| `write_file` | Write a file to the sandbox |
| `list_files` | List files in the sandbox |
| `python_repl` | Execute Python code in a sandbox |
| `web_search` | Web search via Tavily (requires `TAVILY_API_KEY`) |

**Architectural constraint:** `index_url` and `search_knowledge` never appear inside Perception's SYSTEM prompt. Decision learns about tools exclusively from MCP descriptors.

---

## Corpus (55 Documents)

All documents are stored as Markdown files under `sandbox/corpus/`.

| Pattern | Count | Content |
|---------|-------|---------|
| `bollywood_*.md` | 20 | Bollywood film summaries: plot, director, themes, reception |
| `hollywood_*.md` | 20 | Hollywood film summaries: same structure |
| `director_*.md` | 10 | Director profiles: signature style, recurring themes, filmography |
| `genre_notes_*.md` | 5 | Genre primers: road movie, neo-noir, coming-of-age, dystopian sci-fi, ensemble drama |

### Bollywood Films (20)
Dil Chahta Hai, Lagaan, Gangs of Wasseypur, Dil Dhadakne Do, 3 Idiots, Taare Zameen Par, Queen, Andhadhun, Masaan, Tumbbad, Article 15, Dangal, Gully Boy, Kapoor and Sons, Pink, URI, Super 30, Mughal-E-Azam, Sholay, Bard of Blood

### Hollywood Films (20)
Eternal Sunshine of the Spotless Mind, Arrival, Moonlight, Parasite, Her, Interstellar, The Dark Knight, Inception, Whiplash, La La Land, Get Out, 12 Years a Slave, The Grand Budapest Hotel, Spotlight, The Revenant, Gravity, Ex Machina, Mad Max: Fury Road, Marriage Story, Joker

### Director Profiles (10)
Christopher Nolan, Anurag Kashyap, Zoya Akhtar, Bong Joon-ho, Denis Villeneuve, Michel Gondry, Wes Anderson, Alfonso Cuarón, David Lynch, Steven Spielberg

### Genre Notes (5)
Coming-of-Age, Dystopian Sci-Fi, Ensemble Drama, Neo-Noir, Road Movies

---

## Five Custom Queries

These queries require the indexed corpus — the agent cannot answer correctly without retrieving from it.

### 1. Mood/Tone Retrieval
```
I want to watch something that feels like a lazy Sunday afternoon —
nostalgic, warm, about old friendships reconnecting after years apart.
What would you recommend from the indexed films and why?
```

### 2. Directorial Signature
```
Which films in the indexed corpus show a director obsessed with
non-linear time and how memory shapes identity?
```

### 3. Cross-Cinema Theme Comparison
```
Which Bollywood films in the corpus deal with class conflict, and how
do they compare to the Hollywood films that handle the same theme?
```

### 4. Narrative Technique Synthesis
```
Across all indexed films, what narrative techniques do ensemble-cast
stories use to give each character a complete arc within a single film?
```

### 5. Durable Preference Memory (two runs)
```
Run 1: I generally prefer films that end ambiguously rather than with
       a resolved ending. Remember that preference.

Run 2: Given my preference, which films in the indexed corpus would
       I enjoy most?
```

---

## Scripts Reference

| Script | Platform | Purpose |
|---|---|---|
| `start.bat` | Windows | Start gateway, auto-index corpus on first run |
| `stop.bat` | Windows | Kill gateway process on port 8107 |
| `query.bat "..."` | Windows | Run a query via agent7.py |
| `start.sh` | Linux/macOS | Same as start.bat |
| `stop.sh` | Linux/macOS | Same as stop.bat |
| `query.sh "..."` | Linux/macOS | Same as query.bat |

---

## Setup (Manual)

### Prerequisites
- Python 3.11+
- [uv](https://docs.astral.sh/uv/) package manager
- LLMGatewayV7 (parent directory: `LLMGateway/llm_gatewayV7`)
- At least one API key (Gemini recommended — free tier available)

### Steps
```bash
# 1. Install dependencies
uv sync

# 2. Configure keys
cp .env.example .env   # then edit .env

# 3. Start gateway manually (or use start.bat / start.sh)
cd ../LLMGateway/llm_gatewayV7
uv run main.py

# 4. Index corpus (first time only)
cd /path/to/Solution1_CinemaSeek
uv run index_corpus.py

# 5. Run a query
uv run agent7.py "your question"

# Re-index from scratch
rm -rf state/
uv run index_corpus.py
```

---

## FAISS Index Details

- **Dimension:** 768 (fixed — do not change embedding model after first index build)
- **Index type:** `IndexFlatIP` (inner product on L2-normalized vectors = cosine similarity)
- **Persistence:** `state/index.faiss`, `state/index_ids.json`, `state/memory.json`
- **Chunking:** 400-word sliding window, 80-word overlap (~160–180 total chunks)
- **Embedding models:** `nomic-embed-text` (Ollama, primary) → `gemini-embedding-001` (Gemini, fallback)

---

## Logging

| Log | Location |
|---|---|
| Agent run | stdout |
| MCP server | `mcp_server.log` |
| Corpus indexing | `index_corpus.log` |

---

## Architectural Constraints

1. No MCP tool names inside `perception.py`'s SYSTEM string (grep gate: zero matches)
2. Embedding model fixed at 768-dim — changing it invalidates the entire FAISS index
3. `state/` directory persists across runs — Query 5 Run 2 depends on this
4. `index_url` tool name exists only in `mcp_server.py`, never leaked into Perception
