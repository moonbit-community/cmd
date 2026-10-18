///|
async test "wire chunk payload is committed before separator and trailer failures" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-chunk-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      for
        (suffix, expected_kind) in [
          ("5\r\nhello", PartialBodyFailure),
          ("5\r\nhello\r", PartialBodyFailure),
          ("5\r\nhelloX", ReceiveFailure),
          ("5\r\nhello\rX", ReceiveFailure),
          ("5\r\nhello\r\n0\r\n", PartialBodyFailure),
          ("5\r\nhello\r\n0\r\nX-Trailer: yes\r\n", PartialBodyFailure),
          ("5\r\nhello\r\n0\r\nbad trailer\r\n\r\n", ReceiveFailure),
        ] {
        let server = serve_raw_response(
          group,
          "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n" + suffix,
        )
        let failure = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Truncate,
              content_disposition=false,
              remove_on_error=false,
            ),
            transfer_options(),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(
              context,
              Some(
                failure_context(
                  ResponseBody,
                  framing=Chunked,
                  received_bytes=5L,
                  committed_bytes=5L,
                ),
              ),
            )
            Some(kind)
          }
          error => raise error
        } noraise {
          _ => None
        }
        assert_eq(failure, Some(expected_kind))
        assert_eq(@fs.read_file(path).text(), "hello")
      }
    })
  })
}

///|
async test "wire chunked framing overrides Content-Length and accepts extensions and trailers" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let server = serve_raw_response(
        group, "HTTP/1.1 200 OK\r\nTransfer-Encoding: Chunked\r\nContent-Length: 999\r\n\r\n5;name=value\r\nhello\r\n0\r\nX-Trailer: yes\r\n\r\n",
      )
      let result = transfer(
        "http://127.0.0.1:\{server.addr.port()}/",
        DiscardOutput,
        transfer_options(),
      )
      assert_eq(result.received, 5L)
      assert_eq(result.header("Content-Length"), Some("999"))
    })
  })
}

///|
async test "wire protocol metadata limits reject before opening output" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-limits-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      @fs.write_file(path, "preserve")
      let oversized = StringBuilder()
      oversized.write_string("HTTP/1.1 200 OK\r\nX-Large: ")
      for _ in 0..<65537 {
        oversized.write_string("x")
      }
      oversized.write_string("\r\n\r\n")
      let fields = StringBuilder()
      fields.write_string("HTTP/1.1 200 OK\r\n")
      for _ in 0..<1025 {
        fields.write_string("X-Field: x\r\n")
      }
      fields.write_string("\r\n")
      let large_value = StringBuilder()
      for _ in 0..<4096 {
        large_value.write_string("x")
      }
      let cumulative = StringBuilder()
      cumulative.write_string("HTTP/1.1 200 OK\r\n")
      for _ in 0..<256 {
        cumulative.write_string("X-Field: " + large_value.to_string() + "\r\n")
      }
      cumulative.write_string("\r\n")
      let interim = StringBuilder()
      for _ in 0..<129 {
        interim.write_string("HTTP/1.1 100 Continue\r\n\r\n")
      }
      interim.write_string("HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
      for
        wire in [
          oversized.to_string(),
          fields.to_string(),
          cumulative.to_string(),
          interim.to_string(),
        ] {
        let server = serve_raw_response(group, wire)
        let failure = try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/",
            FileOutput(
              path~,
              mode=Truncate,
              content_disposition=false,
              remove_on_error=false,
            ),
            transfer_options(),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(context, Some(failure_context(ResponseHeaders)))
            Some(kind)
          }
          error => raise error
        } noraise {
          _ => None
        }
        assert_eq(failure, Some(ReceiveFailure))
        assert_eq(@fs.read_file(path).text(), "preserve")
      }
      let maximum_interim = StringBuilder()
      for _ in 0..<128 {
        maximum_interim.write_string("HTTP/1.1 100 Continue\r\n\r\n")
      }
      maximum_interim.write_string(
        "HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n",
      )
      let server = serve_raw_response(group, maximum_interim.to_string())
      let result = transfer(
        "http://127.0.0.1:\{server.addr.port()}/",
        DiscardOutput,
        transfer_options(),
      )
      assert_eq(result.status, 200)
      assert_eq(result.received, 0L)
    })
  })
}

///|
async test "wire unknown length uploads stream independent chunks and a final terminator" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let frames : Array[Bytes] = []
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let expected = b"3\r\none\r\n3\r\ntwo\r\n0\r\n\r\n"
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let headers = StringBuilder()
          while connection.read_until("\r\n") is Some(line) && line != "" {
            headers.write_string(line + "\r\n")
          }
          assert_true(
            headers.to_string().contains("Transfer-Encoding: chunked\r\n"),
          )
          assert_false(headers.to_string().contains("Content-Length:"))
          frames.push(connection.read_exactly(expected.length()))
          connection.write(b"HTTP/1.1 200 OK\r\nContent-Length: 0\r\n\r\n")
        })
      })
      let parsed = parse_absolute_url(
        "http://127.0.0.1:\{server.addr.port()}/upload",
      )
      let options = transfer_options(request_method=Post, body=StdinBody)
      let started = @async.now()
      let wire = open_client(parsed, options, started)
      defer wire.close()
      wire.start_request(parsed, Post, {}, {}, StdinBody, options, started)
      wire.write_payload(b"one", options, started)
      wire.write_payload(b"", options, started)
      wire.write_payload(b"two", options, started)
      wire.finish_request(options, started)
      assert_eq(wire.request_payload_bytes, 6L)
      let response = wire.response(Post)
      assert_eq(response.code, 200)
      assert_eq(frames, [expected])
    })
  })
}

///|
async test "wire trailer metadata limits retain already delivered body" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let directory = @fs.tmpdir(prefix="netops-wire-trailer-limit-")
      defer @async.protect_from_cancel(() => {
        @fs.rmdir(directory, recursive=true)
      })
      let path = directory + "/body"
      let response = StringBuilder()
      response.write_string(
        "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n",
      )
      for _ in 0..<1025 {
        response.write_string("X-Trailer: x\r\n")
      }
      response.write_string("\r\n")
      let server = serve_raw_response(group, response.to_string())
      let failure = try
        transfer(
          "http://127.0.0.1:\{server.addr.port()}/",
          FileOutput(
            path~,
            mode=Truncate,
            content_disposition=false,
            remove_on_error=false,
          ),
          transfer_options(),
        )
      catch {
        TransferError(kind~, context~, ..) => {
          assert_eq(
            context,
            Some(
              failure_context(
                ResponseBody,
                framing=Chunked,
                received_bytes=5L,
                committed_bytes=5L,
              ),
            ),
          )
          Some(kind)
        }
        error => raise error
      } noraise {
        _ => None
      }
      assert_eq(failure, Some(ReceiveFailure))
      assert_eq(@fs.read_file(path).text(), "hello")
    })
  })
}
