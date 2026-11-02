///|
priv struct OracleProcessInvocation {
  args : Array[String]
  timeout_ms : Int32
  stdin : Bytes
}

///|
priv struct OracleContainerOwner {
  name : String
  token : String
  evidence : String
  reservation : String
}

///|
let oracle_owner_label = "io.moonbit.cmd.oracle-owner"

///|
async fn save_oracle_lifecycle(
  owner : OracleContainerOwner,
  phase : String,
  error : String?,
) -> Unit {
  @fs.write_file(
    owner.evidence + "/lifecycle.json",
    canonical_json({
      "name": Json(owner.name),
      "owner_label": Json(oracle_owner_label),
      "owner_token": Json(owner.token),
      "reservation": Json(owner.reservation),
      "phase": Json(phase),
      "cleanup_error": ToJson::to_json(error),
    }) +
    "\n",
  )
}

///|
async fn record_oracle_file(
  owner : OracleContainerOwner,
  path : String,
  contents : &@io.Data,
  errors : Array[String],
) -> Unit {
  @fs.write_file(owner.evidence + "/" + path, contents) catch {
    error =>
      errors.push("lifecycle evidence " + path + ": " + error.to_string())
  }
}

///|
async fn oracle_control(
  owner : OracleContainerOwner,
  step : String,
  args : Array[String],
  execute : async (OracleProcessInvocation) -> TimedRun,
  evidence_errors : Array[String],
) -> TimedRun {
  record_oracle_file(
    owner,
    step + ".args.json",
    canonical_json(ToJson::to_json(args)) + "\n",
    evidence_errors,
  )
  let result = execute({ args, timeout_ms: 15000, stdin: b"", })
  record_oracle_file(
    owner,
    step + ".stdout.bin",
    result.output.stdout,
    evidence_errors,
  )
  record_oracle_file(
    owner,
    step + ".stderr.bin",
    result.output.stderr,
    evidence_errors,
  )
  record_oracle_file(
    owner,
    step + ".result.json",
    canonical_json({
      "status": Json(result.output.status),
      "timed_out": Json(result.timed_out),
      "cleanup_error": ToJson::to_json(result.cleanup_error),
    }) +
    "\n",
    evidence_errors,
  )
  result
}

///|
fn oracle_control_succeeded(result : TimedRun) -> Bool {
  !result.timed_out && result.cleanup_error is None && result.output.status == 0
}

///|
fn oracle_control_output(result : TimedRun, step : String) -> RunResult raise {
  guard !result.timed_out &&
    result.cleanup_error is None &&
    result.output.status == 0 else {
    fail("oracle container " + step + " did not complete successfully")
  }
  result.output
}

///|
fn oracle_container_ids(output : Bytes) -> Array[String] raise {
  let ids = @utf8.decode(output)
    .split("\n")
    .filter(line => line != "")
    .map(line => line.to_owned())
    .collect()
  guard ids.length() <= 1 && ids.all(valid_sha256) else {
    fail("oracle container discovery returned invalid or ambiguous IDs")
  }
  ids
}

///|
fn verify_owned_oracle_container(
  owner : OracleContainerOwner,
  expected_id : String,
  output : Bytes,
) -> Unit raise {
  let records : Array[Json] = @json.from_json(@json.parse(@utf8.decode(output)))
  guard records.length() == 1 else {
    fail("oracle container inspect must identify one container")
  }
  match records[0] {
    {
      "Id": String(id),
      "Name": String(name),
      "Config": { "Labels": labels, .. },
      ..
    } => {
      let labels : Map[String, String] = @json.from_json(labels)
      guard id == expected_id &&
        name == "/" + owner.name &&
        labels.get(oracle_owner_label) == Some(owner.token) else {
        fail("oracle container ownership mismatch; removal refused")
      }
    }
    _ => fail("oracle container inspect omitted ownership fields")
  }
}

///|
async fn owned_oracle_absent(
  owner : OracleContainerOwner,
  id : String,
  step : String,
  execute : async (OracleProcessInvocation) -> TimedRun,
  evidence_errors : Array[String],
) -> Bool {
  let exact = oracle_control_output(
    oracle_control(
      owner,
      step + "-id",
      ["ps", "-a", "--no-trunc", "--filter", "id=" + id, "--format={{.ID}}"],
      execute,
      evidence_errors,
    ),
    step,
  )
  let owned = oracle_control_output(
    oracle_control(
      owner,
      step + "-owner",
      [
        "ps",
        "-a",
        "--no-trunc",
        "--filter",
        "label=" + oracle_owner_label + "=" + owner.token,
        "--format={{.ID}}",
      ],
      execute,
      evidence_errors,
    ),
    step,
  )
  oracle_container_ids(exact.stdout).is_empty() &&
  oracle_container_ids(owned.stdout).is_empty()
}

