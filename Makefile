.PHONY: help build kdp arxiv condensed epub html validate stats clean init \
        container-kdp container-arxiv container-condensed container-all all

# Default target
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Build targets:"
	@echo "  kdp         8x10 print-ready PDF for KDP"
	@echo "  arxiv       Letter-size PDF for arXiv"
	@echo "  epub        EPUB e-book"
	@echo "  html        Single-file HTML preview"
	@echo "  condensed   Condensed preprint PDF (arxiv-paper/)"
	@echo "  all         kdp + arxiv + epub + html"
	@echo ""
	@echo "Utility:"
	@echo "  validate    Pre-flight checks (tools, YAML, drafts)"
	@echo "  stats       Word count per chapter"
	@echo "  clean       Remove published/ output files"
	@echo "  init        First-time setup (set title, author, etc.)"
	@echo ""
	@echo "Container builds (no local LaTeX required):"
	@echo "  container-kdp        Container build: KDP"
	@echo "  container-arxiv      Container build: arXiv"
	@echo "  container-condensed  Container build: condensed preprint"
	@echo "  container-all        Container build: all"

build: kdp arxiv epub html

kdp:
	bash publishing/build.sh kdp

arxiv:
	bash publishing/build.sh arxiv

epub:
	bash publishing/build.sh epub

html:
	bash publishing/build.sh html

condensed:
	bash publishing/build-arxiv.sh all

all: kdp arxiv epub html

validate:
	bash publishing/validate.sh

stats:
	bash publishing/stats.sh

init:
	bash publishing/init.sh

clean:
	rm -f published/*.pdf published/*.tex published/*.aux published/*.log \
	      published/*.out published/*.toc published/*.bbl published/*.blg \
	      published/*.fls published/*.fdb_latexmk published/arxiv-condensed* \
	      published/references.bib published/*.epub published/*.html
	@echo "Cleaned published/"

container-kdp:
	bash publishing/run-container.sh kdp

container-arxiv:
	bash publishing/run-container.sh arxiv

container-condensed:
	bash publishing/run-container.sh condensed

container-all:
	bash publishing/run-container.sh all
