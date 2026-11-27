///|
pub(all) suberror TerminalError {
  TerminalError(Int32, String)
}

///|
/// Locate a directory-format ncurses entry. Both character and hexadecimal
/// subdirectories are used by ncurses installations.
pub async fn lookup(specified : String?) -> @terminfo.Entry {
  let name = specified.unwrap_or_else(() => {
    @env.get_env_var("TERM").unwrap_or("")
  })
  guard !name.is_empty() else {
    raise TerminalError(2, "terminal type is required")
  }
  guard name
    .iter()
    .all(ch => {
      ch.is_ascii_alphabetic() ||
      ch.is_ascii_digit() ||
      ch is ('-' | '_' | '.' | '+')
    }) &&
    name != "." &&
    name != ".." else {
    raise TerminalError(3, "invalid terminal type")
  }
  let system = ["/etc/terminfo", "/lib/terminfo", "/usr/share/terminfo"]
  let dirs : Array[String] = []
  if @env.get_env_var("TERMINFO") is Some(path) && !path.is_empty() {
    guard !path.has_prefix("hex:") && !path.has_prefix("b64:") else {
      raise TerminalError(3, "inline terminal databases are unsupported")
    }
    dirs.push(path)
  }
  if @env.get_env_var("HOME") is Some(home) && !home.is_empty() {
    dirs.push(home + "/.terminfo")
  }
  if @env.get_env_var("TERMINFO_DIRS") is Some(paths) {
    let separator = if @async.platform is Windows { ";" } else { ":" }
    for path in paths.split(separator) {
      if path.is_empty() {
        dirs.append(system)
      } else {
        dirs.push(path.to_owned())
      }
    }
  }
  if !(@async.platform is Windows) {
    dirs.append(system)
  }
  let first = name.iter().next().unwrap()
  for dir in dirs {
    for key in [first.to_string(), first.to_int().to_byte().to_hex()] {
      let bytes = @fs.read_binary(dir + "/" + key + "/" + name) catch {
        @os_error.OsError(NotFound, ..) => continue
        @os_error.OsError(NotDirectory, ..) =>
          raise TerminalError(3, "unsupported terminal database " + dir)
        err => raise err
      }
      return decode(bytes) catch {
        _ =>
          raise TerminalError(3, "invalid terminal database entry for " + name)
      }
    }
  }
  raise TerminalError(3, "unknown terminal '" + name + "'")
}

///|
fn output_bytes(data : Bytes) -> Bytes raise {
  for i = 1; i < data.length(); i = i + 1 {
    if data[i - 1] == b'$' && data[i] == b'<' {
      raise TerminalError(4, "capability requires terminal padding")
    }
  }
  data
}

///|
pub fn clear(entry : @terminfo.Entry, keep_scrollback : Bool) -> Bytes raise {
  guard entry.get_str_code("clear") is Some(screen) else {
    raise TerminalError(1, "")
  }
  let extra = if keep_scrollback {
    b""
  } else {
    entry.get_str("E3").unwrap_or(b"")
  }
  output_bytes(screen + extra)
}

///|
pub fn capability(
  entry : @terminfo.Entry,
  name : String,
  args : ArrayView[String],
  explicit_type : Bool,
) -> Bytes raise {
  if name == "clear" && args.is_empty() {
    return clear(entry, false)
  }
  if name == "longname" && args.is_empty() {
    return @utf8.encode(entry.longname())
  }
  if name is ("init" | "reset") {
    raise TerminalError(4, "terminal initialization is unsupported")
  }
  let standard = standard_capabilities.contains(name)
  if (standard && @terminfo.bool_code_index.contains(name)) ||
    entry.ext_booleans.contains(name) {
    guard args.is_empty() else {
      raise TerminalError(2, "boolean capability takes no parameters")
    }
    if entry.get_bool(name) == Some(true) {
      return b""
    }
    raise TerminalError(1, "")
  }
  if (standard && @terminfo.num_code_index.contains(name)) ||
    entry.ext_numbers.contains(name) {
    guard args.is_empty() else {
      raise TerminalError(2, "numeric capability takes no parameters")
    }
    if !explicit_type && name is ("cols" | "co" | "lines" | "li") {
      raise TerminalError(
        4, "live terminal dimensions require an explicit -T database query",
      )
    }
    return @utf8.encode(entry.get_num(name).unwrap_or(-1).to_string() + "\n")
  }
  if (standard && @terminfo.str_code_index.contains(name)) ||
    entry.ext_strings.contains(name) ||
    entry.ext_canceled_strings.contains(name) {
    guard entry.get_str(name) is Some(seq) else { raise TerminalError(1, "") }
    if args.is_empty() {
      return output_bytes(seq)
    }
    guard args.length() <= 9 else {
      raise TerminalError(2, "at most nine numeric parameters are supported")
    }
    let values = Array::make(9, 0)
    for i, raw in args {
      values[i] = @string.parse_int(raw) catch {
        _ => raise TerminalError(2, "capability parameters must be integers")
      }
    }
    return output_bytes(@terminfo.tparm(seq, values))
  }
  raise TerminalError(4, "unknown terminfo capability '" + name + "'")
}