///|
async fn cleanup_oracle_container(
  owner : OracleContainerOwner,
  phase : String,
  execute : async (OracleProcessInvocation) -> TimedRun,
  interrupted~ : Bool,
) -> String? {
  let evidence_errors : Array[String] = []
  save_oracle_lifecycle(owner, phase, None) catch {
    error => evidence_errors.push("lifecycle phase: " + error.to_string())
  }
  let cleanup_error = try {
    let discovered = oracle_control_output(
      oracle_control(
        owner,
        "discover",
        [
          "ps",
          "-a",
          "--no-trunc",
          "--filter",
          "label=" + oracle_owner_label + "=" + owner.token,
          "--format={{.ID}}",
        ],
        execute,
        evidence_errors,
      ),
      "discover",
    )
    let ids = oracle_container_ids(discovered.stdout)
    if ids.is_empty() && interrupted {
      fail(
        "interrupted Docker create has no observed container identity; delayed daemon-create boundary unresolved",
      )
    }
    if ids.length() == 1 {
      let id = ids[0]
      // Preserve full daemon state before any destructive cleanup, and verify
      // both the unique invocation name and label before removing an exact ID.
      let inspected = oracle_control(
        owner,
        "inspect-before-remove",
        ["container", "inspect", id],
        execute,
        evidence_errors,
      )
      if inspected.timed_out || inspected.cleanup_error is Some(_) {
        evidence_errors.push(
          "oracle container cleanup failed: inspect control lifecycle incomplete",
        )
      }
      if oracle_control_succeeded(inspected) {
        verify_owned_oracle_container(owner, id, inspected.output.stdout)
        let removed = oracle_control(
          owner,
          "remove",
          ["rm", "--force", id],
          execute,
          evidence_errors,
        )
        if removed.timed_out || removed.cleanup_error is Some(_) {
          evidence_errors.push(
            "oracle container cleanup failed: remove control lifecycle incomplete",
          )
        }
        if !oracle_control_succeeded(removed) {
          guard owned_oracle_absent(
            owner, id, "remove-race-absence", execute, evidence_errors,
          ) else {
            fail("oracle container removal failed and absence is unproved")
          }
        } else if !owned_oracle_absent(
            owner, id, "verify-absence", execute, evidence_errors,
          ) {
          fail("oracle container remains after exact-ID removal")
        }
      } else if !owned_oracle_absent(
          owner, id, "inspect-race-absence", execute, evidence_errors,
        ) {
        fail("oracle container inspect failed and absence is unproved")
      }
    }
    None
  } catch {
    error => Some("oracle container cleanup failed: " + error.to_string())
  }
  let errors = evidence_errors
  if cleanup_error is Some(error) {
    errors.push(error)
  }
  let detail = if errors.is_empty() { None } else { Some(errors.join("; ")) }
  save_oracle_lifecycle(
    owner,
    phase + (if detail is None { "-cleaned" } else { "-cleanup-failed" }),
    detail,
  ) catch {
    error => errors.push("lifecycle final phase: " + error.to_string())
  }
  if errors.is_empty() {
    None
  } else {
    Some(errors.join("; ") + "; retained reservation=" + owner.reservation)
  }
}

///|
fn validate_oracle_run_args(args : Array[String]) -> Unit raise {
  guard args.get(0) == Some("run") else {
    fail("owned oracle execution requires docker run --rm")
  }
  let mut index = 1
  let mut remove = false
  while index < args.length() {
    let option = args[index]
    match option {
      "--rm" => {
        remove = true
        index += 1
      }
      "-i" | "--interactive" | "--read-only" => index += 1
      "--user"
      | "-u"
      | "--network"
      | "--tmpfs"
      | "-v"
      | "--volume"
      | "-w"
      | "--workdir"
      | "-e"
      | "--env" => {
        guard args.get(index + 1) is Some(_) else {
          fail("missing Docker run option value")
        }
        index += 2
      }
      "--label" | "-l" => {
        guard args.get(index + 1) is Some(value) else {
          fail("missing Docker label value")
        }
        guard value != oracle_owner_label &&
          !value.has_prefix(oracle_owner_label + "=") else {
          fail("caller cannot override oracle container ownership")
        }
        index += 2
      }
      _ if option == "--name" || option.has_prefix("--name=") =>
        fail("caller cannot override oracle container name")
      _ if option.has_prefix("--label=") => {
        let value = option.strip_prefix("--label=").unwrap()
        guard value != oracle_owner_label[:] &&
          !value.has_prefix(oracle_owner_label + "=") else {
          fail("caller cannot override oracle container ownership")
        }
        index += 1
      }
      "--" => {
        index += 1
        break
      }
      _ if option.has_prefix("-") =>
        fail("unsupported owned oracle Docker run option: " + option)
      _ => break
    }
  }
  guard remove && args.get(index) is Some(_) else {
    fail("owned oracle execution requires docker run --rm and an image")
  }
}

