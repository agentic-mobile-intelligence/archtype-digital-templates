#!/usr/bin/env bash
# build.sh — PDF compilation for YOUR BOOK TITLE
# Targets: KDP 8×10 book, arXiv letter PDF, EPUB, HTML
# Usage: bash publishing/build.sh [kdp|arxiv|epub|html|all|release]
set -euo pipefail

BOOK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DRAFTS_DIR="$BOOK_ROOT/drafts"
PUB_DIR="$BOOK_ROOT/published"
ARCHIVE_DIR="$PUB_DIR/archive"
META="$BOOK_ROOT/publishing/metadata.yaml"
SECRETS_FILE="$(dirname "$BOOK_ROOT")/.secrets/.env"

# ── Version string: YYYY-MM-DD-SHORTSHA ───────────────────────────────────────
compute_version() {
  local date_part sha_part
  date_part=$(date +%Y-%m-%d)
  sha_part=$(git -C "$BOOK_ROOT" rev-parse --short HEAD 2>/dev/null || echo "local")
  BUILD_VERSION="${date_part}-${sha_part}"
  echo "Version: $BUILD_VERSION"
}

# ── Dependency checks ──────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v pandoc  >/dev/null 2>&1 || missing+=("pandoc (brew install pandoc)")
  command -v xelatex >/dev/null 2>&1 || missing+=("xelatex (brew install --cask mactex OR brew install basictex)")
  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: Missing required tools:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
  fi
  echo "pandoc $(pandoc --version | head -1 | awk '{print $2}'), xelatex found"

  # Locate eisvogel
  local data_dir=""
  if pandoc --print-data-dir >/dev/null 2>&1; then
    data_dir="$(pandoc --print-data-dir)"
  else
    data_dir="${HOME}/.pandoc"
  fi
  local template_path="$data_dir/templates/eisvogel.latex"
  if [ -f "$template_path" ]; then
    KDP_TEMPLATE="eisvogel"
    echo "eisvogel template found — using for KDP build"
  else
    KDP_TEMPLATE="default"
    echo "WARNING: eisvogel template not found — KDP build will use default template"
    echo "  Install: https://github.com/Wandmalfarbe/pandoc-latex-template"
  fi
}

# ── Regenerate derived drafts from canonical YAML sources ──────────────────────
regenerate_derived() {
  if [ ! -f "$BOOK_ROOT/publishing/patterns.yaml" ]; then
    return 0
  fi
  local gen_script="$BOOK_ROOT/publishing/generate-quick-reference.py"
  if [ ! -f "$gen_script" ]; then
    return 0
  fi
  if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
    python3 "$gen_script"
  else
    echo "WARNING: python3 + PyYAML not available — skipping quick-reference regen"
    echo "  Install: pip install pyyaml"
  fi
}

# ── Draft file list (explicit, in render order) ────────────────────────────────
# ── Draft file list (explicit, in render order) ────────────────────────────────
# Edit this list to match your chapter files. Order here is the render order.
DRAFT_FILES=(
  "$DRAFTS_DIR/00-preface.md"
  "$DRAFTS_DIR/01-introduction.md"
  "$DRAFTS_DIR/01b-part1.md"
  "$DRAFTS_DIR/02-ch1.md"
  "$DRAFTS_DIR/03-ch2.md"
  # Add more chapters here...
  "$DRAFTS_DIR/20-index.md"
)

