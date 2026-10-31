///|
/// Parses the contents of a ripgrep config file: one argument per line,
/// ignoring blank lines and lines starting with `#` (after trimming).
pub fn parse_config_bytes(data : Bytes) -> Array[String] {
  let args = []
  let mut start = 0
  let n = data.length()
  while start < n {
    let mut end = start
    while end < n && data[end] != b'\n' {
      end += 1
    }
    // Decode losslessly (ripgrep accepts arbitrary bytes here) and trim
    // Unicode whitespace like bstr's `trim`.
    let line = @osstr.trim_white_space(@osstr.decode(data[start:end]))
    start = end + 1
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    args.push(line)
  }
  args
}

///|
/// Reads extra arguments from the file in `RIPGREP_CONFIG_PATH`, if set.
async fn config_args() -> Array[String] {
  let config_path = match @sys.env_var("RIPGREP_CONFIG_PATH") {
    None => {
      log_debug(
        "rg::flags::config", "RIPGREP_CONFIG_PATH environment variable is not set, therefore not reading any config file",
      )
      return []
    }
    Some(p) => {
      if p.is_empty() {
        return []
      }
      p
    }
  }
  let data = @sys.read_file(config_path) catch {
    e => {
      message(
        "failed to read the file specified in RIPGREP_CONFIG_PATH: \{config_path}: \{e}",
      )
      return []
    }
  }
  let args = parse_config_bytes(data)
  log_debug(
    "rg::flags::config",
    "\{config_path}: arguments loaded from config file: \{Repr(args)}",
  )
  args
}
