# ADR-0008: Publish the Observed Jq Filter Slice

Status: Accepted
Date: 2026-09-03

## Context

The command accepts jq-like filters, but a complete jq language claim requires
far more parser, evaluator, module, and diagnostic coverage than a smoke run.

## Decision

Document the observed `-c`, `-r`, `-f`, `-n`, and `-l` paths and representative
field/object/map filters. Keep the status `subset verified` until the complete
jq baseline is black-box compared.

## Evidence

Wasm probes for `.name`, compact object output, null input, and JSONL logging
returned the expected values; an empty filter file returned a nonzero parse
diagnostic.

## Consequences

Users get a useful jq-compatible core without a false promise about modules or
the complete language.

## Rollback

Narrow the README/help surface if a future artifact regresses a listed filter.
