# ADR-0012: Execute a Bounded Make Language Through MoonBit

Status: Accepted
Date: 2026-09-03

## Context

GNU Make is both a file language and a process launcher. Forwarding a Makefile
to a host binary would break pure MoonBit and Wasm policy control.

## Decision

Parse variables, dependency rules, timestamps, `-B/-n/-s/-C/-f`, and
command-line assignments in MoonBit. Launch each recipe command through the
same policy-visible child API. Reject unverified GNU extensions explicitly.

## Evidence

An absolute Makefile dry-run under Wasm returned status 0 and expanded the
command-line variable in the recipe. A policy-enabled build and `-s` run also
completed; recipe process lookup and cwd remain subject to the Wasm host
contract.

## Consequences

Basic builds are portable and inspectable; full GNU language/job-control parity
is not claimed.

## Rollback

Add one language feature at a time with a real Wasm positive/negative fixture.
