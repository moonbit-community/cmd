# ADR-0027: Publish Deterministic jq CLI Modes

Status: Accepted
Date: 2026-09-05

## Context

The imported MoonJQ evaluator already implements a broad filter slice, while
the command wrapper previously exposed only compact, raw, file, null, and log
modes. Common scripts also rely on slurping, raw records, sorted keys,
argument bindings, and status selection.

## Decision

Expose those modes in the CLI with deterministic JSON formatting and explicit
`-e` status mapping. `--arg` values are JSON strings; `--argjson` values are
validated before evaluation. The command remains a bounded subset claim rather
than a full jq 1.8.2 claim.

## Evidence

Native and Wasm runner fixtures cover sorted output, raw slurp framing, argument
bindings, and false/null exit statuses.

## Consequences

Data-processing scripts gain predictable CLI behavior without adding a second
evaluator or host process. Modules, streaming, and complete diagnostics remain
outside the published profile.

## Rollback

Remove only the affected option rows and fixtures if an upstream oracle case
shows a semantic mismatch.
