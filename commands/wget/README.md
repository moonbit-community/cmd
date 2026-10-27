# wget

Download HTTP and HTTPS resources for MoonX.

```sh
moonx cli/wget@0.2.4 [OPTION]... [URL]...
```

## Supported scope

Download URLs or URL lists with resume, conditional requests, headers/bodies, retries, redirects, Basic authentication and cookies.

## Options

| Option | Description |
| --- | --- |
| `-q, --quiet` | quiet (no output) |
| `-O, --output-document=FILE` | write documents to FILE |
| `-o, --output-file=FILE` | log messages to FILE |
| `-a, --append-output=FILE` | append messages to FILE |
| `-i, --input-file=FILE` | download URLs found in FILE |
| `-c, --continue` | resume after the already written prefix |
| `-N, --timestamping` | do not re-retrieve unchanged files |
| `-t, --tries=NUMBER` | set number of retries (0 means unlimited) |
| `--retry-connrefused` | retry even if the connection is refused |
| `--retry-on-http-error=CODES` | retry comma-separated HTTP status codes |
| `--waitretry=SECONDS` | wait between retries |
| `--max-redirect=NUMBER` | maximum redirects (default 20) |
| `--content-disposition` | honor Content-Disposition filenames |
| `--header=STRING` | insert STRING among request headers |
| `--user=USER` | HTTP Basic user name |
| `--password=PASSWORD` | HTTP Basic password |
| `--auth-no-challenge` | send Basic credentials on every request, including redirects |
| `--load-cookies=FILE` | load a Netscape cookie jar |
| `--header='Cookie: ...'` | override jar cookies, including on redirects |
| `--save-cookies=FILE` | save persistent cookies |
| `--keep-session-cookies` | also save session cookies |
| `--no-cookies` | disable cookie storage |
| `--method=HTTPMethod` | use a supported HTTP method |
| `--body-data=STRING` | send STRING with an explicit --method |
| `--body-file=FILE` | send FILE with an explicit --method |
| `--no-check-certificate` | disable TLS certificate verification |
| `--no-proxy` | do not use proxy environment variables |
| `-T, --timeout=SECONDS` | set connect and read timeouts |
| `--connect-timeout=SECONDS` | set connection timeout |
| `--read-timeout=SECONDS` | set response inactivity timeout |
| `--idle-timeout=SECONDS` | extension: response inactivity timeout |
| `--help` / `--version` | Show help / package version. |

## Limitations

- Recursive mirroring, FTP, non-Basic authentication, HSTS and timestamp restoration are unsupported.
- Content-encoded bodies remain encoded. Consumed stdin request bodies cannot be replayed.
- Resume retains prior bytes without proving the server's earlier prefix is unchanged. Public-suffix and IDNA cookie handling are unsupported.

## Examples

```sh
moonx cli/wget@0.2.4 -O page.html https://example.com/
moonx cli/wget@0.2.4 -q -O - https://example.com/
```

[Capability matrix](../../docs/compatibility.md) · [ADR](../../docs/adr/0005-transfer.md)
