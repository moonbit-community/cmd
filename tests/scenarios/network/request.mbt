///|
priv struct TransferFileObservation {
  mut work : String?
  mut evidence_name : String?
  snapshots : Array[Array[(String, Bool, Bytes)]]
}

///|
async fn TransferFileObservation::capture(
  self : TransferFileObservation,
) -> Unit {
  guard self.work is Some(work) else { return }
  let names = @fs.readdir(work).filter(name => {
    name != "oracle" && self.evidence_name != Some(name)
  })
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
  evidence_work? : String,
  stdin~ : Bytes = b"",
  oracle_image? : String,
  oracle_args? : Array[String],
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
  environment~ : Map[String, String] = {
    "NO_PROXY": "*",
    "no_proxy": "*",
    "LC_ALL": "C",
  },
  trace_suffix~ : Bool = false,
) -> @harness.RunResult {
  if transfer_files is Some(observation) {
    observation.work = Some(work)
    observation.evidence_name = None
    observation.snapshots.clear()
  }
  defer (if transfer_files is Some(observation) {
    observation.work = None
    observation.evidence_name = None
  })
  if transfer_requests is Some(requests) {
    requests.clear()
  }
  if request_wires is Some(wires) {
    wires.clear()
  }
  let evidence = evidence_work.unwrap_or(work)
  let name = "call-\{@fs.readdir(evidence).length()}"
  let prefix = evidence + "/" + name
  if transfer_files is Some(observation) {
    observation.evidence_name = if evidence == work {
      Some(name + ".intent.json")
    } else {
      None
    }
  }
  if evidence == work && expected_files is Some(files) {
    assert_false(
      files.any(file => file.0 == name + ".intent.json"),
      msg="product fixture collides with invocation evidence",
    )
  }
  let invoked_at = @async.now()
  let returned = Ref(false)
  let returned_at = Ref(invoked_at)
  @fs.write_file(
    prefix + ".intent.json",
    (
      {
        "command": Json(command),
        "args": Json(args),
        "cwd": Json(work),
        "phase": "before-invoke",
        "started_ms": @json.to_json(invoked_at),
      } : Json).stringify(indent=2),
  )
  defer @async.protect_from_cancel(() => {
    // Without a returned execution there is no child status or cleanup verdict.
    @fs.write_file(
      prefix + ".invocation-end.json",
      (
        {
          "returned": Json(returned.val),
          "elapsed_ms": @json.to_json(
            (if returned.val { returned_at.val } else { @async.now() }) -
            invoked_at,
          ),
        } : Json).stringify(indent=2),
    )
  })
  let execution = (executor.invoke)({
    command,
    args,
    stdin,
    cwd: work,
    environment,
  })
  returned_at.val = @async.now()
  returned.val = true
  let result = execution.run.output
  // Exclude only the invocation intent owned by this call from product effects.
  let output_names = if expected_files is Some(_) {
    let names = @fs.readdir(work).filter(file => {
      evidence != work || file != name + ".intent.json"
    })
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
    let oracle_args = oracle_args
      .unwrap_or(args)
      .map(arg => arg.replace_all(old=work, new=oracle_work))
    if transfer_requests is Some(requests) {
      requests.clear()
    }
    if request_wires is Some(wires) {
      wires.clear()
    }
    if transfer_files is Some(observation) {
      observation.work = Some(oracle_work)
      observation.evidence_name = None
      observation.snapshots.clear()
    }
    let oracle_environment : Array[String] = []
    let environment_names = environment.keys().to_array()
    environment_names.sort_by((left, right) => left.lexical_compare(right))
    for name in environment_names {
      oracle_environment.append(["-e", name + "=" + environment[name]])
    }
    let trace_path = oracle_work + "/psl.trace"
    let observer = if trace_suffix {
      [
        "/usr/bin/strace", "-f", "-qq", "-yy", "-e", "trace=openat,read,close", "-s",
        "128", "-o", trace_path,
      ]
    } else {
      []
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
        ..oracle_environment,
        image,
        ..observer,
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
    if trace_suffix {
      let trace = @fs.read_file(trace_path).text()
      guard trace.contains("/usr/share/publicsuffix/public_suffix_list.dat") &&
        trace.contains("</usr/share/publicsuffix/public_suffix_list.dat>,") else {
        fail("real oracle client did not read the pinned public suffix file")
      }
    }
    @fs.write_file(
      prefix + ".oracle.execution.json",
      @harness.canonical_json({
        "command": Json(command),
        "args": Json(oracle_args),
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
