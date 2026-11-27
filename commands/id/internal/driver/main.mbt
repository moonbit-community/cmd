///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("id \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  let modes = ["user", "group", "groups"].filter(mode => parsed.contains(mode))
  guard modes is [mode] else {
    raise Failure::Failure("select exactly one of -u, -g or -G")
  }
  let cred = @procfs.credentials()
  let real = parsed.contains("real")
  let numeric = match mode {
    "user" => [if real { cred.real_uid } else { cred.effective_uid }]
    "group" => [if real { cred.real_gid } else { cred.effective_gid }]
    _ => cred.groups
  }
  let result = if parsed.contains("name") {
    @procfs.local_names(if mode == "user" { Passwd } else { Group }, numeric)
  } else {
    numeric
  }
  @stdio.stdout.text.write(
    if parsed.contains("zero") {
      result.join("\u0000") + "\u0000"
    } else {
      result.join(" ") + "\n"
    },
  )
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("id: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("id: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("id: \{err}\n")
      @env.exit(1)
    }
  }
}
