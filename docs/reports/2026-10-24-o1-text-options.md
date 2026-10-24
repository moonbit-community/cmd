# O1 text option implementation

Date: 2026-10-24. Unpublished 0.2.2 candidates for cut, uniq, comm, join and
wc, selecting core 0.8.0. Published coordinates remain unchanged. This report
records local development evidence before PR and actual-main acceptance.

Cut normalizes intervals and complements, preserving distinct adjacent spans
when inserting an output delimiter. Empty output delimiters emit NUL. Field
and record delimiters can coincide; EOF and GNU's no-selected-field search
path retain their observed behavior without accumulating the input.

Uniq emits repeated members and grouped output from adjacent-key state and
one pending original record. It preserves original bytes, method separators,
option conflicts and GNU's first N-1 members for `-uD`. Comm adds arbitrary
output delimiters and four-field totals, retaining suppressed-column and
default versus explicit order-check behavior. Join adds ASCII key folding,
headers and automatic field layouts, including unpaired records, empty fields
and Cartesian duplicate-key groups.

Wc implements all four total modes, selected counters, aggregate successful
inputs and partial counters after read errors. C-profile `-m` counts bytes;
the obsolete UTF-8 decoder and pending state were removed. Named-file padding
uses public file kind and total byte sizes, with no counting prepass. Public
stdio does not expose descriptor metadata, so exact GNU padding for redirected
regular-file stdin remains unclaimed. This narrow limit and non-C scope are
recorded in ADR-0003 and the compatibility record; totals-only output is
independent of that padding limit.

## Development validation

- Native and Wasm package tests pass for cut (3), uniq (5) and wc (3), including
  read-boundary bytes and retained counters after a partial read failure.
- A fixed GNU coreutils 9.11 comparison passes 100 Native invocations across
  these five commands, including malformed option values, NUL, no final LF,
  adjacent complement cases, repeated groups and error continuation.
- Eighty-three selected observations become registered public regression
  cases; additional overlapping development probes remain outside the corpus.
  Help, catalog, command READMEs, support records and release candidate inputs
  are updated together. Published expectations remain frozen.

The main development comparison is under
`/private/tmp/cmd-o1-native-compare-20261024-final/`; the additional explicit
join-field/header/auto observation is under
`/private/tmp/cmd-o1-native-compare-20261024-fields/`. Package logs are under
`/private/tmp/cmd-o1-cut-uniq-validation-20261024-2/` and
`/private/tmp/cmd-o1-wc-c-validation-20261024/`.

These observations do not establish the formal Wasm 1.5x performance gate or
a registry publication. O2-O13 and resource-stage work remain separate.
