---
title: "Appendix A: The template-start-from-here Reference"
chapter: back-matter
status: draft
---

# Appendix A: The template-start-from-here Reference

This appendix is your field manual for the archetype-digital-templates repository itself. Throughout this book we have discussed patterns for managing upstream and downstream change in template-driven development. This repository is a living example of those patterns—a template designed to produce technical books while remaining syncable with its own upstream archetype. What follows is a complete walkthrough of every directory, configuration file, and automation hook in the repository so that you can fork it, customize it, and begin writing immediately.

## Directory Structure

The top-level layout separates content from tooling, following the tooling-layer separation pattern described in Chapter 5.

```
archtype-digital-templates/
├── drafts/              # All chapter manuscripts (Markdown)
├── publishing/          # Build scripts, metadata, and tooling
├── assets/              # Figures, diagrams, and images
├── book-cover/          # Cover artwork for EPUB and print
├── archive/             # Retired or superseded material
├── published/           # Build output (gitignored)
├── .github/workflows/   # CI pipelines
├── Makefile             # Developer-facing build targets
├── .pre-commit-config.yaml
├── .editorconfig
├── .gitignore
└── README.md
```

The critical boundary is between `drafts/` and `publishing/`. Content lives in `drafts/`; everything required to turn that content into a finished artifact lives in `publishing/`. This separation means upstream tooling improvements can be merged without touching your prose, and your prose edits never risk breaking the build pipeline.

The `published/` directory is gitignored. Build artifacts—PDFs, EPUBs, HTML files—are generated locally or in CI and never committed to the repository. The `archive/` directory holds retired builds, moved there automatically when a new build version replaces the previous one.

## The publishing/ Directory

This directory is the contract surface between your content and the build system. Everything the build pipeline needs—and nothing it does not—lives here.

**metadata.yaml** is the single source of truth for the book's identity. It contains the title, subtitle, author information (name, affiliation, optional ORCID), copyright year, license, subject classification, and keyword list. It also controls PDF rendering: font selections (TeX Gyre Pagella for body text, TeX Gyre Heros for sans-serif headings, Inconsolata for code), table-of-contents depth, line spacing, color-link settings, and LaTeX header includes for packages like `booktabs`, `longtable`, and `listings`. Publishing identifiers—ISBN (print and e-book), ASIN, LCCN, publisher imprint, edition label, and semantic version—are present as commented-out fields, ready to uncomment when the book moves from preprint to release.

**outline.yaml** defines the book's structure declaratively. It maps every front-matter piece, part divider, chapter, and back-matter section to its source file in `drafts/`, listing the section headings each chapter contains. The outline serves three purposes: it is the canonical table of contents used by authors and editors; it drives validation checks that confirm every referenced file exists and contains the expected frontmatter; and it provides a machine-readable manifest that tooling can consume for tasks like generating a pattern quick-reference or computing per-chapter word counts.

**build.sh** is the primary build script. It accepts a single target argument—`kdp`, `arxiv`, `epub`, `html`, `all`, or `release`—and drives Pandoc with the appropriate flags for each output format. The KDP target produces an 8×10-inch print-ready PDF using the Eisvogel LaTeX template with custom geometry, title-page colors, and the `listings` package for code blocks. The arXiv target produces a letter-size, 12-point, single-column PDF suitable for preprint repositories. The EPUB target generates an EPUB3 e-book, optionally embedding a cover image from `book-cover/`. The HTML target produces a single self-contained HTML file for browser preview. Every build is versioned with a `YYYY-MM-DD-SHORTSHA` stamp derived from the current date and the Git short hash, so every artifact is traceable to a specific commit. Previous builds are automatically archived into `published/archive/`, and a `BUILDS.md` index file in `published/` logs each build's version, date, SHA, and output files.

**build-arxiv.sh** handles a separate condensed-preprint workflow for producing a standalone arXiv paper from `publishing/arxiv-paper/`, independent of the full book build.

