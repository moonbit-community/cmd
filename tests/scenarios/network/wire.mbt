///|
async fn wire_scenario_call(
  executor : Executor,
  work : String,
  command : String,
  label : String,
  url : String,
  paths : Array[String],
  cookies : Array[Array[String]],
  output : String,
  requests : Array[@harness.TransferFixtureRequest],
  wires : Array[Bytes],
  failures : Array[String],
  cookie_engine? : Bool,
  oracle_image? : String,
) -> Unit {
  let input_jar = "# Netscape HTTP Cookie File\n"
  let use_input_jar = command == "curl" && cookie_engine == Some(true)
  let args = if command == "curl" {
    [
      "-sS",
      "-L",
      "--retry",
      "0",
      "-o",
      "output.bin",
      ..if use_input_jar {
        ["-b", "input.cookies"]
      } else {
        []
      },
      url,
    ]
  } else {
    [
      "-q",
      "-t",
      "1",
      "-O",
      "output.bin",
      ..if cookie_engine == Some(false) {
        ["--no-cookies"]
      } else {
        []
      },
      url,
    ]
  }
  transfer_scenario_call(
    executor,
    work,
    command,
    label,
    args,
    "",
    paths.map(_ => None),
    requests,
    failures,
    initial_files=[
      ("output.bin", "preserve"),
      ..if use_input_jar {
        [("input.cookies", input_jar)]
      } else {
        []
      },
    ],
    files=[
      ("output.bin", Some(output)),
      ..if use_input_jar {
        [("input.cookies", Some(input_jar))]
      } else {
        []
      },
    ],
    bodies=paths.map(_ => b""),
    paths~,
    cookies~,
    request_wires=wires,
    expected_stderr=if command == "curl" && paths.is_empty() {
      "curl: (3) URL rejected: Malformed input to a URL function\n"
    } else {
      ""
    },
    oracle_image?,
  )
}

