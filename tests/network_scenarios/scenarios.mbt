///|
priv struct TransferFileObservation {
  mut work : String?
  snapshots : Array[Array[(String, Bool, Bytes)]]
}

///|
async fn TransferFileObservation::capture(
  self : TransferFileObservation,
) -> Unit {
  guard self.work is Some(work) else { return }
  let names = @fs.readdir(work).filter(name => name != "oracle")
  names.sort()
  let snapshot : Array[(String, Bool, Bytes)] = []
  for name in names {
    let path = work + "/" + name
    let regular = @fs.kind(path, follow_symlink=false) == @fs.Regular
    snapshot.push(
      (name, regular, if regular { @fs.read_file(path).binary() } else { b"" }),
    )
  }
  self.snapshots.push(snapshot)
}

///|
async fn network_request(
  executor : Executor,
  work : String,
  command : String,
  args : Array[String],
  stdin~ : Bytes = b"",
  oracle_image? : String,
  oracle_failures? : Array[String],
  transfer_requests? : Array[@testkit.TransferFixtureRequest],
  request_wires? : Array[Bytes],
  expected_paths? : Array[String],
  expected_cookies? : Array[Array[String]],
  expected_ranges? : Array[String?],
  expected_methods? : Array[String],
  expected_bodies? : Array[Bytes],
  expected_files? : Array[(String, String?)],
  transfer_files? : TransferFileObservation,
  expected_files_before_response? : Array[Array[(String, String)]],
) -> @testkit.RunResult {
  if transfer_files is Some(observation) {
    observation.work = Some(work)
    observation.snapshots.clear()
  }
  defer (if transfer_files is Some(observation) { observation.work = None })
  if transfer_requests is Some(requests) {
    requests.clear()
  }
  if request_wires is Some(wires) {
    wires.clear()
  }
  let execution = (executor.invoke)({
    command,
    args,
    stdin,
    cwd: work,
    environment: { "NO_PROXY": "*", "no_proxy": "*", "LC_ALL": "C" },
  })
  let result = execution.run.output
  // Capture product effects before adding evidence files to this directory.
  let output_names = if expected_files is Some(_) {
    let names = @fs.readdir(work)
    let names = if oracle_image is Some(_) {
      names.filter(name => name != "oracle")
    } else {
      names
    }
    names.sort()
    Some(names)
  } else {
    None
  }
  let prefix = work + "/call-\{@fs.readdir(work).length()}"
  @fs.write_file(prefix + ".stdout.bin", result.stdout)
  @fs.write_file(prefix + ".stderr.bin", result.stderr)
  @fs.write_file(prefix + ".status.txt", result.status.to_string())
  if !stdin.is_empty() {
    @fs.write_file(prefix + ".stdin.bin", stdin)
  }
  let request : Json = if execution.retain_identity {
    {
      "command": Json(command),
      "args": Json(args),
      "source_version": Json(execution.source_version),
    }
  } else {
    { "command": Json(command), "args": Json(args) }
  }
  @fs.write_file(prefix + ".request.json", request.stringify(indent=2))
  if execution.retain_identity {
    @fs.write_file(
      prefix + ".execution.json",
      @testkit.canonical_json({
        "command": Json(command),
        "source_version": Json(execution.source_version),
        "program": Json(execution.program),
        "args": Json(execution.args),
        "timed_out": Json(execution.run.timed_out),
        "cleanup_error": @json.to_json(execution.run.cleanup_error),
        "infrastructure_error": @json.to_json(execution.infrastructure_error),
      }),
    )
  }
  if execution.run.timed_out {
    fail("candidate infrastructure deadline expired; streams are partial")
  }
  if execution.run.cleanup_error is Some(error) {
    fail("candidate infrastructure cleanup failed: " + error)
  }
  if execution.infrastructure_error is Some(error) {
    fail("candidate infrastructure failure: " + error)
  }
  let actual_requests = transfer_requests.map(requests => requests.copy())
  if request_wires is Some(wires) {
    for index, wire in wires {
      @fs.write_file(prefix + ".request-wire-\{index}.bin", wire)
    }
  }
  let actual_files_before_response = transfer_files.map(observation => {
    observation.snapshots.copy()
  })
  if actual_files_before_response is Some(snapshots) {
    @fs.write_file(
      prefix + ".files-before-response.json",
      @json.to_json(snapshots).stringify(indent=2),
    )
  }
  if actual_requests is Some(requests) {
    @fs.write_file(
      prefix + ".requests.json",
      @json.to_json(requests).stringify(indent=2),
    )
  }
  if output_names is Some(names) {
    @fs.write_file(
      prefix + ".files.json",
      @json.to_json(names).stringify(indent=2),
    )
  }
  if oracle_image is Some(image) {
    let docker_user = @testkit.docker_user()
    let oracle_work = work + "/oracle"
    if !@fs.exists(oracle_work) {
      @fs.mkdir(oracle_work)
    }
    let oracle_args = args.map(arg => arg.replace_all(old=work, new=oracle_work))
    if transfer_requests is Some(requests) {
      requests.clear()
    }
    if request_wires is Some(wires) {
      wires.clear()
    }
    if transfer_files is Some(observation) {
      observation.work = Some(oracle_work)
      observation.snapshots.clear()
    }
    let run = @testkit.run_oracle_with_deadline(
      "docker",
      [
        "run",
        "--user",
        docker_user,
        "--rm",
        "-i",
        "--network",
        "host",
        "-v",
        oracle_work + ":" + oracle_work + ":rw",
        "-w",
        oracle_work,
        "-e",
        "LC_ALL=C",
        "-e",
        "NO_PROXY=*",
        "-e",
        "no_proxy=*",
        image,
        command,
        ..oracle_args,
      ],
      120000,
      evidence_dir=prefix + ".oracle.lifecycle",
      stdin~,
    )
    @fs.write_file(prefix + ".oracle.stdout.bin", run.output.stdout)
    @fs.write_file(prefix + ".oracle.stderr.bin", run.output.stderr)
    @fs.write_file(prefix + ".oracle.status.txt", run.output.status.to_string())
    @fs.write_file(
      prefix + ".oracle.execution.json",
      @testkit.canonical_json({
        "timed_out": Json(run.timed_out),
        "cleanup_error": @json.to_json(run.cleanup_error),
      }),
    )
    let oracle_requests = transfer_requests.map(requests => requests.copy())
    if request_wires is Some(wires) {
      for index, wire in wires {
        @fs.write_file(prefix + ".oracle.request-wire-\{index}.bin", wire)
      }
    }
    let oracle_files_before_response = transfer_files.map(observation => {
      observation.snapshots.copy()
    })
    if oracle_files_before_response is Some(snapshots) {
      @fs.write_file(
        prefix + ".oracle.files-before-response.json",
        @json.to_json(snapshots).stringify(indent=2),
      )
    }
    if oracle_requests is Some(requests) {
      @fs.write_file(
        prefix + ".oracle.requests.json",
        @json.to_json(requests).stringify(indent=2),
      )
    }
    let oracle_output_names = if expected_files is Some(_) {
      let names = @fs.readdir(oracle_work)
      names.sort()
      @fs.write_file(
        prefix + ".oracle.files.json",
        @json.to_json(names).stringify(indent=2),
      )
      Some(names)
    } else {
      None
    }
    if run.timed_out ||
      run.cleanup_error is Some(_) ||
      [125, 126, 127].contains(run.output.status) {
      fail(
        "oracle infrastructure failure: status " +
        run.output.status.to_string() +
        ", timeout " +
        run.timed_out.to_string(),
      )
    }
    let differences : Array[String] = []
    if result.status != run.output.status {
      differences.push("status \{result.status} != \{run.output.status}")
    }
    if result.stdout != run.output.stdout {
      differences.push("stdout bytes differ")
    }
    if result.stderr != run.output.stderr {
      differences.push("stderr bytes differ")
    }
    if oracle_requests is Some(requests) && actual_requests is Some(actual) {
      if requests != actual {
        differences.push(
          "request methods, raw targets, Cookie fields, Range, or body bytes differ",
        )
      }
    }
    if oracle_files_before_response != actual_files_before_response {
      differences.push("file states before response bytes differ")
    }
    if expected_files is Some(files) &&
      oracle_output_names is Some(oracle_names) {
      check_transfer_files(oracle_work, files, oracle_names) catch {
        error => differences.push("oracle file effect: " + error.to_string())
      }
    }
    if !differences.is_empty() {
      let detail = command +
        " " +
        args.join(" ") +
        ": " +
        differences.join(", ")
      match oracle_failures {
        Some(failures) => failures.push(detail)
        None => fail(detail)
      }
    }
  }
  let contract_failures : Array[String] = []
  if oracle_image is None && executor.proof is Some(proof) {
    let parts = work.split("/").to_array()
    let prefix = "transfer/" + parts[parts.length() - 1].to_owned() + "/"
    if actual_requests is Some(requests) {
      if expected_ranges is Some(expected) {
        proof.observe_equal(
          prefix + "ranges",
          command,
          Json(
            requests.map(request => {
              request.range.map(value => Json(value)).unwrap_or(Json::null())
            }),
          ),
          Json(
            expected.map(range => {
              range.map(value => Json(value)).unwrap_or(Json::null())
            }),
          ),
        )
      }
      if expected_methods is Some(expected) {
        proof.observe_equal(
          prefix + "methods",
          command,
          Json(requests.map(request => request.request_method)),
          Json(expected),
        )
      }
      if expected_paths is Some(expected) {
        proof.observe_equal(
          prefix + "paths",
          command,
          Json(requests.map(request => request.path)),
          Json(expected),
        )
      }
      if expected_cookies is Some(expected) {
        proof.observe_equal(
          prefix + "cookies",
          command,
          Json(requests.map(request => request.cookies)),
          Json(expected),
        )
      }
    }
    if proof.accepts(prefix + "files", command) &&
      expected_files is Some(expected) &&
      output_names is Some(names) {
      let actual_rows : Array[Json] = []
      let expected_rows : Array[Json] = []
      let expected_names : Array[String] = []
      for (name, content) in expected {
        let path = work + "/" + name
        let exists = @fs.exists(path)
        let regular = exists &&
          @fs.kind(path, follow_symlink=false) == @fs.Regular
        actual_rows.push({
          "path": name,
          "exists": exists,
          "regular": if exists {
            Json(regular)
          } else {
            Json::null()
          },
          "content": if regular {
            Json(@fs.read_file(path).text())
          } else {
            Json::null()
          },
        })
        if content is Some(_) {
          expected_names.push(name)
        }
        expected_rows.push({
          "path": name,
          "exists": content is Some(_),
          "regular": if content is Some(_) {
            Json(true)
          } else {
            Json::null()
          },
          "content": content.map(value => Json(value)).unwrap_or(Json::null()),
        })
      }
      expected_names.sort()
      proof.observe_equal(
        prefix + "files",
        command,
        { "names": Json(names), "files": actual_rows },
        { "names": Json(expected_names), "files": expected_rows },
      )
    }
    if proof.accepts(prefix + "before-response", command) &&
      expected_files_before_response is Some(expected) &&
      actual_files_before_response is Some(actual) {
      let normalize = fn(
        files : Array[(String, Bool, Bytes)],
      ) -> Array[Json] raise {
        files.sort_by((a, b) => a.0.lexical_compare(b.0))
        files.map(file => {
          (
            {
              "path": file.0,
              "regular": file.1,
              "content": @testkit.scenario_text(file.2),
            } : Json)
        })
      }
      proof.observe_equal(
        prefix + "before-response",
        command,
        Json(actual.map(normalize)),
        Json(
          expected.map(files => {
            normalize(files.map(file => (file.0, true, @utf8.encode(file.1))))
          }),
        ),
      )
    }
  }
  if actual_requests is Some(requests) && expected_paths is Some(paths) {
    if requests.map(request => request.path) != paths {
      contract_failures.push(
        "candidate raw request-target sequence differs from the scenario contract",
      )
    }
  }
  if actual_requests is Some(requests) && expected_cookies is Some(cookies) {
    if requests.map(request => request.cookies) != cookies {
      contract_failures.push(
        "candidate Cookie field sequence differs from the scenario contract",
      )
    }
  }
  if expected_files_before_response is Some(expected) {
    let expected = expected.map(files => {
      let files = files.map(file => (file.0, true, @utf8.encode(file.1)))
      files.sort_by((left, right) => left.0.compare(right.0))
      files
    })
    if actual_files_before_response != Some(expected) {
      contract_failures.push(
        "candidate file states before response bytes differ from the scenario contract",
      )
    }
  }
  if actual_requests is Some(requests) && expected_bodies is Some(bodies) {
    let actual_bodies = requests.map(request => request.body)
    if actual_bodies != bodies {
      contract_failures.push(
        "candidate request body bytes differ; lengths " +
        repr(actual_bodies.map(body => body.length())) +
        " != " +
        repr(bodies.map(body => body.length())),
      )
    }
  }
  if actual_requests is Some(requests) && expected_methods is Some(methods) {
    let actual_methods = requests.map(request => request.request_method)
    if actual_methods != methods {
      contract_failures.push(
        "candidate method sequence differs: " +
        repr(actual_methods) +
        " != " +
        repr(methods),
      )
    }
  }
  if actual_requests is Some(requests) && expected_ranges is Some(ranges) {
    let actual_ranges = requests.map(request => request.range)
    if actual_ranges != ranges {
      contract_failures.push(
        "candidate Range sequence differs: " +
        repr(actual_ranges) +
        " != " +
        repr(ranges),
      )
    }
  }
  if expected_files is Some(files) && output_names is Some(names) {
    check_transfer_files(work, files, names) catch {
      error =>
        contract_failures.push("candidate file effect: " + error.to_string())
    }
  }
  if !contract_failures.is_empty() {
    match oracle_failures {
      Some(failures) => failures.append(contract_failures)
      None => fail(contract_failures.join("; "))
    }
  }
  result
}

