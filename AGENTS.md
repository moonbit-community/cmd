# AGENTS.md

## Permission to modify this file

- Changes to this file require explicit human approval in advance. Authorization
  for ordinary development, refactoring or documentation work does not grant
  permission to modify this file.

## Project structure and responsibilities

- The workspace root uses `moon.work`. Each publishable module maintains its
  own `moon.mod`; each package declares dependencies in `moon.pkg`.
- Command roots contain the entry point, configuration, generated interfaces
  and documentation. The entry delegates to `internal/driver`, which owns
  argument parsing, diagnostics, exit status and I/O orchestration.
- Place command implementations outside the driver in
  `commands/<cmd>/internal/<responsibility>/`, such as parsing, formatting,
  searching or encoding. Package names describe their responsibility; avoid
  vague names such as utils, common and helpers.
- Organize small features as files within an existing package. Create a
  separate package when it needs its own responsibility, interface or dependency
  boundary, not for every step, function or type.
- Put mechanisms shared across commands in `core/<responsibility>/`. Public
  libraries belonging to a module live in that module's public packages.
  Keep public types with the APIs that provide their behavior.

## Implementation and code style

- Use pure MoonBit for product code, test tools and automation; automation
  scripts use `.mbtx`. Do not add implementations in other languages, FFI or
  native stubs. Host programs are limited to reference comparisons, test
  observation, CI setup and diagnostics.
- When a required public MoonBit API is unavailable, document the limitation
  in the applicable ADR and compatibility guide, and add a regression test
  for the rejection behavior.

- Use clear, direct control flow and data flow. Prefer pattern matching,
  guards and necessary early returns; avoid pointless nesting, state flags
  and intermediate conversions.
- Parse, validate and normalize external input at its owning entry boundary.
  Subsequent internal calls use the established result without repeatedly
  checking, parsing or normalizing the same stable data at each layer.
- Express constraints through types and explicit states. Avoid representing
  a known state with multiple booleans, arbitrary strings or unnecessary
  optional values. Do not pile up defensive branches for unreachable states.
- Files, networks, permissions and cancellation can change during execution.
  Handle failures at the actual operation; repeated prechecks do not replace
  error handling for the operation itself.
- Propagate errors directly to the layer that can handle them. Catch only to
  recover, add useful context or translate a public diagnostic. Avoid repeated
  wrapping or printing, swallowed errors and defaults that conceal failure.
- Implement current requirements; introduce abstractions when there is clear
  reuse or a responsibility boundary. Do not add generic frameworks,
  configuration layers, strategy objects or forwarding layers for hypothetical
  extensions.
- Prefer inline expressions for simple conditions, field access, short
  expressions and pure forwarding. Extract functions when they provide clear
  meaning, reuse or isolation. Split by responsibility, not mechanical line
  counts.
- Keep small private types, errors and helpers near the implementation that
  uses them. Do not create files or packages containing only fragments of logic
  for the sake of visual uniformity.
- Prefer existing capabilities and avoid unnecessary allocation, copying,
  encoding conversion and repeated traversal. Use views where borrowing fits;
  do not sacrifice readability or increase processing costs merely to shorten
  the code.
- After replacing an implementation, remove dead branches, temporary switches,
  unnecessary wrappers and duplicate implementations. Comments explain useful
  reasons and constraints rather than restating the code line by line.

- Use `snake_case` for packages, files, functions, variables and fields;
  `PascalCase` for types, traits and enum variants; and `SCREAMING_SNAKE_CASE`
  for constants.
- Keep names short within their owning package and name files by responsibility.
  Common abbreviations are acceptable. Limit single-letter names to small loops
  or mathematical expressions; make units and coordinate meanings explicit.
- Test names describe behavior, conditions and results in English. Preserve
  upstream case identifiers and attribution.
- Separate code blocks with `///|`; prefer `deprecated.mbt` for deprecated code.

## Tooling

- Prefix every local Moon and MoonX command with
  `MOON_HOME="$HOME/.moon-accounts/cli"`. Keep the current PATH; CI uses its own
  toolchain and environment. Do not commit credentials or toolchain caches.
- Use `moon ide` to inspect definitions, references and interfaces.
- Use the shared test entry:
  `MOON_HOME="$HOME/.moon-accounts/cli" moon run tools/run.mbtx -- COMMAND`.
- Serialize check, test, build, info and fmt commands that share a build
  directory.
- After code changes, run relevant tests, `moon info` and `moon fmt`. Check
  that generated interface changes are expected.

## Tests and generated content

- Blackbox tests verify public behavior; whitebox tests verify internal state,
  failure paths and resource lifetimes. Do not widen product APIs to move tests.
- Package test inputs belong in the owning package's `fixtures` directory and
  are resolved from the module directory. Central integration tests may use
  package inputs; package tests must not depend on central test directories.
- Central integration tests verify real processes, streams, exit codes, side
  effects, cancellation and cleanup. Put cases in `tests/cases`, infrastructure
  in `tests/harness` and specialized assertions in `tests/scenarios`.
- Prefer explicit assertions for stable results. Use `Debug` and `debug_inspect`
  for debug snapshots. Update snapshots only when the output actually changes.
- Declare module names and versions only in `moon.mod`. Generated version
  constants ship with the source; runtime commands do not read source metadata.
- Every functional fix, feature addition or performance fix increments the
  affected module's patch version by one (an increase of `0.0.1`), for example
  `0.2.9` to `0.2.10`.
- Option declarations generate argument tables, help and documentation.
  Command adapters own command-specific syntax, precedence and error ordering.

## Documentation

- Write concise paragraphs about current purpose, behavior, usage and necessary
  limits. Avoid experiment reports, development diaries and long accounts of
  test procedures.
- Package READMEs follow `docs/readme_template.md`: a short structure covering
  purpose, examples, common options and necessary notes.
- Every functional change must update `docs/compatibility.md` and the affected
  package's README. Changes to arguments, help or output also update the
  relevant help text, option metadata and regression tests.
- Put detailed algorithm explanations in `docs/performance/`, organized by
  topic. Explain the approach, key steps, complexity and implementation
  tradeoffs, and link the relevant source and tests.
- ADRs briefly describe current decisions, reasons, consequences and conditions
  for reconsideration. Keep CHANGELOG entries short and dated, distinguishing
  development changes from published releases.
- Prefer updating existing documents over adding a summary report for every
  implementation, test or refactoring effort. Preserve history through Git.

## CI and Git

- Product validation targets MoonX/Wasm and runs the complete applicable tests
  on Linux, macOS and Windows. Native is used only for test tools and their
  regressions.
- Run `check inputs` once on Linux. Builds and tests with `--deny-warn` provide
  type checking on all three platforms.
- Linux upstream comparison runs in a separate job. Command and input changes
  select their relevant consumers; shared or unclassified execution inputs and
  missing comparison baselines select all. Ordinary documentation, licenses
  and document assets do not require upstream comparison.
- Share Linux build artifacts early within the same run so upstream preparation
  and comparison can overlap correctness tests. Only main may write compilation
  and Docker caches.
- Change main through PRs with passing `ubuntu-24.04`, `macos-15` and
  `windows-2025` checks, then validate the actual main commit after merging.
  Run relevant local checks before a normal, non-force push. Do not bypass
  branch protection.
- Do not restore retired specialized scanners, audit chains or old entry points.
  Remove one-time collection or experiment scripts after they have served their
  purpose.
