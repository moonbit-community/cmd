///|
pub(all) struct Launch {
  program : String
  prefix : Array[String]
  source_version : String
  published : Bool
}

///|
async fn retain_launch(
  launch : Launch,
  args : Array[String],
  trace : String,
) -> Unit {
  if launch.published {
    @fs.write_file(
      trace + ".invocation.json",
      @testkit.canonical_json({
        "backend": "published-wasm",
        "source_version": launch.source_version,
        "program": launch.program,
        "args": launch.prefix + args,
      }),
    )
  }
}

///|
async fn run_mv(
  launch : Launch,
  work : String,
  args : Array[String],
  directory : String,
) -> @testkit.RunResult {
  let traces = @path.Path(work).dirname().join(Path("streams")).to_string()
  @fs.mkdir(traces, recursive=true, allow_exist=true)
  let prefix = traces + "/mv-\{@fs.readdir(traces).length()}"
  retain_launch(launch, args, prefix)
  let completed = @testkit.run_with_deadline(
    launch.program,
    launch.prefix + args,
    15000,
    stdin=b"",
    cwd=directory,
  )
  @fs.write_file(prefix + ".stdout.bin", completed.output.stdout)
  @fs.write_file(prefix + ".stderr.bin", completed.output.stderr)
  @fs.write_file(prefix + ".status.txt", completed.output.status.to_string())
  if completed.cleanup_error is Some(error) {
    fail("cleanup infrastructure: " + error)
  }
  if completed.timed_out {
    fail("scenario command deadline expired; streams are partial")
  }
  completed.output
}

///|
pub async fn run_helper(args : ArrayView[String]) -> Unit {
  match args {
    ["status-124"] => @sys.exit(124)
    ["capture-then-wait"] => {
      @stdio.stdout.write("partial stdout\n")
      @stdio.stderr.write("partial stderr\n")
      @async.sleep(60000)
    }
    ["read-line"] =>
      for ;; {
        guard @stdio.stdin.read_some(max_len=1) is Some(byte) else { break }
        if byte[0] == b'\n' {
          break
        }
      }
    _ => fail("invalid mv observation helper")
  }
}

///|
pub fn observations() -> Array[String] {
  [
    "status", "stdout", "stderr", "stdout-bytes", "stderr-contract", "content", "type",
    "file-content", "file-type", "symlink-target", "link-type", "referent-content",
    "unchanged-snapshot", "stdin-open", "nonzero-status", "diagnostic",
  ]
}
