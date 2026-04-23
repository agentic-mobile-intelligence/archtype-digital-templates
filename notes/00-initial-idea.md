# Initial Idea — Archetype Digital Templates

**Date:** 2026-04-23

## Core Concept

Template repositories are the starting point for many projects, but after the fork moment, templates and their instances drift apart. This book is about managing that drift intentionally.

## Key Insight

The `template-start-from-here` pattern shows that tooling (build scripts, validation, container configs) lives in the template and should flow downstream. But downstream projects also improve those tools — and those improvements should flow back upstream.

This is a bidirectional sync problem, not a one-way inheritance problem.

## Problems to Address

1. **Downstream drift** — instances accumulate changes the template never sees
2. **Upstream lag** — template improves but instances can't easily adopt
3. **No diff visibility** — no tooling to show what diverged and why
4. **Ownership ambiguity** — which changes belong in the template vs the instance?
5. **Conflict on merge** — pulling upstream often clobbers instance-specific work

## Potential Patterns

- `upstream-pinning` — downstream tracks a specific upstream ref, upgrades intentionally
- `tooling-layer separation` — keep template tooling in a separate directory from content
- `drift-check CI` — automated comparison between instance and upstream template
- `backport PR` — formal process for contributing instance improvements to upstream
- `agentic sync agent` — an agent that monitors instances and proposes PRs to upstream

## Reference

- `template-start-from-here` in this repo — the concrete example
- GitHub's template repository feature — limited, no ongoing sync mechanism
- Cookiecutter / Copier — one-way template stamping tools
- `git subtree` / `git submodule` — related but different problems
