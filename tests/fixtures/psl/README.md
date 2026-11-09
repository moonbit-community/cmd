# Public suffix input

`public_suffix_list.dat` is the complete official Public Suffix List at commit
`94ec5df7273926560d91e77c002000ba1a53fec4` (snapshot commit dated 2026-11-06).
Both ICANN and PRIVATE sections and their original notices are retained.
This date identifies the snapshot, not the last modification of every rule.

- Source: <https://github.com/publicsuffix/list/blob/94ec5df7273926560d91e77c002000ba1a53fec4/public_suffix_list.dat>
- Bytes: 338,457
- SHA-256: `762b6cbdd2dacc597b398fcd7860e2184b684125a58aa177dbdf54916a1f3430`
- License: [MPL 2.0](https://mozilla.org/MPL/2.0/)

`test_psl.txt` is the unchanged official test corpus at that same commit.
Its SHA-256 is
`8f50ad958916d6a8f79fba2363501475571acce752757f9126fe9d2f17dd920d`;
its original CC0 notice is retained. These are independent expectations, not
values regenerated from the product lookup table.

From the repository root, run
`MOON_HOME="$HOME/.moon-accounts/cli" moon run tests/tools/public_suffix.mbtx -- update`
to regenerate `core/netops/cookie_suffix_data.mbt`, or use `check` to verify it.
The generator rejects a missing or changed source and retains every rule.
The pure MoonBit Punycode dependency is pinned in the generator's imports.
It adds A-label aliases only for non-ASCII labels; it does not implement
IDNA/NFKC normalization of URL or Domain inputs. Product suffix lookup has no
runtime data-file or Punycode dependency; URL/IDNA conversion uses Punycode
separately.

Cookie admission follows libpsl 0.21.2's complete ICANN plus PRIVATE policy:
wildcard bases are suffixes, exception rules win, and the request host's longest
suffix bounds the accepted cookie domain. The Curl and Wget adapters retain
their distinct exact-host conversion and cookie-file admission rules.
