///|
async fn report(path : String, error : Error) -> Unit {
  let message = match error {
    Failure(reason) => reason
    @cli.CliError(option~, message~, ..) => message + ": " + option
    other => other.to_string()
  }
  @stdio.stderr.text.write(
    "du: " + (if path == "" { "" } else { path + ": " }) + message + "\n",
  )
}

///|
async fn run(args : ArrayView[String]) -> Int32 {
  let parsed = @cli.parse(args, option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return 0
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("du \{MODULE_VERSION}\n")
    return 0
  }
  guard !parsed.operands.is_empty() else { raise Failure("missing operand") }
  guard parsed.contains("bytes") || parsed.contains("apparent-size") else {
    raise Failure(
      "allocated block counts are unavailable; use --apparent-size or -b",
    )
  }
  let deduplicate = parsed.operands.length() > 1 &&
    !parsed.contains("count-links")
  if deduplicate && @platform.is_windows() {
    raise Failure("multiple operands on Windows require -l to count each name")
  }
  let seen : Array[@xfs.FileIdentity] = []
  let unit = match
    parsed.last_occurrence(["bytes", "block-size", "kilobytes"]) {
    Some("bytes") => 1L
    Some("block-size") =>
      @usage.block_size(parsed.last_value("block-size").unwrap())
    _ => 1024L
  }
  let end = if parsed.contains("null") { "\u0000" } else { "\n" }
  let mut total = 0L
  let mut status = 0
  for path in parsed.operands {
    let size = @usage.apparent(path, follow=parsed.contains("dereference")) catch {
      error => {
        report(path, error)
        status = 1
        continue
      }
    }
    if deduplicate {
      let identity = @xfs.identity(
        path,
        follow_symlink=parsed.contains("dereference"),
      ) catch {
        error => {
          report(path, error)
          status = 1
          continue
        }
      }
      guard identity is Some(id) else {
        report(path, Failure("file identity unavailable; use -l"))
        status = 1
        continue
      }
      if seen.contains(id) {
        continue
      }
      seen.push(id)
    }
    guard size <= 9223372036854775807L - total else {
      raise Failure("total size overflow")
    }
    total += size
    @stdio.stdout.text.write(
      @usage.blocks(size, unit).to_string() + "\t" + path + end,
    )
  }
  if parsed.contains("total") {
    @stdio.stdout.text.write(
      @usage.blocks(total, unit).to_string() + "\ttotal" + end,
    )
  }
  status
}

///|
pub async fn run_main() -> Unit {
  let status = run(@env.args()[1:]) catch {
    error => {
      report("", error)
      1
    }
  }
  if status != 0 {
    @env.exit(status)
  }
}
