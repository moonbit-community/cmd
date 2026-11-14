///|
async test "repeated request lengths reject without writing or opening output" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-request-length-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let output = directory + "/output"
      @fs.write_file(output, b"preserve")
      for second in ["3", "4", "bad"] {
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        defer server.close()
        let observed = group.spawn(() => {
          let (connection, _) = server.accept()
          defer connection.close()
          connection.read_all().binary()
        })
        try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path=output,
              mode=Truncate,
              content_disposition=false,
              remove_on_error=false,
            ),
            options(request_method=Post, body=BytesBody(b"abc"), headers=[
              @netops.http_header("Content-Length", "3"),
              @netops.http_header("content-length", second),
            ]),
          )
        catch {
          @netops.TransferError(kind~, ..) => assert_eq(kind, InputFailure)
          error => raise error
        } noraise {
          _ => fail("repeated lengths must reject")
        }
        assert_eq(observed.wait(), b"")
        assert_eq(@fs.read_file(output).binary(), b"preserve")
      }
    })
  })
}

///|
async test "literal Cookie fields reject injection and jar CR terminates its value" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-generated-header-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let output_path = directory + "/output"
      @fs.write_file(output_path, "preserve")
      for variant in 0..<5 {
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        defer server.close()
        let observed = group.spawn(() => {
          let (connection, _) = server.accept()
          defer connection.close()
          if variant >= 3 {
            let request = StringBuilder()
            while connection.read_until("\r\n") is Some(line) && line != "" {
              request.write_string(line + "\r\n")
            }
            connection.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok")
            return @utf8.encode(request.to_string())
          }
          connection.read_all().binary()
        })
        let jar = CookieJar::new()
        if variant >= 3 {
          jar.load_netscape(
            "127.0.0.1\tFALSE\t/\tFALSE\t0\tsid\tone\rX-Injected: yes\n",
          )
        }
        let literal = match variant {
          0 => Some("sid=one\r\nX-Injected: yes")
          1 => Some("sid=one\nX-Injected: yes")
          2 => Some("sid=one\rX-Injected: yes")
          _ => None
        }
        try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path=output_path,
              mode=Truncate,
              content_disposition=false,
              remove_on_error=false,
            ),
            options(
              cookie_data?=literal,
              cookie_jar=jar,
              headers=if variant == 4 {
                [@netops.http_header("Cookie", "explicit=safe")]
              } else {
                []
              },
              idle_timeout_ms=500,
            ),
          )
        catch {
          @netops.TransferError(kind~, context~, ..) => {
            assert_eq(kind, ProtocolFailure)
            assert_eq(context, Some(failure_context(Request)))
          }
          error => raise error
        } noraise {
          _ => assert_true(variant >= 3)
        }
        if variant < 3 {
          assert_eq(observed.wait(), b"")
          assert_eq(@fs.read_file(output_path).binary(), b"preserve")
        } else {
          let request = @utf8.decode(observed.wait())
          assert_true(request.contains("Cookie: sid=one\r\n"))
          assert_false(request.contains("X-Injected"))
          assert_eq(request.contains("Cookie: explicit=safe\r\n"), variant == 4)
          assert_eq(@fs.read_file(output_path).binary(), b"ok")
        }
      }
    })
  })
}
