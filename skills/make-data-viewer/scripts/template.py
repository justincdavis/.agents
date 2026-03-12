#!/usr/bin/env python3
"""Interactive data viewer template.

Usage:
    python viewer.py [--port 5000] [--host 0.0.0.0]

Access from another machine via SSH tunnel:
    ssh -L 5000:localhost:5000 <remote-host>
    Then open http://localhost:5000
"""
from __future__ import annotations

import argparse
import logging
from pathlib import Path

import numpy as np
from flask import Flask, Response, jsonify, request
from scipy.ndimage import gaussian_filter1d, median_filter, uniform_filter1d

PROJECT_ROOT = Path(__file__).resolve().parents[1]

log = logging.getLogger("viewer")

# ===================================================================
# Data loading — customize for your data format
# ===================================================================

# Global state: loaded once at startup
_raw_data: dict[str, np.ndarray] = {}  # item_name -> 1D array
_groups: dict[str, list[str]] = {}  # group_name -> [item_names]


def discover_items(data_dir: Path) -> dict[str, Path]:
    """Scan a directory and return {item_name: file_path}.

    Customize this for your directory structure. Example assumes:
        data_dir/
            category_a/
                item_1.npy
                item_2.npy
            category_b/
                item_3.npy
    """
    items: dict[str, Path] = {}
    if not data_dir.is_dir():
        return items
    for item_path in sorted(data_dir.rglob("*.npy")):
        # Use relative path as item name, or just stem
        items[item_path.stem] = item_path
    return items


def load_item(path: Path) -> np.ndarray:
    """Load a single data item and return a 1D float64 array.

    Customize this for your file format (CSV, binary, HDF5, etc.).
    """
    return np.load(path).astype(np.float64)


def init_app(data_roots: dict[str, Path]) -> None:
    """Load all data at startup.

    Parameters
    ----------
    data_roots : dict
        Mapping of group_name -> directory_path.
        Example: {"training": Path("data/train"), "test": Path("data/test")}
    """
    global _raw_data, _groups
    _groups = {}
    for group_name, root in data_roots.items():
        paths = discover_items(root)
        _groups[group_name] = sorted(paths.keys())
        for name, path in paths.items():
            _raw_data[name] = load_item(path)
    log.info(
        "Loaded %d items (%s)",
        len(_raw_data),
        ", ".join(f"{k}: {len(v)}" for k, v in _groups.items()),
    )


# ===================================================================
# Processing pipeline
# ===================================================================

FILTER_TYPES = ["none", "median", "gaussian", "moving_average"]


def apply_filter(
    data: np.ndarray,
    filter_type: str,
    filter_size: int,
) -> np.ndarray:
    """Apply a smoothing filter to a 1D array."""
    if filter_type == "none" or filter_size <= 1:
        return data.copy()
    if filter_type == "median":
        size = filter_size if filter_size % 2 == 1 else filter_size + 1
        return median_filter(data, size=size)
    if filter_type == "gaussian":
        sigma = max(filter_size / 4.0, 0.5)
        return gaussian_filter1d(data, sigma=sigma)
    if filter_type == "moving_average":
        return uniform_filter1d(data, size=filter_size)
    raise ValueError(f"Unknown filter type: {filter_type}")


def resample(data: np.ndarray, target_length: int) -> np.ndarray:
    """Resample a 1D array to target_length using linear interpolation."""
    if len(data) == target_length:
        return data.copy()
    x_old = np.linspace(0, 1, len(data))
    x_new = np.linspace(0, 1, target_length)
    return np.interp(x_new, x_old, data)


def process_items(
    selected: list[str],
    filter_type: str,
    filter_size: int,
    resample_length: int,
) -> dict[str, np.ndarray]:
    """Filter and resample selected items to equal length."""
    result: dict[str, np.ndarray] = {}
    for name in selected:
        if name not in _raw_data:
            continue
        filtered = apply_filter(_raw_data[name], filter_type, filter_size)
        resampled = resample(filtered, resample_length)
        result[name] = resampled
    return result


# ===================================================================
# Distance metrics
# ===================================================================


def _dtw_distance(a: np.ndarray, b: np.ndarray) -> float:
    """DTW distance between two equal-length 1D sequences.

    O(n^2) — only use on resampled data (cap at ~1024 samples).
    """
    n = len(a)
    dtw = np.full((n + 1, n + 1), np.inf)
    dtw[0, 0] = 0.0
    for i in range(1, n + 1):
        for j in range(1, n + 1):
            cost = (a[i - 1] - b[j - 1]) ** 2
            dtw[i, j] = cost + min(dtw[i - 1, j], dtw[i, j - 1], dtw[i - 1, j - 1])
    return float(np.sqrt(dtw[n, n]))


