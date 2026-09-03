# ADR-0009: Measure Jqlog Against Its Imported Contract

Status: Accepted
Date: 2026-09-03

## Context

`jqlog` has no standard system utility baseline. Its meaningful upstream is the
imported package snapshot.

## Decision

Treat JSONL stdin/raw input, `-f`, `-h`, valid-line transformation, and
non-JSON skipping as the observed contract. Do not compare it with jq or claim
GNU utility parity.

## Evidence

Wasm JSONL probes transformed valid lines and skipped `not-json`; raw input and
help returned status 0.

## Consequences

The command remains useful and its provenance is explicit.

## Rollback

Pin a replacement imported snapshot and repeat the same black-box cases before
changing the contract.
