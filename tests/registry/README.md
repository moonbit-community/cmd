# Runtime test index

Schema 3 retains case identities, aliases, executable selections, platform
applicability and release policy. It does not register individual Moon package
tests or declare change coverage, evidence obligations or source fingerprints.

`entries` supplies stable IDs used by command fixtures, scenarios, cohorts,
metadata and benchmark references. `release_commands` owns package names,
supported options, comparison profiles, policy sensitivity, releasability and
selected release case IDs. Versions are read from the command `moon.mod` files.

Validation rejects duplicate or empty identities, invalid source selections,
unknown platforms and malformed release metadata. The index is not a passing
test report. Actual assertions determine pass, failure and explicit rejection.

Add or update JSON cases and the applicable index entries together. Stateful
behavior stays in MoonBit scenario functions. Package tests are discovered and
executed by Moon without a second per-test source binding system.

Historical registry snapshots retain their original schemas. The current
index does not backfill them, verify old sources or reconstruct old artifacts.
