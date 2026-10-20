///|
async fn retry_fixture(
  group : @async.TaskGroup[Unit],
  range_response : Bool,
  requests : Array[String],
) -> @socket.TcpServer {
  let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
  group.add_defer(() => server.close())
  group.spawn_bg(no_wait=true, () => {
    server.run_forever((connection, _) => {
      let request = StringBuilder()
      while connection.read_until("\r\n") is Some(line) && line != "" {
        request.write_string(line + "\r\n")
      }
      requests.push(request.to_string())
      let response = if requests.length() == 1 {
        "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nabc"
      } else if range_response {
        "HTTP/1.1 206 Partial Content\r\nContent-Length: 3\r\nContent-Range: bytes 3-5/6\r\n\r\ndef"
      } else {
        "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n\r\nabcdef"
      }
      connection.write(response)
    })
  })
  server
}

///|
async test "wget retries partial output with an updated range without duplicating aggregate files" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="wget-retry-output-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let output = directory + "/output"
      for ranged in [true, false] {
        @fs.write_file(output, "previous-url:")
        let requests : Array[String] = []
        let server = retry_fixture(group, ranged, requests)
        let options = default_options()
        options.quiet = true
        options.no_proxy = true
        options.tries = 2
        options.output_document = Some(output)
        let status = download_one(
          options,
          LogDisabled,
          "http://127.0.0.1:\{server.addr.port()}/body",
          None,
        )
        assert_eq(status, 0)
        assert_eq(requests.length(), 2)
        assert_false(requests[0].contains("Range:"))
        assert_true(requests[1].contains("Range: bytes=3-\r\n"))
        assert_eq(@fs.read_file(output).text(), "previous-url:abcdef")
      }
    })
  })
}

///|
async test "wget retries the same collision selected output and preserves existing names" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let name = "wget-retry-unique-\{@async.now()}.tmp"
      defer @async.protect_from_cancel(() => {
        for path in [name, name + ".1", name + ".2"] {
          if @fs.exists(path) {
            @fs.remove(path)
          }
        }
      })
      @fs.write_file(name, "preserve")
      let requests : Array[String] = []
      let server = retry_fixture(group, true, requests)
      let options = default_options()
      options.quiet = true
      options.no_proxy = true
      options.tries = 2
      let status = download_one(
        options,
        LogDisabled,
        "http://127.0.0.1:\{server.addr.port()}/" + name,
        None,
      )
      assert_eq(status, 0)
      assert_eq(requests.length(), 2)
      assert_true(requests[1].contains("Range: bytes=3-\r\n"))
      assert_eq(@fs.read_file(name).text(), "preserve")
      assert_eq(@fs.read_file(name + ".1").text(), "abcdef")
      assert_false(@fs.exists(name + ".2"))
    })
  })
}

///|
async test "wget exhausted partial retries retain one prefix and report network failure" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="wget-retry-exhausted-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let output = directory + "/output"
      let requests : Array[String] = []
      let server = retry_fixture(group, true, requests)
      let options = default_options()
      options.quiet = true
      options.no_proxy = true
      options.tries = 1
      options.output_document = Some(output)
      let status = download_one(
        options,
        LogDisabled,
        "http://127.0.0.1:\{server.addr.port()}/body",
        None,
      )
      assert_eq(status, 4)
      assert_eq(requests.length(), 1)
      assert_eq(@fs.read_file(output).text(), "abc")
    })
  })
}

///|
async test "wget accepts not modified only for timestamping and preserves existing output" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let name = "wget-not-modified-\{@async.now()}.tmp"
      defer @async.protect_from_cancel(() => {
        for path in [name, name + ".1"] {
          if @fs.exists(path) {
            @fs.remove(path)
          }
        }
      })
      @fs.write_file(name, "preserve")
      let requests : Array[String] = []
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let request = StringBuilder()
          while connection.read_until("\r\n") is Some(line) && line != "" {
            request.write_string(line + "\r\n")
          }
          requests.push(request.to_string())
          connection.write(
            "HTTP/1.1 304 Not Modified\r\nContent-Length: 9\r\n\r\n",
          )
        })
      })
      for timestamping in [false, true] {
        let options = default_options()
        options.quiet = true
        options.no_proxy = true
        options.timestamping = timestamping
        options.tries = 1
        let status = download_one(
          options,
          LogDisabled,
          "http://127.0.0.1:\{server.addr.port()}/" + name,
          None,
        )
        assert_eq(status, if timestamping { 0 } else { 8 })
        assert_eq(@fs.read_file(name).text(), "preserve")
        assert_false(@fs.exists(name + ".1"))
      }
      assert_eq(requests.length(), 2)
      assert_false(requests[0].contains("If-Modified-Since:"))
      assert_true(requests[1].contains("If-Modified-Since:"))
    })
  })
}

///|
async test "wget continued downloads discover the disposition filename before selecting the resume offset" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let name = "wget-resume-disposition-\{@async.now()}.tmp"
      let renamed = name + ".renamed"
      defer @async.protect_from_cancel(() => {
        for path in [name, renamed] {
          if @fs.exists(path) {
            @fs.remove(path)
          }
        }
      })
      for
        (ranged, existing) in [
          (false, false),
          (false, true),
          (true, false),
          (true, true),
        ] {
        @fs.write_file(name, "abc")
        if existing {
          @fs.write_file(renamed, "preserve other file")
        } else if @fs.exists(renamed) {
          @fs.remove(renamed)
        }
        let requests : Array[String] = []
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        group.add_defer(() => server.close())
        group.spawn_bg(no_wait=true, () => {
          server.run_forever((connection, _) => {
            let request = StringBuilder()
            while connection.read_until("\r\n") is Some(line) && line != "" {
              request.write_string(line + "\r\n")
            }
            requests.push(request.to_string())
            let response = if ranged {
              "HTTP/1.1 206 Partial Content\r\nContent-Length: 3\r\nContent-Range: bytes 3-5/6\r\n"
            } else {
              "HTTP/1.1 200 OK\r\nContent-Length: 6\r\n"
            }
            let body = if ranged { "def" } else { "abcdef" }
            connection.write(
              response +
              "Content-Disposition: attachment; filename=" +
              renamed +
              "\r\n\r\n" +
              body,
            )
          })
        })
        let options = default_options()
        options.quiet = true
        options.no_proxy = true
        options.tries = 1
        options.continue_download = true
        options.content_disposition = true
        let status = download_one(
          options,
          LogDisabled,
          "http://127.0.0.1:\{server.addr.port()}/" + name,
          None,
        )
        assert_eq(status, if ranged { 4 } else { 0 })
        assert_eq(requests.length(), if ranged { 1 } else { 2 })
        assert_true(requests[0].has_prefix("HEAD /"))
        assert_false(requests[0].contains("Range:"))
        if !ranged {
          assert_true(requests[1].has_prefix("GET /"))
          if existing {
            assert_true(requests[1].contains("Range: bytes=19-\r\n"))
          } else {
            assert_false(requests[1].contains("Range:"))
          }
        }
        assert_eq(@fs.read_file(name).text(), "abc")
        assert_eq(@fs.exists(renamed), existing || !ranged)
        if existing {
          assert_eq(@fs.read_file(renamed).text(), "preserve other file")
        } else if !ranged {
          assert_eq(@fs.read_file(renamed).text(), "abcdef")
        }
      }
    })
  })
}
