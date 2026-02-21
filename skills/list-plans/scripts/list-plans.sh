#!/usr/bin/env bash
set -uo pipefail

# --- Globals ---
CUTOFF_ISO=""
CUTOFF_EPOCH=0
TOTAL_SESSIONS=0
PLAN_MODE_COUNT=0
UNINDEXED_COUNT=0
declare -A PROJECTS=()
declare -A BRANCHES=()

# --- Helpers ---

section() {
    echo ""
    echo "=== $1 ==="
}

parse_timeframe() {
    local tf="${1:-24h}"
    local num="${tf%[hdw]}"
    local unit="${tf: -1}"

    case "$unit" in
        h) CUTOFF_ISO=$(date -u -d "$num hours ago" +%Y-%m-%dT%H:%M:%SZ)
           CUTOFF_EPOCH=$(date -u -d "$num hours ago" +%s) ;;
        d) CUTOFF_ISO=$(date -u -d "$num days ago" +%Y-%m-%dT%H:%M:%SZ)
           CUTOFF_EPOCH=$(date -u -d "$num days ago" +%s) ;;
        w) CUTOFF_ISO=$(date -u -d "$num weeks ago" +%Y-%m-%dT%H:%M:%SZ)
           CUTOFF_EPOCH=$(date -u -d "$num weeks ago" +%s) ;;
        *) echo "ERROR: Invalid timeframe: $tf (use e.g. 24h, 3d, 1w)"; exit 1 ;;
    esac
}

check_plan_mode() {
    local file="$1"
    local count
    count=$(grep -c 'EnterPlanMode\|ExitPlanMode' "$file" 2>/dev/null) || count=0
    echo "$count"
}

