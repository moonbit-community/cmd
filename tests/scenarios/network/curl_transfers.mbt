///|
fn transfer_object(value : Json) -> Map[String, Json] raise {
  guard value is Object(fields) else {
    fail("transfer fixture object required")
  }
  fields
}

///|
fn transfer_array(value : Json) -> Array[Json] raise {
  guard value is Array(values) else { fail("transfer fixture array required") }
  values
}

///|
fn transfer_string(value : Json) -> String raise {
  guard value is String(value) else { fail("transfer fixture string required") }
  value
}

///|
fn transfer_filename(value : Json) -> String raise {
  let name = transfer_string(value)
  assert_false(["", ".", "..", "oracle"].contains(name))
  assert_false(name.contains("/") || name.contains("\\"))
  name
}

///|
async fn transfer_create_files(work : String, files : Array[Json]) -> Unit {
  let seen : Map[String, Bool] = Map([])
  for file in files {
    let fields = transfer_object(file)
    let name = transfer_filename(fields["name"])
    assert_false(seen.contains(name))
    seen[name] = true
    if fields.get("kind") == Some(Json("directory")) {
      @fs.mkdir(work + "/" + name)
      transfer_create_files(
        work + "/" + name,
        transfer_array(fields["entries"]),
      )
    } else {
      assert_true(
        fields.get("kind") is None || fields.get("kind") == Some(Json("file")),
      )
      @fs.write_file(
        work + "/" + name,
        @harness.decode_hex(transfer_string(fields["hex"]), name),
      )
    }
  }
}

///|
async fn transfer_file_state(
  work : String,
  oracle_child~ : Bool = false,
) -> Json {
  let names = @fs.readdir(work).filter(name => {
    !(oracle_child && name == "oracle")
  })
  names.sort_by((left, right) => left.lexical_compare(right))
  let result : Array[Json] = []
  for name in names {
    let path = work + "/" + name
    match @fs.kind(path, follow_symlink=false) {
      @fs.Regular =>
        result.push({
          "name": Json(name),
          "hex": Json(@crypto.bytes_to_hex_string(@fs.read_file(path).binary())),
        })
      @fs.Directory =>
        result.push({
          "name": Json(name),
          "kind": "directory",
          "entries": transfer_file_state(path),
        })
      _ => result.push({ "name": Json(name), "kind": "unexpected-file-type" })
    }
  }
  Json(result)
}

///|
fn transfer_expected_files(value : Json) -> Json raise {
  let result = transfer_array(value).map(file => {
    let fields = transfer_object(file)
    let name = transfer_filename(fields["name"])
    if fields.get("kind") == Some(Json("directory")) {
      (
        name,
        (
          {
            "name": Json(name),
            "kind": "directory",
            "entries": transfer_expected_files(fields["entries"]),
          } : Json),
      )
    } else {
      assert_true(
        fields.get("kind") is None || fields.get("kind") == Some(Json("file")),
      )
      (name, ({ "name": Json(name), "hex": fields["hex"] } : Json))
    }
  })
  result.sort_by((a, b) => a.0.lexical_compare(b.0))
  Json(result.map(value => value.1))
}

