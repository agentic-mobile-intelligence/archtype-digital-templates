#!/usr/bin/env bash
# stats.sh — word count per chapter
# Usage: bash publishing/stats.sh
# Compatible with bash 3.2+ (macOS default)
set -euo pipefail
BOOK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
DRAFTS_DIR="$BOOK_ROOT/drafts"
METADATA="$BOOK_ROOT/publishing/metadata.yaml"
SNAPSHOT="$BOOK_ROOT/.word-count.json"
STUB_THRESHOLD=200

# ---------------------------------------------------------------------------
# Read book title from metadata.yaml
# ---------------------------------------------------------------------------
BOOK_TITLE="Your Book"
if [[ -f "$METADATA" ]]; then
  _raw=$(grep -m1 '^title:' "$METADATA" | sed 's/^title:[[:space:]]*//' | tr -d '"')
  [[ -n "$_raw" ]] && BOOK_TITLE="$_raw"
fi

# ---------------------------------------------------------------------------
# Strip markdown and count words in a single file
# strip order: YAML frontmatter, code fences, HTML comments, headers
# ---------------------------------------------------------------------------
count_words() {
  local file="$1"
  sed -n '/^---$/,/^---$/!p;//d' "$file" \
    | sed '/^```/,/^```/d' \
    | sed 's/<!--.*-->//g' \
    | sed '/<!--/,/-->/d' \
    | grep -v '^[[:space:]]*#' \
    | wc -w \
    | tr -d ' '
}

# ---------------------------------------------------------------------------
# Collect files: drafts/*.md excluding _archive/, sorted by name
# (bash 3.2-compatible: no mapfile, no associative arrays)
# ---------------------------------------------------------------------------
FILES=$(find "$DRAFTS_DIR" -maxdepth 1 -name '*.md' ! -path '*/_archive/*' | sort)

if [[ -z "$FILES" ]]; then
  echo "No markdown files found in $DRAFTS_DIR"
  exit 0
fi

# ---------------------------------------------------------------------------
# Measure column widths
# ---------------------------------------------------------------------------
COL_FILE=7   # minimum "Chapter" header width
while IFS= read -r f; do
  rel="drafts/$(basename "$f")"
  len=${#rel}
  (( len > COL_FILE )) && COL_FILE=$len
done <<< "$FILES"
(( COL_FILE += 2 ))  # padding
COL_WORDS=10  # enough for "1,000,000"

# ---------------------------------------------------------------------------
# Border helpers (bash 3.2-compatible: awk instead of printf repeat)
# ---------------------------------------------------------------------------
WIDE=$(( COL_FILE + COL_WORDS + 3 ))

DOUBLE=$(awk -v n="$WIDE" 'BEGIN{ for(i=0;i<n;i++) printf "═"; print "" }')
SINGLE=$(awk -v n="$WIDE" 'BEGIN{ for(i=0;i<n;i++) printf "─"; print "" }')

# ---------------------------------------------------------------------------
# Comma-format an integer (awk, always available)
# ---------------------------------------------------------------------------
comma_fmt() {
  awk -v n="$1" 'BEGIN{
    s=sprintf("%d",n); r=""; l=length(s)
    for(i=1;i<=l;i++){r=r substr(s,i,1); if((l-i)%3==0 && i<l) r=r ","}
    print r
  }'
}

# ---------------------------------------------------------------------------
# Single pass: collect rows, total, and JSON fragments
# (bash 3.2-compatible: no associative arrays, no mapfile)
# ---------------------------------------------------------------------------
TOTAL=0
ROWS=""
JSON_CHAPTERS=""
SEP=""

while IFS= read -r f; do
  rel="drafts/$(basename "$f")"
  wc=$(count_words "$f")
  TOTAL=$(( TOTAL + wc ))

  wc_fmt=$(comma_fmt "$wc")

  stub_flag=""
  (( wc < STUB_THRESHOLD )) && stub_flag="  ⚠ stub"

  ROWS="${ROWS}$(printf " %-*s %*s%s" "$COL_FILE" "$rel" "$COL_WORDS" "$wc_fmt" "$stub_flag")
"
  JSON_CHAPTERS="${JSON_CHAPTERS}${SEP}    \"${rel}\": ${wc}"
  SEP=",
"
done <<< "$FILES"

total_fmt=$(comma_fmt "$TOTAL")

# ---------------------------------------------------------------------------
# Print table
# ---------------------------------------------------------------------------
echo "$DOUBLE"
printf " Word Count — %s\n" "$BOOK_TITLE"
echo "$DOUBLE"
printf " %-*s %*s\n" "$COL_FILE" "Chapter" "$COL_WORDS" "Words"
echo "$SINGLE"
printf "%s" "$ROWS"
echo "$SINGLE"
printf " %-*s %*s\n" "$COL_FILE" "TOTAL" "$COL_WORDS" "$total_fmt"
echo "$DOUBLE"

# ---------------------------------------------------------------------------
# Save snapshot to .word-count.json
# ---------------------------------------------------------------------------
DATE_TODAY=$(date +%Y-%m-%d)

{
  printf '{\n'
  printf '  "date": "%s",\n' "$DATE_TODAY"
  printf '  "total": %d,\n' "$TOTAL"
  printf '  "chapters": {\n'
  printf '%s' "$JSON_CHAPTERS"
  printf '\n  }\n'
  printf '}\n'
} > "$SNAPSHOT"

echo ""
echo "Snapshot saved to .word-count.json"
