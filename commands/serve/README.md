# serve

Minimal static HTTP file server, implemented in pure MoonBit with
`moonbitlang/async@0.22.7`. The local candidate is `cli/serve@0.1.0`; it is not
published yet.

```sh
MOON_HOME="$HOME/.moon-accounts/cli" moon run --target wasm --release commands/serve -- public
```

Usage: `serve [--host ADDRESS] [-p PORT|--port PORT] [DIRECTORY]`.
The directory defaults to `.`, the address to `127.0.0.1`, and the port to 8000.
Use a numeric IPv4/IPv6 address; port 0 selects an available port. The actual
address is printed to stderr. `--port=8000` and `-p8000` are also accepted,
each option may be supplied once, and `--` ends option parsing. Use `-h` or
`--help` for usage and `-V` or `--version` for version information. Metadata
requests exit without reading stdin or starting a listener. Argument syntax
errors print the standard parser diagnostic with usage to stderr and exit 1.

GET streams regular files with Content-Length and an extension-based MIME type;
HEAD sends the same headers without a body. Unknown extensions use
`application/octet-stream`; responses disable MIME sniffing. Directories serve
`index.html`, redirecting to a trailing slash when needed; absent files/indexes
return 404. Other methods return 405.
There is no directory listing, SPA fallback, upload, range, cache, compression
or TLS support. Every readable file under the selected root, including hidden
files, is eligible for serving.

Paths are percent-decoded once as UTF-8; queries do not select files. Traversal
segments, malformed escapes, control bytes, backslashes, drive/stream colons
and Windows device/alias names are rejected with 400 on all platforms. Canonical
targets must remain under the canonical root, including symlink targets and
`index.html`; forbidden/unreadable/nonregular targets return 404. Symlinks
within the root are permitted. Open files stream through a 64 KiB buffer
written directly to the socket, with at most 64 simultaneous connections.
Successful GET/HEAD file responses send `Connection: close` and close the
connection; redirects and error responses keep it open. Files should remain
stable while served; a shortened file aborts its response, and appended bytes
are excluded.

Wasm policy adds process permissions; it is supplied by the launcher, not
installed by this command. For example, save `serve-policy.json` beside `public`
and launch from that parent directory:

```json
{
  "fs": { "read": ["public"] },
  "net": { "bind": ["127.0.0.1:8000"] }
}
```

After building the workspace:

```sh
moonrun --policy serve-policy.json _build/wasm/release/build/cli/serve/serve.wasm -- public
```

Keep write/process/network-connect permissions absent. Neither path-based
checks nor the current host policy establish race-free confinement against
hostile concurrent filesystem replacement. Serve a trusted, stable directory;
descriptor-relative confined opening on Wasm is the missing unlock condition.
See [compatibility](../../docs/compatibility.md) and the
[filesystem decision](../../docs/adr/0004-filesystem.md).
