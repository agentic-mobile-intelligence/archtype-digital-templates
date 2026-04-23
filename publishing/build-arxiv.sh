#!/usr/bin/env bash
# build-arxiv.sh — condensed arXiv preprint build
# Input:  publishing/arxiv-paper/main.md + metadata.yaml + references.bib
# Output: published/arxiv-condensed.tex (arXiv source upload)
#         published/arxiv-condensed.pdf (local preview)
# Usage:  bash publishing/build-arxiv.sh [tex|pdf|all]     (default: all)
set -euo pipefail

BOOK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAPER_DIR="$BOOK_ROOT/publishing/arxiv-paper"
PUB_DIR="$BOOK_ROOT/published"
TEMPLATE="$BOOK_ROOT/publishing/templates/arxiv.latex"
SRC="$PAPER_DIR/main.md"
META="$PAPER_DIR/metadata.yaml"
BIB="$PAPER_DIR/references.bib"

TARGET="${1:-all}"

# ── Dependency checks ────────────────────────────────────────────────────────
check_deps() {
  local missing=()
  command -v pandoc  >/dev/null 2>&1 || missing+=("pandoc (brew install pandoc)")
  command -v xelatex >/dev/null 2>&1 || missing+=("xelatex (brew install --cask mactex OR brew install basictex)")
  if [ "$TARGET" != "tex" ]; then
    command -v latexmk >/dev/null 2>&1 || missing+=("latexmk (bundled with MacTeX)")
  fi
  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: Missing required tools:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
  fi
  echo "pandoc $(pandoc --version | head -1 | awk '{print $2}'), xelatex found"
}

# ── Input validation ─────────────────────────────────────────────────────────
validate_inputs() {
  local missing=()
  [ -f "$SRC" ]      || missing+=("$SRC")
  [ -f "$META" ]     || missing+=("$META")
  [ -f "$TEMPLATE" ] || missing+=("$TEMPLATE")
  [ -f "$BIB" ]      || missing+=("$BIB")
  if [ ${#missing[@]} -gt 0 ]; then
    echo "ERROR: Missing input files:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    exit 1
  fi
  local words
  words=$(wc -w < "$SRC" | tr -d ' ')
  echo "source: $SRC ($words words)"
  if [ "$words" -lt 500 ]; then
    echo "  NOTE: source is very short — placeholder/skeleton state"
  fi
}

# ── TeX emission (arXiv source upload) ───────────────────────────────────────
build_tex() {
  echo ""
  echo "==> Emitting LaTeX source for arXiv upload..."
  mkdir -p "$PUB_DIR"

  pandoc \
    --metadata-file="$META" \
    --template="$TEMPLATE" \
    --natbib \
    --bibliography="$BIB" \
    --top-level-division=section \
    --standalone \
    -f markdown+yaml_metadata_block+raw_tex \
    -t latex \
    -o "$PUB_DIR/arxiv-condensed.tex" \
    "$SRC"

  cp "$BIB" "$PUB_DIR/references.bib"

  echo "  tex: $PUB_DIR/arxiv-condensed.tex"
  echo "  bib: $PUB_DIR/references.bib"
  echo "  (arXiv upload: tar -czf submission.tar.gz arxiv-condensed.tex references.bib)"
}

# ── PDF build (local preview via pandoc → xelatex → bibtex → xelatex×2) ──────
build_pdf() {
  echo ""
  echo "==> Building PDF preview..."
  mkdir -p "$PUB_DIR"

  [ -f "$PUB_DIR/arxiv-condensed.tex" ] || build_tex

  (
    cd "$PUB_DIR"
    latexmk -xelatex -interaction=nonstopmode -halt-on-error \
            -bibtex arxiv-condensed.tex >/dev/null
  )

  local pdf="$PUB_DIR/arxiv-condensed.pdf"
  if [ ! -f "$pdf" ]; then
    echo "ERROR: PDF build failed — check $PUB_DIR/arxiv-condensed.log" >&2
    exit 1
  fi

  local size pages=""
  size=$(du -sh "$pdf" | cut -f1)
  if command -v pdfinfo >/dev/null 2>&1; then
    pages=$(pdfinfo "$pdf" 2>/dev/null | grep "^Pages:" | awk '{print $2}')
    echo "  pdf: $pdf — ${pages} pages, ${size}"
    if [ -n "$pages" ] && [ "$pages" -gt 30 ]; then
      echo "  WARN: $pages pages exceeds ~25pp target for condensed preprint"
    fi
  else
    echo "  pdf: $pdf — ${size}"
  fi

  if command -v pdffonts >/dev/null 2>&1; then
    echo "  font embedding check:"
    if pdffonts "$pdf" | awk 'NR>2 {print $(NF-4)}' | grep -q "no"; then
      echo "    FAIL: at least one font is not embedded — arXiv will reject"
      pdffonts "$pdf" | awk 'NR<=2 || $(NF-4)=="no"'
      exit 1
    else
      echo "    OK: all fonts embedded"
    fi
  fi
}

# ── Main ─────────────────────────────────────────────────────────────────────
usage() { echo "Usage: $0 [tex|pdf|all]"; }

check_deps
validate_inputs

case "$TARGET" in
  tex) build_tex ;;
  pdf) build_pdf ;;
  all) build_tex; build_pdf ;;
  *)   usage; exit 1 ;;
esac

echo ""
echo "Outputs in $PUB_DIR:"
ls -lh "$PUB_DIR"/arxiv-condensed.* 2>/dev/null || echo "  (none)"
