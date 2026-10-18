///|
async test "generated Cookie fields reject line injection before writing request bytes" {
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
            transfer_options(
              cookie_data?=literal,
              cookie_jar=jar,
              headers=if variant == 4 {
                [http_header("Cookie", "explicit=safe")]
              } else {
                []
              },
              idle_timeout_ms=500,
            ),
          )
        catch {
          TransferError(kind~, context~, ..) => {
            assert_eq(kind, ProtocolFailure)
            assert_eq(context, Some(failure_context(Request)))
          }
          error => raise error
        } noraise {
          _ => fail("generated request fields must reject CR/LF")
        }
        assert_eq(observed.wait(), b"")
        assert_eq(@fs.read_file(output_path).binary(), b"preserve")
      }
    })
  })
}