///|
fn transfer_check_requests(
  requests : Array[(String, String, String)],
  tunnels : Array[String],
  exchanges : Array[Json],
  candidate~ : Bool,
  proxy_authority~ : String,
) -> Unit raise {
  assert_eq(requests.length(), exchanges.length())
  assert_eq(tunnels.length(), if candidate { exchanges.length() } else { 0 })
  for index, request in requests {
    let expected = transfer_object(exchanges[index])
    let original = transfer_string(expected["request_line"])
    let parts = original.split(" ").to_array()
    assert_eq(parts.length(), 3)
    assert_eq(parts[0], "GET")
    assert_eq(parts[2], "HTTP/1.1")
    let url = parts[1].strip_prefix("http://").unwrap().to_owned()
    let slash = url.find("/").unwrap()
    let authority = url[:slash].to_owned()
    assert_eq(
      request.0,
      if candidate {
        "GET " + url[slash:].to_owned() + " HTTP/1.1"
      } else {
        original
      },
    )
    let hosts = request.2
      .split("\r\n")
      .filter(line => line.to_owned().to_lower().has_prefix("host:"))
      .map(line => line.to_owned())
      .to_array()
    let expected_hosts : Array[String] = @json.from_json(
      expected["host_fields"],
    )
    assert_eq(hosts, expected_hosts)
    assert_eq(hosts.length(), 1)
    let cookie_fields = request.2
      .split("\r\n")
      .filter(line => line.to_owned().to_lower().has_prefix("cookie:"))
      .map(line => line.to_owned())
      .to_array()
    let frozen_cookies : Array[String] = @json.from_json(
      expected["cookie_fields"],
    )
    assert_eq(cookie_fields, frozen_cookies)
    let authorization = request.2
      .split("\r\n")
      .filter(line => line.to_owned().to_lower().has_prefix("authorization:"))
      .to_array()
    assert_true(authorization.is_empty())
    assert_eq(request.1, transfer_string(expected["cookie"]))
    if candidate {
      assert_eq(
        tunnels[index].split("\r\n").to_array()[0],
        "CONNECT " + authority + ":80 HTTP/1.1",
      )
      // This retains the existing proxy Host contract, not upstream parity.
      assert_eq(host_field(tunnels[index], "host"), proxy_authority)
    }
  }
}

///|
fn transfer_phase_expected(phase : Map[String, Json]) -> Json raise {
  assert_eq(phase["files_after_complete"], Json(true))
  {
    "status": phase["status"],
    "stdout_hex": phase["stdout_hex"],
    "stderr_hex": phase["stderr_hex"],
    "cookies": Json(
      transfer_array(phase["exchanges"]).map(exchange => {
        transfer_object(exchange)["cookie"]
      }),
    ),
    "files_after": transfer_expected_files(phase["files_after"]),
  }
}

