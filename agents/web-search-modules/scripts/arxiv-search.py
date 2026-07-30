#!/usr/bin/env python3
"""Query the arXiv API (http://export.arxiv.org/api/query) for papers.

Usage:
  arxiv-search.py "query" [--category cs.CL] [--author "Name"] [--max 10] [--sort relevance|date] [--json]
  arxiv-search.py --author "Name" [--category cs.CL]   (query is optional if a filter is given)
  arxiv-search.py --id 1706.03762[,id...]

Query terms are ANDed. Wrap the whole query in embedded double quotes for an exact-phrase
search, e.g. --> arxiv-search.py '"attention is all you need"'

Exit codes: 0 success, 1 API/network error, 2 usage error.
"""

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

API_URL = "http://export.arxiv.org/api/query"
USER_AGENT = "agents-web-search-agent/1.0 (academic-paper-lookup)"
TIMEOUT = 30
MAX_CAP = 50
ABSTRACT_WORD_LIMIT = 60

ATOM_NS = "{http://www.w3.org/2005/Atom}"
ARXIV_NS = "{http://arxiv.org/schemas/atom}"


def truncate_words(text, limit=ABSTRACT_WORD_LIMIT):
    text = " ".join(text.split())
    words = text.split(" ")
    if len(words) <= limit:
        return text
    return " ".join(words[:limit]) + " ..."


def build_query(args):
    parts = []
    q = (args.query or "").strip()
    if q:
        if q.startswith('"') and q.endswith('"') and q[1:-1].strip():
            # Caller asked for an exact phrase; pass it through quoted.
            parts.append(f"all:{q}")
        else:
            # arXiv's query parser mishandles an unquoted multi-word term when it is
            # combined with AND clauses -- the cat:/au: filters get silently dropped
            # and the result set balloons. Quote and AND each term instead.
            parts.extend(f'all:"{t}"' for t in q.replace('"', " ").split())
    if args.category:
        parts.append(f"cat:{args.category}")
    if args.author:
        parts.append(f'au:"{args.author}"')
    if not parts:
        return None
    return " AND ".join(parts)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
        return resp.read()


def parse_entries(xml_bytes):
    root = ET.fromstring(xml_bytes)
    entries = []
    for entry in root.findall(f"{ATOM_NS}entry"):
        entry_id = entry.findtext(f"{ATOM_NS}id", default="").strip()
        arxiv_id = entry_id.rsplit("/abs/", 1)[-1] if "/abs/" in entry_id else entry_id
        title = " ".join(entry.findtext(f"{ATOM_NS}title", default="").split())
        summary = " ".join(entry.findtext(f"{ATOM_NS}summary", default="").split())
        published = entry.findtext(f"{ATOM_NS}published", default="")[:10]
        primary_cat_el = entry.find(f"{ARXIV_NS}primary_category")
        primary_cat = primary_cat_el.get("term") if primary_cat_el is not None else ""
        authors = [
            a.findtext(f"{ATOM_NS}name", default="").strip()
            for a in entry.findall(f"{ATOM_NS}author")
        ]
        pdf_url = ""
        for link in entry.findall(f"{ATOM_NS}link"):
            if link.get("title") == "pdf" or link.get("type") == "application/pdf":
                pdf_url = link.get("href", "")
                break
        if not pdf_url:
            pdf_url = f"https://arxiv.org/pdf/{arxiv_id}"

        entries.append(
            {
                "id": arxiv_id,
                "title": title,
                "published": published,
                "primary_category": primary_cat,
                "authors": authors,
                "pdf_url": pdf_url,
                "abstract": summary,
            }
        )
    return entries


def print_human(entries):
    if not entries:
        print("No results found.")
        return
    for e in entries:
        authors = e["authors"]
        if len(authors) > 3:
            author_str = ", ".join(authors[:3]) + f" (+{len(authors) - 3} more)"
        else:
            author_str = ", ".join(authors)
        print(e["title"])
        print(f"arXiv:{e['id']} | {e['published']} | {e['primary_category']}")
        if author_str:
            print(author_str)
        print(e["pdf_url"])
        print(truncate_words(e["abstract"]))
        print()


def print_json(entries):
    for e in entries:
        print(json.dumps(e))


def main():
    parser = argparse.ArgumentParser(description="Search arXiv or look up papers by id.")
    parser.add_argument("query", nargs="?", help="search terms")
    parser.add_argument("--id", help="comma-separated arXiv id(s) for direct lookup")
    parser.add_argument("--category", help="arXiv category filter, e.g. cs.CL")
    parser.add_argument("--author", help="author name filter")
    parser.add_argument("--max", type=int, default=10, help="max results (capped at 50)")
    parser.add_argument("--sort", choices=["relevance", "date"], default="relevance")
    parser.add_argument("--json", action="store_true", help="output JSON lines")
    args = parser.parse_args()

    if not args.id and not (args.query or args.category or args.author):
        print(
            "ERROR: provide a query, --id, or at least one of --category/--author",
            file=sys.stderr,
        )
        return 2

    max_results = args.max
    if max_results < 1:
        print("ERROR: --max must be a positive integer", file=sys.stderr)
        return 2
    if max_results > MAX_CAP:
        max_results = MAX_CAP

    params = {"start": 0, "max_results": max_results}

    if args.id:
        ids = [i.strip() for i in args.id.split(",") if i.strip()]
        if not ids:
            print("ERROR: --id requires at least one id", file=sys.stderr)
            return 2
        params["id_list"] = ",".join(ids)
        # Never silently drop requested ids: widen max_results to cover them.
        if len(ids) > max_results:
            params["max_results"] = min(len(ids), MAX_CAP)
    else:
        search_query = build_query(args)
        if not search_query:
            print("ERROR: could not build a search query", file=sys.stderr)
            return 2
        params["search_query"] = search_query
        if args.sort == "date":
            params["sortBy"] = "submittedDate"
            params["sortOrder"] = "descending"
        else:
            params["sortBy"] = "relevance"
            params["sortOrder"] = "descending"

    url = f"{API_URL}?{urllib.parse.urlencode(params)}"

    try:
        raw = fetch(url)
    except urllib.error.HTTPError as e:
        print(f"ERROR: arXiv API returned HTTP {e.code}: {e.reason}", file=sys.stderr)
        return 1
    except urllib.error.URLError as e:
        print(f"ERROR: failed to reach arXiv API: {e.reason}", file=sys.stderr)
        return 1
    except Exception as e:  # noqa: BLE001
        print(f"ERROR: unexpected failure querying arXiv API: {e}", file=sys.stderr)
        return 1

    try:
        entries = parse_entries(raw)
    except ET.ParseError as e:
        print(f"ERROR: failed to parse arXiv response: {e}", file=sys.stderr)
        return 1

    if args.id and not entries:
        print("ERROR: no papers found for the given id(s)", file=sys.stderr)
        return 1

    if args.json:
        print_json(entries)
    else:
        print_human(entries)

    return 0


if __name__ == "__main__":
    sys.exit(main())
