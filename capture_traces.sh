#!/usr/bin/env bash
# Run all base queries A-H and custom queries 1-5, saving traces.
# Usage: bash capture_traces.sh [base|custom|all]

set -e
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

TRACES_BASE="traces/base"
TRACES_CUSTOM="traces/custom"
mkdir -p "$TRACES_BASE" "$TRACES_CUSTOM"

run_query() {
    local label="$1"
    local query="$2"
    local outfile="$3"
    echo ""
    echo "================================================================"
    echo "Running [$label]: ${query:0:80}..."
    echo "================================================================"
    uv run python agent7.py "$query" 2>&1 | tee "$outfile"
    echo ""
    echo "Saved to $outfile"
}

MODE="${1:-all}"

if [[ "$MODE" == "base" || "$MODE" == "all" ]]; then
    echo "=== BASE QUERIES ==="

    # Clear state before A (fresh start)
    rm -f state/memory.json state/index.faiss state/index_ids.json

    # Query A: Shannon Wikipedia
    run_query "A" \
        "Fetch https://en.wikipedia.org/wiki/Claude_Shannon and tell me his birth date, death date, and three key contributions to information theory." \
        "$TRACES_BASE/A.txt"

    # Query B: Tokyo activities + weather
    run_query "B" \
        "Find 3 family-friendly things to do in Tokyo this weekend. Check Saturday's weather forecast there and tell me which one is most appropriate." \
        "$TRACES_BASE/B.txt"

    # Query C Run 1: Store birthday
    run_query "C1" \
        "My mom's birthday is 15 May 2026. Remember that and create reminders for two weeks before and on the day." \
        "$TRACES_BASE/C1.txt"

    # Query C Run 2: Recall birthday (state persists from C1)
    run_query "C2" \
        "When is mom's birthday?" \
        "$TRACES_BASE/C2.txt"

    # Query D: Asyncio research
    run_query "D" \
        "Search for 'Python asyncio best practices', read the top 3 results, and give me a short numbered list of the advice they agree on." \
        "$TRACES_BASE/D.txt"

    # Clear state before E (new domain: papers)
    rm -f state/memory.json state/index.faiss state/index_ids.json

    # Query E: Index attention.md, extract transformer contributions
    run_query "E" \
        "Index the file papers/attention.md and tell me what the three key contributions of the Transformer architecture are according to this paper." \
        "$TRACES_BASE/E.txt"

    # Query F Run 1: Index all papers (state from E continues)
    run_query "F1" \
        "Index every .md file under papers/. Confirm how many chunks were indexed in total." \
        "$TRACES_BASE/F1.txt"

    # Query F Run 2: Fresh process, persisted state (NO state clear here)
    run_query "F2" \
        "Across the papers I have indexed, what do they say about chain-of-thought reasoning?" \
        "$TRACES_BASE/F2.txt"

    # Query G: Synonym recall (credit assignment)
    run_query "G" \
        "Across these papers, how do they handle the credit assignment problem?" \
        "$TRACES_BASE/G.txt"

    # Query H: Cross-document synthesis
    run_query "H" \
        "Compare how the ReAct paper and the Chain-of-Thought paper differ in their treatment of intermediate reasoning." \
        "$TRACES_BASE/H.txt"

    echo ""
    echo "=== BASE QUERIES COMPLETE ==="
fi

if [[ "$MODE" == "custom" || "$MODE" == "all" ]]; then
    echo ""
    echo "=== CUSTOM QUERIES (CinemaSeek corpus) ==="

    # Build movie corpus index (clear state from papers first)
    rm -f state/memory.json state/index.faiss state/index_ids.json
    echo "Indexing movie corpus..."
    uv run python index_corpus.py 2>&1 | tail -5

    # Custom Query 1: Lazy Sunday mood
    run_query "1" \
        "I want to watch something that feels like a lazy Sunday afternoon — nostalgic, warm, about old friendships reconnecting after years apart. What would you recommend from the indexed films and why?" \
        "$TRACES_CUSTOM/1_with_corpus.txt"

    # Custom Query 2: Director obsessed with non-linear time
    run_query "2" \
        "Which films in the indexed corpus show a director obsessed with non-linear time and how memory shapes identity?" \
        "$TRACES_CUSTOM/2_with_corpus.txt"

    # Custom Query 3: Class conflict comparison
    run_query "3" \
        "Which Bollywood films in the corpus deal with class conflict, and how do they compare to the Hollywood films that handle the same theme?" \
        "$TRACES_CUSTOM/3_with_corpus.txt"

    # Custom Query 4: Ensemble narrative techniques
    run_query "4" \
        "Across all indexed films, what narrative techniques do ensemble-cast stories use to give each character a complete arc within a single film?" \
        "$TRACES_CUSTOM/4_with_corpus.txt"

    # Custom Query 5 Run 1: Store preference
    run_query "5_run1" \
        "I generally prefer films that end ambiguously rather than with a resolved ending. Remember that preference." \
        "$TRACES_CUSTOM/5_run1_store_preference.txt"

    # Custom Query 5 Run 2: Query with preference
    run_query "5_run2" \
        "Given my preference, which films in the indexed corpus would I enjoy most?" \
        "$TRACES_CUSTOM/5_run2_query.txt"

    echo ""
    echo "=== CUSTOM QUERIES COMPLETE ==="
fi

echo ""
echo "All traces saved to traces/"
ls -la "$TRACES_BASE/" "$TRACES_CUSTOM/"
