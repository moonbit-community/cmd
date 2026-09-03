# ADR-0020: Use a Byte-Oriented Tr Profile

Status: Accepted
Date: 2026-09-03

## Context

Locale-sensitive character classes and multibyte semantics differ across
targets, while the command runtime has a stable byte stream boundary.

## Decision

Support translation, deletion, squeeze, complement, ranges, and the observed
classes over the byte-oriented profile. Do not claim locale-specific GNU
classes beyond the probe.

## Evidence

Wasm stdin probes for translation and deletion/squeeze returned status 0 and
the expected bytes.

## Consequences

Pipeline behavior is deterministic across native and Wasm; locale extensions
remain explicit gaps.

## Rollback

Add a character profile only with byte-for-byte fixtures for every target.
