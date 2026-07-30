# Academic Papers Module

> Strategy module extracted from web-search-agent.md: academic paper search specific

**Trigger scenarios**: paper lookup, academic research, algorithm fundamentals

## Search Sources (Academic Sources)
- **Google Scholar** (scholar.google.com) - comprehensive academic search engine
- **arXiv** (arxiv.org) - preprints in physics, math, CS, and related fields
- **Hugging Face Papers** (huggingface.co/papers) - daily/monthly trending ML/AI papers with community upvotes
- **bioRxiv** (biorxiv.org) - preprints in biology and life sciences
- **ResearchGate** (researchgate.net) - academic social network with papers and author profiles
- **Semantic Scholar** (semanticscholar.org) - AI-powered academic search
- **ACM Digital Library** and **IEEE Xplore** - CS and engineering papers

## API Query Tools (Preferred for Paper Lookup)

Three helper scripts provide direct academic API access via Bash. **Prefer these over
WebSearch/WebFetch** for: finding papers by topic/author/id, resolving DOIs/arXiv ids,
citation counts, citation/reference traversal, and PDF links. Use web search instead for:
discussions, blog explanations, community reception, and implementation writeups.

Invoke with unquoted paths (the leading `~` must tilde-expand):

- **arXiv** — preprint search and id lookup:
  `python3 {{AGENTS_DIR}}/web-search-modules/scripts/arxiv-search.py "query" --category cs.LG --max 10 --sort date`
  `python3 {{AGENTS_DIR}}/web-search-modules/scripts/arxiv-search.py --id 1706.03762`
  Terms are ANDed; wrap the query in embedded double quotes for an exact phrase
  (`'"speculative decoding"'`). `--author`/`--category` may be used without a query.

- **Semantic Scholar** — relevance search, per-paper details (incl. TLDR), citations/references:
  `python3 {{AGENTS_DIR}}/web-search-modules/scripts/s2-search.py search "query" --year 2022-2025 --min-citations 50`
  `python3 {{AGENTS_DIR}}/web-search-modules/scripts/s2-search.py citations ARXIV:2201.11903 --max 20`
  Keyless but rate-limited; on a persistent 429, fall back to OpenAlex. A key raises the
  limit (S2_API_KEY env var, or `machine api.semanticscholar.org` password in ~/.netrc).

- **OpenAlex** — broad scholarly index, best for citation-count filtering/sorting and OA PDFs:
  `python3 {{AGENTS_DIR}}/web-search-modules/scripts/openalex-search.py "query" --from-year 2021 --sort cited --oa-only`

Workflow: API search first -> pick candidates -> `s2-search.py paper <id>` for details ->
citations/references for the network -> WebSearch only for surrounding discussion.

## Query Strategy (1.3 Academic Paper Search)
- Use Google Scholar as primary source with advanced search operators
- Search by author names, paper titles, DOI numbers, institutions, and publication years
- Use quotation marks for exact titles and author name combinations
- Include year ranges to find seminal works and recent publications
- Look for related papers and citation patterns to identify seminal works
- Search for preprints on arXiv, bioRxiv, and institutional repositories
- Check author profiles and ResearchGate for publications and PDFs
- Identify open-access versions and legal paper download sources
- Track citation networks to understand research evolution
- Note impact factors, h-index, and citation counts for relevance assessment
- Search for conference proceedings, journals, and workshop papers
- Identify funding agencies and research grants for context
- Start with the API tools above for any paper lookup, metadata, or citation task; fall back to Google Scholar via WebSearch when APIs return nothing
- Cross-check citation counts between Semantic Scholar and OpenAlex when impact matters
