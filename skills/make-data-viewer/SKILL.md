---
name: jcd:make-data-viewer
description: Use when the user wants to build an interactive browser-based data viewer, comparison tool, or dashboard for exploring datasets — especially time-series, trace, or scientific data that needs filtering, overlaying, or distance comparison
disable-model-invocation: false
user-invocable: true
context: conversation
model: sonnet
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Make Data Viewer

Build an interactive browser-based data viewer as a single-file Flask + Plotly.js application. Start from the template at `~/.claude/skills/make-data-viewer/scripts/template.py`.

## Process

1. **Gather requirements** — ask these questions (skip any already answered):
   - What data are you viewing? (file format, directory structure, how many items)
   - What comparisons do you need? (overlay, side-by-side, heatmap, table)
   - How do you access this machine? (local, SSH, remote desktop)
   - What filtering or transforms should be configurable? (smoothing, normalization, resampling)
   - Do items have natural groups/categories for the sidebar?

2. **Read the template** — always start by reading `~/.claude/skills/make-data-viewer/scripts/template.py`. It contains a complete working viewer with:
   - Data discovery, loading, filtering, resampling
   - Distance computation (Euclidean + DTW)
   - Flask REST API (`/api/items`, `/api/compare`)
   - Full dark-theme HTML+Plotly.js frontend with sidebar controls
   - Paired slider+number inputs, debounced updates, status bar
   - CLI with `--host`, `--port`, `--debug`

3. **Customize the template** — adapt these sections for the user's data:
   - `discover_items()` — scan their directory structure
   - `load_item()` — read their file format (CSV, binary, HDF5, NPY, etc.)
   - `init_app()` — point at their data directories and define group names
   - Y-axis label and plot titles
   - Default checkbox state (which groups checked by default)
   - Add domain-specific controls if needed

4. **Build iteratively** — implement in this order:
   a. Get data loading working first (test with a print)
   b. Verify the API returns correct JSON (test with `app.test_client()`)
   c. Start the server and check the browser
   d. Add domain-specific features the user requests

5. **Apply these UX rules** (learned from real user feedback):
   - Sliders MUST have paired number inputs for typing exact values
   - Debounce slider drag events at 600ms, typed input at 300ms — this prevents lag
   - Stack time-series plots vertically (full width), NEVER side-by-side — horizontal compression kills y-axis readability
   - Default to the most representative data variant (largest, smoothed, latest — ask the user which)
   - Group items by source/category in the sidebar with select-all/select-none buttons
   - Show a status line with current parameter values and item count

## Common Extensions

Users will often request these after seeing the initial viewer:

**Phase/segment splitting** — if data has distinct phases (e.g. warmup/steady-state, prefill/decode), add a checkbox toggle. When enabled: split each trace at the boundary, show phases as stacked vertical plots (full width each), with distance heatmaps side-by-side below. The split point can come from metadata timestamps or a user-specified index.

**Custom distance metrics** — Euclidean is the default (fast). DTW is useful for time-warped comparisons but is O(n^2) — always cap the resample length to 1024 when DTW is selected. The template includes both.

**Data smoothing** — the template includes median, gaussian, and moving average filters. Median with size ~100 is often the most useful for noisy time-series.

**Quick-select buttons** — beyond All/None, add domain-specific buttons (e.g. "Real Only", "Latest Run", "Failed Only") based on what groupings make sense.

## Tech Stack

| Component | Choice | Why |
|-----------|--------|-----|
| Backend | Flask | Minimal deps, single file, no async needed |
| Frontend | Plotly.js (CDN) | Interactive scientific plots, no build step |
| Numerical | NumPy + SciPy | Filtering, resampling, distance computation |
| HTML | Inline string in Python | No template dir, true single-file deployment |
| Access | `--host 0.0.0.0` + SSH tunnel | Works on headless machines |

## Install

```bash
uv pip install flask
# scipy and numpy are usually already available
```

## Smoke Testing

After building, always verify before telling the user it works:

```python
# 1. Test data discovery
items = discover_items(Path("data/"))
print(f"Found {len(items)} items")

# 2. Test loading
name, path = next(iter(items.items()))
data = load_item(path)
print(f"{name}: {len(data)} samples, range [{data.min():.2f}, {data.max():.2f}]")

# 3. Test API with Flask test client
with app.test_client() as client:
    resp = client.get("/api/items")
    assert resp.status_code == 200

    resp = client.post("/api/compare", json={
        "selected": list(items.keys())[:3],
        "filter_type": "median",
        "filter_size": 50,
        "resample_length": 1024,
        "distance_metric": "euclidean",
    })
    result = resp.get_json()
    assert "traces" in result
    assert "distance_matrix" in result

# 4. Brief server start test
# timeout 5 python viewer.py --port 5001
```
