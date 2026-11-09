///|
#derive(FromJson)
priv struct CookieDomainCase {
  id : String
  tool : String
  hosts : Array[String]
  fields : Array[Array[String]]
  input : String
  locale : String
  tz : String
  url_encoding_flags : Array[String]
  keep_session : Bool
  expected : Json
}

///|
fn cookie_domain_requests(
  requests : Array[(String, String, String)],
  tunnels : Array[String],
  indices : Array[Int32],
  offset : Int32,
  expected : Map[String, Json],
  candidate~ : Bool,
  proxy_authority~ : String,
) -> Array[String] raise {
  let hosts : Array[Array[String]] = @json.from_json(expected["host_fields"])
  let targets : Array[String] = @json.from_json(expected["request_targets"])
  let cookies : Array[String] = @json.from_json(expected["cookies"])
  let frozen_requests : Array[Json] = @json.from_json(expected["requests"])
  assert_eq(frozen_requests.length(), cookies.length())
  assert_eq(requests.length(), indices.length())
  assert_eq(tunnels.length(), if candidate { indices.length() } else { 0 })
  let observed : Array[String] = []
  for position, index in indices {
    let request = requests[position]
    let frozen = offset + position
    assert_eq(
      request.0,
      if candidate {
        "GET /step/" + index.to_string() + " HTTP/1.1"
      } else {
        targets[frozen]
      },
    )
    let actual_hosts = request.2
      .split("\r\n")
      .filter(line => line.to_owned().to_lower().has_prefix("host:"))
      .map(line => line.to_owned())
      .to_array()
    assert_eq(actual_hosts, hosts[frozen])
    assert_eq(actual_hosts.length(), 1)
    guard frozen_requests[frozen] is { "lines": Array(lines), .. } else {
      fail("original oracle request fields required")
    }
    let original_fields : Array[String] = @json.from_json(Json(lines))
    let original_cookies = original_fields.filter(line => {
      line.to_lower().has_prefix("cookie:")
    })
    let actual_cookies = request.2
      .split("\r\n")
      .filter(line => line.to_owned().to_lower().has_prefix("cookie:"))
      .map(line => line.to_owned())
      .to_array()
    assert_eq(actual_cookies, original_cookies)
    assert_false(
      original_fields.any(line => line.to_lower().has_prefix("authorization:")),
    )
    assert_false(
      request.2
      .split("\r\n")
      .any(line => line.to_owned().to_lower().has_prefix("authorization:")),
    )
    assert_eq(request.1, cookies[frozen])
    if candidate {
      let authority = actual_hosts[0][5:].trim().to_owned() + ":80"
      assert_eq(
        tunnels[position].split("\r\n").to_array()[0],
        "CONNECT " + authority + " HTTP/1.1",
      )
      // Existing tunnel framing names the proxy here; this is not an
      // upstream CONNECT-header parity claim.
      assert_eq(host_field(tunnels[position], "host"), proxy_authority)
    }
    observed.push(request.1)
  }
  observed
}

