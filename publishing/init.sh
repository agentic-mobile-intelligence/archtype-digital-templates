#!/usr/bin/env bash
set -euo pipefail

# ── Banner ────────────────────────────────────────────────────────────────────
echo "========================================"
echo "  Book Template — First-Time Setup"
echo "========================================"
echo ""

# ── Detect sed -i syntax (macOS vs Linux) ─────────────────────────────────────
if sed -i '' 's/x/x/' /dev/null 2>/dev/null; then
  SED_INPLACE=(sed -i '')
else
  SED_INPLACE=(sed -i)
fi

# ── Prompt helper ─────────────────────────────────────────────────────────────
prompt_value() {
  local label="$1"
  local default="$2"
  local result
  if [[ -n "$default" ]]; then
    read -r -p "${label} [${default}]: " result
    echo "${result:-$default}"
  else
    read -r -p "${label}: " result
    echo "$result"
  fi
}

# ── Collect values ────────────────────────────────────────────────────────────
BOOK_TITLE=$(prompt_value "Book title (required)" "")
BOOK_SUBTITLE=$(prompt_value "Book subtitle" "Pre-Release Preprint")
AUTHOR_NAME=$(prompt_value "Author name (required)" "")
AUTHOR_AFFILIATION=$(prompt_value "Author affiliation" "")
ORCID=$(prompt_value "ORCID (optional, press Enter to skip)" "")
COPYRIGHT_YEAR=$(prompt_value "Copyright year" "$(date +%Y)")
SUBJECT_AREA=$(prompt_value "Subject area" "")

# ── Validate required fields ───────────────────────────────────────────────────
if [[ -z "$BOOK_TITLE" ]]; then
  echo ""
  echo "Book title is required. Please enter it:"
  read -r -p "Book title: " BOOK_TITLE
  if [[ -z "$BOOK_TITLE" ]]; then
    echo "Error: book title is required. Exiting." >&2
    exit 1
  fi
fi

if [[ -z "$AUTHOR_NAME" ]]; then
  echo ""
  echo "Author name is required. Please enter it:"
  read -r -p "Author name: " AUTHOR_NAME
  if [[ -z "$AUTHOR_NAME" ]]; then
    echo "Error: author name is required. Exiting." >&2
    exit 1
  fi
fi

# ── Resolve paths relative to repo root ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

METADATA_YAML="$SCRIPT_DIR/metadata.yaml"
OUTLINE_YAML="$SCRIPT_DIR/outline.yaml"
ARXIV_METADATA_YAML="$SCRIPT_DIR/arxiv-paper/metadata.yaml"
ARXIV_MAIN_MD="$SCRIPT_DIR/arxiv-paper/main.md"

# ── Apply replacements ─────────────────────────────────────────────────────────

# publishing/metadata.yaml
"${SED_INPLACE[@]}" \
  "s|title: \"YOUR BOOK TITLE\"|title: \"${BOOK_TITLE}\"|g" \
  "$METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|subtitle: \"YOUR SUBTITLE — Pre-Release Preprint\"|subtitle: \"${BOOK_TITLE} — ${BOOK_SUBTITLE}\"|g" \
  "$METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|name: \"Your Name\"|name: \"${AUTHOR_NAME}\"|g" \
  "$METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|affiliation: \"your-site.example\"|affiliation: \"${AUTHOR_AFFILIATION}\"|g" \
  "$METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|orcid: \"\"|orcid: \"${ORCID}\"|g" \
  "$METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|date: \"2026\"|date: \"${COPYRIGHT_YEAR}\"|g" \
  "$METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|rights: \"© 2026 Your Name.*\"|rights: \"© ${COPYRIGHT_YEAR} ${AUTHOR_NAME}. Pre-Release Edition licensed under CC BY 4.0.\"|g" \
  "$METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|subject: \"YOUR SUBJECT AREA\"|subject: \"${SUBJECT_AREA}\"|g" \
  "$METADATA_YAML"

# publishing/outline.yaml
"${SED_INPLACE[@]}" \
  "s|title: \"YOUR BOOK TITLE\"|title: \"${BOOK_TITLE}\"|g" \
  "$OUTLINE_YAML"

# publishing/arxiv-paper/metadata.yaml
"${SED_INPLACE[@]}" \
  "s|title: \"YOUR BOOK TITLE: A Condensed Overview\"|title: \"${BOOK_TITLE}: A Condensed Overview\"|g" \
  "$ARXIV_METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|name: \"Your Name\"|name: \"${AUTHOR_NAME}\"|g" \
  "$ARXIV_METADATA_YAML"

"${SED_INPLACE[@]}" \
  "s|affiliation: \"your-site.example\"|affiliation: \"${AUTHOR_AFFILIATION}\"|g" \
  "$ARXIV_METADATA_YAML"

# publishing/arxiv-paper/main.md
"${SED_INPLACE[@]}" \
  "s|title: \"YOUR BOOK TITLE: A Condensed Overview\"|title: \"${BOOK_TITLE}: A Condensed Overview\"|g" \
  "$ARXIV_MAIN_MD"

# ── Report ─────────────────────────────────────────────────────────────────────
echo ""
echo "Updated: publishing/metadata.yaml"
echo "Updated: publishing/outline.yaml"
echo "Updated: publishing/arxiv-paper/metadata.yaml"
echo "Updated: publishing/arxiv-paper/main.md"
echo ""
echo "Next steps:"
echo "  1. Write your chapters in drafts/"
echo "  2. Update publishing/build.sh DRAFT_FILES list to match your chapters"
echo "  3. Run: bash publishing/validate.sh"
echo "  4. Build: bash publishing/run-container.sh kdp"