def compute_distance_matrix(
    items: dict[str, np.ndarray],
    metric: str = "euclidean",
) -> tuple[list[str], list[list[float]]]:
    """Pairwise distance matrix. Returns (names, matrix_as_nested_list)."""
    names = sorted(items.keys())
    n = len(names)
    matrix = np.zeros((n, n))
    for i in range(n):
        for j in range(i + 1, n):
            if metric == "euclidean":
                d = float(np.linalg.norm(items[names[i]] - items[names[j]]))
            elif metric == "dtw":
                d = _dtw_distance(items[names[i]], items[names[j]])
            else:
                raise ValueError(f"Unknown metric: {metric}")
            matrix[i, j] = d
            matrix[j, i] = d
    return names, matrix.tolist()


# ===================================================================
# Flask application
# ===================================================================

app = Flask(__name__)


@app.route("/api/items")
def api_items():
    """Return available items grouped by category."""
    return jsonify(_groups)


@app.route("/api/compare", methods=["POST"])
def api_compare():
    """Process and compare selected items.

    POST body (JSON):
        selected: list[str]       -- item names to compare
        filter_type: str          -- "none" | "median" | "gaussian" | "moving_average"
        filter_size: int          -- smoothing window size
        resample_length: int      -- target length after resampling
        distance_metric: str      -- "euclidean" | "dtw"
    """
    data = request.get_json()
    selected = data.get("selected", [])
    filter_type = data.get("filter_type", "none")
    filter_size = int(data.get("filter_size", 1))
    resample_length = int(data.get("resample_length", 2048))
    distance_metric = data.get("distance_metric", "euclidean")

    if not selected:
        return jsonify({"error": "No items selected"}), 400

    # DTW is O(n^2) per pair — cap resample length
    if distance_metric == "dtw" and resample_length > 1024:
        resample_length = 1024

    processed = process_items(selected, filter_type, filter_size, resample_length)
    trace_data = {name: processed[name].tolist() for name in sorted(processed)}
    names, matrix = compute_distance_matrix(processed, distance_metric)

    return jsonify(
        {
            "traces": trace_data,
            "distance_matrix": {"names": names, "values": matrix},
        }
    )


# ===================================================================
# HTML frontend — inline for single-file deployment
# ===================================================================

HTML_PAGE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Data Viewer</title>
<script src="https://cdn.plot.ly/plotly-2.35.2.min.js"></script>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: system-ui, sans-serif;
    display: flex;
    height: 100vh;
    background: #1a1a2e;
    color: #e0e0e0;
  }

  /* --- Sidebar --- */
  #sidebar {
    width: 320px;
    padding: 16px;
    overflow-y: auto;
    background: #16213e;
    border-right: 1px solid #333;
  }
  .control-group { margin-bottom: 16px; }
  .control-group > label {
    display: block;
    font-weight: 600;
    margin-bottom: 4px;
    color: #a0c4ff;
  }
  select { width: 100%; }

  /* Paired slider + number input */
  .slider-pair {
    display: flex;
    gap: 8px;
    align-items: center;
  }
  .slider-pair input[type=range] { flex: 1; }
  .slider-pair input[type=number] { width: 70px; }

  /* Item groups */
  .item-group { margin-bottom: 12px; }
  .item-group h3 {
    font-size: 13px;
    color: #ffb347;
    margin-bottom: 4px;
    text-transform: uppercase;
  }
  .item-list {
    max-height: 200px;
    overflow-y: auto;
    font-size: 12px;
  }
  .item-list label {
    display: block;
    padding: 1px 0;
    cursor: pointer;
  }
  .item-list input { margin-right: 4px; }

  /* Buttons */
  .btn-row { display: flex; gap: 8px; margin-bottom: 8px; }
  .btn-row button {
    padding: 4px 10px;
    font-size: 12px;
    cursor: pointer;
    background: #0f3460;
    color: #e0e0e0;
    border: 1px solid #555;
    border-radius: 3px;
  }
  .btn-row button:hover { background: #1a5276; }

  /* Main area */
  #main {
    flex: 1;
    display: flex;
    flex-direction: column;
    padding: 16px;
    gap: 16px;
    overflow-y: auto;
  }
  .plot-container { flex: 1; min-height: 350px; }
  #status { font-size: 12px; color: #888; padding: 4px 0; }
