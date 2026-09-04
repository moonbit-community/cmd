# Compatibility Fixtures

`runner/cases.json` is the machine-readable semantic compatibility contract. Binary stdin and
file contents are hexadecimal so the repository can represent NUL bytes and
invalid UTF-8 without an implicit text conversion. The unified runner creates a
fresh candidate directory and upstream directory for every case; fixture files
must therefore use validated relative paths only.

The unified runner also consumes the policy profiles in `policy/`. Policy tests
execute pre-built Wasm artifacts with `moonrun --policy`; they never rebuild
command packages. Public-network endpoints are not valid fixtures.