**validate.sh** runs pre-flight checks before building. It verifies that required tools are installed (Pandoc, XeLaTeX, Python 3 with PyYAML), validates YAML syntax in `metadata.yaml`, `outline.yaml`, and `patterns.yaml`, checks that placeholder values like "YOUR BOOK TITLE" and "Your Name" have been replaced, confirms every file listed in the `DRAFT_FILES` array exists and is non-empty, and inspects each draft's frontmatter for the required `title:` field.

**init.sh** is a one-time interactive setup script. It prompts for the book title, subtitle, author name, affiliation, ORCID, copyright year, and subject area, then performs find-and-replace across `metadata.yaml`, `outline.yaml`, and the arXiv paper files to swap placeholder values for real ones. Run it once after forking the template; it is idempotent but designed for initial configuration.

**stats.sh** produces a per-chapter word-count table, stripping YAML frontmatter, fenced code blocks, HTML comments, and Markdown headers before counting. It flags files below a 200-word threshold as stubs and writes a `.word-count.json` snapshot to the repository root for programmatic consumption.

**Other files**: `latex-preamble.tex` contains LaTeX preamble customizations included in every PDF build. `patterns.yaml` is an optional structured catalog of patterns (used in this book to define the patterns described in Part 2). `generate-quick-reference.py` reads `patterns.yaml` and writes a formatted quick-reference appendix to `drafts/`. `Containerfile` and `run-container.sh` support containerized builds so authors without a local LaTeX installation can produce PDFs via Podman or Docker.

## metadata.yaml in Detail

The metadata file doubles as a Pandoc metadata file, meaning every key-value pair is passed directly to Pandoc's template engine. This is by design: rather than maintaining a separate configuration layer, the template uses Pandoc's native metadata mechanism so that a single file controls both the book's identity and its rendering behavior.

Key sections:

- **Identity**: `title`, `subtitle`, `author` (with nested `name`, `affiliation`, `orcid`), `date`, `rights`, `lang`, `subject`, `keywords`.
- **Publishing IDs** (commented until release): `isbn-print`, `isbn-ebook`, `asin`, `lccn`, `publisher`, `version`, `edition`.
- **PDF controls**: `colorlinks`, `linkcolor`, `urlcolor`, `toccolor`, `numbersections`, `toc`, `toc-depth`, `lof`, `lot`.
- **Typography**: `top-level-division`, `linestretch`, `mainfont`, `sansfont`, `monofont`, `monofontoptions`.
- **Code rendering**: `listings: true` enables the LaTeX `listings` package. The `header-includes` block configures `lstset` defaults for font size, line breaking, frame style, and margins.

When you fork the template, run `make init` (which calls `publishing/init.sh`) to replace placeholder values. After that, edit `metadata.yaml` directly for any further customization.

## outline.yaml Structure

The outline is organized into four top-level keys: `front_matter`, `part_1` through `part_N`, and `back_matter`. Each part has a `title`, an optional `divider_file` (a Markdown file that renders as a part title page), and a `chapters` array. Each chapter entry specifies a `number`, `title`, `source_file`, and `sections` list. Front-matter and back-matter entries use an `id` instead of a chapter number.

This structure makes it straightforward for automated tooling to enumerate chapters, verify file existence, or generate navigation. If you add or remove a chapter, update both `outline.yaml` and the `DRAFT_FILES` array in `build.sh`—the validation script will catch any mismatch.

## Draft Frontmatter Conventions

Every Markdown file in `drafts/` begins with a YAML frontmatter block delimited by `---`. The required fields are:

- **title**: The chapter or section title as it should appear in the table of contents and rendered output.
- **chapter**: A chapter number (integer) for body chapters, or a label like `front-matter` or `back-matter` for non-numbered sections.
- **status**: One of `draft`, `review`, or `final`. The build script warns when files with `status: draft` are included in the output, giving authors a visual reminder of incomplete work.

Part divider files (e.g., `01b-part1.md`, `04b-part2.md`) use a simplified frontmatter with just `title` and `chapter`, since they exist only to insert a part title page in the rendered output.

