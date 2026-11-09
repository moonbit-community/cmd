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
            options(),
          )
        catch {
          @netops.TransferError(kind~, context~, ..) => {
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
        options(),
      )
      assert_eq(result.status, 200)
      assert_eq(result.received, 0L)
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
          options(),
        )
      catch {
        @netops.TransferError(kind~, context~, ..) => {
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
