///|
#derive(FromJson)
priv struct WgetCookieCase {
  label : String
  hosts : Array[String]
  fields : Array[Array[String]]
  input : String
  expected : Json
}

///|
fn wget_cookie_observations(
  requests : Array[(String, String, String)],
  hosts : Array[String],
  indices : Array[Int32],
) -> Array[String] raise {
  assert_eq(requests.length(), indices.length())
  let cookies : Array[String] = []
  for position, index in indices {
    let request = requests[position]
    let path = "/step/" + index.to_string()
    assert_true(
      request.0 == "GET " + path + " HTTP/1.1" ||
      request.0 == "GET http://" + hosts[index] + path + " HTTP/1.1",
      msg=request.0,
    )
    let host = hosts[index]
      .strip_suffix(":80")
      .unwrap_or(hosts[index][:])
      .to_owned()
    assert_eq(host_field(request.2, "host"), host)
    assert_eq(host_field(request.2, "authorization"), "")
    cookies.push(request.1)
  }
  cookies
}

///|
async fn network_wget_cookies_scenario(
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  let source = @json.parse(
    @fs.read_file(
      @harness.repository_root() + "/tests/fixtures/network/wget-cookies.json",
    ).text(),
  )
  guard source is { "schema": 1, "cases": Array(definitions), .. } else {
    fail("Wget cookie corpus required")
  }
  assert_eq(definitions.length(), 58)
  let failures : Array[String] = []
  for definition in definitions {
    let fixture : WgetCookieCase = @json.from_json(definition)
    assert_eq(fixture.hosts.length(), fixture.fields.length())
    guard fixture.expected is Object(expected) else {
      fail("expected observations required")
    }
    let expected_rows : Array[String] = @json.from_json(expected["rows"])
    let expected_cookies : Array[String] = @json.from_json(expected["cookies"])
    let directory = work + "/wget-cookie-" + fixture.label
    @fs.mkdir(directory)
    @fs.write_file(directory + "/input.jar", fixture.input)
    @fs.write_file(directory + "/sentinel", b"unchanged\n")
    if oracle_image is Some(_) {
      @fs.mkdir(directory + "/oracle")
      @fs.write_file(directory + "/oracle/input.jar", fixture.input)
      @fs.write_file(directory + "/oracle/sentinel", b"unchanged\n")
    }
    @async.with_task_group(group => {
      let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
      group.add_defer(() => server.close())
      let reload = Ref(false)
      let requests : Array[(String, String, String)] = []
      let tunnels : Array[String] = []
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let mut request = suffix_request(connection)
          if request.0.has_prefix("CONNECT ") {
            tunnels.push(request.2)
            connection.write("HTTP/1.1 200 Connection Established\r\n\r\n")
            request = suffix_request(connection)
          }
          let index = if reload.val {
            fixture.hosts.length() - 1
          } else {
            requests.length()
          }
          guard index < fixture.hosts.length() else {
            fail("unexpected Wget cookie request")
          }
          requests.push(request)
          let body = "step=" + index.to_string() + "\n"
          let fields = if reload.val { [] } else { fixture.fields[index] }
          connection.write(
            "HTTP/1.1 200 OK\r\n" +
            fields.map(value => "Set-Cookie: " + value + "\r\n").join("") +
            "Content-Length: " +
            body.length().to_string() +
            "\r\nConnection: close\r\n\r\n" +
            body,
          )
        })
      })
      let statuses : Array[Int32] = []
      let outputs : Array[String] = []
      let errors : Array[String] = []
      let cookies : Array[String] = []
      let row_orders : Array[Array[String]] = []
      for pass in [0, 1] {
        reload.val = pass == 1
        requests.clear()
        tunnels.clear()
        let candidate : Array[(String, String, String)] = []
        let candidate_tunnels : Array[String] = []
        let indices = if pass == 0 {
          fixture.hosts.mapi((index, _) => index)
        } else {
          [fixture.hosts.length() - 1]
        }
        let output_name = if pass == 0 { "saved.jar" } else { "reloaded.jar" }
        defer @async.protect_from_cancel(() => {
          @fs.write_file(
            directory + "/requests-" + pass.to_string() + ".wire.json",
            Json({
              "candidate": @json.to_json(candidate),
              "oracle": @json.to_json(requests),
              "candidate_connect": Json(candidate_tunnels),
              "oracle_connect": Json(tunnels),
            }).stringify(indent=2) +
            "\n",
          )
        })
        let oracle_names = if oracle_image is Some(_) {
          @fs.readdir(directory + "/oracle")
        } else {
          []
        }
        let observing : Executor = {
          proof: executor.proof,
          invoke: invocation => {
            let before = @fs.readdir(directory)
            assert_false(before.contains(output_name))
            let execution = (executor.invoke)(invocation)
            candidate.append(requests)
            candidate_tunnels.append(tunnels)
            requests.clear()
            tunnels.clear()
            before.push(output_name)
            before.sort()
            let after = @fs.readdir(directory)
            after.sort()
            assert_eq(after, before)
            execution
          },
        }
        let proxy = "http://127.0.0.1:" + server.addr.port().to_string()
        let result = network_request(
          observing,
          directory,
          "wget",
          [
            "-qO-",
            "-t1",
            "--keep-session-cookies",
            "--load-cookies=" +
            directory +
            (if pass == 0 { "/input.jar" } else { "/saved.jar" }),
            "--save-cookies=" + directory + "/" + output_name,
            ..indices.map(index => {
              "http://" + fixture.hosts[index] + "/step/" + index.to_string()
            }),
          ],
          environment={
            "LC_ALL": "C",
            "NO_PROXY": "",
            "no_proxy": "",
            "http_proxy": proxy,
            "HTTP_PROXY": proxy,
          },
          oracle_image?,
          oracle_failures=failures,
        )
        check_network_response(
          result,
          indices.map(index => "step=" + index.to_string() + "\n").join(""),
        )
        statuses.push(result.status)
        outputs.push(@harness.scenario_text(result.stdout))
        errors.push(@harness.scenario_text(result.stderr))
        let observed = wget_cookie_observations(
          candidate,
          fixture.hosts,
          indices,
        )
        let expected_slice = if pass == 0 {
          expected_cookies[:fixture.hosts.length()].to_owned()
        } else {
          [expected_cookies.last().unwrap()]
        }
        assert_eq(observed, expected_slice, msg=fixture.label)
        cookies.append(observed)
        assert_eq(
          cookie_rows(@fs.read_file(directory + "/" + output_name).text()),
          expected_rows,
          msg=fixture.label,
        )
        if expected.get("row_orders") is Some(order) {
          let orders : Array[Array[String]] = @json.from_json(order)
          let actual = cookie_rows(
            @fs.read_file(directory + "/" + output_name).text(),
            sorted=false,
          )
          assert_eq(actual, orders[pass])
          row_orders.push(actual)
        }
        assert_eq(@fs.read_file(directory + "/input.jar").text(), fixture.input)
        assert_eq(
          @fs.read_file(directory + "/sentinel").binary(),
          b"unchanged\n",
        )
        if oracle_image is Some(_) {
          assert_eq(
            wget_cookie_observations(requests, fixture.hosts, indices),
            expected_slice,
            msg="oracle " + fixture.label,
          )
          assert_eq(
            cookie_rows(
              @fs.read_file(directory + "/oracle/" + output_name).text(),
            ),
            expected_rows,
            msg="oracle " + fixture.label,
          )
          if expected.get("row_orders") is Some(order) {
            let orders : Array[Array[String]] = @json.from_json(order)
            assert_eq(
              cookie_rows(
                @fs.read_file(directory + "/oracle/" + output_name).text(),
                sorted=false,
              ),
              orders[pass],
            )
          }
          assert_eq(
            @fs.read_file(directory + "/oracle/input.jar").text(),
            fixture.input,
          )
          assert_eq(
            @fs.read_file(directory + "/oracle/sentinel").binary(),
            b"unchanged\n",
          )
          oracle_names.push(output_name)
          oracle_names.sort()
          let after = @fs.readdir(directory + "/oracle")
          after.sort()
          assert_eq(after, oracle_names)
        } else {
          assert_true(requests.is_empty())
        }
      }
      let observed : Json = {
        "status": Json(statuses),
        "stdout": Json(outputs),
        "stderr": Json(errors),
        "cookies": Json(cookies),
        "rows": Json(
          cookie_rows(@fs.read_file(directory + "/reloaded.jar").text()),
        ),
        "requests": Json(cookies.length()),
      }
      if observed is Object(fields) && expected.contains("row_orders") {
        fields["row_orders"] = Json(row_orders)
      }
      assert_eq(observed, fixture.expected, msg=fixture.label)
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "wget-cookie/" + fixture.label,
          "wget",
          observed,
          fixture.expected,
        )
      }
    })
  }
  guard failures.is_empty() else { fail(failures.join("\n")) }
}
