#!/usr/bin/env python3
"""Query the OpenAlex Works API (https://api.openalex.org/works).

Usage:
  openalex-search.py "query" [--max 10] [--from-year N] [--to-year N]
                      [--sort cited|relevance|date] [--min-citations N] [--oa-only] [--json]

Uses the "polite pool" via a mailto parameter, which gets faster and more consistent
response times. The email is looked up as the OPENALEX_MAILTO env var, falling back to
the login field of a `machine api.openalex.org` entry in ~/.netrc, then to a default.

Exit codes: 0 success, 1 API/network error, 2 usage error.
"""

import argparse
import json
import netrc
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API_URL = "https://api.openalex.org/works"
API_HOST = "api.openalex.org"
USER_AGENT = "agents-web-search-agent/1.0 (academic-paper-lookup)"
DEFAULT_MAILTO = "davisjustin302@gmail.com"
TIMEOUT = 30
MAX_CAP = 50
ABSTRACT_WORD_LIMIT = 60


def get_mailto():
    mailto = os.environ.get("OPENALEX_MAILTO")
    if mailto:
        return mailto
    try:
        auth = netrc.netrc().authenticators(API_HOST)
    except (FileNotFoundError, netrc.NetrcParseError):
        auth = None
    return auth[0] if auth and auth[0] else DEFAULT_MAILTO


def truncate_words(text, limit=ABSTRACT_WORD_LIMIT):
    if not text:
        return ""
    text = " ".join(text.split())
    words = text.split(" ")
    if len(words) <= limit:
        return text
    return " ".join(words[:limit]) + " ..."


def reconstruct_abstract(inverted_index):
    if not inverted_index:
        return ""
    positions = {}
    max_pos = 0
    for word, idxs in inverted_index.items():
        for i in idxs:
            positions[i] = word
            if i > max_pos:
                max_pos = i
    return " ".join(positions.get(i, "") for i in range(max_pos + 1)).strip()


def build_filters(args):
    filters = []
    if args.from_year:
        filters.append(f"from_publication_date:{args.from_year}-01-01")
    if args.to_year:
        filters.append(f"to_publication_date:{args.to_year}-12-31")
    if args.min_citations is not None:
        filters.append(f"cited_by_count:>{args.min_citations - 1}")
    if args.oa_only:
        filters.append("is_oa:true")
    return ",".join(filters)


def fetch_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return json.loads(resp.read())


def extract_work(w):
    title = w.get("display_name") or w.get("title") or ""
    year = w.get("publication_year", "")
    venue = ""
    primary_location = w.get("primary_location") or {}
    source = primary_location.get("source") or {}
    if source:
        venue = source.get("display_name", "") or ""
    cited_by = w.get("cited_by_count", "")
    doi = w.get("doi", "") or ""
    oa = w.get("open_access") or {}
    oa_pdf = oa.get("oa_url", "") or ""
    authors = [
        (a.get("author") or {}).get("display_name", "")
        for a in (w.get("authorships") or [])
    ]
    abstract = reconstruct_abstract(w.get("abstract_inverted_index"))

    return {
        "title": title,
        "year": year,
        "venue": venue,
        "cited_by_count": cited_by,
        "doi": doi,
        "oa_pdf_url": oa_pdf,
        "authors": authors,
        "abstract": abstract,
    }


def print_human(works):
    if not works:
        print("No results found.")
        return
    for w in works:
        authors = w["authors"]
        if len(authors) > 3:
            author_str = ", ".join(authors[:3]) + f" (+{len(authors) - 3} more)"
        else:
            author_str = ", ".join(authors)
        print(w["title"])
        print(f"{w['year']} | {w['venue']} | cited by {w['cited_by_count']}")
        if w["doi"]:
            print(w["doi"])
        if w["oa_pdf_url"]:
            print(w["oa_pdf_url"])
        if author_str:
            print(author_str)
        if w["abstract"]:
            print(truncate_words(w["abstract"]))
        print()


def print_json(works):
    for w in works:
        print(json.dumps(w))


def main():
    parser = argparse.ArgumentParser(description="Search OpenAlex works.")
    parser.add_argument("query")
    parser.add_argument("--max", type=int, default=10, help="max results (capped at 50)")
    parser.add_argument("--from-year", type=int, default=None)
    parser.add_argument("--to-year", type=int, default=None)
    parser.add_argument("--sort", choices=["cited", "relevance", "date"], default="relevance")
    parser.add_argument("--min-citations", type=int, default=None)
    parser.add_argument("--oa-only", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if not args.query.strip():
        print("ERROR: query must not be empty", file=sys.stderr)
        return 2

    max_results = args.max
    if max_results < 1:
        print("ERROR: --max must be a positive integer", file=sys.stderr)
        return 2
    if max_results > MAX_CAP:
        max_results = MAX_CAP

    params = {
        "search": args.query,
        "per-page": max_results,
        "mailto": get_mailto(),
    }

    filters = build_filters(args)
    if filters:
        params["filter"] = filters

    if args.sort == "cited":
        params["sort"] = "cited_by_count:desc"
    elif args.sort == "date":
        params["sort"] = "publication_date:desc"
    # relevance is the default OpenAlex sort when "search" is set; no sort param needed.

    url = f"{API_URL}?{urllib.parse.urlencode(params)}"

    try:
        data = fetch_json(url)
    except urllib.error.HTTPError as e:
        print(f"ERROR: OpenAlex API returned HTTP {e.code}: {e.reason}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"ERROR: failed to reach OpenAlex API: {e.reason}", file=sys.stderr)
        return 1
    except Exception as e:  # noqa: BLE001
        print(f"ERROR: unexpected failure querying OpenAlex API: {e}", file=sys.stderr)
        return 1

    results = data.get("results", [])
    works = [extract_work(w) for w in results]

    if args.json:
        print_json(works)
    else:
        print_human(works)

    return 0


if __name__ == "__main__":
    sys.exit(main())
