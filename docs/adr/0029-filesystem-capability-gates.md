# ADR-0029: Gate Metadata-Dependent Filesystem Options

Status: Superseded by ADR-0030
Date: 2026-09-05

## Context

The runtime exposes a larger portable subset than the original gate recorded:
kind, regular-file size, access checks, symbolic-link creation, and atime/mtime/
ctime reads. Setters, hard links, readlink, cross-device classification, and
special-file creation remain unavailable.

## Decision

Publish explicit capability predicates in `core/platform`, retain the aggregate
aliases, and let commands implement the strict public subset. Continue to reject
operations that need unavailable setters, hard links, readlink, special-file
creation, or cross-device classification before side effects.

## Evidence

Cross-target platform tests assert the capability matrix; existing command
negative fixtures verify no-side-effect rejection.

## Consequences

ADR-0030 supersedes the all-closed P8 decision while preserving its fail-closed
boundaries.

## Rollback

Keep the explicit rejection and update the support record if a target loses a
runtime primitive.
