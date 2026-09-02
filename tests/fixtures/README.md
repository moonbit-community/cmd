# Compatibility Fixtures

`oracle/cases.json` is the machine-readable Phase 0 contract. Binary stdin and
file contents are hexadecimal so the repository can represent NUL bytes and
invalid UTF-8 without an implicit text conversion. The oracle runner creates a
fresh candidate directory and upstream directory for every case; fixture files
must therefore use validated relative paths only.

Future filesystem, process, and local HTTP fixtures belong below this directory.
Public-network endpoints are not valid compatibility fixtures.
