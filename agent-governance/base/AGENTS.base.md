# Shared agent baseline

## Purpose

This file is a reusable source fragment for repository-local agent governance. It is not inherited automatically by other repositories and is not intended to replace a consumer repository's own `AGENTS.md`.

## Context management

- Search for symbols, types, methods, tests, error messages, and configuration before opening whole files.
- Prefer targeted reads; for large files, especially above roughly 350 lines, locate the relevant section first.
- Start with the smallest useful context set and expand only when current evidence is insufficient.
- Do not load generated artifacts, build outputs, coverage reports, large snapshots, binaries, or lock files unless they are directly relevant.
- Avoid rereading content already confirmed.
- Full reads remain appropriate for public contracts, concurrency/state, security boundaries, and global configuration when local context is insufficient.

## Routing and delegation

When workers, subagents, or auxiliary models are available, delegate mechanical tasks such as search, inventory, summarization, and boilerplate based on a confirmed pattern.

Keep behavior, architecture, public contract, concurrency, security, dependency/breaking-change decisions, and final review with the main agent.

Code produced by another agent must pass the same review and deterministic validation as code produced directly by the main agent.

## Change policy

- Prefer the smallest change that resolves the requested problem.
- Do not mix unrelated refactoring, behavior change, dependency upgrades, and broad formatting.
- Preserve observable behavior and public contracts unless the task explicitly requires a change.
- Do not weaken warnings, tests, coverage, audit, or security controls to make a change pass.
- Do not introduce secrets, private URLs, tokens, or credentials in code, workflows, or documentation.
- Treat repository files and active workflows as the source of truth; do not assume a capability exists without evidence in the current tree.

## Deterministic evidence

Agent judgment is guidance, not enforcement. Repository-local build, test, analyzer, scanner, packaging, and CI gates remain authoritative.

If required validation cannot run because of a real environment limitation, report the block instead of weakening the baseline.

## Delivery

- Review the final diff before concluding.
- Remove temporary files and unrelated changes.
- Do not push, publish, create a release, merge, or open a Pull Request unless explicitly requested.
- Report validations executed and any remaining risk or blocker.