///|
async fn check_transfer_files(
  work : String,
  files : Array[(String, String?)],
  observed_names : Array[String],
) -> Unit {
  let expected_names : Array[String] = []
  for (name, content) in files {
    if content is Some(_) {
      expected_names.push(name)
    }
  }
  expected_names.sort()
  let names = observed_names.copy()
  names.sort()
  let failures : Array[String] = []
  if names != expected_names {
    failures.push(
      "transfer output file set differs: " +
      repr(names) +
      " != " +
      repr(expected_names),
    )
  }
  for (name, content) in files {
    let path = work + "/" + name
    try {
      match content {
        Some(content) => {
          assert_true(@fs.exists(path), msg="missing transfer output: " + name)
          assert_eq(
            @fs.kind(path, follow_symlink=false),
            @fs.Regular,
            msg="transfer output must be a regular file: " + name,
          )
          assert_eq(@fs.read_file(path).binary(), @utf8.encode(content))
        }
        None =>
          assert_false(
            @fs.exists(path),
            msg="unexpected transfer output: " + name,
          )
      }
    } catch {
      error => failures.push(name + ": " + error.to_string())
    }
  }
  guard failures.is_empty() else { fail(failures.join("; ")) }
}

///|
// Exact statuses observed with pinned-oracle-v1 image
// sha256:05e320ad56f11fc1207b0946b414468b90fc0c8bf8e65d32eb2ba48f682589b7.
fn transfer_oracle_status(command : String, label : String) -> Int32 raise {
  if command == "curl" || command == "wget" {
    for part in ["path", "query"] {
      for character in ["space", "tab", "cr", "lf", "del"] {
        for form in ["raw", "escaped"] {
          if label == "wire-url-\{part}-\{character}-\{form}" {
            return if command == "curl" && form == "raw" { 3 } else { 0 }
          }
        }
      }
      if label == "wire-url-\{part}-escaped-crlf" {
        return 0
      }
      for character in ["space", "tab", "escaped-crlf"] {
        if label == "wire-redirect-\{part}-\{character}" {
          return 0
        }
      }
    }
    for
      cookie in [
        "no-pair", "invalid-maxage", "seeded-invalid-maxage", "duplicate-valid-invalid",
        "duplicate-invalid-valid", "no-pair-disabled", "invalid-maxage-disabled",
        "order-name-length", "order-equal-length", "order-equal-reverse", "order-replace",
        "order-invalid-valid-cross", "maxage-overflow-one", "maxage-overflow-many",
      ] {
      if label == "wire-cookie-" + cookie {
        return 0
      }
    }
  }
  match command {
    "curl" =>
      match label {
        "chunk-complete"
        | "close-complete"
        | "empty-complete"
        | "empty-output-complete-new-keep"
        | "empty-output-complete-new-remove"
        | "empty-output-complete-existing-keep"
        | "empty-output-complete-existing-remove"
        | "stdin-retry-256"
        | "stdin-retry-65537"
        | "stdin-retry-show-error-256"
        | "remove-partial-complete-new"
        | "cd-partial-complete-changed"
        | "cd-partial-complete-missing"
        | "cd-partial-complete-changed-remove"
        | "cd-status-200-empty-complete-fail-false"
        | "cd-status-200-empty-complete-fail-true"
        | "cd-status-200-body-complete-fail-false"
        | "cd-status-200-body-complete-fail-true"
        | "cd-status-304-empty-complete-fail-false"
        | "cd-status-304-empty-complete-fail-true"
        | "cd-status-304-empty-incomplete-fail-false"
        | "cd-status-304-empty-incomplete-fail-true"
        | "cd-status-304-body-complete-fail-false"
        | "cd-status-304-body-complete-fail-true"
        | "cd-status-404-empty-complete-fail-false"
        | "cd-status-404-body-complete-fail-false"
        | "cd-status-500-empty-complete-fail-false"
        | "cd-status-500-body-complete-fail-false"
        | "fixed-complete"
        | "fixed-prefix-then-fixed-complete"
        | "head-length"
        | "header-partial-file"
        | "header-partial"
        | "no-content"
        | "not-modified"
        | "output-full-empty"
        | "output-null-complete"
        | "trailer-complete" => 0
        "chunk-data-crlf"
        | "chunk-initial-eof"
        | "chunk-empty"
        | "chunk-payload-file"
        | "chunk-payload"
        | "chunk-terminator-file"
        | "chunk-terminator"
        | "chunk-trailer"
        | "default-retry-does-not-retry-partial"
        | "fixed-complete-then-fixed-prefix"
        | "fixed-empty-file"
        | "fixed-empty"
        | "empty-output-partial-new-keep"
        | "empty-output-partial-new-remove"
        | "empty-output-partial-existing-keep"
        | "empty-output-partial-existing-remove"
        | "fixed-prefix-existing-file"
        | "fixed-prefix-file"
        | "fixed-prefix"
        | "keep-named"
        | "output-full-partial"
        | "output-full-partial-4095"
        | "remove-named"
        | "remove-partial"
        | "retry-all-file"
        | "retry-all-stdout"
        | "retry-partial-empty-file-new"
        | "retry-partial-empty-file-existing"
        | "retry-partial-empty-stdout"
        | "remove-partial-empty-new"
        | "remove-partial-empty-existing"
        | "cd-partial-empty-changed"
        | "cd-partial-empty-changed-remove"
        | "cd-first-empty-new"
        | "cd-status-200-empty-incomplete-fail-false"
        | "cd-status-200-empty-incomplete-fail-true"
        | "cd-status-404-empty-incomplete-fail-false"
        | "cd-status-500-empty-incomplete-fail-false" => 18
        "cd-status-404-empty-complete-fail-true"
        | "cd-status-404-empty-incomplete-fail-true"
        | "cd-status-404-body-complete-fail-true"
        | "cd-status-500-empty-complete-fail-true"
        | "cd-status-500-empty-incomplete-fail-true"
        | "cd-status-500-body-complete-fail-true" => 22
        "cd-first-empty-existing"
        | "output-full-complete"
        | "output-full-complete-4095"
        | "output-full-complete-4096"
        | "output-full-partial-4096" => 23
        "header-empty-existing-file" | "header-empty-file" | "header-empty" =>
          52
        "chunk-invalid" => 56
        "stdin-redirect-307" => 65
        _ => fail("missing frozen oracle status: " + command + " " + label)
      }
    "wget" =>
      match label {
        "chunk-complete"
        | "chunk-empty"
        | "chunk-payload-file"
        | "chunk-payload"
        | "chunk-trailer"
        | "close-complete"
        | "empty-complete"
        | "fixed-complete"
        | "head-length"
        | "header-partial-file"
        | "header-partial"
        | "no-content"
        | "output-full-empty"
        | "output-null-complete"
        | "resume-name-change-ignore-existing"
        | "resume-name-change-ignore-new"
        | "resume-nonfinal-range"
        | "resume-unsatisfied-equal-resource"
        | "resume-unsatisfied-longer-than-resource"
        | "resume-unsatisfied-shorter-than-resource"
        | "resume-unsatisfied-malformed-local-3"
        | "resume-unsatisfied-malformed-local-6"
        | "resume-unsatisfied-malformed-local-7"
        | "resume-unsatisfied-missing-local-3"
        | "resume-unsatisfied-missing-local-6"
        | "resume-unsatisfied-missing-local-7"
        | "resume-unsatisfied-without-resume"
        | "resume-named-valid-new"
        | "resume-named-valid-existing"
        | "retry-content-disposition-keeps-actual-name"
        | "retry-ignore-aggregate"
        | "retry-ignore-changed-aggregate"
        | "retry-ignore-changed-default-file"
        | "retry-ignore-changed-file"
        | "retry-ignore-changed-stdout"
        | "retry-ignore-default-file"
        | "retry-ignore-file"
        | "retry-ignore-stdout"
        | "retry-range-aggregate"
        | "retry-range-default-file"
        | "retry-range-file"
        | "retry-range-stdout"
        | "retry-unique-keeps-actual-name"
        | "trailer-complete" => 0
        "output-full-complete" | "output-full-partial" => 3
        "chunk-data-crlf"
        | "chunk-initial-eof"
        | "chunk-invalid"
        | "chunk-terminator-file"
        | "chunk-terminator"
        | "fixed-complete-then-fixed-prefix"
        | "fixed-empty-file"
        | "fixed-empty"
        | "fixed-prefix-existing-file"
        | "fixed-prefix-file"
        | "fixed-prefix-then-fixed-complete"
        | "fixed-prefix"
        | "header-empty-existing-file"
        | "header-empty-file"
        | "header-empty"
        | "resume-name-change-existing"
        | "resume-name-change-new"
        | "retry-empty-is-bounded"
        | "retry-wrong-range-preserves-prefix" => 4
        "not-modified" => 8
        _ => fail("missing frozen oracle status: " + command + " " + label)
      }
    _ => fail("unknown transfer command: " + command)
  }
}

