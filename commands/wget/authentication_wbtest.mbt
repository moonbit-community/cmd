///|
async test "rejected Basic credentials retain the wire authentication state" {
  @async.with_timeout(10000, () => {
    @async.with_task_group(group => {
      let root = @fs.tmpdir(prefix="wget-authentication")
      defer @async.protect_from_cancel(() => @fs.rmdir(root, recursive=true))
      for
        (challenge, preemptive) in [
          (true, false),
          (true, true),
          (false, false),
          (false, true),
        ] {
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
              "HTTP/1.1 401 Unauthorized\r\n" +
              (if challenge {
                "WWW-Authenticate: Basic realm=\"fixture\"\r\n"
              } else {
                ""
              }) +
              "Content-Length: 0\r\n\r\n",
            )
          })
        })
        let output = root + "/kept"
        @fs.write_file(output, b"preserved")
        let options = default_options()
        options.quiet = true
        options.no_proxy = true
        options.tries = 1
        options.user = Some("user")
        options.password = Some("bad")
        options.auth_no_challenge = preemptive
        options.output_document = Some(output)
        let status = download_one(
          options,
          LogDisabled,
          "http://127.0.0.1:\{server.addr.port()}/",
          None,
        )
        assert_eq(status, 6)
        assert_eq(
          requests.length(),
          if challenge && !preemptive {
            2
          } else {
            1
          },
        )
        let header = "Authorization: Basic dXNlcjpiYWQ=\r\n"
        assert_eq(requests[0].contains(header), preemptive)
        if challenge && !preemptive {
          assert_true(requests[1].contains(header))
        }
        assert_eq(@fs.read_file(output).binary(), b"preserved")
      }
    })
  })
}