validate_files() {
  local missing=()
  local empty_files=()
  local draft_status_files=()
  for f in "${DRAFT_FILES[@]}"; do
    if [ ! -f "$f" ]; then
      missing+=("$f")
    else
      if [ ! -s "$f" ]; then
        empty_files+=("$f")
      fi
      local status
      status=$(grep -m1 '^status:' "$f" 2>/dev/null | awk -F': ' '{print $2}' | tr -d ' \r' || true)
      if [ "$status" = "draft" ]; then
        draft_status_files+=("$f")
      fi
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: Missing draft files:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
  fi
  if [ ${#empty_files[@]} -gt 0 ]; then
    echo "WARNING: ${#empty_files[@]} draft file(s) is empty:"
    printf '  %s\n' "${empty_files[@]}"
  fi
  if [ ${#draft_status_files[@]} -gt 0 ]; then
    echo "WARNING: ${#draft_status_files[@]} files have status: draft and will be included in the build:"
    printf '  %s\n' "${draft_status_files[@]}"
  fi
  echo "${#DRAFT_FILES[@]} draft files validated"
}

# ── Archive previous versioned builds ─────────────────────────────────────────
archive_old_builds() {
  mkdir -p "$ARCHIVE_DIR"
  local archived=0
  for f in "$PUB_DIR"/book-*.pdf \
           "$PUB_DIR"/arxiv-*.pdf \
           "$PUB_DIR"/book-*.epub \
           "$PUB_DIR"/book-*.html; do
    [ -f "$f" ] || continue
    [[ "$(basename "$f")" == *"${BUILD_VERSION}"* ]] && continue
    mv "$f" "$ARCHIVE_DIR/" && (( archived++ )) || true
  done
  [ "$archived" -gt 0 ] && echo "Archived $archived previous build(s) → $ARCHIVE_DIR"
  return 0
}

# ── Build index (published/BUILDS.md) ─────────────────────────────────────────
update_build_index() {
  local index="$PUB_DIR/BUILDS.md"
  if [ ! -f "$index" ]; then
    printf '# Build History\n\n| Build | Date | SHA | Files |\n|-------|------|-----|-------|\n' > "$index"
  fi
  local files="" date_part sha_part
  date_part="${BUILD_VERSION%-*}"
  sha_part="${BUILD_VERSION##*-}"
  [ -f "$PUB_DIR/book-${BUILD_VERSION}.pdf"  ] && files+="book.pdf "
  [ -f "$PUB_DIR/arxiv-${BUILD_VERSION}.pdf" ] && files+="arxiv.pdf "
  [ -f "$PUB_DIR/book-${BUILD_VERSION}.epub" ] && files+="book.epub "
  [ -f "$PUB_DIR/book-${BUILD_VERSION}.html" ] && files+="book.html "
  printf '| %s | %s | %s | %s |\n' \
    "$BUILD_VERSION" "$date_part" "$sha_part" "${files% }" >> "$index"
  echo "Build index updated → $index"
}

# ── Stats ──────────────────────────────────────────────────────────────────────
report_stats() {
  local pdf="$1" label="$2"
  if [ ! -f "$pdf" ]; then
    echo "[$label] BUILD FAILED — output not created" >&2; exit 1
  fi
  local size pages=""
  size=$(du -sh "$pdf" | cut -f1)
  if [[ "$pdf" == *.pdf ]] && command -v pdfinfo >/dev/null 2>&1; then
    pages=$(pdfinfo "$pdf" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
    echo "[$label] OK — $pdf — ${pages} pages, ${size}"
  else
    echo "[$label] OK — $pdf — ${size}"
  fi
}

# ── Target: KDP 8×10 Book ──────────────────────────────────────────────────────
build_kdp() {
  echo ""
  echo "==> Building KDP target (8×10 book)..."
  mkdir -p "$PUB_DIR"

  pandoc \
    --metadata-file="$META" \
    --pdf-engine=xelatex \
    --template="$KDP_TEMPLATE" \
    --include-in-header="$BOOK_ROOT/publishing/latex-preamble.tex" \
    --top-level-division=chapter \
    --toc \
    --toc-depth=2 \
    --variable papersize=custom \
    --variable "geometry=paperwidth=8in,paperheight=10in,top=0.85in,bottom=0.85in,inner=1.125in,outer=0.875in,includeheadfoot" \
    --variable documentclass=book \
    --variable fontsize=10pt \
    --variable book=true \
    --variable titlepage=true \
    --variable disable-header-and-footer=true \
    --variable "titlepage-color=1A1A2E" \
    --variable "titlepage-text-color=EEEEEE" \
    --variable "titlepage-rule-color=4A90D9" \
    --variable titlepage-rule-height=4 \
    --highlight-style=tango \
    --listings \
    -o "$PUB_DIR/book-${BUILD_VERSION}.pdf" \
    "${DRAFT_FILES[@]}"

  cp "$PUB_DIR/book-${BUILD_VERSION}.pdf" "$PUB_DIR/book.pdf"
  report_stats "$PUB_DIR/book-${BUILD_VERSION}.pdf" "KDP"
}

# ── Target: arXiv letter PDF ───────────────────────────────────────────────────
build_arxiv() {
  echo ""
  echo "==> Building arXiv target (letter, single-column)..."
  mkdir -p "$PUB_DIR"

  pandoc \
    --metadata-file="$META" \
    --pdf-engine=xelatex \
    --top-level-division=chapter \
    --toc \
    --toc-depth=1 \
    --variable documentclass=report \
    --variable "classoption=12pt" \
    --variable papersize=letter \
    --variable "geometry=margin=1in" \
    --variable fontsize=12pt \
    --variable linestretch=1.2 \
    --highlight-style=monochrome \
    --listings \
    -o "$PUB_DIR/arxiv-${BUILD_VERSION}.pdf" \
    "${DRAFT_FILES[@]}"

  cp "$PUB_DIR/arxiv-${BUILD_VERSION}.pdf" "$PUB_DIR/arxiv.pdf"
  report_stats "$PUB_DIR/arxiv-${BUILD_VERSION}.pdf" "arXiv"
}

# ── Target: EPUB e-book ────────────────────────────────────────────────────────
build_epub() {
  echo ""
  echo "==> Building EPUB target..."
  mkdir -p "$PUB_DIR"

  pandoc \
    --metadata-file="$META" \
    --toc \
    --toc-depth=2 \
    --epub-cover-image="$BOOK_ROOT/book-cover/cover.jpg" \
    --to epub3 \
    -o "$PUB_DIR/book-${BUILD_VERSION}.epub" \
    "${DRAFT_FILES[@]}" 2>/dev/null || \
  pandoc \
    --metadata-file="$META" \
    --toc \
    --toc-depth=2 \
    --to epub3 \
    -o "$PUB_DIR/book-${BUILD_VERSION}.epub" \
    "${DRAFT_FILES[@]}"

  cp "$PUB_DIR/book-${BUILD_VERSION}.epub" "$PUB_DIR/book.epub"
  report_stats "$PUB_DIR/book-${BUILD_VERSION}.epub" "EPUB"
}

# ── Target: HTML preview ───────────────────────────────────────────────────────
build_html() {
  echo ""
  echo "==> Building HTML preview..."
  mkdir -p "$PUB_DIR"

  pandoc \
    --metadata-file="$META" \
    --toc \
    --toc-depth=2 \
    --standalone \
    --embed-resources \
    --highlight-style=tango \
    -o "$PUB_DIR/book-${BUILD_VERSION}.html" \
    "${DRAFT_FILES[@]}"

  cp "$PUB_DIR/book-${BUILD_VERSION}.html" "$PUB_DIR/book.html"
  report_stats "$PUB_DIR/book-${BUILD_VERSION}.html" "HTML"
}

# ── Target: Gitea release ──────────────────────────────────────────────────────
build_release() {
  echo ""
  echo "==> Pushing release to Gitea (tag: build-${BUILD_VERSION})..."

  if [ ! -f "$SECRETS_FILE" ]; then
    echo "ERROR: .secrets/.env not found at $SECRETS_FILE" >&2; exit 1
  fi
  local token repo_name release_id
  token=$(grep GITEA_TOKEN "$SECRETS_FILE" | cut -d= -f2 | tr -d '\n ')
  [ -z "$token" ] && { echo "ERROR: GITEA_TOKEN not in $SECRETS_FILE" >&2; exit 1; }

  repo_name=$(basename "$BOOK_ROOT")
  local api="https://amiable-beetle-gitea-server.cloud.nexlayer.ai/api/v1"
  local repo="elizaga/${repo_name}"

  # Create release
  release_id=$(curl -s -X POST "${api}/repos/${repo}/releases" \
    -H "Authorization: token ${token}" \
    -H "Content-Type: application/json" \
    -d "{\"tag_name\":\"build-${BUILD_VERSION}\",\"name\":\"Build ${BUILD_VERSION}\",\"body\":\"Auto-published build — ${BUILD_VERSION}\",\"draft\":false}" \
    | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null)

  [ -z "$release_id" ] && { echo "ERROR: Failed to create Gitea release" >&2; exit 1; }
  echo "Gitea release created — ID: $release_id"

  # Upload PDF assets
  for asset in \
    "$PUB_DIR/book-${BUILD_VERSION}.pdf" \
    "$PUB_DIR/arxiv-${BUILD_VERSION}.pdf"; do
    [ -f "$asset" ] || continue
    local fname
    fname=$(basename "$asset")
    curl -s -X POST "${api}/repos/${repo}/releases/${release_id}/assets" \
      -H "Authorization: token ${token}" \
      -F "attachment=@${asset}" >/dev/null && echo "  Uploaded: $fname"
  done
  echo "Release: https://amiable-beetle-gitea-server.cloud.nexlayer.ai/${repo}/releases/tag/build-${BUILD_VERSION}"
}

# ── Main ───────────────────────────────────────────────────────────────────────
usage() {
  cat <<USAGE
Usage: $(basename "$0") [kdp|arxiv|epub|html|all|release]

Targets:
  kdp      8×10 print-ready PDF for KDP / IngramSpark
  arxiv    Letter-size PDF for arXiv or preprint repositories
  epub     EPUB e-book (epub3)
  html     Single-file HTML preview (self-contained)
  all      All targets: kdp + arxiv + epub + html (default)
  release  Build kdp + arxiv, archive old builds, push Gitea release

Version format: YYYY-MM-DD-SHORTSHA  (e.g. 2026-04-23-df70723)
Output:        published/book-<version>.pdf  +  published/book.pdf (latest copy)
Archive:       published/archive/<previous-builds>

Requirements: pandoc, xelatex
Optional:     python3 + pyyaml, pdfinfo (poppler)
USAGE
}

TARGET="${1:-all}"

case "$TARGET" in
  -h|--help) usage; exit 0 ;;
esac

check_deps
compute_version
regenerate_derived
validate_files

case "$TARGET" in
  kdp)     build_kdp;    archive_old_builds; update_build_index ;;
  arxiv)   build_arxiv;  archive_old_builds; update_build_index ;;
  epub)    build_epub;   archive_old_builds; update_build_index ;;
  html)    build_html;   archive_old_builds; update_build_index ;;
  all)     build_kdp; build_arxiv; build_epub; build_html
           archive_old_builds; update_build_index ;;
  release) build_kdp; build_arxiv
           archive_old_builds; update_build_index; build_release ;;
  *)       usage; exit 1 ;;
esac

echo ""
echo "Output files:"
ls -lh "$PUB_DIR"/*.pdf "$PUB_DIR"/*.epub "$PUB_DIR"/*.html 2>/dev/null | grep -v '/archive/' || echo "  (none)"
