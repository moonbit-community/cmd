# sha256sum

Compute SHA-256 digests for binary input and verify standard checksum files
with `-c`. Supports stdin, multiple files, binary/text compatibility flags,
and NUL-delimited output with `-z`.

With no file operand, an interactive terminal receives an EOF waiting prompt;
piped, redirected, and explicit `-` input remain silent.
