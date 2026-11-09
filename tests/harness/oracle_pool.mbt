///|
priv struct OracleWorker {
  owner : OracleContainerOwner
  signature : Array[String]
  mut busy : Bool
  mut invocations : Int32
  execute : async (OracleProcessInvocation) -> TimedRun
}

///|
priv struct OraclePool {
  root : String
  image : String
  limit : Int32
  mut workers : Array[OracleWorker]
  mut creating : Int32
  mut failure : String?
  available : @cond_var.Cond
  execute : async (OracleProcessInvocation) -> TimedRun
}

///|
let oracle_pool : Ref[OraclePool?] = Ref(None)

///|
priv struct OracleExec {
  configuration : Array[String]
  environment : Array[String]
  directory : String?
  command : Array[String]
}

///|
fn oracle_exec_plan(
  args : Array[String],
  root : String,
  image : String,
) -> OracleExec? raise {
  validate_oracle_run_args(args)
  let configuration = [
    "--read-only",
    "--tmpfs",
    "/tmp:rw,nosuid,nodev,size=64m",
    "-v",
    root + ":" + root + ":rw",
  ]
  let environment : Array[String] = []
  let mut directory = None
  let mut index = 1
  while index < args.length() {
    match args[index] {
      "--rm" | "-i" | "--interactive" | "--read-only" => index += 1
      "--user" | "-u" | "--network" => {
        configuration.append([args[index], args[index + 1]])
        index += 2
      }
      "--tmpfs" => {
        if args[index + 1] != "/tmp:rw,nosuid,nodev,size=64m" {
          return None
        }
        index += 2
      }
      "-e" | "--env" => {
        environment.append(["-e", args[index + 1]])
        index += 2
      }
      "-w" | "--workdir" => {
        let value = args[index + 1]
        if value != root && !value.has_prefix(root + "/") {
          return None
        }
        directory = Some(value)
        index += 2
      }
      "-v" | "--volume" => {
        let parts = args[index + 1]
          .split(":")
          .map(StringView::to_owned)
          .collect()
        guard parts is [source, target, mode] && source == target else {
          return None
        }
        if source == root || source.has_prefix(root + "/") {
          if mode != "rw" {
            return None
          }
        } else if mode == "ro" {
          configuration.append(["-v", args[index + 1]])
        } else {
          return None
        }
        index += 2
      }
      value if value == image =>
        return Some({
          configuration,
          environment,
          directory,
          command: args[index + 1:].to_owned(),
        })
      _ => return None
    }
  }
  None
}

///|
async fn oracle_worker_control(
  invocation : OracleProcessInvocation,
) -> TimedRun {
  run_with_deadline(
    "docker",
    invocation.args,
    invocation.timeout_ms,
    stdin=invocation.stdin,
  )
}

///|
async fn stop_oracle_worker(worker : OracleWorker) -> Unit {
  if cleanup_oracle_container(
      worker.owner,
      "worker-finished",
      worker.execute,
      interrupted=false,
    )
    is Some(error) {
    fail(error)
  }
  @fs.rmdir(worker.owner.reservation, recursive=true)
}

///|
async fn start_oracle_worker(
  pool : OraclePool,
  configuration : Array[String],
) -> OracleWorker {
  let reservation = @fs.tmpdir(prefix="mooncmd-oracle-worker-")
  let token = @path.Path(reservation).basename().to_owned()
  let evidence = pool.root + "/oracle-workers/" + token
  {
    errdefer @fs.rmdir(reservation, recursive=true)
    @fs.mkdir(evidence, recursive=true)
  }
  let owner = { name: token, token, evidence, reservation, }
  let started = Ref(false)
  defer (if !started.val {
    @async.protect_from_cancel(() => {
      if cleanup_oracle_container(
          owner,
          "worker-start-failed",
          pool.execute,
          interrupted=true,
        )
        is Some(error) {
        fail(error)
      }
      @fs.rmdir(reservation, recursive=true)
    })
  })
  let errors : Array[String] = []
  let result = oracle_control(
    owner,
    "start",
    [
      "run",
      "-d",
      "--name",
      token,
      "--label",
      oracle_owner_label + "=" + token,
      ..configuration,
      pool.image,
      "/bin/sleep",
      "infinity",
    ],
    pool.execute,
    errors,
  )
  let output = oracle_control_output(result, "worker start")
  let id = @utf8.decode(output.stdout).trim().to_owned()
  guard valid_sha256(id) else { fail("invalid oracle worker identity") }
  let inspected = oracle_control_output(
    oracle_control(
      owner,
      "inspect-start",
      ["container", "inspect", id],
      pool.execute,
      errors,
    ),
    "worker identity",
  )
  verify_owned_oracle_container(owner, id, inspected.stdout)
  guard errors.is_empty() else { fail(errors.join("; ")) }
  started.val = true
  container_starts.val += 1
  {
    owner,
    signature: configuration,
    busy: true,
    invocations: 0,
    execute: pool.execute,
  }
}