File naming follows the convention `NN-slug.md` where `NN` is a two-digit sort key. Part dividers use a `b` suffix (e.g., `01b`) to sort between the preceding section and the first chapter of the part. This naming scheme ensures that a simple alphabetical sort produces the correct reading order.

## CI Workflows

Two GitHub Actions workflows automate validation and builds.

**validate.yml** runs on every pull request and every push to `main`. It installs Pandoc, Python 3, and PyYAML, then executes `publishing/validate.sh`. This catches YAML syntax errors, missing draft files, unfilled placeholders, and missing frontmatter before any build is attempted. It is lightweight and fast—no LaTeX installation required.

**build.yml** runs on pushes to `main`, on version tags (`v*`), and on pull requests. The build job installs the full LaTeX toolchain (texlive-xetex, texlive-fonts-recommended, texlive-fonts-extra, texlive-latex-extra, fonts-texgyre, fonts-inconsolata), downloads and installs the Eisvogel template, and runs `publishing/build.sh kdp` to produce the print-ready PDF. On pushes to `main`, the resulting PDF is uploaded as a GitHub Actions artifact. A separate release job triggers only on version tags: it builds all targets (KDP, arXiv, EPUB, HTML) plus the condensed arXiv paper, then creates a GitHub Release with the generated files attached and auto-generated release notes.

The apt package cache is preserved between runs using `actions/cache` keyed on the workflow file hash, so repeat builds skip the network fetch for unchanged packages.

## Pre-Commit Hooks

The `.pre-commit-config.yaml` file defines hooks that run automatically before every commit, catching problems at authoring time rather than in CI.

**File hygiene hooks** (from `pre-commit/pre-commit-hooks`):

- `check-yaml`: Validates YAML syntax across all `.yaml` and `.yml` files.
- `check-added-large-files`: Blocks files over 500 KB (excluding `published/`), preventing accidental commits of build artifacts or large binaries.
- `end-of-file-fixer`: Ensures every file ends with a newline.
- `trailing-whitespace`: Strips trailing whitespace, with an exception for Markdown's intentional double-space line breaks.
- `mixed-line-ending`: Normalizes all line endings to LF.
- `no-commit-to-branch`: Prevents direct commits to `main`, encouraging branch-based workflows.

**Custom local hooks**:

- `no-placeholder-title`: Scans YAML and Markdown files for the string "YOUR BOOK TITLE," catching cases where `init.sh` was not run or a file was added without updating the placeholder.
- `no-placeholder-author`: Scans YAML files for "Your Name."
- `no-pdf-commit`: Blocks any `.pdf` file from being committed, since PDFs belong in the gitignored `published/` directory, not in version control.

To install the hooks after forking: `pip install pre-commit && pre-commit install`. To run them manually against all files: `pre-commit run --all-files`.

## The Makefile

The Makefile provides a developer-friendly interface over the shell scripts in `publishing/`. Running `make` with no arguments prints a help menu listing all available targets. The primary build targets—`make kdp`, `make arxiv`, `make epub`, `make html`, `make all`—delegate to `publishing/build.sh`. Utility targets include `make validate` (pre-flight checks), `make stats` (word counts), `make clean` (remove build artifacts from `published/`), and `make init` (first-time setup). Container-based build targets (`make container-kdp`, `make container-arxiv`, `make container-all`) delegate to `publishing/run-container.sh` for authors who prefer not to install LaTeX locally.

## Quick Start After Forking

1. Fork or clone the repository.
2. Run `make init` to set your book title, author, and metadata.
3. Edit `publishing/outline.yaml` to define your chapters.
4. Create corresponding Markdown files in `drafts/` with the required frontmatter.
5. Update the `DRAFT_FILES` array in `publishing/build.sh` to match.
6. Run `make validate` to confirm everything is wired up.
7. Run `make kdp` (or `make container-kdp`) to produce your first PDF.
8. Install pre-commit hooks: `pip install pre-commit && pre-commit install`.
9. Push to a GitHub repository to activate CI workflows.

From here, the patterns in Chapters 4 through 8 apply: pin your fork to a specific upstream ref, use drift detection to monitor divergence, and backport improvements that belong in the archetype.
