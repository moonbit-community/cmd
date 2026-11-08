# curl

Transfer HTTP and HTTPS data for MoonX.

```sh
moonx cli/curl@0.2.5 [options...] <url>
```

## Supported scope

Send requests, upload files, follow redirects, manage cookies, retry failures and write responses to stdout or files.

Unreleased workspace correction: repeated custom request fields retain their
argument order, including an interleaved User-Agent. Final response fields keep
their order, casing and repetition after optional-whitespace normalization.
Interim fields are excluded. Request Content-Length must be singular; framing
and generated-header validation still apply. The published coordinate is unchanged.

The workspace also validates `__Secure-` and `__Host-` cookies before storage
or jar import, after curl path normalization. Secure cookies require HTTPS or
the exact localhost, 127.0.0.1 or ::1 exception; other HTTP origins cannot
replace or delete an overlapping live Secure cookie. Host-only and domain
cookies keep separate replacement identities. Explicit Cookie text is unchanged.

## Options

| Option | Description |
| --- | --- |
| `-s, --silent` | silent mode |
| `-S, --show-error` | show errors with --silent |
| `-f, --fail` | fail on HTTP response codes >= 400 |
| `-o, --output <file>` | write to file instead of stdout |
| `-O, --remote-name` | use the remote file name |
| `-J, --remote-header-name` | use Content-Disposition with -O |
| `-L, --location` | follow redirects |
| `--max-redirs <num>` | maximum redirects (default 50) |
| `-I, --head` | show response headers only |
| `-H, --header <header>` | send custom fields in order, retaining repeats |
| `-u, --user <user:password>` | HTTP Basic authentication |
| `-b, --cookie <data\|file>` | send cookies or load a Netscape jar |
| `-c, --cookie-jar <file>` | write a Netscape cookie jar |
| `-H 'Cookie: ...'` | send a separate field after stored jar cookies |
| `-X, --request <method>` | specify a supported HTTP method |
| `-d, --data <data>` | HTTP POST data |
| `--data-raw <data>` | HTTP POST data without @ expansion |
| `--data-binary <data>` | HTTP POST data without conversion |
| `--data-urlencode <data>` | URL-encode HTTP POST data |
| `-T, --upload-file <file>` | stream file as an upload |
| `--retry <num>` | retry transient failures |
| `--retry-delay <seconds>` | wait between retries |
| `--retry-max-time <secs>` | maximum time spent retrying |
| `--retry-connrefused` | retry connection refused failures |
| `--retry-all-errors` | retry all transfer errors |
| `--connect-timeout <secs>` | maximum connection setup time |
| `-m, --max-time <seconds>` | maximum time for one transfer |
| `--idle-timeout <seconds>` | extension: inactivity timeout |
| `-k, --insecure` | allow insecure TLS connections |
| `-x, --proxy <url>` | use this proxy |
| `--noproxy <list>` | bypass proxy for matching hosts |
| `--remove-on-error` | remove opened output after final failure |
| `-O -J` | creates valid Content-Disposition filenames exclusively for 2xx/3xx. |
| `-sS` | keeps each failed attempt's error visible even if a later retry succeeds. |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Only HTTP/HTTPS and GET, HEAD, POST, PUT, DELETE, CONNECT, OPTIONS, TRACE and PATCH are supported.
- Header removal, semicolon empty-field syntax and header files are not yet supported; Host and Transfer-Encoding remain transport-managed.
- PSL/IDNA remain unsupported. In particular, `__Host-` with `Domain=localhost`
  or an exact public suffix still lacks curl's PSL host-only conversion; full
  prefix/domain parity and complete jar grammar/serialization are not claimed.
- Content-encoded responses remain encoded. A redirect cannot rewind consumed stdin uploads.
- Partial stdout remains after failure; files remain unless --remove-on-error is selected. -O -J does not overwrite an existing selected name.

## Examples

```sh
moonx cli/curl@0.2.5 https://example.com/
moonx cli/curl@0.2.5 -L -o page.html https://example.com/
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0005-transfer.md)