///|
async fn borrow_oracle_worker(
  pool : OraclePool,
  configuration : Array[String],
) -> OracleWorker {
  for ;; {
    if pool.failure is Some(error) {
      fail("oracle pool unavailable: " + error)
    }
    if pool.workers
      .iter()
      .find_first(worker => !worker.busy && worker.signature == configuration)
      is Some(worker) {
      worker.busy = true
      return worker
    }
    if pool.workers.length() + pool.creating < pool.limit {
      pool.creating += 1
      defer {
        pool.creating -= 1
        pool.available.broadcast()
      }
      let worker = {
        errdefer {
          pool.failure = Some("worker creation failed")
        }
        start_oracle_worker(pool, configuration)
      }
      pool.workers.push(worker)
      return worker
    }
    if pool.workers.iter().find_first(worker => !worker.busy) is Some(worker) {
      worker.busy = true
      {
        errdefer {
          pool.failure = Some("worker replacement cleanup failed")
          pool.available.broadcast()
        }
        stop_oracle_worker(worker)
      }
      pool.workers = pool.workers.filter(item => {
        item.owner.token != worker.owner.token
      })
      pool.available.broadcast()
      continue
    }
    pool.available.wait()
  }
}

///|
fn oracle_worker_is_idle(output : Bytes) -> Bool {
  let text = @utf8.decode(output) catch { _ => return false }
  let rows = text.split("\n").filter(row => !row.trim().is_empty()).collect()
  rows.length() == 2 &&
  rows[0].trim() == "PID" &&
  rows[1].trim().iter().all(ch => ch >= '0' && ch <= '9')
}

///|
async fn run_in_oracle_worker(
  pool : OraclePool,
  plan : OracleExec,
  timeout_ms : Int32,
  evidence_dir : String,
  stdin : Bytes,
) -> TimedRun {
  let worker = borrow_oracle_worker(pool, plan.configuration)
  let reusable = Ref(false)
  worker.invocations += 1
  let temporary = worker.owner.evidence +
    "/tmp-" +
    worker.invocations.to_string()
  defer (if reusable.val { @fs.rmdir(temporary, recursive=true) })
  defer @async.protect_from_cancel(() => {
    if reusable.val {
      worker.busy = false
    } else {
      {
        errdefer {
          pool.failure = Some("worker cleanup failed")
          pool.available.broadcast()
        }
        stop_oracle_worker(worker)
      }
      pool.workers = pool.workers.filter(item => {
        item.owner.token != worker.owner.token
      })
    }
    pool.available.broadcast()
  })
  @fs.mkdir(temporary)
  @fs.mkdir(evidence_dir)
  let args = ["exec", "-i", ..plan.environment]
  if !plan.environment.any(value => value.has_prefix("TMPDIR=")) {
    args.append(["-e", "TMPDIR=" + temporary])
  }
  if plan.directory is Some(path) {
    args.append(["-w", path])
  }
  args.append([worker.owner.name, ..plan.command])
  @fs.write_file(
    evidence_dir + "/exec.json",
    canonical_json({ "worker": worker.owner.name, "args": Json(args) }),
  )
  let result = (pool.execute)({ args, timeout_ms, stdin, })
  @fs.write_file(
    evidence_dir + "/result.json",
    canonical_json({
      "status": result.output.status,
      "timed_out": result.timed_out,
      "cleanup_error": @json.to_json(result.cleanup_error),
    }),
  )
  if result.timed_out || result.cleanup_error is Some(_) {
    return result
  }
  let state = (pool.execute)({
    args: ["top", worker.owner.name, "-eo", "pid"],
    timeout_ms: 15000,
    stdin: b"",
  })
  @fs.write_file(evidence_dir + "/processes.txt", state.output.stdout)
  guard oracle_control_succeeded(state) &&
    oracle_worker_is_idle(state.output.stdout) else {
    fail("oracle worker retained a process or could not observe cleanup")
  }
  reusable.val = true
  result
}

///|
async fn with_oracle_workers_using(
  root : String,
  image : String,
  limit : Int32,
  control : async (OracleProcessInvocation) -> TimedRun,
  execute : async () -> Unit,
) -> Unit {
  guard oracle_pool.val is None && limit > 0 && limit <= 2 else {
    fail("invalid oracle worker scope")
  }
  let pool = {
    root: @fs.realpath(root),
    image,
    limit,
    workers: [],
    creating: 0,
    failure: None,
    available: @cond_var.Cond(),
    execute: control,
  }
  oracle_pool.val = Some(pool)
  defer @async.protect_from_cancel(() => {
    oracle_pool.val = None
    let errors : Array[String] = []
    for worker in pool.workers {
      stop_oracle_worker(worker) catch {
        error => errors.push(error.to_string())
      }
    }
    guard errors.is_empty() else { fail(errors.join("; ")) }
  })
  execute()
}

///|
pub async fn with_oracle_workers(
  root : String,
  image : String,
  limit : Int32,
  execute : async () -> Unit,
) -> Unit {
  with_oracle_workers_using(root, image, limit, oracle_worker_control, execute)
}
