# sha256sum

Compute SHA-256 digests for binary input and verify standard checksum files
with `-c`. Supports stdin, multiple files, binary/text compatibility flags,
and NUL-delimited output with `-z`.

With no file operand, the command silently reads stdin until EOF, matching the
upstream terminal, pipe, redirection, and explicit `-` behavior.
