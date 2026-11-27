///|
async fn report(path : String, error : Error) -> Unit {
  let message = match error {
    Failure(reason) => reason
    @cli.CliError(option~, message~, ..) => message + ": " + option
    other => other.to_string()
  }
  @stdio.stderr.text.write(
    "readlink: " + (if path == "" { "" } else { path + ": " }) + message + "\n",
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
    @stdio.stdout.text.write("readlink \{MODULE_VERSION}\n")
    return 0
  }
  guard !parsed.operands.is_empty() else { raise Failure("missing operand") }
  let existence : @pathresolve.Existence? = match
    parsed.last_occurrence([
      "canonicalize", "canonicalize-existing", "canonicalize-missing",
    ]) {
    Some("canonicalize") => Some(AllButLast)
    Some("canonicalize-existing") => Some(Existing)
    Some("canonicalize-missing") => Some(Missing)
    _ => None
  }
  let multi = parsed.operands.length() > 1
  if multi && parsed.contains("no-newline") {
    @stdio.stderr.text.write(
      "readlink: ignoring --no-newline with multiple arguments\n",
    )
  }
  let end = if parsed.contains("zero") {
    "\u0000"
  } else if parsed.contains("no-newline") && !multi {
    ""
  } else {
    "\n"
  }
  let mut status = 0
  for path in parsed.operands {
    match existence {
      Some(mode) => {
        let resolved = @pathresolve.resolve_path(path, mode, false) catch {
          @pathresolve.ReadlinkBoundary(_) => {
            @stdio.stderr.text.write(
              "readlink: stored symbolic-link target unavailable\n",
            )
            status = 1
            continue
          }
          error => {
            if parsed.contains("verbose") {
              @stdio.stderr.text.write(
                "readlink: " +
                path +
                ": " +
                @pathresolve.error_text(error) +
                "\n",
              )
            }
            status = 1
            continue
          }
        }
        @stdio.stdout.text.write(resolved + end)
      }
      None => {
        let kind = @fs.kind(path, follow_symlink=false) catch {
          error => {
            if parsed.contains("verbose") {
              report(path, error)
            }
            status = 1
            continue
          }
        }
        if kind is SymLink {
          @stdio.stderr.text.write(
            "readlink: stored symbolic-link target unavailable\n",
          )
        } else if parsed.contains("verbose") {
          @stdio.stderr.text.write("readlink: " + path + ": Invalid argument\n")
        }
        status = 1
      }
    }
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