///|
async fn network_cookie_domains_scenario(
  executor : Executor,
  work : String,
  tool~ : String,
  oracle_image? : String,
) -> Unit {
  assert_true(tool == "curl" || tool == "wget")
  let source = @json.parse(
    @fs.read_file(
      @harness.repository_root() + "/tests/fixtures/network/cookie-domains.json",
    ).text(),
  )
  guard source is { "schema": 1, "cases": Array(definitions), .. } else {
    fail("frozen cookie Domain corpus required")
  }
  assert_eq(definitions.length(), 255)
  let failures : Array[String] = []
  let seen : Map[String, Bool] = Map([])
  let mut selected = 0
  for definition in definitions {
    let fixture : CookieDomainCase = @json.from_json(definition)
    assert_false(seen.contains(fixture.id))
    seen[fixture.id] = true
    if fixture.tool != tool {
      continue
    }
    selected += 1
    assert_eq(fixture.hosts.length(), fixture.fields.length())
    assert_true(fixture.hosts.length() > 0)
    guard fixture.expected is Object(expected) else {
      fail("expected observations required")
    }
    let expected_rows : Array[Array[String]] = @json.from_json(
      expected["rows_by_phase"],
    )
    let expected_orders : Array[Array[String]] = @json.from_json(
      expected["row_orders"],
    )
    assert_eq(expected_rows.length(), 2)
    assert_eq(expected_orders.length(), 2)
    let directory = work +
      "/cookie-domain-" +
      fixture.id.replace_all(old="/", new="-")
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
      let responses : Array[Json] = []
      let observer_errors : Array[String] = []
      group.spawn_bg(no_wait=true, () => {
        server.run_forever((connection, _) => {
          let result = try {
            let mut request = suffix_request(connection)
            if request.0.has_prefix("CONNECT ") {
              tunnels.push(request.2)
              connection.write("HTTP/1.1 200 Connection Established\r\n\r\n")
              request = suffix_request(connection)
            }
            requests.push(request)
            let index = if reload.val {
              fixture.hosts.length() - 1
            } else {
              requests.length() - 1
            }
            guard index < fixture.hosts.length() else {
              fail("unexpected Domain request")
            }
            let body = "step=" + index.to_string() + "\n"
            let fields = if reload.val { [] } else { fixture.fields[index] }
            let response = @utf8.encode(
              "HTTP/1.1 200 OK\r\n" +
              fields.map(value => "Set-Cookie: " + value + "\r\n").join("") +
              "Content-Length: " +
              body.length().to_string() +
              "\r\nConnection: close\r\n\r\n" +
              body,
            )
            responses.push({
              "phase": Json(if reload.val { 1 } else { 0 }),
              "index": Json(index),
              "hex": Json(@crypto.bytes_to_hex_string(response)),
            })
            connection.write(response)
            Ok(())
          } catch {
            error => Err(error)
          }
          match result {
            Ok(_) => ()
            Err(error) => {
              observer_errors.push(error.to_string())
              raise error
            }
          }
        })
      })
      let statuses : Array[Int32] = []
      let outputs : Array[String] = []
      let errors : Array[String] = []
      let cookies : Array[String] = []
      let row_orders : Array[Array[String]] = []
      let rows_by_phase : Array[Array[String]] = []
      for pass in [0, 1] {
        reload.val = pass == 1
        requests.clear()
        tunnels.clear()
        responses.clear()
        let candidate : Array[(String, String, String)] = []
        let candidate_tunnels : Array[String] = []
        let candidate_responses : Array[Json] = []
        let expected_names : Array[String] = []
        let actual_names : Array[String] = []
        let indices = if pass == 0 {
          fixture.hosts.mapi((index, _) => index)
        } else {
          [fixture.hosts.length() - 1]
        }
        let offset = if pass == 0 { 0 } else { fixture.hosts.length() }
        let output_name = if pass == 0 { "saved.jar" } else { "reloaded.jar" }
        let saved = if pass == 1 {
          Some(@fs.read_file(directory + "/saved.jar").binary())
        } else {
          None
        }
        let oracle_saved = if pass == 1 && oracle_image is Some(_) {
          Some(@fs.read_file(directory + "/oracle/saved.jar").binary())
        } else {
          None
        }
        let candidate_returned = Ref(false)
        defer @async.protect_from_cancel(() => {
          @fs.write_file(
            directory + "/requests-" + pass.to_string() + ".wire.json",
            Json({
              "candidate": @json.to_json(candidate),
              "oracle": @json.to_json(requests),
              "candidate_connect": Json(candidate_tunnels),
              "oracle_connect": Json(tunnels),
              "observer_errors": Json(observer_errors),
              "candidate_returned": Json(candidate_returned.val),
              "candidate_responses": Json(candidate_responses),
              "oracle_responses": Json(responses),
              "candidate_expected_files": Json(expected_names),
              "candidate_actual_files": Json(actual_names),
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
          invoke: invocation => {
            let before = @fs.readdir(directory)
            assert_false(before.contains(output_name))
            defer {
              candidate.append(requests)
              candidate_tunnels.append(tunnels)
              candidate_responses.append(responses)
              requests.clear()
              tunnels.clear()
              responses.clear()
            }
            let execution = (executor.invoke)(invocation)
            candidate_returned.val = true
            before.push(output_name)
            before.sort()
            let after = @fs.readdir(directory)
            after.sort()
            expected_names.append(before)
            actual_names.append(after)
            execution
          },
        }
        let load = directory +
          (if pass == 0 { "/input.jar" } else { "/saved.jar" })
        let save = directory + "/" + output_name
        let urls = indices.map(index => {
          "http://" + fixture.hosts[index] + "/step/" + index.to_string()
        })
        let args = if tool == "wget" {
          [
            "-qO-",
            "-t1",
            ..if fixture.keep_session {
              ["--keep-session-cookies"]
            } else {
              []
            },
            ..fixture.url_encoding_flags,
            "--load-cookies=" + load,
            "--save-cookies=" + save,
            ..urls,
          ]
        } else {
          assert_true(fixture.url_encoding_flags.is_empty())
          ["-s", "--max-time", "5", "-b", load, "-c", save, ..urls]
        }
        let oracle_args = [
          ..if tool == "wget" {
            ["--no-config", "--no-netrc"]
          } else {
            ["-q"]
          },
          ..args,
        ]
        let proxy = "http://127.0.0.1:" + server.addr.port().to_string()
        let result = network_request(
          observing,
          directory,
          tool,
          args,
          environment={
            "LC_ALL": fixture.locale,
            "LC_CTYPE": "C",
            "LANG": "C",
            "TZ": fixture.tz,
            "NO_PROXY": "",
            "no_proxy": "",
            "http_proxy": proxy,
            "HTTP_PROXY": if @async.platform is Windows {
              proxy
            } else {
              ""
            },
            "https_proxy": "",
            "HTTPS_PROXY": "",
            "ALL_PROXY": "",
            "all_proxy": "",
          },
          oracle_image?,
          oracle_args~,
          oracle_failures=failures,
        )
        assert_true(observer_errors.is_empty(), msg=observer_errors.join("\n"))
        assert_eq(actual_names, expected_names)
        let expected_responses : Array[Json] = @json.from_json(
          expected["responses"],
        )
        let phase_responses = expected_responses.filter(value => {
          value is Object(fields) && fields.get("phase") == Some(Json(pass))
        })
        assert_eq(phase_responses.length(), indices.length())
        assert_eq(candidate_responses, phase_responses)
        if saved is Some(bytes) {
          assert_eq(@fs.read_file(directory + "/saved.jar").binary(), bytes)
        }
        if oracle_saved is Some(bytes) {
          assert_eq(
            @fs.read_file(directory + "/oracle/saved.jar").binary(),
            bytes,
          )
        }
        statuses.push(result.status)
        outputs.push(@harness.scenario_text(result.stdout))
        errors.push(@harness.scenario_text(result.stderr))
        cookies.append(
          cookie_domain_requests(
            candidate,
            candidate_tunnels,
            indices,
            offset,
            expected,
            candidate=true,
            proxy_authority="127.0.0.1:" + server.addr.port().to_string(),
          ),
        )
        for
          engine in (if oracle_image is Some(_) {
            ["", "/oracle"]
          } else {
            [""]
          }) {
          let base = directory + engine
          let jar = @fs.read_file(base + "/" + output_name).text()
          let rows = cookie_rows(jar)
          let order = cookie_rows(jar, sorted=false)
          assert_eq(rows, expected_rows[pass], msg=fixture.id + engine)
          assert_eq(order, expected_orders[pass], msg=fixture.id + engine)
          assert_eq(
            @fs.read_file(base + "/input.jar").binary(),
            @utf8.encode(fixture.input),
          )
          assert_eq(@fs.read_file(base + "/sentinel").binary(), b"unchanged\n")
          if engine == "" {
            rows_by_phase.push(rows)
            row_orders.push(order)
          }
        }
        if oracle_image is Some(_) {
          assert_eq(responses, phase_responses)
          ignore(
            cookie_domain_requests(
              requests,
              tunnels,
              indices,
              offset,
              expected,
              candidate=false,
              proxy_authority="127.0.0.1:" + server.addr.port().to_string(),
            ),
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
        "rows_by_phase": Json(rows_by_phase),
        "row_orders": Json(row_orders),
      }
      let frozen : Map[String, Json] = Map([])
      for
        key in [
          "status", "stdout", "stderr", "cookies", "rows_by_phase", "row_orders",
        ] {
        frozen[key] = expected[key]
      }
      assert_eq(observed, Json(frozen), msg=fixture.id)
      if oracle_image is None {
        @harness.assert_observation(
          "cookie-domain/" + fixture.id,
          tool,
          observed,
          Json(frozen),
        )
      }
    })
  }
  assert_eq(seen.length(), 255)
  assert_eq(selected, if tool == "curl" { 120 } else { 135 })
  guard failures.is_empty() else { fail(failures.join("\n")) }
}