</style>
</head>
<body>

<div id="sidebar">
  <h2 style="margin-bottom:12px; color:#a0c4ff;">Data Viewer</h2>

  <!-- Filter type dropdown -->
  <div class="control-group">
    <label>Filter Type</label>
    <select id="filter-type">
      <option value="none">None (raw)</option>
      <option value="median" selected>Median</option>
      <option value="gaussian">Gaussian</option>
      <option value="moving_average">Moving Average</option>
    </select>
  </div>

  <!-- Filter size: slider + number input (always pair these) -->
  <div class="control-group">
    <label>Filter Size</label>
    <div class="slider-pair">
      <input type="range" id="filter-size" min="1" max="500" value="100">
      <input type="number" id="filter-size-num" min="1" max="500" value="100">
    </div>
  </div>

  <!-- Resample length: slider + number input -->
  <div class="control-group">
    <label>Resample Length</label>
    <div class="slider-pair">
      <input type="range" id="resample-length" min="256" max="8192" step="256" value="2048">
      <input type="number" id="resample-length-num" min="256" max="8192" step="256" value="2048">
    </div>
  </div>

  <!-- Distance metric -->
  <div class="control-group">
    <label>Distance Metric</label>
    <select id="distance-metric">
      <option value="euclidean" selected>Euclidean</option>
      <option value="dtw">DTW (slower)</option>
    </select>
  </div>

  <!-- Item selection with group headers and quick-select buttons -->
  <div class="control-group">
    <label>Items</label>
    <div class="btn-row">
      <button onclick="selectAll()">All</button>
      <button onclick="selectNone()">None</button>
    </div>
    <div id="item-checkboxes"></div>
  </div>

  <div id="status">Loading items...</div>
</div>

<div id="main">
  <!-- Trace overlay plot (full width, stacked vertically) -->
  <div id="trace-plot" class="plot-container"></div>
  <!-- Distance heatmap -->
  <div id="distance-plot" class="plot-container"></div>
</div>

<script>
let itemGroups = {};
let debounceTimer = null;

// -------------------------------------------------------------------
// Item loading and selection
// -------------------------------------------------------------------

async function loadItems() {
  const resp = await fetch("/api/items");
  itemGroups = await resp.json();
  const container = document.getElementById("item-checkboxes");
  container.innerHTML = "";
  for (const [group, names] of Object.entries(itemGroups)) {
    const div = document.createElement("div");
    div.className = "item-group";
    div.innerHTML = `<h3>${group} (${names.length})</h3>`;
    const list = document.createElement("div");
    list.className = "item-list";
    for (const name of names) {
      const lbl = document.createElement("label");
      const cb = document.createElement("input");
      cb.type = "checkbox";
      cb.value = name;
      cb.dataset.group = group;
      cb.checked = true;  // default: all selected (customize per use case)
      cb.addEventListener("change", scheduleUpdate);
      lbl.appendChild(cb);
      lbl.appendChild(document.createTextNode(" " + name));
      list.appendChild(lbl);
    }
    div.appendChild(list);
    container.appendChild(div);
  }
  scheduleUpdate();
}

function getSelected() {
  return Array.from(document.querySelectorAll("#item-checkboxes input:checked"))
    .map(cb => cb.value);
}

function selectAll() {
  document.querySelectorAll("#item-checkboxes input")
    .forEach(cb => cb.checked = true);
  scheduleUpdate();
}

function selectNone() {
  document.querySelectorAll("#item-checkboxes input")
    .forEach(cb => cb.checked = false);
  scheduleUpdate();
}

// -------------------------------------------------------------------
// Debounced update — slider drags use longer delay to reduce lag
// -------------------------------------------------------------------

function scheduleUpdate(delay) {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(doUpdate, delay || 300);
}