///|
async fn run_oracle_with_deadline_using(
  args : Array[String],
  timeout_ms : Int32,
  evidence_dir : String,
  execute : async (OracleProcessInvocation) -> TimedRun,
  stdin~ : Bytes = b"",
) -> TimedRun {
  validate_oracle_run_args(args)
  // Atomic directory creation reserves a fresh invocation token across drivers.
  // An uncertain cleanup retains this reservation for manual diagnosis.
  let reservation = @fs.tmpdir(prefix="mooncmd-oracle")
  let retain_reservation = Ref(false)
  defer (if !retain_reservation.val {
    @fs.rmdir(reservation, recursive=true) catch {
      _ => ()
    }
  })
  let token = @path.Path(reservation).basename().to_owned()
  @fs.mkdir(evidence_dir)
  let owner = { name: token, token, evidence: evidence_dir, reservation, }
  let owned_args = [
    "run",
    "--name",
    owner.name,
    "--label",
    oracle_owner_label + "=" + owner.token,
    ..args[1:],
  ]
  @fs.write_file(
    evidence_dir + "/run.args.json",
    canonical_json(ToJson::to_json(owned_args)) + "\n",
  )
  save_oracle_lifecycle(owner, "running", None)
  let cleaned = Ref(false)
  let result_observed : Ref[TimedRun?] = Ref(None)
  let failure : Ref[String?] = Ref(None)
  defer (if !cleaned.val {
    let phase = if @async.is_being_cancelled() {
      "outer-cancelled"
    } else {
      "exception"
    }
    @async.protect_from_cancel(() => {
      let error = cleanup_oracle_container(
        owner,
        phase,
        execute,
        interrupted=match result_observed.val {
          None => true
          Some(result) =>
            result.timed_out ||
            result.output.status < 0 ||
            result.cleanup_error is Some(_)
        },
      )
      if error is Some(_) {
        retain_reservation.val = true
      }
      if failure.val is Some(invocation_error) {
        @fs.write_file(
          evidence_dir + "/invocation-error.txt",
          invocation_error + "\n",
        ) catch {
          _ => retain_reservation.val = true
        }
      }
      if error is Some(detail) {
        fail(
          detail +
          (match failure.val {
            Some(original) => "; invocation failed: " + original
            None => ""
          }),
        )
      }
    })
  })
  let result = execute({ args: owned_args, timeout_ms, stdin, }) catch {
    error => {
      failure.val = Some(error.to_string())
      fail("oracle invocation failed: " + error.to_string())
    }
  }
  result_observed.val = Some(result)
  let evidence_errors : Array[String] = []
  record_oracle_file(
    owner,
    "run.result.json",
    canonical_json({
      "status": Json(result.output.status),
      "timed_out": Json(result.timed_out),
      "cleanup_error": ToJson::to_json(result.cleanup_error),
    }) +
    "\n",
    evidence_errors,
  )
  if !result.timed_out &&
    result.cleanup_error is None &&
    result.output.status == 0 {
    // Docker's normal --rm completion is the fast path. Abnormal completion
    // and cancellation require independent daemon ownership observations.
    save_oracle_lifecycle(owner, "completed-with-rm", None) catch {
      error =>
        evidence_errors.push(
          "lifecycle normal completion: " + error.to_string(),
        )
    }
    if evidence_errors.is_empty() {
      cleaned.val = true
      return result
    }
  }
  let cleanup_error = @async.protect_from_cancel(() => {
    cleanup_oracle_container(
      owner,
      "abnormal-exit",
      execute,
      interrupted=result.timed_out ||
        result.output.status < 0 ||
        result.cleanup_error is Some(_),
    )
  })
  cleaned.val = true
  let cleanup_error = match (cleanup_error, evidence_errors.is_empty()) {
    (None, true) => None
    (Some(error), true) => Some(error)
    (None, false) =>
      Some(evidence_errors.join("; ") + "; retained reservation=" + reservation)
    (Some(error), false) => Some(error + "; " + evidence_errors.join("; "))
  }
  retain_reservation.val = cleanup_error is Some(_) ||
    result.cleanup_error is Some(_)
  {
    ..result,
    cleanup_error: match (result.cleanup_error, cleanup_error) {
      (Some(first), Some(second)) => Some(first + "; " + second)
      (Some(error), None) | (None, Some(error)) => Some(error)
      (None, None) => None
    },
  }
}

///|
/// Run a command oracle with invocation-owned Docker container cleanup.
/// `args` must use the runners' Docker option prefix and `run --rm` contract.
/// Lifecycle evidence is retained in the new `evidence_dir`; a successful
/// normal exit uses --rm. Interrupted creation without observed container
/// identity remains an infrastructure boundary, with its token reserved.
pub async fn run_oracle_with_deadline(
  docker : String,
  args : Array[String],
  timeout_ms : Int32,
  evidence_dir~ : String,
  stdin~ : Bytes = b"",
  extra_env~ : Map[String, String] = Map([]),
  inherit_env~ : Bool = true,
) -> TimedRun {
  run_oracle_with_deadline_using(
    args,
    timeout_ms,
    evidence_dir,
    invocation => {
      run_with_deadline(
        docker,
        invocation.args,
        invocation.timeout_ms,
        stdin=invocation.stdin,
        extra_env~,
        inherit_env~,
      )
    },
    stdin~,
  )
}
