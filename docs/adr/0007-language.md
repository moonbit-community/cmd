# ADR-0007: Interpreted Language Slices

Status: Accepted  
Date: 2026-09-05

## Context

Delegating shell scripts or Makefiles to host executables would produce a
different language and bypass the Wasm policy boundary.

## Decision

Interpret a deliberately bounded POSIX shell and Make language in MoonBit.
Support the tested grammar and graph features, explicit child recipes,
conditionals, includes, pattern rules, and automatic variables. Reject
unsupported Bash syntax, interactive/job-control features, and unbounded GNU
extensions rather than guessing.

## Consequences

Behavior is portable and policy-visible, but the project does not claim Bash or
full GNU Make compatibility. Every grammar feature needs an execution and
negative fixture.

## Evidence

The P5 and P7 manifest groups cover shell substitution, heredocs, branching,
loops, functions, grouping, parameters, Make conditionals/includes/patterns,
and parser failures.

## Revisit when

The supported language slice grows enough to require a versioned grammar
specification or a separate evaluator boundary.