async function doUpdate() {
  const selected = getSelected();
  if (selected.length === 0) {
    document.getElementById("status").textContent = "Select at least one item.";
    Plotly.purge("trace-plot");
    Plotly.purge("distance-plot");
    return;
  }

  const params = {
    selected,
    filter_type: document.getElementById("filter-type").value,
    filter_size: parseInt(document.getElementById("filter-size").value),
    resample_length: parseInt(document.getElementById("resample-length").value),
    distance_metric: document.getElementById("distance-metric").value,
  };

  document.getElementById("status").textContent =
    `Computing (${selected.length} items)...`;

  try {
    const resp = await fetch("/api/compare", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(params),
    });
    const result = await resp.json();
    if (result.error) {
      document.getElementById("status").textContent = result.error;
      return;
    }
    renderTraces(result.traces, params);
    renderDistanceMatrix(result.distance_matrix, params);
    document.getElementById("status").textContent =
      `${selected.length} items | ${params.filter_type} ` +
      `(size=${params.filter_size}) | ${params.distance_metric}`;
  } catch (err) {
    document.getElementById("status").textContent = "Error: " + err.message;
  }
}

// -------------------------------------------------------------------
// Plotly rendering
// -------------------------------------------------------------------

function renderTraces(traces, params) {
  const plotData = Object.entries(traces).map(([name, values]) => ({
    y: values,
    name: name,
    type: "scatter",
    mode: "lines",
    line: { width: 1.5 },
  }));

  const layout = {
    title: `Traces (${params.filter_type}, size=${params.filter_size})`,
    xaxis: { title: "Sample Index" },
    yaxis: { title: "Value" },
    paper_bgcolor: "#1a1a2e",
    plot_bgcolor: "#16213e",
    font: { color: "#e0e0e0" },
    legend: { font: { size: 10 } },
    margin: { t: 40, r: 10, b: 40, l: 60 },
  };

  Plotly.react("trace-plot", plotData, layout, { responsive: true });
}

function renderDistanceMatrix(dm, params) {
  const plotData = [{
    z: dm.values,
    x: dm.names,
    y: dm.names,
    type: "heatmap",
    colorscale: "Viridis",
    hoverongaps: false,
    text: dm.values.map(row => row.map(v => v.toFixed(1))),
    texttemplate: "%{text}",
    textfont: { size: 9 },
  }];

  const layout = {
    title: `Distance Matrix (${params.distance_metric})`,
    paper_bgcolor: "#1a1a2e",
    plot_bgcolor: "#16213e",
    font: { color: "#e0e0e0" },
    margin: { t: 40, r: 10, b: 100, l: 100 },
    xaxis: { tickangle: -45, tickfont: { size: 9 } },
    yaxis: { tickfont: { size: 9 } },
  };

  Plotly.react("distance-plot", plotData, layout, { responsive: true });
}

// -------------------------------------------------------------------
// Wire up controls
// -------------------------------------------------------------------

// Dropdowns: immediate update
document.getElementById("filter-type")
  .addEventListener("change", () => scheduleUpdate());
document.getElementById("distance-metric")
  .addEventListener("change", () => scheduleUpdate());

// Filter size: sync slider <-> number, debounce drags longer (600ms)
document.getElementById("filter-size").addEventListener("input", (e) => {
  document.getElementById("filter-size-num").value = e.target.value;
  scheduleUpdate(600);
});
document.getElementById("filter-size-num").addEventListener("change", (e) => {
  document.getElementById("filter-size").value = e.target.value;
  scheduleUpdate();
});

// Resample length: sync slider <-> number, debounce drags longer
document.getElementById("resample-length").addEventListener("input", (e) => {
  document.getElementById("resample-length-num").value = e.target.value;
  scheduleUpdate(600);
});
document.getElementById("resample-length-num").addEventListener("change", (e) => {
  document.getElementById("resample-length").value = e.target.value;
  scheduleUpdate();
});

// Boot
loadItems();
</script>
</body>
</html>"""


@app.route("/")
def index():
    return Response(HTML_PAGE, mimetype="text/html")


# ===================================================================
# CLI entry point
# ===================================================================


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Interactive data viewer")
    p.add_argument(
        "--host", default="0.0.0.0", help="Bind address (default: 0.0.0.0)"
    )
    p.add_argument("--port", type=int, default=5000, help="Port (default: 5000)")
    p.add_argument("--debug", action="store_true", help="Enable Flask debug mode")
    return p.parse_args()


if __name__ == "__main__":
    args = parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")

    # ---- Customize: point these at your data directories ----
    init_app(
        {
            "group_a": PROJECT_ROOT / "data" / "group_a",
            "group_b": PROJECT_ROOT / "data" / "group_b",
        }
    )

    print(f"Starting viewer at http://{args.host}:{args.port}")
    print(f"  SSH tunnel: ssh -L {args.port}:localhost:{args.port} <host>")
    app.run(host=args.host, port=args.port, debug=args.debug)
