///|
async fn run() -> Unit {
  let parsed = @cli.parse(@env.args()[1:], option_specs())
  if parsed.contains("help") {
    @stdio.stdout.text.write(metadata_help())
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.text.write("nproc \{MODULE_VERSION}\n")
    return
  }
  guard parsed.operands.is_empty() else {
    raise Failure::Failure("unexpected operand: " + parsed.operands[0])
  }
  let ignore = match parsed.last_value("ignore") {
    Some(raw) => @string.parse_uint64(raw)
    None => 0UL
  }
  let count = if parsed.contains("all") {
    guard @async.platform is Linux else {
      raise Failure::Failure("configured CPU count requires Linux sysfs")
    }
    let entries = @fs.readdir("/sys/devices/system/cpu")
    let cpus = entries.filter(name => {
      name.strip_prefix("cpu") is Some(number) &&
      !number.is_empty() &&
      number.iter().all(ch => ch >= '0' && ch <= '9')
    })
    guard !cpus.is_empty() else {
      raise Failure::Failure("no configured CPU entries")
    }
    cpus.length().to_uint64()
  } else {
    let limit = omp("OMP_THREAD_LIMIT").unwrap_or(0xffffffffffffffffUL)
    match omp("OMP_NUM_THREADS") {
      Some(threads) => threads.min(limit)
      None => {
        guard @async.platform is Linux else {
          raise Failure::Failure("CPU affinity requires Linux procfs")
        }
        current().min(limit)
      }
    }
  }
  @stdio.stdout.text.write(
    (if count > ignore { count - ignore } else { 1UL }).to_string() + "\n",
  )
}

///|
pub async fn run_main() -> Unit {
  run() catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.text.write("nproc: \{message}: '\{option}'\n")
      @env.exit(1)
    }
    Failure::Failure(message) => {
      @stdio.stderr.text.write("nproc: \{message}\n")
      @env.exit(1)
    }
    err => {
      @stdio.stderr.text.write("nproc: \{err}\n")
      @env.exit(1)
    }
  }
}
