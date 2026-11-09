///|
async fn network_header_fields_scenario(
  executor : Executor,
  work : String,
  failures : Array[String],
  oracle_image? : String,
) -> Unit {
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[String] = []
    let response_fields = "X-Value: first\r\nSet-Cookie: a=1\r\nx-value: second\r\nSet-Cookie: b=2\r\nContent-Length: 0\r\n"
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((connection, _) => {
        guard connection.read_until("\r\n") is Some(start) else {
          fail("missing request line")
        }
        let fields : Array[String] = []
        let wire = StringBuilder()
        let mut authorization = None
        wire.write_string(start + "\r\n")
        while connection.read_until("\r\n") is Some(line) && line != "" {
          wire.write_string(line + "\r\n")
          let lower = line.to_lower()
          if lower.has_prefix("x-marker:") || lower.has_prefix("user-agent:") {
            fields.push(line)
          }
          if lower.has_prefix("authorization:") {
            authorization = Some(line)
          }
        }
        requests.push(wire.to_string())
        if start.has_prefix("HEAD /response ") {
          connection.write("HTTP/1.1 200 OK\r\n" + response_fields + "\r\n")
        } else if start.has_prefix("GET /challenge ") && authorization is None {
          connection.write(
            "HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Unknown realm=\"first\"\r\nWWW-Authenticate: Basic realm=\"a,b\"\r\nContent-Length: 0\r\n\r\n",
          )
        } else {
          let body = if start.has_prefix("GET /challenge ") {
            authorization.unwrap_or("missing") + "\n"
          } else {
            fields.join("\n") + "\n"
          }
          connection.write(
            "HTTP/1.1 200 OK\r\nContent-Length: \{body.length()}\r\n\r\n" + body,
          )
        }
      })
    })
    let base = "http://127.0.0.1:\{server.addr.port()}"
    for
      (label, command, args, expected, count) in [
        (
          "curl-default-agent",
          "curl",
          [
            "-sS",
            "-H",
            "X-Marker: first",
            "-H",
            "X-Marker: second",
            base + "/fields",
          ],
          "User-Agent: curl/8.22.0\nX-Marker: first\nX-Marker: second\n",
          1,
        ),
        (
          "curl-fields",
          "curl",
          [
            "-sS",
            "-H",
            "X-Marker: first",
            "-H",
            "User-Agent: coverage",
            "-H",
            "X-Marker: second",
            base + "/fields",
          ],
          "X-Marker: first\nUser-Agent: coverage\nX-Marker: second\n",
          1,
        ),
        (
          "wget-fields",
          "wget",
          [
            "-qO-",
            "--header=X-Marker: first",
            "--header=User-Agent: coverage",
            "--header=X-Marker: second",
            base + "/fields",
          ],
          "User-Agent: coverage\nX-Marker: second\n",
          1,
        ),
        (
          "curl-response-fields",
          "curl",
          ["-sSI", base + "/response"],
          "HTTP/1.1 200 OK\r\n" + response_fields + "\r\n",
          1,
        ),
        (
          "wget-challenge-fields",
          "wget",
          ["-qO-", "-t1", "--user=user", "--password=pass", base + "/challenge"],
          "Authorization: Basic dXNlcjpwYXNz\n",
          2,
        ),
      ] {
      requests.clear()
      let candidate : Array[String] = []
      let observing : Executor = {
        invoke: invocation => {
          let execution = (executor.invoke)(invocation)
          candidate.append(requests)
          requests.clear()
          execution
        },
      }
      let result = network_request(
        observing,
        work,
        command,
        args,
        oracle_image?,
        oracle_failures=failures,
      )
      check_network_response(result, expected)
      assert_eq(candidate.length(), count)
      assert_eq(
        requests.length(),
        if oracle_image is Some(_) {
          count
        } else {
          0
        },
      )
      if label == "wget-challenge-fields" {
        for
          attempt in [
            candidate,
            ..if oracle_image is Some(_) {
              [requests]
            } else {
              []
            },
          ] {
          let auth = attempt.map(wire => {
            wire
            .split("\r\n")
            .filter(line => {
              line.to_owned().to_lower().has_prefix("authorization:")
            })
            .map(line => line.to_owned())
            .to_array()
          })
          assert_eq(auth, [[], ["Authorization: Basic dXNlcjpwYXNz"]])
        }
      }
      @fs.write_file(
        work + "/" + label + ".wire.json",
        @json.to_json({ "candidate": candidate, "oracle": requests }).stringify(
          indent=2,
        ),
      )
      if oracle_image is None {
        @harness.assert_observation(
          "headers/" + label,
          command,
          {
            "status": result.status,
            "stdout": @harness.scenario_text(result.stdout),
            "stderr": @harness.scenario_text(result.stderr),
            "requests": candidate.length(),
          },
          { "status": 0, "stdout": expected, "stderr": "", "requests": count },
        )
      }
    }
  })
}
