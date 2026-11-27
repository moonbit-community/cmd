///|
async test "directory construction normalizes roots and rejects missing or regular-file roots" {
  let work = @fs.tmpdir(prefix="serve-directory-")
  defer @fs.remove(work, recursive=true)
  @fs.mkdir(work + "/nested")
  @fs.write_text(work + "/file", "not a directory")
  let _ = @static_files.Directory::Directory(work + "/nested/..")
  for path in [work + "/missing", work + "/file"] {
    let accepted = try {
      let _ = @static_files.Directory::Directory(path)
      true
    } catch {
      _ => false
    }
    assert_false(accepted, msg=path)
  }
}

///|
async test "independent directories serve concurrent requests on separate listeners" {
  @async.with_timeout(10000, () => {
    let work = @fs.tmpdir(prefix="serve-sites-")
    defer @fs.remove(work, recursive=true)
    @fs.mkdir(work + "/a")
    @fs.mkdir(work + "/b")
    let first = Bytes::from_array(Array::make(150000, b'a'))
    let second = Bytes::from_array(Array::make(150000, b'b'))
    @fs.write_binary(work + "/a/data.bin", first)
    @fs.write_binary(work + "/b/data.bin", second)
    let a = @static_files.Directory::Directory(work + "/a/../a")
    let b = @static_files.Directory::Directory(work + "/b")
    let server_a = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server_a.close()
    let server_b = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server_b.close()
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        server_a.run_forever((request, connection) => {
          a.serve(request, connection)
        })
      })
      group.spawn_bg(() => {
        server_b.run_forever((request, connection) => {
          b.serve(request, connection)
        })
      })
      let tasks = []
      for _ in 0..<4 {
        for (server, expected) in [(server_a, first), (server_b, second)] {
          tasks.push(
            group.spawn(() => {
              let (response, body) = @http.get(
                "http://" + server.local_addr().to_string() + "/data.bin",
              )
              assert_eq(response.code, 200)
              assert_eq(response.headers.get("Content-Length"), Some("150000"))
              assert_eq(
                response.headers.get("Content-Type"),
                Some("application/octet-stream"),
              )
              assert_eq(body.binary(), expected)
            }),
          )
        }
      }
      for task in tasks {
        task.wait()
      }
      group.return_immediately()
    })
  })
}

///|
async test "mounted directories preserve redirects and enforce each selected root" {
  @async.with_timeout(10000, () => {
    let work = @fs.tmpdir(prefix="serve-mounts-")
    defer @fs.remove(work, recursive=true)
    let root = @fs.realpath(work)
    @fs.mkdir(root + "/a/nested", recursive=true)
    @fs.mkdir(root + "/a/%2e%2e")
    @fs.mkdir(root + "/b")
    @fs.write_text(root + "/a/nested/index.html", "mounted index")
    @fs.write_text(root + "/a/%2e%2e/visible.txt", "decoded once")
    @fs.write_text(root + "/b/secret.txt", "second site")
    if !(@async.platform is Windows) {
      @fs.symlink(root + "/a/escape", target=root + "/b")
    }
    let a = @static_files.Directory::Directory(root + "/a")
    let b = @static_files.Directory::Directory(root + "/b")
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    defer server.close()
    @async.with_task_group(group => {
      group.spawn_bg(() => {
        server.run_forever((request, connection) => {
          if request.path.strip_prefix("/a/") is Some(path) {
            a.serve(request, connection, path="/" + path.to_owned())
          } else if request.path.strip_prefix("/b/") is Some(path) {
            b.serve(request, connection, path="/" + path.to_owned())
          } else {
            connection.send_response(404, "Not Found", extra_headers={
              "Content-Length": "0",
            })
          }
        })
      })
      let base = "http://" + server.local_addr().to_string()
      let (redirect, _) = @http.get(base + "/a/nested?q=1")
      assert_eq(redirect.code, 301)
      assert_eq(redirect.headers.get("Location"), Some("/a/nested/?q=1"))
      for
        (path, status, expected) in [
          ("/a/nested/", 200, "mounted index"),
          ("/a/secret.txt", 404, ""),
          ("/b/secret.txt", 200, "second site"),
          ("/b/nested/", 404, ""),
          ("/a/%2e%2e/b/secret.txt", 400, ""),
          ("/b/%2e%2e/a/nested/index.html", 400, ""),
          ("/a/%252e%252e/visible.txt", 200, "decoded once"),
        ] {
        let (response, body) = @http.get(base + path)
        assert_eq(response.code, status, msg=path)
        assert_eq(body.text(), expected, msg=path)
      }
      let (head, body) = @http.request_binary(Head, base + "/a/nested/", b"")
      assert_eq(head.code, 200)
      assert_eq(head.headers.get("Content-Length"), Some("13"))
      assert_eq(head.headers.get("Content-Type"), Some("text/html"))
      assert_eq(body.binary(), b"")
      if !(@async.platform is Windows) {
        let (response, body) = @http.get(base + "/a/escape/secret.txt")
        assert_eq(response.code, 404)
        assert_eq(body.binary(), b"")
      }
      group.return_immediately()
    })
  })
}
