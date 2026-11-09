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
          ("5\r\nhello", @netops.PartialBodyFailure),
          ("5\r\nhello\r", @netops.PartialBodyFailure),
          ("5\r\nhelloX", @netops.ReceiveFailure),
          ("5\r\nhello\rX", @netops.ReceiveFailure),
          ("5\r\nhello\r\n0\r\n", @netops.PartialBodyFailure),
          ("5\r\nhello\r\n0\r\nX-Trailer: yes\r\n", @netops.PartialBodyFailure),
          ("5\r\nhello\r\n0\r\nbad trailer\r\n\r\n", @netops.ReceiveFailure),
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
        assert_eq(failure, Some(expected_kind))
        assert_eq(@fs.read_file(path).text(), "hello")
      }
    })
  })
}
