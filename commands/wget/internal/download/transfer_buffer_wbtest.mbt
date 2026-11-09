///|
async test "curl content disposition creates exclusive output before empty body failures" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let token = @async.now().to_string()

      for existing in [false, true] {
        let suffix = "wget"
        let path = "netops-cd-empty-\{token}-\{suffix}-\{existing}.bin"
        defer @async.protect_from_cancel(() => {
          if @fs.exists(path) {
            @fs.remove(path)
          }
        })
        if existing {
          @fs.write_file(path, b"preserve")
        }
        let server = serve_raw_response(
          group,
          "HTTP/1.1 200 OK\r\nContent-Disposition: attachment; filename=\"\{path}\"\r\nContent-Length: 9\r\n\r\n",
        )
        let opened : Array[String?] = []
        try
          transfer(
            "http://127.0.0.1:\{server.addr.port()}/body",
            FileOutput(
              path=path + ".fallback",
              mode=Truncate,
              content_disposition=true,
              remove_on_error=false,
            ),
            options(),
            observer=event => {
              if event is OutputStarted(path~, ..) {
                opened.push(path)
              }
            },
          )
        catch {
          @netops.TransferError(kind~, ..) =>
            assert_eq(kind, PartialBodyFailure)
          error => raise error
        } noraise {
          _ =>
            fail("an incomplete body or an existing curl destination must fail")
        }
        assert_eq(opened, [Some(path)])
        assert_eq(@fs.read_file(path).binary(), b"")
        assert_false(@fs.exists(path + ".fallback"))
      }
    })
  })
}

///|
async test "content disposition naming remains active on HTTP errors" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let token = @async.now().to_string()

      let suffix = "wget"
      let selected = "netops-cd-status-\{token}-\{suffix}.selected"
      let fallback = selected + ".url"
      defer @async.protect_from_cancel(() => {
        for path in [selected, fallback] {
          if @fs.exists(path) {
            @fs.remove(path)
          }
        }
      })
      let server = serve_raw_response(
        group,
        "HTTP/1.1 404 Not Found\r\nContent-Disposition: attachment; filename=\"\{selected}\"\r\nContent-Length: 5\r\n\r\nhello",
      )
      let result = transfer(
        "http://127.0.0.1:\{server.addr.port()}/" + fallback,
        FileOutput(
          path=fallback,
          mode=Truncate,
          content_disposition=true,
          remove_on_error=false,
        ),
        options(),
      )
      assert_eq(result.output_path, Some(selected))
      assert_eq(@fs.read_file(selected).binary(), b"hello")
      assert_false(@fs.exists(fallback))
    })
  })
}
