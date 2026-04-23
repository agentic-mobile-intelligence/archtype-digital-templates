#!/usr/bin/env bash
# validate.sh — pre-flight checks before running build.sh
# Usage: bash publishing/validate.sh
set -euo pipefail

BOOK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'; NC='\033[0m'
if [ ! -t 1 ]; then RED=''; YELLOW=''; GREEN=''; NC=''; fi

ERRORS=0

fail()  { echo -e "${RED}FAIL${NC}  $*" >&2; (( ERRORS++ )) || true; }
warn()  { echo -e "${YELLOW}WARN${NC}  $*"; }
ok()    { echo -e "${GREEN}OK${NC}    $*"; }

echo "==> validate.sh — pre-flight checks for $(basename "$BOOK_ROOT")"
echo ""

# ── 1. Tool availability ───────────────────────────────────────────────────────
echo "--- Tool checks ---"

if command -v pandoc >/dev/null 2>&1; then
  ok "pandoc $(pandoc --version | head -1 | awk '{print $2}')"
else
  fail "pandoc not found (brew install pandoc)"
fi

if command -v xelatex >/dev/null 2>&1; then
  ok "xelatex found"
else
  warn "xelatex not found — PDF builds will fail (brew install --cask mactex OR brew install basictex)"
fi

if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
  ok "python3 + pyyaml found"
else
  warn "python3 or pyyaml not available — pattern quick-reference regeneration will be skipped"
  warn "  Install: pip install pyyaml"
fi

echo ""

# ── 2. YAML syntax validation ──────────────────────────────────────────────────
echo "--- YAML syntax checks ---"

check_yaml() {
  local file="$1"
  if [ ! -f "$file" ]; then
    warn "YAML file not found (skipping): $file"
    return
  fi
  if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
    ok "$file"
  else
    fail "$file — YAML parse error"
    python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>&1 | sed 's/^/       /' >&2
  fi
}

check_yaml "$BOOK_ROOT/publishing/metadata.yaml"
check_yaml "$BOOK_ROOT/publishing/outline.yaml"

if [ -f "$BOOK_ROOT/publishing/patterns.yaml" ]; then
  check_yaml "$BOOK_ROOT/publishing/patterns.yaml"
else
  warn "publishing/patterns.yaml not found — skipping (optional for pattern books)"
fi

check_yaml "$BOOK_ROOT/publishing/arxiv-paper/metadata.yaml"

echo ""

# ── 3. Placeholder value checks ───────────────────────────────────────────────
echo "--- Placeholder checks ---"

META="$BOOK_ROOT/publishing/metadata.yaml"
if [ -f "$META" ]; then
  if grep -q "YOUR BOOK TITLE" "$META" 2>/dev/null; then
    warn "metadata.yaml still contains placeholder: 'YOUR BOOK TITLE'"
  else
    ok "metadata.yaml: title placeholder replaced"
  fi

  if grep -q "Your Name" "$META" 2>/dev/null; then
    warn "metadata.yaml still contains placeholder: 'Your Name'"
  else
    ok "metadata.yaml: author placeholder replaced"
  fi
else
  fail "metadata.yaml not found: $META"
fi

echo ""

# ── 4. Draft file existence and non-empty check ────────────────────────────────
echo "--- Draft file checks ---"

BUILD_SH="$BOOK_ROOT/publishing/build.sh"
if [ ! -f "$BUILD_SH" ]; then
  fail "build.sh not found: $BUILD_SH"
  echo ""
else
  # Parse lines of the form: "$DRAFTS_DIR/filename.md"
  # Extract just the filename portion after $DRAFTS_DIR/
  mapfile -t DRAFT_NAMES < <(
    grep -E '"\$DRAFTS_DIR/' "$BUILD_SH" \
      | sed 's/.*"\$DRAFTS_DIR\/\([^"]*\)".*/\1/' \
      | grep '\.md$'
  )

  if [ ${#DRAFT_NAMES[@]} -eq 0 ]; then
    warn "No draft files parsed from build.sh DRAFT_FILES array"
  else
    for name in "${DRAFT_NAMES[@]}"; do
      fpath="$BOOK_ROOT/drafts/$name"
      if [ ! -f "$fpath" ]; then
        fail "Draft file missing: drafts/$name"
      elif [ ! -s "$fpath" ]; then
        fail "Draft file is empty: drafts/$name"
      else
        ok "drafts/$name — exists and non-empty"
      fi
    done
  fi

  echo ""

  # ── 5. Frontmatter title check ─────────────────────────────────────────────
  echo "--- Frontmatter checks ---"

  for name in "${DRAFT_NAMES[@]}"; do
    fpath="$BOOK_ROOT/drafts/$name"
    if [ ! -f "$fpath" ]; then
      continue  # already reported above
    fi
    # Check first 10 lines for a title: line
    if head -10 "$fpath" | grep -q '^title:'; then
      ok "drafts/$name — has title: in frontmatter"
    else
      fail "drafts/$name — no 'title:' found in first 10 lines"
    fi
  done

  echo ""
fi

# ── Summary ────────────────────────────────────────────────────────────────────
if [ "$ERRORS" -eq 0 ]; then
  echo -e "${GREEN}All checks passed${NC}"
else
  echo -e "${RED}${ERRORS} error(s) found${NC}" >&2
fi

[ "$ERRORS" -eq 0 ]
