#!/usr/bin/env python3
"""Query the Semantic Scholar Graph API (https://api.semanticscholar.org/graph/v1).

Usage:
  s2-search.py search "query" [--max 10] [--year 2020-2024] [--min-citations 50] [--fields tldr,venue] [--json]
  s2-search.py paper <id> [--json]
  s2-search.py citations <id> [--max 20] [--json]
  s2-search.py references <id> [--max 20] [--json]

<id> accepts Semantic Scholar paper ids or prefixed external ids, e.g. ARXIV:2201.11903, DOI:10.xxxx.

An API key raises the rate limit; it is looked up as the S2_API_KEY env var, falling back
to the password field of a `machine api.semanticscholar.org` entry in ~/.netrc, and sent as
the x-api-key header. On HTTP 429 the script retries with 2s/5s/11s backoff before giving up.

Exit codes: 0 success, 1 API/network error, 2 usage error.
"""

import argparse
import json
import netrc
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

API_BASE = "https://api.semanticscholar.org/graph/v1"
API_HOST = "api.semanticscholar.org"
USER_AGENT = "agents-web-search-agent/1.0 (academic-paper-lookup)"
TIMEOUT = 30
MAX_CAP = 50
TEXT_WORD_LIMIT = 60
RETRY_DELAYS = [2, 5, 11]

SEARCH_FIELDS = "title,authors,year,venue,citationCount,externalIds,abstract"
PAPER_FIELDS = "title,authors,year,venue,citationCount,externalIds,abstract,tldr,openAccessPdf"
LIST_FIELDS = "title,authors,year,venue,citationCount,externalIds"


def truncate_words(text, limit=TEXT_WORD_LIMIT):
    if not text:
        return ""
    text = " ".join(text.split())
    words = text.split(" ")
    if len(words) <= limit:
        return text
    return " ".join(words[:limit]) + " ..."


def get_api_key():
    api_key = os.environ.get("S2_API_KEY")
    if api_key:
        return api_key
    try:
        auth = netrc.netrc().authenticators(API_HOST)
    except (FileNotFoundError, netrc.NetrcParseError):
        return None
    return auth[2] if auth else None


def fetch_json(url):
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    api_key = get_api_key()
    if api_key:
        headers["x-api-key"] = api_key

    req = urllib.request.Request(url, headers=headers)

    last_err = None
    for attempt, delay in enumerate([0] + RETRY_DELAYS):
        if delay:
            time.sleep(delay)
        try:
            with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code == 429:
                last_err = e
                continue
            raise
    raise last_err


def print_human_papers(papers):
    if not papers:
        print("No results found.")
        return
    for p in papers:
        if p is None:
            continue
        title = p.get("title", "")
        year = p.get("year", "")
        venue = p.get("venue", "") or ""
        cited = p.get("citationCount", "")
        ext_ids = p.get("externalIds") or {}
        ext_str = ", ".join(f"{k}:{v}" for k, v in ext_ids.items()) if ext_ids else ""
        authors = [a.get("name", "") for a in (p.get("authors") or [])]
        author_str = ", ".join(authors[:5]) + (f" (+{len(authors) - 5} more)" if len(authors) > 5 else "")
        tldr = (p.get("tldr") or {}).get("text") if isinstance(p.get("tldr"), dict) else None
        text = tldr or p.get("abstract") or ""

        print(title)
        print(f"{year} | {venue} | cited by {cited}")
        if ext_str:
            print(ext_str)
        if author_str:
            print(author_str)
        if text:
            print(truncate_words(text))
        pdf = p.get("openAccessPdf")
        if pdf and pdf.get("url"):
            print(pdf["url"])
        print()


def print_json_papers(papers):
    for p in papers:
        if p is None:
            continue
        print(json.dumps(p))


def cmd_search(args):
    max_results = min(args.max, MAX_CAP) if args.max > 0 else None
    if not max_results:
        print("ERROR: --max must be a positive integer", file=sys.stderr)
        return 2

    fields = SEARCH_FIELDS
    if args.fields:
        extra = [f.strip() for f in args.fields.split(",") if f.strip()]
        existing = set(fields.split(","))
        fields = fields + "," + ",".join(f for f in extra if f not in existing)

    params = {"query": args.query, "limit": max_results, "fields": fields}
    if args.year:
        params["year"] = args.year
    if args.min_citations is not None:
        params["minCitationCount"] = args.min_citations

    url = f"{API_BASE}/paper/search?{urllib.parse.urlencode(params)}"
    data = fetch_json(url)
    papers = data.get("data", [])
    if args.json:
        print_json_papers(papers)
    else:
        print_human_papers(papers)
    return 0


