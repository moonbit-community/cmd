# ADR-0002: Keep Implicit Stdin Byte-Clean and Silent

Status: Accepted
Date: 2026-09-03

## Context

The upstream text commands block while reading an implicit terminal stdin. A
repository-specific prompt changes pipe, redirection, and transcript behavior.

## Decision

`base64`, `cat`, `head`, `nl`, `paste`, `sha256sum`, `sh`, `sort`, `tail`,
`tee`, `uniq`, `wc`, `xargs`, and `xxd` read implicit stdin until EOF or their
semantic quota without adding a prompt. Terminal, pipeline, redirection, and
explicit `-` use the same byte path.

## Evidence

`printf 'a\\nb\\n' | moon run --target wasm --release commands/xargs -- printf '<%s>\\n'`
returned the child output without a prompt; stdin probes for the other rows
returned only the command output.

## Consequences

Interactive use has the same wait semantics as the upstream commands. Progress
meters remain an explicit stderr feature of HTTP commands only.

## Rollback

Change the shared terminal policy and update every affected README/help string
only with a new upstream comparison showing that a prompt is required.