///|
async fn network_curl_transfers_scenario(
  executor : Executor,
  work : String,
  corpus~ : String,
  oracle_image? : String,
) -> Unit {
  let count = match corpus {
    "curl-cookie-lifecycle" => 20
    "curl-http-retry" => 15
    _ => fail("unknown frozen Curl transfer corpus")
  }
  let fixture = transfer_object(
    @json.parse(
      @fs.read_file(
        @harness.repository_root() +
        "/tests/fixtures/network/" +
        corpus +
        ".json",
      ).text(),
    ),
  )
  assert_eq(fixture["schema"], Json(1))
  assert_eq(fixture["case_count"], Json(count))
  let definitions = transfer_array(fixture["cases"])
  assert_eq(definitions.length(), count)
  let seen : Map[String, Bool] = Map([])
  let failures : Array[String] = []
  for definition in definitions {
    let spec = transfer_object(definition)
    let label = transfer_filename(spec["label"])
    assert_false(seen.contains(label))
    seen[label] = true
    assert_eq(spec["command"], Json("curl"))
    let directory = work + "/" + label
    let evidence = work + "/" + label + ".evidence"
    @fs.mkdir(directory)
    @fs.mkdir(evidence)
    let initial = transfer_array(spec["initial_files"])
    transfer_create_files(directory, initial)
    if oracle_image is Some(_) {
      @fs.mkdir(directory + "/oracle")
      transfer_create_files(directory + "/oracle", initial)
    }
    assert_eq(
      transfer_file_state(directory, oracle_child=oracle_image is Some(_)),
      transfer_expected_files(Json(initial)),
    )
    let phases = transfer_array(spec["phases"])
    assert_true(phases.length() > 0 && phases.length() <= 2)
    let observed : Array[Json] = []
    let expected : Array[Json] = []
    for phase_index, phase_value in phases {
      let phase = transfer_object(phase_value)
      let exchanges = transfer_array(phase["exchanges"])
      let frozen = transfer_phase_expected(phase)
      expected.push(frozen)
      let pending = Ref(0)
      let current_work = Ref(directory)
      let requests : Array[(String, String, String)] = []
      let tunnels : Array[String] = []
      let responses : Array[Json] = []
      let before_files : Array[Json] = []
      let checks : Array[Json] = []
      let observer_errors : Array[String] = []
      let candidate_requests : Array[(String, String, String)] = []
      let candidate_tunnels : Array[String] = []
      let candidate_responses : Array[Json] = []
      let candidate_before : Array[Json] = []
      let candidate_checks : Array[Json] = []
      let candidate_files = Ref(Json::null())
      let oracle_files = Ref(Json::null())
      let returned = Ref(false)
      defer @async.protect_from_cancel(() => {
        @fs.write_file(
          evidence + "/phase-" + phase_index.to_string() + ".wire.json",
          Json({
            "candidate": @json.to_json(candidate_requests),
            "oracle": @json.to_json(requests),
            "candidate_connect": Json(candidate_tunnels),
            "oracle_connect": Json(tunnels),
            "candidate_responses": Json(candidate_responses),
            "oracle_responses": Json(responses),
            "candidate_files_before_response": Json(candidate_before),
            "oracle_files_before_response": Json(before_files),
            "candidate_file_checks": Json(candidate_checks),
            "oracle_file_checks": Json(checks),
            "candidate_files_after": candidate_files.val,
            "oracle_files_after": oracle_files.val,
            "candidate_returned": Json(returned.val),
            "observer_quiesced": Json(pending.val == 0),
            "observer_errors": Json(observer_errors),
          }).stringify(indent=2) +
          "\n",
        )
      })
      @async.with_task_group(group => {
        let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
        group.add_defer(() => server.close())
        group.spawn_bg(no_wait=true, () => {
          server.run_forever((connection, _) => {
            let request_work = current_work.val
            let candidate = request_work == directory
            let requests = if candidate { candidate_requests } else { requests }
            let tunnels = if candidate { candidate_tunnels } else { tunnels }
            let responses = if candidate {
              candidate_responses
            } else {
              responses
            }
            let before_files = if candidate {
              candidate_before
            } else {
              before_files
            }
            let checks = if candidate { candidate_checks } else { checks }
            pending.val += 1
            defer {
              pending.val -= 1
            }
            let outcome = try {
              let mut request = suffix_request(connection)
              if request.0.has_prefix("CONNECT ") {
                tunnels.push(request.2)
                connection.write("HTTP/1.1 200 Connection Established\r\n\r\n")
                request = suffix_request(connection)
              }
              let index = requests.length()
              requests.push(request)
              guard exchanges.get(index) is Some(value) else {
                fail("request exceeds frozen transfer exchanges")
              }
              let exchange = transfer_object(value)
              before_files.push(
                transfer_file_state(
                  request_work,
                  oracle_child=candidate && oracle_image is Some(_),
                ),
              )
              if exchange.get("mutation") is Some(value) {
                let mutation = transfer_object(value)
                assert_eq(mutation["at"], Json("before-response"))
                let name = transfer_filename(mutation["name"])
                @fs.write_file(
                  request_work + "/" + name,
                  @harness.decode_hex(transfer_string(mutation["hex"]), name),
                )
              }
              if exchange.get("observed_file_before") is Some(value) {
                let check = transfer_object(value)
                assert_eq(check["at"], Json("before-response"))
                let name = transfer_filename(check["name"])
                let path = request_work + "/" + name
                let actual : Map[String, Json] = {
                  "name": Json(name),
                  "exists": Json(@fs.exists(path)),
                  "at": "before-response",
                }
                if @fs.exists(path) {
                  actual["hex"] = Json(
                    @crypto.bytes_to_hex_string(@fs.read_file(path).binary()),
                  )
                }
                checks.push(Json(actual))
              }
              if exchange.get("delay_ms") is Some(value) {
                let delay : Int32 = @json.from_json(value)
                assert_true(delay >= 0 && delay <= 2000)
                @async.sleep(delay)
              }
              let bytes = @harness.decode_hex(
                transfer_string(exchange["response_hex"]),
                label,
              )
              connection.write(bytes)
              responses.push({
                "index": Json(index),
                "hex": Json(@crypto.bytes_to_hex_string(bytes)),
              })
              Ok(())
            } catch {
              error => Err(error)
            }
            match outcome {
              Ok(_) => ()
              Err(error) => {
                observer_errors.push(error.to_string())
                raise error
              }
            }
          })
        })
        let observing : Executor = {
          proof: executor.proof,
          invoke: invocation => {
            let execution = (executor.invoke)(invocation)
            returned.val = true
            try {
              @async.with_timeout(5000, () => {
                while pending.val > 0 {
                  @async.sleep(5)
                }
              })
              candidate_files.val = transfer_file_state(
                directory,
                oracle_child=oracle_image is Some(_),
              )
            } catch {
              error => observer_errors.push(error.to_string())
            }
            current_work.val = directory + "/oracle"
            execution
          },
        }
        let original : Array[String] = @json.from_json(phase["oracle_args"])
        assert_eq(original[0], "-q")
        let args = original[1:].to_owned()
        let proxy = "http://127.0.0.1:" + server.addr.port().to_string()
        let environment = {
          "LC_ALL": transfer_string(spec["locale"]),
          "LC_CTYPE": transfer_string(spec["lc_ctype"]),
          "LANG": transfer_string(spec["lang"]),
          "TZ": transfer_string(spec["tz"]),
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
        }
        @fs.write_file(
          evidence + "/phase-" + phase_index.to_string() + ".inputs.json",
          Json({
            "args": Json(args),
            "oracle_args": Json(original),
            "environment": Json(environment),
            "stdin_hex": phase["stdin_hex"],
          }).stringify(indent=2) +
          "\n",
        )
        let result = network_request(
          observing,
          directory,
          "curl",
          args,
          evidence_work=evidence,
          stdin=@harness.decode_hex(transfer_string(phase["stdin_hex"]), label),
          environment~,
          oracle_image?,
          oracle_args=original,
          oracle_failures=failures,
        )
        @async.with_timeout(5000, () => {
          while pending.val > 0 {
            @async.sleep(5)
          }
        })
        if oracle_image is Some(_) {
          oracle_files.val = transfer_file_state(directory + "/oracle")
        }
        assert_true(returned.val)
        assert_true(observer_errors.is_empty(), msg=observer_errors.join("\n"))
        let expected_responses = exchanges.mapi((index, value) => {
          (
            {
              "index": Json(index),
              "hex": transfer_object(value)["response_hex"],
            } : Json)
        })
        let expected_checks = exchanges.filter_map(value => {
          transfer_object(value).get("observed_file_before")
        })
        for
          candidate in (if oracle_image is Some(_) {
            [true, false]
          } else {
            [true]
          }) {
          transfer_check_requests(
            if candidate {
              candidate_requests
            } else {
              requests
            },
            if candidate {
              candidate_tunnels
            } else {
              tunnels
            },
            exchanges,
            candidate~,
            proxy_authority="127.0.0.1:" + server.addr.port().to_string(),
          )
          assert_eq(
            if candidate {
              candidate_responses
            } else {
              responses
            },
            expected_responses,
          )
          assert_eq(
            if candidate {
              candidate_checks
            } else {
              checks
            },
            expected_checks,
          )
          let actual_before = if candidate {
            candidate_before
          } else {
            before_files
          }
          assert_eq(actual_before.length(), exchanges.length())
          for index, exchange in exchanges {
            if transfer_object(exchange).get("files_before_response")
              is Some(files) {
              assert_eq(actual_before[index], transfer_expected_files(files))
            }
          }
          assert_eq(
            if candidate {
              candidate_files.val
            } else {
              oracle_files.val
            },
            transfer_object(frozen)["files_after"],
          )
        }
        let actual : Json = {
          "status": Json(result.status),
          "stdout_hex": Json(@crypto.bytes_to_hex_string(result.stdout)),
          "stderr_hex": Json(@crypto.bytes_to_hex_string(result.stderr)),
          "cookies": Json(candidate_requests.map(request => request.1)),
          "files_after": candidate_files.val,
        }
        observed.push(actual)
        assert_eq(actual, frozen, msg=label)
      })
    }
    if oracle_image is None && executor.proof is Some(proof) {
      proof.observe_equal(
        corpus + "/" + label,
        "curl",
        Json(observed),
        Json(expected),
      )
    }
  }
  assert_eq(seen.length(), count)
  guard failures.is_empty() else { fail(failures.join("\n")) }
}
