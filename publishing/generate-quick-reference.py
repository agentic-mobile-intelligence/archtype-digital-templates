#!/usr/bin/env python3
"""Regenerate drafts/22-pattern-quick-reference.md from publishing/patterns.yaml.

publishing/patterns.yaml is the canonical source of pattern metadata.
The markdown quick-reference is a generated view; do not edit it directly —
edit the YAML and re-run this script (or let build.sh run it for you).

Requires: Python 3 + PyYAML (apt: python3-yaml  |  pip: pyyaml).
"""
import argparse
import sys
from collections import OrderedDict
from datetime import date
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.stderr.write(
        "ERROR: PyYAML is required.\n"
        "  Debian/Ubuntu: apt-get install python3-yaml\n"
        "  macOS/pip:     pip install pyyaml\n"
    )
    sys.exit(1)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Regenerate drafts/22-pattern-quick-reference.md from publishing/patterns.yaml"
    )
    root = Path(__file__).resolve().parent.parent
    parser.add_argument(
        "--input", type=Path,
        default=root / "publishing" / "patterns.yaml",
        help="Path to patterns.yaml (default: publishing/patterns.yaml)"
    )
    parser.add_argument(
        "--output", type=Path,
        default=root / "drafts" / "22-pattern-quick-reference.md",
        help="Path to output markdown (default: drafts/22-pattern-quick-reference.md)"
    )
    return parser.parse_args()


def validate_data(data: dict) -> list[str]:
    errors = []
    for key in ["main_catalog", "appendix", "generated", "summary"]:
        if key not in data:
            errors.append(f"Missing required top-level key: '{key}'")

    for i, p in enumerate(data.get("main_catalog", [])):
        for field in ["number", "name", "intent", "chapter", "chapter_title"]:
            if field not in p:
                errors.append(f"main_catalog[{i}] missing field '{field}' (pattern: {p.get('name', '?')})")

    for i, p in enumerate(data.get("appendix", [])):
        for field in ["id", "name", "intent"]:
            if field not in p:
                errors.append(f"appendix[{i}] missing field '{field}'")

    for field in ["main_catalog_count", "appendix_count", "total"]:
        if field not in data.get("summary", {}):
            errors.append(f"summary missing field '{field}'")

    ref = data.get("reference_book")
    if ref is not None and isinstance(ref, dict):
        for field in ["title", "year"]:
            if field not in ref:
                errors.append(f"reference_book missing field '{field}'")

    return errors


