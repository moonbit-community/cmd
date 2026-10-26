///|
/// Parses the contents of a ripgrep config file: one argument per line,
/// ignoring blank lines and lines starting with `#` (after trimming).
/// Returns the arguments and any per-line errors.
pub fn parse_config_bytes(data : Bytes) -> (Array[String], Array[String]) {
  let args = []
  let errs = []
  let mut line_number = 0
  let mut start = 0
  let n = data.length()
  while start < n {
    let mut end = start
    while end < n && data[end] != b'\n' {
      end += 1
    }
    line_number += 1
    // Decode losslessly (ripgrep accepts arbitrary bytes here) and trim
    // Unicode whitespace like bstr's `trim`.
    let line = @osstr.trim_white_space(@osstr.decode(data[start:end]))
    start = end + 1
    if line.is_empty() || line.has_prefix("#") {
      continue
    }
    ignore(line_number)
    args.push(line)
  }
  (args, errs)
}

///|
/// Reads extra arguments from the file in `RIPGREP_CONFIG_PATH`, if set.
pub async fn config_args() -> Array[String] {
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
  let (args, errs) = parse_config_bytes(data)
  for err in errs {
    message("\{config_path}:\{err}")
  }
  log_debug(
    "rg::flags::config",
    "\{config_path}: arguments loaded from config file: \{Repr(args)}",
  )
  args
}