format_session() {
    local line="$1"
    # Parse: SESSION|sid|path|summary|firstPrompt|branch|created|modified|msgCount|projectPath|source
    IFS='|' read -r _tag sid path summary first_prompt branch created modified msg_count project_path source <<< "$line"

    # Determine display title
    local title="${summary:-}"
    [[ -z "$title" || "$title" == "null" ]] && title="${first_prompt:-}"
    [[ -z "$title" || "$title" == "null" ]] && title="(no title)"
    if [[ ${#title} -gt 80 ]]; then
        title="${title:0:80}..."
    fi

    # Truncate first_prompt for display
    local display_prompt="${first_prompt:-}"
    if [[ ${#display_prompt} -gt 120 ]]; then
        display_prompt="${display_prompt:0:120}..."
    fi

    # Check plan mode
    local plan_mode="No"
    if [[ -f "$path" ]]; then
        local pm_count
        pm_count=$(check_plan_mode "$path")
        if [[ "$pm_count" -gt 0 ]]; then
            plan_mode="Yes"
            ((PLAN_MODE_COUNT++)) || true
        fi
    fi

    # Track unindexed count
    if [[ "$source" == "unindexed" ]]; then
        ((UNINDEXED_COUNT++)) || true
    fi

    # Track project and branch
    local project_name
    project_name=$(basename "${project_path:-unknown}" 2>/dev/null) || project_name="unknown"
    PROJECTS["$project_name"]=1
    [[ -n "${branch:-}" && "${branch:-}" != "null" ]] && BRANCHES["$branch"]=1

    # Print
    echo "  --- $title"
    echo "      Branch: ${branch:-unknown} | Messages: ${msg_count:-?} | Plan Mode: $plan_mode"
    echo "      Created: ${created:-?} | Modified: ${modified:-?}"
    if [[ -n "${display_prompt:-}" && "${display_prompt:-}" != "null" ]]; then
        echo "      First Prompt: $display_prompt"
    fi
    echo "      Source: $source"
    echo ""

    ((TOTAL_SESSIONS++)) || true
}

print_summary() {
    section "Summary"
    echo "  Total sessions: $TOTAL_SESSIONS"
    echo "  Plan mode sessions: $PLAN_MODE_COUNT"
    echo "  Unindexed sessions: $UNINDEXED_COUNT"

    if [[ ${#PROJECTS[@]} -gt 0 ]]; then
        echo "  Projects: ${!PROJECTS[*]}"
    fi

    if [[ ${#BRANCHES[@]} -gt 0 ]]; then
        echo "  Branches: ${!BRANCHES[*]}"
    fi
}

# --- Python3-inline functions ---

process_indexed() {
    local index_file="$1"
    python3 -c '
import json, sys

index_file = sys.argv[1]
cutoff = sys.argv[2]

try:
    with open(index_file, "r") as f:
        data = json.load(f)
except Exception:
    sys.exit(0)

entries = data.get("entries", [])

for e in entries:
    sid = e.get("sessionId", "")
    print(f"INDEXED_ID|{sid}")

    modified = e.get("modified", "")
    if modified < cutoff:
        continue

    msg_count = e.get("messageCount", 0)
    if msg_count is not None and msg_count <= 2:
        continue

    if e.get("isSidechain", False):
        continue

    path = e.get("fullPath", "")
    summary = (e.get("summary", "") or "").replace("|", "-").replace("\n", " ")
    first_prompt = (e.get("firstPrompt", "") or "").replace("|", "-").replace("\n", " ")
    branch = (e.get("gitBranch", "") or "").replace("|", "-")
    created = e.get("created", "")
    project_path = (e.get("projectPath", "") or "").replace("|", "-")

    print(f"SESSION|{sid}|{path}|{summary}|{first_prompt}|{branch}|{created}|{modified}|{msg_count}|{project_path}|indexed")
' "$index_file" "$CUTOFF_ISO" 2>/dev/null || true
}

extract_unindexed_meta() {
    local jsonl_file="$1"
    python3 -c '
import json, sys

jsonl_file = sys.argv[1]

try:
    entries = []
    with open(jsonl_file, "r") as f:
        for i, line in enumerate(f):
            if i >= 10:
                break
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                continue

            t = obj.get("type", "")
            if t in ("summary", "file-history-snapshot", "queue-operation"):
                continue
            entries.append(obj)

    if not entries:
        sys.exit(0)

    # Find first real user message
    for obj in entries:
        if obj.get("type") != "user":
            continue

        msg = obj.get("message", {})
        content = msg.get("content", "")

        if isinstance(content, list):
            text_parts = []
            for part in content:
                if isinstance(part, dict) and part.get("type") == "text":
                    text_parts.append(part.get("text", ""))
            content = " ".join(text_parts)

        if not isinstance(content, str):
            continue

        # Skip meta/command messages
        if content.startswith(("<local-command", "<command-name", "<command-message")):
            continue

        sid = obj.get("sessionId", "")
        timestamp = obj.get("timestamp", "")
        cwd = (obj.get("cwd", "") or "").replace("|", "-")
        branch = (obj.get("gitBranch", "") or "").replace("|", "-")

        content = content.replace("|", "-").replace("\n", " ")[:200]

        print(f"SESSION|{sid}|{jsonl_file}||{content}|{branch}|{timestamp}|{timestamp}|?|{cwd}|unindexed")
        break

except Exception:
    pass
' "$jsonl_file" 2>/dev/null || true
}

# --- find_unindexed ---

find_unindexed() {
    local project_dir="$1"
    local indexed_ids="$2"

    while IFS= read -r jsonl_file; do
        [[ -z "$jsonl_file" ]] && continue

        local base
        base=$(basename "$jsonl_file" .jsonl)

        # Skip if this ID is in the indexed set
        if [[ -n "$indexed_ids" ]] && echo "$indexed_ids" | grep -qF "$base"; then
            continue
        fi

        # Pre-filter by mtime
        local file_epoch
        file_epoch=$(stat --format='%Y' "$jsonl_file" 2>/dev/null) || continue
        if [[ "$file_epoch" -lt "$CUTOFF_EPOCH" ]]; then
            continue
        fi

        extract_unindexed_meta "$jsonl_file"
    done < <(find "$project_dir" -maxdepth 1 -name '*.jsonl' -type f 2>/dev/null)
}

# --- Main ---

main() {
    parse_timeframe "${1:-24h}"

    section "Recent Claude Sessions"
    echo "  Timeframe: ${1:-24h} (cutoff: $CUTOFF_ISO)"

    local projects_base="$HOME/.claude/projects"

    if [[ ! -d "$projects_base" ]]; then
        echo "  No projects directory found at $projects_base"
        return
    fi

    declare -A processed_dirs=()

    # Process all sessions-index.json files
    while IFS= read -r index_file; do
        [[ -z "$index_file" ]] && continue

        local project_dir
        project_dir=$(dirname "$index_file")
        processed_dirs["$project_dir"]=1

        local project_name
        project_name=$(basename "$project_dir")

        local indexed_ids=""
        local sessions=()

        while IFS= read -r line; do
            if [[ "$line" == INDEXED_ID\|* ]]; then
                local id="${line#INDEXED_ID|}"
                indexed_ids="${indexed_ids}${id}"$'\n'
            elif [[ "$line" == SESSION\|* ]]; then
                sessions+=("$line")
            fi
        done < <(process_indexed "$index_file")

        # Find unindexed sessions in the same directory
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$line" == SESSION\|* ]]; then
                sessions+=("$line")
            fi
        done < <(find_unindexed "$project_dir" "$indexed_ids")

        if [[ ${#sessions[@]} -gt 0 ]]; then
            section "Project: $project_name"
            for s in "${sessions[@]}"; do
                format_session "$s"
            done
        fi
    done < <(find "$projects_base" -name 'sessions-index.json' -type f 2>/dev/null)

    # Scan project dirs that had no sessions-index.json
    while IFS= read -r project_dir; do
        [[ -z "$project_dir" ]] && continue
        [[ -v "processed_dirs[$project_dir]" ]] && continue

        # Check if dir has any .jsonl files
        local has_jsonl
        has_jsonl=$(find "$project_dir" -maxdepth 1 -name '*.jsonl' -type f -print -quit 2>/dev/null)
        [[ -z "$has_jsonl" ]] && continue

        processed_dirs["$project_dir"]=1
        local project_name
        project_name=$(basename "$project_dir")

        local sessions=()
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            if [[ "$line" == SESSION\|* ]]; then
                sessions+=("$line")
            fi
        done < <(find_unindexed "$project_dir" "")

        if [[ ${#sessions[@]} -gt 0 ]]; then
            section "Project: $project_name"
            for s in "${sessions[@]}"; do
                format_session "$s"
            done
        fi
    done < <(find "$projects_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)

    print_summary

    if [[ "$TOTAL_SESSIONS" -eq 0 ]]; then
        echo ""
        echo "  No sessions found in the specified timeframe."
        echo "  Try a wider timeframe, e.g.: list-plans.sh 3d  or  list-plans.sh 1w"
    fi
}

main "$@"