def build_markdown(data: dict) -> str:
    lines: list[str] = []

    ref_book = data.get("reference_book")
    has_analog_col = ref_book is not None

    generated_date = date.today().isoformat()

    lines += [
        "---",
        'title: "Pattern Quick Reference"',
        "chapter: back-matter",
        "status: generated",
        f"date: {generated_date}",
        "source: publishing/patterns.yaml",
        "---",
        "",
        "<!--",
        "  GENERATED FILE — do not edit directly.",
        "  Source:      publishing/patterns.yaml",
        "  Regenerate:  python3 publishing/generate-quick-reference.py",
        "               (or: bash publishing/build.sh — regenerates automatically)",
        "-->",
        "",
        "# Pattern Quick Reference",
        "",
    ]

    if has_analog_col:
        short = ref_book.get("short", f"{ref_book.get('author', 'the reference')} {ref_book.get('year', '')}")
        intro = (
            "This is a condensed reference to every pattern in the book, intended "
            "for readers returning to the catalog after their first read-through. "
            "Patterns are grouped by chapter in the order they appear in the book "
            "(not alphabetized), with the appendix of discovered patterns listed "
            f"last. For the main catalog, the fourth column shows the "
            f"corresponding pattern from *{ref_book.get('title', short)}* "
            f"({short}); an em dash means no analog."
        )
    else:
        intro = (
            "This is a condensed reference to every pattern in the book, intended "
            "for readers returning to the catalog after their first read-through. "
            "Patterns are grouped by chapter in the order they appear in the book "
            "(not alphabetized), with the appendix of discovered patterns listed last."
        )
    lines.append(intro)

    lines += [
        "",
        "## Main Catalog",
        "",
    ]

    # Group patterns by chapter preserving YAML order.
    by_chapter: "OrderedDict[int, dict]" = OrderedDict()
    for p in data["main_catalog"]:
        ch = p["chapter"]
        if ch not in by_chapter:
            by_chapter[ch] = {"title": p["chapter_title"], "patterns": []}
        by_chapter[ch]["patterns"].append(p)

    for ch, info in by_chapter.items():
        lines += [
            f"### Chapter {ch} — {info['title']}",
            "",
        ]
        if has_analog_col:
            lines += [
                "| # | Pattern | Intent (one line) | Analog |",
                "|---|---------|--------------------|--------|",
            ]
        else:
            lines += [
                "| # | Pattern | Intent (one line) |",
                "|---|---------|-------------------|",
            ]
        for p in info["patterns"]:
            if has_analog_col:
                analog = p.get("fowler_analog") or "—"
                lines.append(f"| {p['number']} | {p['name']} | {p['intent']} | {analog} |")
            else:
                lines.append(f"| {p['number']} | {p['name']} | {p['intent']} |")
        lines.append("")

    lines += [
        "## Discovered Agentic Patterns (Appendix)",
        "",
        "| # | Pattern | Intent (one line) |",
        "|---|---------|--------------------|",
    ]
    for p in data["appendix"]:
        lines.append(f"| {p['id']} | {p['name']} | {p['intent']} |")
    lines.append("")

    # Alphabetical index — condensed cross-view of every pattern by name.
    lines += [
        "## Alphabetical Index",
        "",
        "Every pattern sorted by name, with its catalog ID and location. "
        "Use this view to find a pattern when you know its name but not "
        "its chapter.",
        "",
        "| Pattern | # | Location |",
        "|---------|---|----------|",
    ]
    alpha: list[dict] = []
    for p in data["main_catalog"]:
        alpha.append({
            "name": p["name"],
            "id": str(p["number"]),
            "location": f"Ch{p['chapter']}",
        })
    for p in data["appendix"]:
        alpha.append({
            "name": p["name"],
            "id": p["id"],
            "location": "Appendix",
        })
    alpha.sort(key=lambda x: x["name"].lower())
    for p in alpha:
        lines.append(f"| {p['name']} | {p['id']} | {p['location']} |")
    lines.append("")

    s = data.get("summary", {})
    if s:
        lines += [
            "## Summary",
            "",
            f"- Main catalog: **{s.get('main_catalog_count', '?')}** patterns "
            f"(Ch9–Ch18, numbered #1–#{s.get('main_catalog_count', '?')}).",
            f"- Appendix: **{s.get('appendix_count', '?')}** discovered "
            f"agentic patterns (A1–A{s.get('appendix_count', '?')}).",
            f"- Total: **{s.get('total', '?')}**.",
            "",
        ]

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    yaml_src = args.input
    md_out = args.output

    if not yaml_src.exists():
        sys.stderr.write(f"ERROR: canonical source missing: {yaml_src}\n")
        return 1

    with yaml_src.open() as f:
        data = yaml.safe_load(f)

    errors = validate_data(data)
    if errors:
        sys.stderr.write("ERROR: patterns.yaml validation failed:\n")
        for e in errors:
            sys.stderr.write(f"  - {e}\n")
        return 1

    try:
        md = build_markdown(data)
    except (KeyError, TypeError) as e:
        sys.stderr.write(f"ERROR: Failed to generate markdown: {e}\n")
        sys.stderr.write("  Check that patterns.yaml matches the expected schema.\n")
        return 1

    md_out.write_text(md)

    root = Path(__file__).resolve().parent.parent
    try:
        rel_yaml = yaml_src.relative_to(root)
        rel_md = md_out.relative_to(root)
    except ValueError:
        rel_yaml = yaml_src
        rel_md = md_out
    print(f"generate-quick-reference: wrote {rel_md} from {rel_yaml}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
