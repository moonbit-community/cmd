///|
async fn report(path : String, error : Error) -> Unit {
  if error is @usage.UnreadableDirectory {
    @stdio.stderr.text.write(
      "du: cannot read directory '\{path}': Permission denied\n",
    )
    return
  }
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
  let apparent = parsed.contains("bytes") || parsed.contains("apparent-size")
  let inodes = parsed.contains("inodes")
  guard apparent || inodes else {
    raise Failure(
      "allocated block counts are unavailable; use --apparent-size or -b",
    )
  }
  guard !(parsed.contains("all") && parsed.contains("summarize")) else {
    raise Failure("cannot both summarize and show all entries")
  }
  if inodes && apparent {
    @stdio.stderr.text.write(
      "du: warning: options --apparent-size and -b are ineffective with --inodes\n",
    )
  }
  let unit = match
    parsed.last_occurrence(["bytes", "block-size", "kilobytes"]) {
    Some("bytes") => 1L
    Some("block-size") =>
      @usage.block_size(parsed.last_value("block-size").unwrap())
    _ => 1024L
  }
  let end = if parsed.contains("null") { "\u0000" } else { "\n" }
  let mut status = 0
  let operands = if parsed.operands.is_empty() {
    ["."]
  } else {
    parsed.operands
  }
  let print_size : async (String, Int64) -> Unit = (path, size) => {
    @stdio.stdout.text.write(
      @usage.blocks(size, if inodes { 1L } else { unit }).to_string() +
      "\t" +
      path +
      end,
    )
  }
  let total = @usage.measure(
    operands[:],
    detail=if parsed.contains("all") {
      All
    } else if parsed.contains("summarize") {
      Summary
    } else {
      Directories
    },
    follow=parsed.contains("dereference"),
    count_links=parsed.contains("count-links"),
    inodes~,
    emit=print_size,
    report=(path, error) => {
      status = 1
      report(path, error)
    },
  )
  if parsed.contains("total") {
    print_size("total", total)
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
