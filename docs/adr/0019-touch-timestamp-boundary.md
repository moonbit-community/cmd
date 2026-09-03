# ADR-0019: Create and Update Files, Reject Arbitrary Timestamp Setters

Status: Accepted
Date: 2026-09-03

## Context

Portable file APIs expose creation and current-time update but not a verified
arbitrary timestamp setter for every target.

## Decision

Support normal create/update and `-c`. Recognize but reject `-d`, `-r`, `-t`,
and arbitrary `-a/-m` timestamp requests before mutation.

## Evidence

Wasm create/no-create probes returned 0; `touch -d 2020-01-01` returned
nonzero.

## Consequences

The command never reports a timestamp it could not set.

## Rollback

Enable setters after a portable timestamp-write probe covers native and Wasm.