///|
async fn network_wire_scenario(
  executor : Executor,
  work : String,
  failures : Array[String],
  oracle_image? : String,
) -> Unit {
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[@harness.TransferFixtureRequest] = []
    let wires : Array[Bytes] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((connection, _) => {
        @harness.serve_wire_fixture(connection, requests, wires)
      })
    })
    let base = "http://127.0.0.1:\{server.addr.port()}"
    @fs.write_file(work + "/../wire-origin.txt", base)
    for
      (label, value, encoded) in [
        ("space", " ", "%20"),
        ("tab", "\t", "%09"),
        ("cr", "\r", "%0D"),
        ("lf", "\n", "%0A"),
        ("del", "\u007f", "%7F"),
      ] {
      for part in ["path", "query"] {
        for (form, text) in [("raw", value), ("escaped", encoded)] {
          let target = if part == "path" {
            "/wire-url/probe-a" + text + "b"
          } else {
            "/wire-url/probe?q=a" + text + "b"
          }
          let encoded_target = if part == "path" {
            "/wire-url/probe-a" + encoded + "b"
          } else {
            "/wire-url/probe?q=a" + encoded + "b"
          }
          for command in ["curl", "wget"] {
            let rejected = command == "curl" && form == "raw"
            let paths = if rejected { [] } else { [encoded_target] }
            wire_scenario_call(
              executor,
              work,
              command,
              "wire-url-\{part}-\{label}-\{form}",
              base + target,
              paths,
              paths.map(_ => []),
              if rejected {
                "preserve"
              } else {
                "ok"
              },
              requests,
              wires,
              failures,
              oracle_image?,
            )
          }
        }
      }
    }
    for part in ["path", "query"] {
      let target = if part == "path" {
        "/wire-url/probe-a%0D%0Ab"
      } else {
        "/wire-url/probe?q=a%0D%0Ab"
      }
      for command in ["curl", "wget"] {
        wire_scenario_call(
          executor,
          work,
          command,
          "wire-url-\{part}-escaped-crlf",
          base + target,
          [target],
          [[]],
          "ok",
          requests,
          wires,
          failures,
          oracle_image?,
        )
      }
    }
    for
      (label, encoded) in [
        ("space", "%20"),
        ("tab", "%09"),
        ("escaped-crlf", "%0D%0A"),
      ] {
      for part in ["path", "query"] {
        let start = "/wire-redirect-\{part}-\{label}"
        for command in ["curl", "wget"] {
          let encoded = if command == "curl" &&
            part == "query" &&
            label == "space" {
            "+"
          } else {
            encoded
          }
          let target = if part == "path" {
            "/wire-url/next-a" + encoded + "b"
          } else {
            "/wire-url/next?q=a" + encoded + "b"
          }
          wire_scenario_call(
            executor,
            work,
            command,
            "wire-redirect-\{part}-\{label}",
            base + start,
            [start, target],
            [[], []],
            "ok",
            requests,
            wires,
            failures,
            oracle_image?,
          )
        }
      }
    }
    for
      label in [
        "no-pair", "invalid-maxage", "seeded-invalid-maxage", "duplicate-valid-invalid",
        "duplicate-invalid-valid",
      ] {
      let start = "/wire-cookie-" + label
      for command in ["curl", "wget"] {
        let last_cookie = if command == "curl" {
          if label == "duplicate-invalid-valid" {
            "valid=ok; sid=good"
          } else {
            "valid=ok"
          }
        } else {
          match label {
            "seeded-invalid-maxage" => "sid=old; valid=ok"
            "duplicate-valid-invalid" | "duplicate-invalid-valid" =>
              "sid=good; valid=ok"
            _ => "valid=ok"
          }
        }
        let paths = if label == "seeded-invalid-maxage" {
          [start, start + "/hop-1", start + "/hop-2"]
        } else {
          [start, start + "/hop-1"]
        }
        let cookies = if label == "seeded-invalid-maxage" {
          [[], ["sid=old"], [last_cookie]]
        } else {
          [[], [last_cookie]]
        }
        wire_scenario_call(
          executor,
          work,
          command,
          "wire-cookie-" + label,
          base + start,
          paths,
          cookies,
          "Cookie: " + last_cookie,
          requests,
          wires,
          failures,
          cookie_engine=true,
          oracle_image?,
        )
        if label == "no-pair" || label == "invalid-maxage" {
          wire_scenario_call(
            executor,
            work,
            command,
            "wire-cookie-" + label + "-disabled",
            base + start,
            paths,
            paths.map(_ => []),
            "",
            requests,
            wires,
            failures,
            cookie_engine=false,
            oracle_image?,
          )
        }
      }
    }
    for
      (label, curl_cookies, wget_cookies) in [
        (
          "order-name-length",
          [[], ["longname=2; bb=3; a=1"]],
          [[], ["a=1; bb=3; longname=2"]],
        ),
        (
          "order-equal-length",
          [[], ["cc=3; bb=2; aa=1"]],
          [[], ["aa=1; bb=2; cc=3"]],
        ),
        (
          "order-equal-reverse",
          [[], ["aa=1; bb=2; cc=3"]],
          [[], ["aa=1; bb=2; cc=3"]],
        ),
        (
          "order-replace",
          [[], ["bb=2; aa=1"], ["bb=2; aa=3"]],
          [[], ["aa=1; bb=2"], ["aa=3; bb=2"]],
        ),
        (
          "order-invalid-valid-cross",
          [[], ["sid=old"], [], ["sid=new"]],
          [[], ["sid=old"], ["sid=old"], ["sid=new"]],
        ),
        (
          "maxage-overflow-one",
          [[], ["sid=old"], ["valid=ok; sid=new"]],
          [[], ["sid=old"], ["valid=ok"]],
        ),
        (
          "maxage-overflow-many",
          [[], ["sid=old"], ["valid=ok; sid=new"]],
          [[], ["sid=old"], ["valid=ok"]],
        ),
      ] {
      let start = "/wire-cookie-" + label
      for command in ["curl", "wget"] {
        let cookies = if command == "curl" {
          curl_cookies
        } else {
          wget_cookies
        }
        let paths = Array::makei(cookies.length(), index => {
          if index == 0 {
            start
          } else {
            start + "/hop-\{index}"
          }
        })
        let output = cookies[cookies.length() - 1]
          .map(value => "Cookie: " + value)
          .join("\n")
        wire_scenario_call(
          executor,
          work,
          command,
          "wire-cookie-" + label,
          base + start,
          paths,
          cookies,
          output,
          requests,
          wires,
          failures,
          cookie_engine=true,
          oracle_image?,
        )
      }
    }
  })
}
