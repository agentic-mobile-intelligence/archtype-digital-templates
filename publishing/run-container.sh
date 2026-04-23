#!/usr/bin/env bash
# run-container.sh — build book PDFs via container (no local LaTeX required)
# Usage: bash publishing/run-container.sh [kdp|arxiv|all|condensed|condensed-tex]
#   kdp | arxiv | all  — runs publishing/build.sh (full-manuscript targets)
#   condensed          — runs publishing/build-arxiv.sh all (condensed preprint tex + pdf)
#   condensed-tex      — runs publishing/build-arxiv.sh tex (condensed preprint tex only)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BOOK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET="${1:-kdp}"
IMAGE="${IMAGE:-book-pdf}"
TEMPLATE_DIR="$SCRIPT_DIR/templates"
EISVOGEL_VERSION="${EISVOGEL_VERSION:-2.4.2}"
EISVOGEL_URL="https://github.com/Wandmalfarbe/pandoc-latex-template/releases/download/${EISVOGEL_VERSION}/Eisvogel-${EISVOGEL_VERSION}.tar.gz"

# Detect container runtime
if command -v podman >/dev/null 2>&1; then
  CONTAINER_CMD="podman"
elif command -v docker >/dev/null 2>&1; then
  CONTAINER_CMD="docker"
else
  echo "ERROR: Neither podman nor docker found. Install one to use container builds." >&2
  echo "  macOS: brew install podman  (or Docker Desktop from docker.com)" >&2
  exit 1
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [kdp|arxiv|epub|html|all|condensed|condensed-tex]

Targets:
  kdp            8x10 print-ready PDF for KDP / IngramSpark
  arxiv          Letter-size PDF for arXiv / preprint repositories
  epub           EPUB e-book (epub3)
  html           Single-file HTML preview (self-contained)
  all            All targets: kdp + arxiv + epub + html
  condensed      Condensed preprint PDF (arxiv-paper/main.md)
  condensed-tex  Condensed preprint .tex only (for arXiv source upload)

Environment variables:
  EISVOGEL_VERSION   Override eisvogel template version (default: $EISVOGEL_VERSION)
  IMAGE              Override container image name (default: $IMAGE)

Examples:
  bash publishing/run-container.sh all
  EISVOGEL_VERSION=2.5.0 bash publishing/run-container.sh kdp
  ls -lh published/*.pdf

Requires: podman or docker
See README.md for full documentation.
EOF
}

# Handle help flags
case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

# ── Build image if not present ─────────────────────────────────────────────────
if ! $CONTAINER_CMD image exists "$IMAGE" 2>/dev/null; then
  echo "==> Building container image..."
  $CONTAINER_CMD build -t "$IMAGE" -f "$SCRIPT_DIR/Containerfile" "$BOOK_ROOT" || {
    echo "ERROR: Container image build failed." >&2
    exit 1
  }
fi

# ── Download eisvogel template if not cached ───────────────────────────────────
mkdir -p "$TEMPLATE_DIR"
if [ ! -f "$TEMPLATE_DIR/eisvogel.latex" ]; then
  echo "==> Downloading eisvogel template..."
  TMP=$(mktemp -d)
  curl -fsSL -o "$TMP/eisvogel.tar.gz" "$EISVOGEL_URL"
  tar -xzf "$TMP/eisvogel.tar.gz" -C "$TMP"
  cp "$TMP"/*.latex "$TEMPLATE_DIR/eisvogel.latex" 2>/dev/null || \
    find "$TMP" -name "eisvogel.latex" -exec cp {} "$TEMPLATE_DIR/eisvogel.latex" \;
  rm -rf "$TMP"
  echo "   eisvogel.latex saved to $TEMPLATE_DIR"
fi

# ── Route to the appropriate build script ──────────────────────────────────────
case "$TARGET" in
  kdp|arxiv|all|epub|html)
    BUILD_CMD=(bash publishing/build.sh "$TARGET")
    ;;
  condensed)
    BUILD_CMD=(bash publishing/build-arxiv.sh all)
    ;;
  condensed-tex)
    BUILD_CMD=(bash publishing/build-arxiv.sh tex)
    ;;
  *)
    echo "Unknown target: $TARGET" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
esac

# ── Run build inside container ─────────────────────────────────────────────────
echo "==> Running build (target: $TARGET)..."
$CONTAINER_CMD run --rm \
  -v "$BOOK_ROOT:/data:z" \
  -v "$TEMPLATE_DIR/eisvogel.latex:/root/.pandoc/templates/eisvogel.latex:ro,z" \
  -v "$TEMPLATE_DIR/eisvogel.latex:/root/.local/share/pandoc/templates/eisvogel.latex:ro,z" \
  -w /data \
  "$IMAGE" \
  "${BUILD_CMD[@]}"
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
  echo "" >&2
  echo "ERROR: Build failed inside container (exit $EXIT_CODE)." >&2
  echo "  Re-run with: CONTAINER_LOG=1 bash publishing/run-container.sh $TARGET" >&2
  exit $EXIT_CODE
fi
