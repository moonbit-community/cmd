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
  transfer_requests? : Array[@harness.TransferFixtureRequest],
  request_wires? : Array[Bytes],
  expected_paths? : Array[String],
  expected_cookies? : Array[Array[String]],
  expected_ranges? : Array[String?],
  expected_methods? : Array[String],
  expected_bodies? : Array[Bytes],
  expected_files? : Array[(String, String?)],
  transfer_files? : TransferFileObservation,
  expected_files_before_response? : Array[Array[(String, String)]],
) -> @harness.RunResult {
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
      @harness.canonical_json({
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
    let docker_user = @harness.docker_user()
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
    let run = @harness.run_oracle_with_deadline(
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
      @harness.canonical_json({
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
      if expected_bodies is Some(expected) {
        proof.observe_equal(
          prefix + "bodies",
          command,
          Json(
            requests.map(request => {
              request.body.to_array().map(byte => byte.to_int())
            }),
          ),
          Json(expected.map(body => body.to_array().map(byte => byte.to_int()))),
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
              "content": @harness.scenario_text(file.2),
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
