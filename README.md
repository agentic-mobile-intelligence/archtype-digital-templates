# Archetype Digital Templates

**Managing Upstream and Downstream Change in Template-Driven Development**

A book about the patterns, tools, and disciplines needed to manage template repositories when multiple downstream instances diverge — and how to flow improvements back upstream without breaking anyone.

## The Problem

When you create a project from a template, you immediately begin to diverge. The template improves. Your instance improves. Neither side knows about the other's changes. Eventually you have:

- Template improvements that instances can't easily adopt
- Instance-level fixes that should have been in the template from day one
- No clear ownership of which changes belong where

This book addresses that problem directly.

## What This Book Covers

- How to structure a template repo for long-term maintainability
- Strategies for downstream instances to track and pull upstream changes
- Patterns for contributing improvements back to the upstream template
- Tooling for detecting drift between template and instances
- Agentic workflows that automate the sync cycle

## Building

```bash
bash publishing/run-container.sh kdp       # KDP 8×10 PDF
bash publishing/run-container.sh all       # All formats
```

## Remotes

```
origin  → git@github.com:agentic-mobile-intelligence/archtype-digital-templates.git
gitea   → https://amiable-beetle-gitea-server.cloud.nexlayer.ai/elizaga/archtype-digital-templates.git
```
