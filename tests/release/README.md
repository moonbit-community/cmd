# Exact-version MoonX acceptance

`policy.json` owns release selection and support metadata. `candidate.json` is
derived from that policy, current versions and `../cases/manifest.json` through
`tests/run.mbtx -- index update`. `latest.json` owns published coordinates and
points to the independent frozen `latest-cases.json` expectations. Neither
index generation nor acceptance rewrites those published inputs.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" CMD_TEST_REPORT_ROOT=/absolute/fresh-report moon run tests/run.mbtx -- published
```

The entry builds release test tools and invokes the same driver used for
workspace validation. All product children resolve exact MoonX coordinates;
startup probes and acceptance execute serially. On Linux, prepare the pinned
oracle into the same report root first. The manual release workflow runs the
full applicable suite on Linux, macOS and Windows and pinned comparisons on
Linux. It does not publish or modify committed files.

`CMD_RELEASE_MANIFEST` selects another manifest, for example the candidate
after its selected versions have been uploaded. The internal release runner
accepts `functional`, `oracle` and `all`; it has no legacy suite aliases.
`--command` and `--case` are diagnostic subsets, not full acceptance.
Only a manifest explicitly marked as a candidate may select the canonical
`../cases/manifest.json`; other parent-directory paths remain rejected.

After a separately authorized publication and successful exact-coordinate
acceptance, promote coordinates and their independent expectations through a
reviewed change. Keep unchanged packages at their existing versions; timeout
remains local-only. Package publication uses `moon publish` only.

Retired snapshots and tools remain in
[Git at 234f960](https://github.com/moonbit-community/cmd/tree/234f9602347e43bd6d7c86c454489fc3f672c722/tests/release_runner).
The active tree has no overlay manifests, duplicate current-case index,
source-gate wrapper, historical rotation or compatibility launch path.
