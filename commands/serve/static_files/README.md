# Static files

Serve independent directory roots through caller-owned Wasm HTTP listeners.
This public Wasm package is included in `cli/serve`.

Import `cli/serve/static_files` as `@static_files` and
`moonbitlang/core/async/http` and `moonbitlang/core/async/socket` for the listener:

```moonbit
async fn main {
  let app = @static_files.Directory::Directory("app/dist")
  let docs = @static_files.Directory::Directory("docs/dist")
  let server = @http.Server(@socket.Addr::parse("127.0.0.1:8000"))
  defer server.close()
  server.run_forever((request, connection) => {
    if request.path.strip_prefix("/docs/") is Some(path) {
      docs.serve(request, connection, path="/" + path.to_owned())
    } else {
      app.serve(request, connection)
    }
  })
}
```

Construction canonicalizes the root and rejects missing paths and regular
files. Each instance has an immutable private root and can handle concurrent
requests; open files and buffers belong to individual requests.

`serve(request, connection, path?)` responds to one request. Omit `path` to use
the original request target. When mounting a route, pass a slash-prefixed,
still percent-encoded URL path after removing the route prefix. The handler
decodes it once and checks the resolved target against that instance's root.
Directory redirects preserve the original request's prefix and query.

The handler retains the command's GET/HEAD, index.html, MIME and file-streaming
behavior. It does not start or close the listener. Launcher permissions must
cover the selected roots and listen addresses; per-root path checks still
apply when one process can read multiple roots. Use trusted, stable roots:
path canonicalization and open cannot prevent concurrent path replacement.
