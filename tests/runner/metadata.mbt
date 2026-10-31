///|
struct MetadataObservation {
  status : Int32
  stdout : String
  stderr : String
  unread : String
} derive(FromJson)

///|
// A separate observer retains the inherited input descriptor after the command
// exits. Reading its remaining bytes detects even a partial stdin consumption.
async fn metadata_observer(args : ArrayView[String]) -> Unit {
  guard args.length() > 0 else { fail("metadata observer requires a command") }
  let (status, output, errors) = @process.collect_output(
    args[0],
    args[1:],
    stdin=@stdio.stdin,
  )
  let remaining = @stdio.stdin.read_all()
  let observation : Json = {
    "status": status,
    "stdout": @utf8.decode(output.binary()),
    "stderr": @utf8.decode(errors.binary()),
    "unread": @utf8.decode(remaining.binary()),
  }
  @stdio.stdout.write(observation.stringify())
}

///|
async fn invocation(
  name : String,
  root : String,
  args : Array[String],
  evidence : String,
  probe : String,
) -> @testkit.RunResult {
  let completed = @testkit.run_with_deadline(
    @fs.realpath(@env.args()[0]),
    ["--metadata-observer", ..@testkit.command_line(root, name, args)],
    15000,
    stdin=b"metadata stdin must remain unread\n",
  )
  guard !completed.timed_out &&
    completed.cleanup_error is None &&
    completed.output.status == 0 else {
    fail(
      "metadata observer failed or timed out: " +
      @utf8.decode_lossy(completed.output.stderr),
    )
  }
  let observation : MetadataObservation = @json.from_json(
    @json.parse(@utf8.decode(completed.output.stdout)),
  )
  guard observation.unread == "metadata stdin must remain unread\n" else {
    fail("metadata command consumed stdin: " + name + " " + probe)
  }
  let actual : @testkit.RunResult = {
    status: observation.status,
    stdout: @utf8.encode(observation.stdout),
    stderr: @utf8.encode(observation.stderr),
  }
  @fs.write_file(evidence + "/" + probe + ".stdout.bin", actual.stdout)
  @fs.write_file(evidence + "/" + probe + ".stderr.bin", actual.stderr)
  @fs.write_file(
    evidence + "/" + probe + ".status.txt",
    actual.status.to_string(),
  )
  if completed.cleanup_error is Some(error) {
    fail("metadata child cleanup: " + error)
  }
  guard !completed.timed_out else {
    fail("metadata probe deadline expired: " + probe)
  }
  actual
}

///|
async fn metadata_report(
  name : String,
  root : String,
  backend : String,
  directory : String,
  retain_success~ : Bool = false,
  fixture? : @testkit.Case,
) -> @testkit.CaseReport {
  let started = @async.now()
  let evidence = directory + "/metadata-" + name
  let base : @testkit.CaseReport = {
    id: "metadata:" + name,
    command: name,
    result: "pass",
    verification: "contract",
    stage: "complete",
    detail: "",
    platform: @testkit.host_platform(),
    backend,
    source_version: "workspace",
    duration_ms: 0L,
    observations: [],
    missing_observations: [],
    local_contract: None,
    evidence: Some(evidence),
  }
  try {
    @fs.mkdir(evidence)
    let version = @testkit.metadata_version(name)
    let help = invocation(name, root, ["--help"], evidence, "help")
    let help_text = @utf8.decode(help.stdout)
    let declared_errors = match fixture {
      Some(definition) => @testkit.check_contract(definition, help, root)
      None => []
    }
    let help_ok = declared_errors.is_empty() &&
      help.status == 0 &&
      help.stderr == b"" &&
      help_text.has_prefix("Usage: " + name) &&
      help_text.has_suffix("\n") &&
      help_text.contains("--help") &&
      help_text.contains("--version")
    let actual_version = invocation(
      name,
      root,
      ["--version"],
      evidence,
      "version",
    )
    let expected = @utf8.encode(name + " " + version + "\n")
    let mut version_ok = actual_version.status == 0 &&
      actual_version.stderr == b"" &&
      actual_version.stdout == expected
    if [
        "cksum", "column", "csplit", "date", "diff", "env", "fmt", "fold", "gunzip",
        "gzip", "hexdump", "md5sum", "od", "patch", "realpath", "sed", "seq", "sha1sum",
        "sha512sum", "split", "strings", "tree", "unlink", "which", "zcat",
      ].contains(name) {
      let combined = invocation(
        name,
        root,
        ["--version", "metadata-unused-operand"],
        evidence,
        "combined-version",
      )
      version_ok = version_ok &&
        combined.status == 0 &&
        combined.stderr == b"" &&
        combined.stdout == expected
    }
    if name == "hexdump" || name == "rg" {
      let alias_result = invocation(
        name,
        root,
        ["-V"],
        evidence,
        "version-alias",
      )
      version_ok = version_ok &&
        alias_result.status == 0 &&
        alias_result.stderr == b"" &&
        alias_result.stdout == expected
    }
    if help_ok && version_ok && !retain_success {
      @fs.rmdir(evidence, recursive=true)
    }
    {
      ..base,
      result: if help_ok && version_ok {
        "pass"
      } else {
        "fail"
      },
      stage: if help_ok && version_ok {
        "complete"
      } else {
        "assertion"
      },
      detail: "help=\{help_ok} version=\{version_ok}" +
      (if declared_errors.is_empty() {
        ""
      } else {
        "; " + declared_errors.join("; ")
      }),
      duration_ms: @async.now() - started,
      observations: ["status", "stdout", "stderr", "stdin-unread"],
      evidence: if help_ok && version_ok && !retain_success {
        None
      } else {
        Some(evidence)
      },
    }
  } catch {
    error =>
      {
        ..base,
        result: "infra",
        stage: "metadata-probe",
        detail: error.to_string(),
        duration_ms: @async.now() - started,
      }
  }
}
