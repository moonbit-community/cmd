# ADR-0016: Keep Sort In-Process on Wasm

Status: Accepted
Date: 2026-09-03

## Context

External temporary files and locale-dependent host sorting are not a stable
portable baseline for a Wasm command.

## Decision

Use one in-process record array for line or NUL records. The P3 ordering surface
includes repeated field/character keys, key-local modifiers, `-b/-d/-f/-i`,
numeric/general/human/month/version comparisons, unique output, and check
modes. Compare transformed bytes under the documented C-locale profile and do
not claim GNU external-sort behavior.

Recognize `-R` but reject it before input is read. Random ordering is not
portable or reproducible until the command has an explicit deterministic seed
contract.

## Evidence

Native, pinned GNU, and Wasm-policy fixtures cover multiple modified keys,
GNU blank-field boundaries, C-locale case folding, human suffix magnitude,
comparison families, nonprinting bytes, NUL records, ordered/disordered checks,
and file authorization. The strict oracle manifest records the exact byte and
status comparisons.

## Consequences

The common sort workflow is deterministic and policy-light, with explicit
resource limits supplied by the host. Memory remains proportional to the full
input because external spilling is outside this profile.

## Rollback

Add external spilling only behind a separately audited portable filesystem
contract.