def cmd_paper(args):
    pid = urllib.parse.quote(args.id, safe=":")
    url = f"{API_BASE}/paper/{pid}?fields={PAPER_FIELDS}"
    data = fetch_json(url)
    if args.json:
        print(json.dumps(data))
    else:
        print_human_papers([data])
    return 0


def cmd_related(args, endpoint):
    max_results = min(args.max, MAX_CAP) if args.max > 0 else None
    if not max_results:
        print("ERROR: --max must be a positive integer", file=sys.stderr)
        return 2
    pid = urllib.parse.quote(args.id, safe=":")
    # /citations returns entries wrapping the citing paper under "citingPaper";
    # /references returns entries wrapping the referenced paper under "citedPaper".
    key = "citingPaper" if endpoint == "citations" else "citedPaper"
    params = {"limit": max_results, "fields": LIST_FIELDS}
    url = f"{API_BASE}/paper/{pid}/{endpoint}?{urllib.parse.urlencode(params)}"
    data = fetch_json(url)
    raw_list = data.get("data", [])
    papers = [item.get(key) for item in raw_list if item.get(key)]
    if args.json:
        print_json_papers(papers)
    else:
        print_human_papers(papers)
    return 0


def main():
    parser = argparse.ArgumentParser(description="Query the Semantic Scholar Graph API.")
    sub = parser.add_subparsers(dest="command")

    p_search = sub.add_parser("search", help="search papers by relevance")
    p_search.add_argument("query")
    p_search.add_argument("--max", type=int, default=10)
    p_search.add_argument("--year", help="year or year range, e.g. 2020-2024")
    p_search.add_argument("--min-citations", type=int, default=None)
    p_search.add_argument("--fields", help="extra comma-separated fields to request")
    p_search.add_argument("--json", action="store_true")

    p_paper = sub.add_parser("paper", help="fetch details for a single paper")
    p_paper.add_argument("id")
    p_paper.add_argument("--json", action="store_true")

    p_cit = sub.add_parser("citations", help="list papers citing this paper")
    p_cit.add_argument("id")
    p_cit.add_argument("--max", type=int, default=20)
    p_cit.add_argument("--json", action="store_true")

    p_ref = sub.add_parser("references", help="list papers referenced by this paper")
    p_ref.add_argument("id")
    p_ref.add_argument("--max", type=int, default=20)
    p_ref.add_argument("--json", action="store_true")

    args = parser.parse_args()

    if not args.command:
        parser.print_usage(sys.stderr)
        print("ERROR: a subcommand is required (search, paper, citations, references)", file=sys.stderr)
        return 2

    if args.command == "search" and not args.query.strip():
        print("ERROR: query must not be empty", file=sys.stderr)
        return 2

    try:
        if args.command == "search":
            return cmd_search(args)
        if args.command == "paper":
            return cmd_paper(args)
        if args.command == "citations":
            return cmd_related(args, "citations")
        if args.command == "references":
            return cmd_related(args, "references")
    except urllib.error.HTTPError as e:
        if e.code == 429:
            print(
                "ERROR: Semantic Scholar rate limit (429) persisted after retries. "
                "Wait a while and retry, or provide an API key (S2_API_KEY env var or "
                "a 'machine api.semanticscholar.org' entry in ~/.netrc) for a higher limit.",
                file=sys.stderr,
            )
        elif e.code == 404:
            print(f"ERROR: not found (HTTP 404) for id/query: {getattr(args, 'id', getattr(args, 'query', ''))}", file=sys.stderr)
        else:
            print(f"ERROR: Semantic Scholar API returned HTTP {e.code}: {e.reason}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"ERROR: failed to reach Semantic Scholar API: {e.reason}", file=sys.stderr)
        return 1
    except Exception as e:  # noqa: BLE001
        print(f"ERROR: unexpected failure querying Semantic Scholar API: {e}", file=sys.stderr)
        return 1

    return 2


if __name__ == "__main__":
    sys.exit(main())