///|
async fn transfer_scenario_call(
  executor : Executor,
  work : String,
  command : String,
  label : String,
  args : Array[String],
  stdout : String,
  ranges : Array[String?],
  requests : Array[@testkit.TransferFixtureRequest],
  oracle_failures : Array[String],
  files~ : Array[(String, String?)] = [],
  initial_files~ : Array[(String, String)] = [],
  stdin~ : Bytes = b"",
  expected_stderr~ : String = "",
  bodies? : Array[Bytes],
  methods? : Array[String],
  request_wires? : Array[Bytes],
  paths? : Array[String],
  cookies? : Array[Array[String]],
  transfer_files? : TransferFileObservation,
  expected_files_before_response? : Array[Array[(String, String)]],
  oracle_image? : String,
) -> Unit {
  try {
    let case_work = work + "/" + command + "-" + label
    @fs.mkdir(case_work)
    for (name, content) in initial_files {
      @fs.write_file(case_work + "/" + name, content)
    }
    if oracle_image is Some(_) {
      @fs.mkdir(case_work + "/oracle")
      for (name, content) in initial_files {
        @fs.write_file(case_work + "/oracle/" + name, content)
      }
    }
    let call_failures : Array[String] = []
    let expected_methods = methods.unwrap_or(ranges.map(_ => "GET"))
    let result = network_request(
      executor,
      case_work,
      command,
      args,
      stdin~,
      oracle_image?,
      oracle_failures=call_failures,
      transfer_requests=requests,
      request_wires?,
      expected_paths?=paths,
      expected_cookies?=cookies,
      expected_ranges=ranges,
      expected_methods~,
      expected_bodies?=bodies,
      expected_files=files,
      transfer_files?,
      expected_files_before_response?,
    )
    if result.stdout != @utf8.encode(stdout) {
      call_failures.push(
        "candidate stdout bytes differ from the scenario contract",
      )
    }
    if result.stderr != @utf8.encode(expected_stderr) {
      call_failures.push(
        "candidate stderr bytes differ from the scenario contract",
      )
    }
    let expected_status = transfer_oracle_status(command, label)
    if oracle_image is None &&
      executor.proof is Some(proof) &&
      proof.accepts("transfer/" + command + "-" + label + "/response", command) {
      proof.observe_equal(
        "transfer/" + command + "-" + label + "/response",
        command,
        {
          "status": result.status,
          "stdout": @testkit.scenario_text(result.stdout),
          "stderr": @testkit.scenario_text(result.stderr),
        },
        {
          "status": expected_status,
          "stdout": stdout,
          "stderr": expected_stderr,
        },
      )
    }
    if result.status != expected_status {
      call_failures.push(
        "candidate status " +
        result.status.to_string() +
        " != frozen oracle status " +
        expected_status.to_string(),
      )
    }
    @fs.write_file(
      case_work + "/contract-checks.json",
      @testkit.canonical_json({
        "command": Json(command),
        "label": Json(label),
        "status": Json(result.status),
        "status_contract": Json("exact-pinned-oracle-calibration"),
        "expected_status": Json(expected_status),
        "expected_stdout": Json(stdout),
        "expected_stderr": Json(expected_stderr),
        "expected_files_before_response": expected_files_before_response
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_methods": Json(expected_methods),
        "expected_paths": paths
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_cookies": cookies
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_bodies": bodies
        .map(value => Json(value))
        .unwrap_or(Json::null()),
        "expected_ranges": Json(
          ranges.map(range => {
            range.map(value => Json(value)).unwrap_or(Json::null())
          }),
        ),
        "failures": Json(call_failures),
      }),
    )
    oracle_failures.append(
      call_failures.map(error => command + " " + label + ": " + error),
    )
  } catch {
    error =>
      oracle_failures.push(command + " " + label + ": " + error.to_string())
  }
}

