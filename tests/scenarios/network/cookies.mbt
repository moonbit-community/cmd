///|
priv struct CookieSecurityCase {
  label : String
  host : String
  source : String
  target : String
  fields : Array[String]
  input : String
  cookie : String
  rows : Array[String]
}

///|
fn cookie_rows(text : String, sorted~ : Bool = true) -> Array[String] {
  let rows = text
    .split("\n")
    .filter_map(line => {
      let line = line.trim_end(chars="\r").to_owned()
      if line == "" || (line.has_prefix("#") && !line.has_prefix("#HttpOnly_")) {
        None
      } else {
        Some(line)
      }
    })
    .to_array()
  if sorted {
    rows.sort_by((left, right) => left.lexical_compare(right))
  }
  rows
}

///|
async fn network_cookie_security_scenario(
  executor : Executor,
  work : String,
  failures : Array[String],
  oracle_image? : String,
) -> Unit {
  let cases : Array[CookieSecurityCase] = []
  for
    (label, field, accepted) in [
      ("secure-missing-flag", "__Secure-a=v; Path=/", false),
      ("secure-loopback", "__Secure-a=v; Secure; Path=/", true),
      ("host-root", "__Host-a=v; Secure; Path=/", true),
      ("host-missing-flag", "__Host-a=v; Path=/", false),
      (
        "host-exact-ip-domain", "__Host-a=v; Secure; Domain=127.0.0.1; Path=/", true,
      ),
      ("host-nested-path", "__Host-a=v; Secure; Path=/private", false),
      ("host-default-root", "__Host-a=v; Secure", true),
      ("host-relative-path", "__Host-a=v; Secure; Path=relative", true),
      ("host-quoted-path", "__Host-a=v; Secure; Path=\"/\"", true),
      ("host-double-slash-path", "__Host-a=v; Secure; Path=//", true),
      ("host-path-value-ows", "__Host-a=bad; Secure; Path= /nested", false),
      ("host-path-name-ows", "__Host-a=bad; Secure; Path =/nested", false),
      (
        "host-path-quoted-ows", "__Host-a=bad; Secure; Path= \t\"/nested\"", false,
      ),
      ("host-path-tab-ows", "__Host-a=bad; Secure; Path\t=\t/nested", false),
      (
        "host-domain-ows", "__Host-a=v; Secure; Domain = 127.0.0.1 ; Path = /", true,
      ),
      (
        "host-empty-domain", "__Host-a=v; Secure; Domain=127.0.0.1; Domain=; Path=/",
        true,
      ),
      ("host-pair-ows", "__Host-a \t= v \t; Secure; Path = /", true),
      ("host-empty-maxage", "__Host-a=v; Secure; Path=/; Max-Age=", true),
      ("secure-assigned-flag", "__Secure-a=v; Secure = true; Path=/", false),
    ] {
    let name = if label.has_prefix("secure-") {
      "__Secure-a"
    } else {
      "__Host-a"
    }
    cases.push({
      label,
      host: "127.0.0.1",
      source: "/set",
      target: "/inspect",
      fields: [field],
      input: "",
      cookie: if accepted {
        name + "=v"
      } else {
        ""
      },
      rows: if accepted {
        ["127.0.0.1\tFALSE\t/\tTRUE\t0\t" + name + "\tv"]
      } else {
        []
      },
    })
  }
  cases.push({
    label: "host-default-nested",
    host: "127.0.0.1",
    source: "/nested/set",
    target: "/nested/inspect",
    fields: ["__Host-a=v; Secure"],
    input: "",
    cookie: "",
    rows: [],
  })
  cases.push({
    label: "prefix-case-sensitive",
    host: "127.0.0.1",
    source: "/set",
    target: "/inspect",
    fields: ["__secure-a=v; Path=/"],
    input: "",
    cookie: "__secure-a=v",
    rows: ["127.0.0.1\tFALSE\t/\tFALSE\t0\t__secure-a\tv"],
  })
  for
    (label, path) in [
      ("double-slash", "//"),
      ("quoted", "\"/\""),
      ("relative", "relative"),
    ] {
    cases.push({
      label: "jar-path-" + label,
      host: "127.0.0.1",
      source: "/set",
      target: "/inspect",
      fields: [],
      input: "127.0.0.1\tFALSE\t" + path + "\tTRUE\t0\t__Host-a\tv\n",
      cookie: "__Host-a=v",
      rows: ["127.0.0.1\tFALSE\t/\tTRUE\t0\t__Host-a\tv"],
    })
  }
  cases.push({
    label: "jar-reject-invalid-prefixes",
    host: "127.0.0.1",
    source: "/set",
    target: "/inspect",
    fields: [],
    input: "127.0.0.1\tFALSE\t/\tFALSE\t0\t__Secure-a\tbad\n" +
    "127.0.0.1\tTRUE\t/\tTRUE\t0\t__Host-b\tbad\n" +
    "127.0.0.1\tFALSE\t/private\tTRUE\t0\t__Host-c\tbad\n" +
    "127.0.0.1\tFALSE\t/\tTRUE\t0\t__Host-d\tgood\n",
    cookie: "__Host-d=good",
    rows: ["127.0.0.1\tFALSE\t/\tTRUE\t0\t__Host-d\tgood"],
  })
  cases.push({
    label: "invalid-prefix-preserves-loaded-value",
    host: "127.0.0.1",
    source: "/set",
    target: "/inspect",
    fields: ["__Host-a=bad; Path=/"],
    input: "127.0.0.1\tFALSE\t/\tTRUE\t0\t__Host-a\tgood\n",
    cookie: "__Host-a=good",
    rows: ["127.0.0.1\tFALSE\t/\tTRUE\t0\t__Host-a\tgood"],
  })
  // A trailing-dot localhost is reachable locally but is not curl's exact
  // localhost secure-context exception. No TLS or external DNS is required.
  cases.push({
    label: "insecure-origin-rejects-secure",
    host: "localhost.",
    source: "/set",
    target: "/inspect",
    fields: ["sid=v; Secure; Path=/"],
    input: "",
    cookie: "",
    rows: [],
  })
  for
    (label, path, field, allowed) in [
      ("same-path", "/login", "sid=plain; Path=/login", false),
      ("child-path", "/login", "sid=plain; Path=/login/en", false),
      ("component-prefix", "/login", "sid=plain; Path=/loginhelper", false),
      ("first-component", "/login/en", "sid=plain; Path=/login/fr", false),
      ("different-path", "/login", "sid=plain; Path=/other", true),
      ("deletion", "/login", "sid=; Path=/login; Max-Age=0", false),
      ("pair-name-ows", "/", "sid = plain; Path = /", false),
    ] {
    let old_row = "localhost.\tFALSE\t" + path + "\tTRUE\t0\tsid\tsecure"
    cases.push({
      label: "insecure-overlay-" + label,
      host: "localhost.",
      source: "/set",
      target: "/other",
      fields: [field],
      input: old_row + "\n",
      cookie: if allowed {
        "sid=plain"
      } else {
        ""
      },
      rows: [
        old_row,
        ..if allowed {
          ["localhost.\tFALSE\t/other\tFALSE\t0\tsid\tplain"]
        } else {
          []
        },
      ],
    })
  }
  cases.push({
    label: "secure-loopback-allows-replacement",
    host: "127.0.0.1",
    source: "/set",
    target: "/inspect",
    fields: ["sid=plain; Path=/"],
    input: "127.0.0.1\tFALSE\t/\tTRUE\t0\tsid\tsecure\n",
    cookie: "sid=plain",
    rows: ["127.0.0.1\tFALSE\t/\tFALSE\t0\tsid\tplain"],
  })
  cases.push({
    label: "jar-stdin",
    host: "127.0.0.1",
    source: "/set",
    target: "/inspect",
    fields: [],
    input: "127.0.0.1\tFALSE\t//\tTRUE\t0\t__Host-a\tv\n",
    cookie: "__Host-a=v",
    rows: ["127.0.0.1\tFALSE\t/\tTRUE\t0\t__Host-a\tv"],
  })
  cases.push({
    label: "jar-ambiguous-path-rejected",
    host: "127.0.0.1",
    source: "/set",
    target: "/inspect",
    fields: [],
    input: "127.0.0.1\tFALSE\t\tTRUE\t0\t__Host-a\tv\n127.0.0.1\tFALSE\tTRUE\tTRUE\t0\t__Host-b\tv\n",
    cookie: "",
    rows: [],
  })
  let identity_input = "localhost\tFALSE\t/\tFALSE\t0\tsid\thost\n.localhost\tTRUE\t/\tFALSE\t0\tsid\tdomain\n"
  for
    (label, fields, cookie, rows) in [
      (
        "jar-scope-identity",
        [],
        "sid=domain; sid=host",
        [
          ".localhost\tTRUE\t/\tFALSE\t0\tsid\tdomain", "localhost\tFALSE\t/\tFALSE\t0\tsid\thost",
        ],
      ),
      (
        "host-deletion-preserves-domain",
        ["sid=; Path=/; Max-Age=0"],
        "sid=domain",
        [".localhost\tTRUE\t/\tFALSE\t0\tsid\tdomain"],
      ),
    ] {
    cases.push({
      label,
      host: "localhost",
      source: "/set",
      target: "/inspect",
      fields,
      input: identity_input,
      cookie,
      rows,
    })
  }
  @async.with_task_group(group => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let fields : Ref[Array[String]] = Ref([])
    let target = Ref("/inspect")
    let requests : Array[String] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((connection, _) => {
        guard connection.read_until("\r\n") is Some(start) else {
          fail("missing request line")
        }
        let wire = StringBuilder()
        wire.write_string(start + "\r\n")
        let cookies : Array[String] = []
        while connection.read_until("\r\n") is Some(line) && line != "" {
          wire.write_string(line + "\r\n")
          if line.to_lower().has_prefix("cookie:") {
            cookies.push(line[7:].trim_start(chars=" \t").to_owned())
          }
        }
        requests.push(wire.to_string())
        if start.contains("/set ") {
          connection.write(
            "HTTP/1.1 302 Found\r\nLocation: " +
            target.val +
            "\r\n" +
            fields.val.map(field => "Set-Cookie: " + field + "\r\n").join("") +
            "Content-Length: 0\r\n\r\n",
          )
        } else {
          let body = "cookie=" + cookies.join("; ") + "\n"
          connection.write(
            "HTTP/1.1 200 OK\r\nContent-Length: \{body.length()}\r\n\r\n" + body,
          )
        }
      })
    })
    for fixture in cases {
      let directory = work + "/cookie-security-" + fixture.label
      @fs.mkdir(directory)
      let jar = "# Netscape HTTP Cookie File\n" + fixture.input
      @fs.write_file(directory + "/input.jar", jar)
      if oracle_image is Some(_) {
        @fs.mkdir(directory + "/oracle")
        @fs.write_file(directory + "/oracle/input.jar", jar)
      }
      fields.val = fixture.fields
      target.val = fixture.target
      requests.clear()
      let candidate : Array[String] = []
      defer @async.protect_from_cancel(() => {
        @fs.write_file(
          directory + "/requests.wire.json",
          @json.to_json({ "candidate": candidate, "oracle": requests }).stringify(
            indent=2,
          ),
        )
      })
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
        directory,
        "curl",
        [
          "-sSL",
          "-b",
          if fixture.label == "jar-stdin" {
            "-"
          } else {
            directory + "/input.jar"
          },
          "-c",
          directory + "/saved.jar",
          "http://" + fixture.host + ":\{server.addr.port()}" + fixture.source,
        ],
        stdin=if fixture.label == "jar-stdin" { @utf8.encode(jar) } else { b"" },
        oracle_image?,
        oracle_failures=failures,
      )
      check_network_response(result, "cookie=" + fixture.cookie + "\n")
      assert_eq(candidate.length(), 2, msg=fixture.label)
      assert_eq(
        requests.length(),
        if oracle_image is Some(_) {
          2
        } else {
          0
        },
        msg=fixture.label,
      )
      let rows = cookie_rows(@fs.read_file(directory + "/saved.jar").text())
      let expected = fixture.rows.copy()
      expected.sort_by((left, right) => left.lexical_compare(right))
      assert_eq(rows, expected, msg=fixture.label)
      assert_eq(@fs.read_file(directory + "/input.jar").text(), jar)
      if oracle_image is Some(_) {
        assert_eq(
          cookie_rows(@fs.read_file(directory + "/oracle/saved.jar").text()),
          expected,
          msg="oracle " + fixture.label,
        )
        assert_eq(@fs.read_file(directory + "/oracle/input.jar").text(), jar)
      }
      if oracle_image is None {
        @harness.assert_observation(
          "cookie-security/" + fixture.label,
          "curl",
          {
            "status": result.status,
            "stdout": @harness.scenario_text(result.stdout),
            "stderr": @harness.scenario_text(result.stderr),
            "requests": candidate.length(),
            "rows": rows,
          },
          {
            "status": 0,
            "stdout": "cookie=" + fixture.cookie + "\n",
            "stderr": "",
            "requests": 2,
            "rows": expected,
          },
        )
      }
    }
    for
      (label, field, expected) in [
        (
          "prefix-is-ordinary", "__Host-a=plain; Path=/", "cookie=__Host-a=plain\n",
        ),
        (
          "secure-remains-https-only", "__Secure-a=v; Secure; Path=/", "cookie=\n",
        ),
      ] {
      fields.val = [field]
      target.val = "/inspect"
      requests.clear()
      let candidate : Array[String] = []
      defer @async.protect_from_cancel(() => {
        @fs.write_file(
          work + "/wget-" + label + ".wire.json",
          @json.to_json({ "candidate": candidate, "oracle": requests }).stringify(
            indent=2,
          ),
        )
      })
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
        "wget",
        ["-qO-", "-t1", "http://127.0.0.1:\{server.addr.port()}/set"],
        oracle_image?,
        oracle_failures=failures,
      )
      check_network_response(result, expected)
      assert_eq(candidate.length(), 2)
      assert_eq(requests.length(), if oracle_image is Some(_) { 2 } else { 0 })
      if oracle_image is None {
        @harness.assert_observation(
          "cookie-security/wget-" + label,
          "wget",
          {
            "status": result.status,
            "stdout": @harness.scenario_text(result.stdout),
            "stderr": @harness.scenario_text(result.stderr),
            "requests": candidate.length(),
          },
          { "status": 0, "stdout": expected, "stderr": "", "requests": 2 },
        )
      }
    }
  })
}