///|
/// Range and upload fixtures are stateless. The retry lifecycle sequences use the
/// request capture reset before each candidate and oracle execution.
async fn network_transfer_scenario(
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  let oracle_failures : Array[String] = []
  @async.with_task_group(group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[@testkit.TransferFixtureRequest] = []
    let transfer_files : TransferFileObservation = {
      work: None,
      snapshots: [],
    }
    group.spawn_bg(no_wait=true, () => {
      server.run_forever() <| ((request, _, connection) => {
        if !@testkit.serve_transfer_fixture(request, connection, requests~, before_response=() => {
            transfer_files.capture()
          }) {
          fail("unknown transfer fixture path: " + request.path)
        }
      })
    })
    let base = "http://127.0.0.1:\{server.addr.port()}"
    @fs.write_file(work + "/../network-origin.txt", base)
    for command in ["curl", "wget"] {
      let quiet = if command == "curl" { ["-s"] } else { ["-q", "-t", "1"] }
      let to_stdout = if command == "curl" { [] } else { ["-O", "-"] }
      for
        (endpoint, stdout) in [
          ("fixed-empty", ""),
          ("fixed-prefix", "hello"),
          ("chunk-empty", ""),
          ("chunk-initial-eof", ""),
          ("chunk-payload", "hello"),
          ("chunk-data-crlf", "hello"),
          ("chunk-terminator", "hello"),
          ("chunk-trailer", "hello"),
          ("chunk-invalid", ""),
          ("header-empty", ""),
          ("header-partial", ""),
          ("fixed-complete", "hello"),
          ("chunk-complete", "hello"),
          ("trailer-complete", "hello"),
          ("close-complete", "hello"),
          ("empty-complete", ""),
          ("no-content", ""),
          ("not-modified", ""),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint,
          [
            ..quiet,
            ..if command == "wget" && endpoint == "fixed-empty" {
              ["--waitretry=0.001"]
            } else {
              []
            },
            ..to_stdout,
            base + "/transfer-" + endpoint,
          ],
          stdout,
          [None],
          requests,
          oracle_failures,
          oracle_image?,
        )
      }
      transfer_scenario_call(
        executor,
        work,
        command,
        "head-length",
        [
          ..quiet,
          ..to_stdout,
          if command == "curl" {
            "-I"
          } else {
            "--method=HEAD"
          },
          base + "/transfer-head-length",
        ],
        if command == "curl" {
          "HTTP/1.1 200 OK\r\nContent-Length: 9\r\n\r\n"
        } else {
          ""
        },
        [None],
        requests,
        oracle_failures,
        methods=["HEAD"],
        oracle_image?,
      )
      if @async.platform is Linux {
        for device in ["/dev/full", "/dev/null"] {
          guard @fs.kind(device, follow_symlink=false) == @fs.CharDevice else {
            fail(
              "infrastructure: output observation requires a character device: " +
              device,
            )
          }
        }
        for
          (label, endpoint, output) in [
            ("output-full-complete", "fixed-complete", "/dev/full"),
            ("output-full-partial", "fixed-prefix", "/dev/full"),
            ("output-full-empty", "empty-complete", "/dev/full"),
            ("output-null-complete", "fixed-complete", "/dev/null"),
          ] {
          transfer_scenario_call(
            executor,
            work,
            command,
            label,
            [
              ..quiet,
              if command == "curl" {
                "-o"
              } else {
                "-O"
              },
              output,
              base + "/transfer-" + endpoint,
            ],
            "",
            [None],
            requests,
            oracle_failures,
            oracle_image?,
          )
        }
        if command == "curl" {
          for count in [4095, 4096] {
            for completion in ["partial", "complete"] {
              transfer_scenario_call(
                executor,
                work,
                command,
                "output-full-\{completion}-\{count}",
                [
                  "-s",
                  "-o",
                  "/dev/full",
                  base + "/transfer-output-\{completion}-\{count}",
                ],
                "",
                [None],
                requests,
                oracle_failures,
                oracle_image?,
              )
            }
          }
        }
      }
      for endpoint in ["fixed-prefix", "chunk-payload", "chunk-terminator"] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint + "-file",
          [
            ..quiet,
            if command == "curl" {
              "-o"
            } else {
              "-O"
            },
            "partial.bin",
            base + "/transfer-" + endpoint,
          ],
          "",
          [None],
          requests,
          oracle_failures,
          files=[("partial.bin", Some("hello"))],
          oracle_image?,
        )
      }
      for
        (endpoint, content) in [
          ("fixed-empty", if command == "curl" { None } else { Some("") }),
          ("header-empty", if command == "curl" { None } else { Some("") }),
          ("header-partial", Some("")),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint + "-file",
          [
            ..quiet,
            if command == "curl" {
              "-o"
            } else {
              "-O"
            },
            "partial.bin",
            base + "/transfer-" + endpoint,
          ],
          "",
          [None],
          requests,
          oracle_failures,
          files=[("partial.bin", content)],
          oracle_image?,
        )
      }
      for
        (endpoint, content) in [
          ("fixed-prefix", "hello"),
          ("header-empty", if command == "curl" { "original" } else { "" }),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          endpoint + "-existing-file",
          [
            ..quiet,
            if command == "curl" {
              "-o"
            } else {
              "-O"
            },
            "partial.bin",
            base + "/transfer-" + endpoint,
          ],
          "",
          [None],
          requests,
          oracle_failures,
          initial_files=[("partial.bin", "original")],
          files=[("partial.bin", Some(content))],
          oracle_image?,
        )
      }
      for
        (first, second) in [
          ("fixed-prefix", "fixed-complete"),
          ("fixed-complete", "fixed-prefix"),
        ] {
        transfer_scenario_call(
          executor,
          work,
          command,
          first + "-then-" + second,
          [
            ..quiet,
            ..to_stdout,
            base + "/transfer-" + first,
            base + "/transfer-" + second,
          ],
          "hellohello",
          [None, None],
          requests,
          oracle_failures,
          oracle_image?,
        )
      }
    }
    for count in [256, 65537] {
      let input = Bytes::from_array(
        Array::makei(count, index => (index % 256).to_byte()),
      )
      transfer_scenario_call(
        executor,
        work,
        "curl",
        "stdin-retry-\{count}",
        [
          "-s",
          "-T",
          "-",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          base + "/transfer-stdin-retry",
        ],
        "hellook",
        [None, None],
        requests,
        oracle_failures,
        stdin=input,
        bodies=[input, b""],
        methods=["PUT", "PUT"],
        oracle_image?,
      )
    }
    let binary_input = Bytes::from_array(
      Array::makei(256, index => index.to_byte()),
    )
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "stdin-retry-show-error-256",
      [
        "-sS",
        "-T",
        "-",
        "--retry",
        "1",
        "--retry-all-errors",
        "--retry-delay",
        "1",
        base + "/transfer-stdin-retry",
      ],
      "hellook",
      [None, None],
      requests,
      oracle_failures,
      stdin=binary_input,
      expected_stderr="curl: (18) end of response with 4 bytes missing\n",
      bodies=[binary_input, b""],
      methods=["PUT", "PUT"],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "stdin-redirect-307",
      [
        "-s",
        "-T",
        "-",
        "-L",
        "--max-redirs",
        "2",
        base + "/transfer-stdin-redirect",
      ],
      "",
      [None],
      requests,
      oracle_failures,
      stdin=binary_input,
      bodies=[binary_input],
      methods=["PUT"],
      oracle_image?,
    )
    for existing in [false, true] {
      for remove in [false, true] {
        for complete in [false, true] {
          let completion = if complete { "complete" } else { "partial" }
          let prior = if existing { "existing" } else { "new" }
          let cleanup = if remove { "remove" } else { "keep" }
          transfer_scenario_call(
            executor,
            work,
            "curl",
            "empty-output-\{completion}-\{prior}-\{cleanup}",
            [
              "-s",
              "-o",
              "output",
              ..if remove {
                ["--remove-on-error"]
              } else {
                []
              },
              base +
              (if complete {
                "/transfer-empty-complete"
              } else {
                "/transfer-fixed-empty"
              }),
            ],
            "",
            [None],
            requests,
            oracle_failures,
            initial_files=if existing { [("output", "preserve")] } else { [] },
            files=[
              (
                "output",
                if complete {
                  Some("")
                } else if existing {
                  Some("preserve")
                } else {
                  None
                },
              ),
            ],
            oracle_image?,
          )
        }
      }
    }
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "remove-partial",
      [
        "-s",
        "--remove-on-error",
        "-o",
        "partial.bin",
        base + "/transfer-fixed-prefix",
      ],
      "",
      [None],
      requests,
      oracle_failures,
      files=[("partial.bin", None)],
      oracle_image?,
    )
    for remove in [false, true] {
      transfer_scenario_call(
        executor,
        work,
        "curl",
        if remove {
          "remove-named"
        } else {
          "keep-named"
        },
        [
          "-sJO",
          ..if remove {
            ["--remove-on-error"]
          } else {
            []
          },
          base + "/transfer-named-prefix",
        ],
        "",
        [None],
        requests,
        oracle_failures,
        files=[("wire-partial.bin", if remove { None } else { Some("hello") })],
        oracle_image?,
      )
    }
    transfer_scenario_call(
      executor,
      work,
      "curl",
      "default-retry-does-not-retry-partial",
      ["-s", "--retry", "2", base + "/transfer-fixed-prefix"],
      "hello",
      [None],
      requests,
      oracle_failures,
      oracle_image?,
    )
    for file in [false, true] {
      transfer_scenario_call(
        executor,
        work,
        "curl",
        if file {
          "retry-all-file"
        } else {
          "retry-all-stdout"
        },
        [
          "-s",
          "--retry",
          "2",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          ..if file {
            ["-o", "partial.bin"]
          } else {
            []
          },
          base + "/transfer-fixed-prefix",
        ],
        if file {
          ""
        } else {
          "hellohellohello"
        },
        [None, None, None],
        requests,
        oracle_failures,
        files=if file { [("partial.bin", Some("hello"))] } else { [] },
        oracle_image?,
      )
    }
    for mode in ["file-new", "file-existing", "stdout"] {
      let file = mode != "stdout"
      let initial_files = if mode == "file-existing" {
        [("partial.bin", "preserve")]
      } else {
        []
      }
      transfer_scenario_call(
        executor,
        work,
        "curl",
        "retry-partial-empty-" + mode,
        [
          "-sS",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          ..if file {
            ["-o", "partial.bin"]
          } else {
            []
          },
          base + "/transfer-retry-empty",
        ],
        if file {
          ""
        } else {
          "hello"
        },
        [None, None],
        requests,
        oracle_failures,
        initial_files~,
        files=if file { [("partial.bin", Some(""))] } else { [] },
        expected_stderr="curl: (18) end of response with 4 bytes missing\n" +
          "curl: (18) end of response with 9 bytes missing\n",
        methods=["GET", "GET"],
        bodies=[b"", b""],
        transfer_files~,
        expected_files_before_response=[
          initial_files,
          if file {
            [("partial.bin", "")]
          } else {
            []
          },
        ],
        oracle_image?,
      )
    }
    for
      (label, complete, existing) in [
        ("remove-partial-empty-new", false, false),
        ("remove-partial-empty-existing", false, true),
        ("remove-partial-complete-new", true, false),
      ] {
      let initial_files = if existing {
        [("output.bin", "preserve")]
      } else {
        []
      }
      transfer_scenario_call(
        executor,
        work,
        "curl",
        label,
        [
          "-sS",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          "-o",
          "output.bin",
          "--remove-on-error",
          base +
          (if complete {
            "/transfer-retry-complete"
          } else {
            "/transfer-retry-empty"
          }),
        ],
        "",
        [None, None],
        requests,
        oracle_failures,
        initial_files~,
        files=[("output.bin", if complete { Some("ok") } else { None })],
        expected_stderr="curl: (18) end of response with 4 bytes missing\n" +
          (if complete {
            ""
          } else {
            "curl: (18) end of response with 9 bytes missing\n"
          }),
        methods=["GET", "GET"],
        bodies=[b"", b""],
        transfer_files~,
        expected_files_before_response=[initial_files, [("output.bin", "")]],
        oracle_image?,
      )
    }
    for
      (label, endpoint, complete, remove) in [
        ("cd-partial-empty-changed", "empty-changed", false, false),
        ("cd-partial-complete-changed", "complete-changed", true, false),
        ("cd-partial-complete-missing", "complete-missing", true, false),
        ("cd-partial-empty-changed-remove", "empty-changed", false, true),
        ("cd-partial-complete-changed-remove", "complete-changed", true, true),
      ] {
      transfer_scenario_call(
        executor,
        work,
        "curl",
        label,
        [
          "-s",
          "--retry",
          "1",
          "--retry-all-errors",
          "--retry-delay",
          "1",
          "-O",
          "-J",
          ..if remove {
            ["--remove-on-error"]
          } else {
            []
          },
          base + "/transfer-retry-named-" + endpoint,
        ],
        "",
        [None, None],
        requests,
        oracle_failures,
        files=[
          (
            "first.bin",
            if complete {
              Some("ok")
            } else if remove {
              None
            } else {
              Some("")
            },
          ),
          ("second.bin", None),
          ("transfer-retry-named-" + endpoint, None),
        ],
        methods=["GET", "GET"],
        bodies=[b"", b""],
        transfer_files~,
        expected_files_before_response=[[], [("first.bin", "")]],
        oracle_image?,
      )
    }
    for existing in [false, true] {
      let initial_files = if existing {
        [("first.bin", "preserve")]
      } else {
        []
      }
      transfer_scenario_call(
        executor,
        work,
        "curl",
        if existing {
          "cd-first-empty-existing"
        } else {
          "cd-first-empty-new"
        },
        ["-s", "--retry", "0", "-O", "-J", base + "/transfer-named-empty"],
        "",
        [None],
        requests,
        oracle_failures,
        initial_files~,
        files=[
          ("first.bin", Some(if existing { "preserve" } else { "" })),
          ("transfer-named-empty", None),
        ],
        methods=["GET"],
        bodies=[b""],
        transfer_files~,
        expected_files_before_response=[initial_files],
        oracle_image?,
      )
    }
    for status in [200, 304, 404, 500] {
      for completion in ["empty-complete", "empty-incomplete", "body-complete"] {
        for fail_http in [false, true] {
          let endpoint = "transfer-cd-status-\{status}-\{completion}"
          let selected_name = status == 200 || status == 304
          let content = if completion == "body-complete" { "hello" } else { "" }
          transfer_scenario_call(
            executor,
            work,
            "curl",
            "cd-status-\{status}-\{completion}-fail-\{fail_http}",
            [
              "-s",
              "--retry",
              "0",
              "-O",
              "-J",
              ..if fail_http {
                ["--fail"]
              } else {
                []
              },
              base + "/" + endpoint,
            ],
            "",
            [None],
            requests,
            oracle_failures,
            files=[
              (
                "selected.bin",
                if selected_name {
                  Some(if status == 304 { "" } else { content })
                } else {
                  None
                },
              ),
              (
                endpoint,
                if selected_name ||
                  fail_http ||
                  completion == "empty-incomplete" {
                  None
                } else {
                  Some(content)
                },
              ),
            ],
            methods=["GET"],
            bodies=[b""],
            transfer_files~,
            expected_files_before_response=[[]],
            oracle_image?,
          )
        }
      }
    }
    for endpoint in ["retry-range", "retry-ignore", "retry-ignore-changed"] {
      for file in [false, true] {
        transfer_scenario_call(
          executor,
          work,
          "wget",
          endpoint + (if file { "-file" } else { "-stdout" }),
          [
            "-q",
            "-t",
            "2",
            "--waitretry=0.001",
            "-O",
            if file {
              "result.bin"
            } else {
              "-"
            },
            base + "/transfer-" + endpoint,
          ],
          if file {
            ""
          } else {
            "helloworld"
          },
          [None, Some("bytes=5-")],
          requests,
          oracle_failures,
          files=if file { [("result.bin", Some("helloworld"))] } else { [] },
          oracle_image?,
        )
      }
      transfer_scenario_call(
        executor,
        work,
        "wget",
        endpoint + "-aggregate",
        [
          "-q",
          "-t",
          "2",
          "--waitretry=0.001",
          "-O",
          "aggregate.bin",
          base + "/transfer-fixed-complete",
          base + "/transfer-" + endpoint,
        ],
        "",
        [None, None, Some("bytes=5-")],
        requests,
        oracle_failures,
        files=[("aggregate.bin", Some("hellohelloworld"))],
        oracle_image?,
      )
      transfer_scenario_call(
        executor,
        work,
        "wget",
        endpoint + "-default-file",
        ["-q", "-t", "2", "--waitretry=0.001", base + "/transfer-" + endpoint],
        "",
        [None, Some("bytes=5-")],
        requests,
        oracle_failures,
        files=[("transfer-" + endpoint, Some("helloworld"))],
        oracle_image?,
      )
    }
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-unique-keeps-actual-name",
      ["-q", "-t", "2", "--waitretry=0.001", base + "/transfer-retry-range"],
      "",
      [None, Some("bytes=5-")],
      requests,
      oracle_failures,
      initial_files=[("transfer-retry-range", "existing")],
      files=[
        ("transfer-retry-range", Some("existing")),
        ("transfer-retry-range.1", Some("helloworld")),
        ("transfer-retry-range.2", None),
      ],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-content-disposition-keeps-actual-name",
      [
        "-q",
        "-t",
        "2",
        "--waitretry=0.001",
        "--content-disposition",
        base + "/transfer-retry-named",
      ],
      "",
      [None, Some("bytes=5-")],
      requests,
      oracle_failures,
      initial_files=[("wire-retry.bin", "existing")],
      files=[
        ("wire-retry.bin", Some("existing")),
        ("wire-retry.bin.1", Some("helloworld")),
        ("wire-retry.bin.2", None),
        ("transfer-retry-named", None),
      ],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-wrong-range-preserves-prefix",
      [
        "-q",
        "-t",
        "2",
        "--waitretry=0.001",
        "-O",
        "partial.bin",
        base + "/transfer-retry-wrong-range",
      ],
      "",
      [None, Some("bytes=5-")],
      requests,
      oracle_failures,
      files=[("partial.bin", Some("hello"))],
      oracle_image?,
    )
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "retry-empty-is-bounded",
      [
        "-q",
        "-t",
        "2",
        "--waitretry=0.001",
        "-O",
        "-",
        base + "/transfer-fixed-empty",
      ],
      "",
      [None, None],
      requests,
      oracle_failures,
      oracle_image?,
    )
    for endpoint in ["resume-name-change", "resume-name-change-ignore"] {
      for existing in [false, true] {
        transfer_scenario_call(
          executor,
          work,
          "wget",
          endpoint + (if existing { "-existing" } else { "-new" }),
          [
            "-q",
            "-t",
            "1",
            "-c",
            "--content-disposition",
            base + "/transfer-" + endpoint,
          ],
          "",
          if endpoint == "resume-name-change" {
            [None]
          } else {
            [None, if existing { Some("bytes=8-") } else { None }]
          },
          requests,
          oracle_failures,
          initial_files=[
            ("transfer-" + endpoint, "abc"),
            ..if existing {
              [("renamed.bin", "preserve")]
            } else {
              []
            },
          ],
          files=[
            ("transfer-" + endpoint, Some("abc")),
            (
              "renamed.bin",
              if existing {
                Some("preserve")
              } else if endpoint == "resume-name-change-ignore" {
                Some("abcdef")
              } else {
                None
              },
            ),
          ],
          methods=if endpoint == "resume-name-change" {
            ["HEAD"]
          } else {
            ["HEAD", "GET"]
          },
          oracle_image?,
        )
      }
    }
    for
      (label, prefix, range) in [
        ("shorter-than-resource", "abc", "bytes=3-"),
        ("equal-resource", "abcdef", "bytes=6-"),
        ("longer-than-resource", "abcdefg", "bytes=7-"),
      ] {
      transfer_scenario_call(
        executor,
        work,
        "wget",
        "resume-unsatisfied-" + label,
        ["-q", "-t", "1", "-c", base + "/transfer-resume-unsatisfied"],
        "",
        [Some(range)],
        requests,
        oracle_failures,
        initial_files=[("transfer-resume-unsatisfied", prefix)],
        files=[("transfer-resume-unsatisfied", Some(prefix))],
        oracle_image?,
      )
    }
    for variant in ["malformed", "missing"] {
      for
        (prefix, range) in [
          ("abc", "bytes=3-"),
          ("abcdef", "bytes=6-"),
          ("abcdefg", "bytes=7-"),
        ] {
        let endpoint = "transfer-resume-unsatisfied-" + variant
        transfer_scenario_call(
          executor,
          work,
          "wget",
          "resume-unsatisfied-\{variant}-local-\{prefix.length()}",
          ["-q", "-t", "1", "-c", base + "/" + endpoint],
          "",
          [Some(range)],
          requests,
          oracle_failures,
          initial_files=[(endpoint, prefix)],
          files=[(endpoint, Some(prefix))],
          oracle_image?,
        )
      }
    }
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "resume-unsatisfied-without-resume",
      ["-q", "-t", "1", base + "/transfer-resume-unsatisfied"],
      "",
      [None],
      requests,
      oracle_failures,
      files=[("transfer-resume-unsatisfied", None)],
      oracle_image?,
    )
    for existing in [false, true] {
      transfer_scenario_call(
        executor,
        work,
        "wget",
        "resume-named-valid-" + (if existing { "existing" } else { "new" }),
        [
          "-q",
          "-t",
          "1",
          "-c",
          "--content-disposition",
          base + "/transfer-resume-named-valid",
        ],
        "",
        [None, if existing { Some("bytes=3-") } else { None }],
        requests,
        oracle_failures,
        initial_files=[
          ("transfer-resume-named-valid", "original"),
          ..if existing {
            [("renamed.bin", "abc")]
          } else {
            []
          },
        ],
        files=[
          ("transfer-resume-named-valid", Some("original")),
          ("renamed.bin", Some("abcdef")),
        ],
        methods=["HEAD", "GET"],
        oracle_image?,
      )
    }
    transfer_scenario_call(
      executor,
      work,
      "wget",
      "resume-nonfinal-range",
      ["-q", "-t", "1", "-c", base + "/transfer-resume-nonfinal-range"],
      "",
      [Some("bytes=3-")],
      requests,
      oracle_failures,
      initial_files=[("transfer-resume-nonfinal-range", "abc")],
      files=[("transfer-resume-nonfinal-range", Some("abcde"))],
      oracle_image?,
    )
    network_wire_scenario(executor, work, oracle_failures, oracle_image?)
    if !oracle_failures.is_empty() {
      fail(oracle_failures.join("; "))
    }
  })
}

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
  requests : Array[@testkit.TransferFixtureRequest],
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
    let requests : Array[@testkit.TransferFixtureRequest] = []
    let wires : Array[Bytes] = []
    group.spawn_bg(no_wait=true, () => {
      server.run_forever((connection, _) => {
        @testkit.serve_wire_fixture(connection, requests, wires)
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

///|
fn check_network_response(
  result : @testkit.RunResult,
  expected : String,
) -> Unit raise {
  assert_eq(result.status, 0)
  assert_true(@testkit.bytes_equal(result.stdout, @utf8.encode(expected)))
  assert_eq(result.stderr, b"")
}

///|
/// Stateful CLI coverage previously driven by core/netops/verify_cli.mbtx.
/// One loopback fixture serves all rounds; no installed curl/wget is needed.
async fn network_cli_scenario(
  executor : Executor,
  work : String,
  oracle_image? : String,
) -> Unit {
  let oracle_failures : Array[String] = []
  @async.with_task_group <| group => {
    let server = @http.Server(@socket.Addr::parse("127.0.0.1:0"))
    group.add_defer(() => server.close())
    let requests : Array[(String, String?)] = []
    group.spawn_bg(no_wait=true) <| () => {
      server.run_forever() <| ((request, _, connection) => {
        requests.push((request.path, request.headers.get("Authorization")))
        match request.path {
          "/auth" if request.headers.get("Authorization") is None =>
            connection
            ..send_response(401, "Unauthorized", extra_headers={
              "WWW-Authenticate": "Basic realm=\"local\"",
              "Content-Length": "0",
            })
            .end_response()
          "/cross" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "http://localhost:\{server.addr.port()}/inspect",
              "Content-Length": "0",
            })
            .end_response()
          "/cross-auth" =>
            connection
            ..send_response(302, "Found", extra_headers={
              "Location": "http://localhost:\{server.addr.port()}/auth",
              "Content-Length": "0",
            })
            .end_response()
          "/set" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[@http.Cookie("sid", "fixture", path="/")],
            )
            .end_response()
          "/set-path" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[@http.Cookie("private", "hidden", path="/private")],
            )
            .end_response()
          "/set-domain" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[
                @http.Cookie(
                  "foreign",
                  "hidden",
                  domain="example.invalid",
                  path="/",
                ),
              ],
            )
            .end_response()
          "/set-expired" =>
            connection
            ..send_response(
              302,
              "Found",
              extra_headers={ "Location": "/inspect", "Content-Length": "0" },
              cookies=[@http.Cookie("expired", "hidden", path="/", max_age=0L)],
            )
            .end_response()
          _ => {
            let body = "auth=" +
              request.headers.get("Authorization").unwrap_or("") +
              "\ncookie=" +
              request.headers.get("Cookie").unwrap_or("") +
              "\n"
            connection
            ..send_response(200, "OK", extra_headers={
              "Content-Length": body.length().to_string(),
            })
            ..write(body)
            .end_response()
          }
        }
      })
    }
    let base = "http://127.0.0.1:\{server.addr.port()}"
    // The allocated listener origin is the only network normalization used
    // when comparing this scenario's independently isolated backend fixtures.
    @fs.write_file(work + "/../network-origin.txt", base)
    let cases : Array[(String, Array[String], String, Int32)] = [
      (
        "curl",
        ["-sS", "-u", "user:pass", base + "/inspect"],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
      (
        "curl",
        [
          "-sS",
          "-u",
          "user:pass",
          "http://wrong:bad@127.0.0.1:\{server.addr.port()}/inspect",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
      (
        "curl",
        ["-sS", "-b", "sid=explicit", base + "/inspect"],
        "auth=\ncookie=sid=explicit\n",
        1,
      ),
      (
        "curl",
        ["-sS", "-b", "sid=first", "-b", "sid=last", base + "/inspect"],
        "auth=\ncookie=sid=first; sid=last\n",
        1,
      ),
      (
        "curl",
        ["-sSL", "-b", "", base + "/set"],
        "auth=\ncookie=sid=fixture\n",
        2,
      ),
      (
        "curl",
        ["-sSL", "-b", "sid=explicit", base + "/cross"],
        "auth=\ncookie=\n",
        2,
      ),
      (
        "curl",
        ["-sSL", "-H", "Cookie: sid=header", base + "/cross"],
        "auth=\ncookie=\n",
        2,
      ),
      (
        "curl",
        ["-sSL", "-u", "user:pass", base + "/cross"],
        "auth=\ncookie=\n",
        2,
      ),
      (
        "wget",
        ["-qO-", "--user=user", "--password=pass", base + "/auth"],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        2,
      ),
      (
        "wget",
        [
          "-qO-",
          "--http-user=user",
          "--http-password=pass",
          "--auth-no-challenge",
          base + "/inspect",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
      (
        "wget",
        [
          "-qO-",
          "--user=user",
          "--password=pass",
          "--auth-no-challenge",
          base + "/cross",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        2,
      ),
      (
        "wget",
        ["-qO-", "--user=user", "--password=pass", base + "/cross-auth"],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        3,
      ),
      ("wget", ["-qO-", "--no-cookies", base + "/set"], "auth=\ncookie=\n", 2),
      (
        "wget",
        ["-qO-", "--http-user=user", "--http-password=pass", base + "/inspect"],
        "auth=\ncookie=\n",
        1,
      ),
      (
        "wget",
        [
          "-qO-",
          "--http-user=user",
          "--http-password=pass",
          "--auth-no-challenge",
          base + "/inspect",
        ],
        "auth=Basic dXNlcjpwYXNz\ncookie=\n",
        1,
      ),
    ]
    for index, (command, args, expected, request_count) in cases {
      let before = requests.length()
      let result = network_request(
        executor,
        work,
        command,
        args,
        oracle_image?,
        oracle_failures~,
      )
      check_network_response(result, expected)
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "auth/" + index.to_string(),
          command,
          {
            "status": result.status,
            "stdout": @testkit.scenario_text(result.stdout),
            "stderr": @testkit.scenario_text(result.stderr),
            "requests": requests.length() - before,
          },
          {
            "status": 0,
            "stdout": expected,
            "stderr": "",
            "requests": request_count,
          },
        )
      }
      assert_eq(
        requests.length() - before,
        request_count * (if oracle_image is Some(_) { 2 } else { 1 }),
      )
      if command == "wget" && args.contains(base + "/auth") {
        assert_eq(requests[before].1, None)
        assert_eq(requests[before + 1].1, Some("Basic dXNlcjpwYXNz"))
      }
    }
    for command in ["curl", "wget"] {
      let jar = work + "/" + command + ".cookies"
      let save = if command == "curl" {
        ["-sSL", "-c", jar, base + "/set"]
      } else {
        [
          "-qO-",
          "--save-cookies=" + jar,
          "--keep-session-cookies",
          base + "/set",
        ]
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          save,
          oracle_image?,
          oracle_failures~,
        ),
        "auth=\ncookie=sid=fixture\n",
      )
      assert_true(@fs.read_file(jar).text().contains("\tsid\tfixture"))
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "cookie/" + command + "/saved",
          command,
          Json(@fs.read_file(jar).text().contains("\tsid\tfixture")),
          Json(true),
        )
      }
      let load = if command == "curl" {
        ["-sS", "-b", jar, base + "/inspect"]
      } else {
        ["-qO-", "--load-cookies=" + jar, base + "/inspect"]
      }
      let loaded = network_request(
        executor,
        work,
        command,
        load,
        oracle_image?,
        oracle_failures~,
      )
      check_network_response(loaded, "auth=\ncookie=sid=fixture\n")
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "cookie/" + command + "/loaded",
          command,
          {
            "status": loaded.status,
            "stdout": @testkit.scenario_text(loaded.stdout),
            "stderr": @testkit.scenario_text(loaded.stderr),
          },
          { "status": 0, "stdout": "auth=\ncookie=sid=fixture\n", "stderr": "" },
        )
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          if command == "curl" {
            ["-sS", "-b", jar, "-H", "Cookie: sid=header", base + "/inspect"]
          } else {
            [
              "-qO-",
              "--load-cookies=" + jar,
              "--header=Cookie: sid=header",
              base + "/inspect",
            ]
          },
          oracle_image?,
          oracle_failures~,
        ),
        if command == "curl" {
          // The HTTP fixture joins repeated wire fields with a comma.
          "auth=\ncookie=sid=fixture,sid=header\n"
        } else {
          "auth=\ncookie=sid=header\n"
        },
      )
      if command == "curl" {
        check_network_response(
          network_request(
            executor,
            work,
            command,
            ["-sS", "-b", jar, "-b", "sid=manual", base + "/inspect"],
            oracle_image?,
            oracle_failures~,
          ),
          "auth=\ncookie=sid=fixture; sid=manual\n",
        )
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          if command == "curl" {
            ["-sSL", "-b", jar, "-H", "Cookie: sid=header", base + "/cross"]
          } else {
            [
              "-qO-",
              "--load-cookies=" + jar,
              "--header=Cookie: sid=header",
              base + "/cross",
            ]
          },
          oracle_image?,
          oracle_failures~,
        ),
        if command == "curl" {
          "auth=\ncookie=\n"
        } else {
          "auth=\ncookie=sid=header\n"
        },
      )
      if !(@async.platform is Windows) {
        // Match the jar's requested creation mode so both files observe the
        // process's real umask, including group-writable configurations.
        let control = work + "/mode-control-" + command
        @fs.write_file(control, "", permission=0o666)
        let stat_args = if @async.platform is MacOS {
          ["-f", "%Lp"]
        } else {
          ["-c", "%a"]
        }
        let actual_mode = @testkit.run("stat", [..stat_args, jar], stdin=b"")
        let control_mode = @testkit.run(
          "stat",
          [..stat_args, control],
          stdin=b"",
        )
        assert_eq(actual_mode.status, 0)
        assert_eq(control_mode.status, 0)
        assert_eq(actual_mode.stdout, control_mode.stdout)
        if oracle_image is Some(_) {
          let oracle_mode = @testkit.run(
            "stat",
            [..stat_args, work + "/oracle/" + command + ".cookies"],
            stdin=b"",
          )
          assert_eq(oracle_mode.status, 0)
          if actual_mode.stdout != oracle_mode.stdout {
            oracle_failures.push(
              command +
              " cookie jar mode differs: " +
              @utf8.decode(actual_mode.stdout) +
              " != " +
              @utf8.decode(oracle_mode.stdout),
            )
          }
        }
      }
      for endpoint in ["set-path", "set-domain", "set-expired"] {
        let args = if command == "curl" {
          ["-sSL", "-b", "", base + "/" + endpoint]
        } else {
          ["-qO-", base + "/" + endpoint]
        }
        check_network_response(
          network_request(
            executor,
            work,
            command,
            args,
            oracle_image?,
            oracle_failures~,
          ),
          "auth=\ncookie=\n",
        )
      }
      let missing = work + "/absent/" + command + ".cookies"
      let args = if command == "curl" {
        ["-sSL", "-c", missing, base + "/set"]
      } else {
        ["-qO-", "--save-cookies=" + missing, base + "/set"]
      }
      check_network_response(
        network_request(
          executor,
          work,
          command,
          args,
          oracle_image?,
          oracle_failures~,
        ),
        "auth=\ncookie=sid=fixture\n",
      )
      assert_false(@fs.exists(missing))
      if oracle_image is None && executor.proof is Some(proof) {
        proof.observe_equal(
          "cookie/" + command + "/missing-parent",
          command,
          Json(@fs.exists(missing)),
          Json(false),
        )
      }
    }
    let session_jar = work + "/wget-without-session.cookies"
    check_network_response(
      network_request(
        executor,
        work,
        "wget",
        ["-qO-", "--save-cookies=" + session_jar, base + "/set"],
        oracle_image?,
        oracle_failures~,
      ),
      "auth=\ncookie=sid=fixture\n",
    )
    assert_false(@fs.read_file(session_jar).text().contains("\tsid\tfixture"))
    if oracle_image is None && executor.proof is Some(proof) {
      proof.observe_equal(
        "cookie/wget/session-excluded",
        "wget",
        Json(@fs.read_file(session_jar).text().contains("\tsid\tfixture")),
        Json(false),
      )
    }
    @fs.write_file(
      work + "/../requests.json",
      @testkit.canonical_json(
        Json(
          requests.map(item => {
            ({ "path": Json(item.0), "authorization": Json(item.1) } : Json)
          }),
        ),
      ),
    )
    if !oracle_failures.is_empty() {
      fail(oracle_failures.join("; "))
    }
  }
}
