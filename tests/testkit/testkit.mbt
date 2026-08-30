///|
pub(all) struct RunResult {
  status : Int
  stdout : Bytes
  stderr : Bytes
}

///|
pub fn executable_path(root : String, command : String) -> String {
  @path.Path(root)
  .join(Path("cli"))
  .join(Path(command))
  .join(Path(command + ".exe"))
  .to_string()
}

///|
pub fn normalize_lf(text : String) -> String {
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
pub fn normalize_diagnostic(text : String, temporary_root? : String) -> String {
  let normalized = normalize_lf(text)
  match temporary_root {
    Some(root) => normalized.replace_all(old=root, new="${TMP}")
    None => normalized
  }
}

///|
pub async fn run(
  program : String,
  args : Array[String],
  stdin? : Bytes,
  cwd? : String,
  extra_env? : Map[String, String] = Map([]),
  inherit_env? : Bool = true,
) -> RunResult {
  let input_dir = match stdin {
    Some(_) => Some(@fs.tmpdir(prefix="mooncmd-input"))
    None => None
  }
  defer (if input_dir is Some(path) {
    @fs.rmdir(path, recursive=true) catch {
      _ => ()
    }
  })
  let input = match (input_dir, stdin) {
    (Some(dir), Some(data)) => {
      let path = @path.Path(dir).join(Path("stdin.bin")).to_string()
      @fs.write_file(path, data)
      Some(@process.redirect_from_file(path))
    }
    _ => None
  }
  let (status, stdout, stderr) = match (input, cwd) {
    (Some(input), Some(cwd)) =>
      @process.collect_output(
        program,
        args,
        extra_env~,
        inherit_env~,
        stdin=input,
        cwd~,
        no_console_window=true,
      )
    (Some(input), None) =>
      @process.collect_output(
        program,
        args,
        extra_env~,
        inherit_env~,
        stdin=input,
        no_console_window=true,
      )
    (None, Some(cwd)) =>
      @process.collect_output(
        program,
        args,
        extra_env~,
        inherit_env~,
        cwd~,
        no_console_window=true,
      )
    (None, None) =>
      @process.collect_output(
        program,
        args,
        extra_env~,
        inherit_env~,
        no_console_window=true,
      )
  }
  { status, stdout: stdout.binary(), stderr: stderr.binary(), }
}

///|
pub fn bytes_equal(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index, byte in left {
    if byte != right[index] {
      return false
    }
  }
  true
}

///|
pub fn contains_bytes(haystack : Bytes, needle : String) -> Bool {
  let needle = @utf8.encode(needle)
  if needle.length() == 0 {
    return true
  }
  if needle.length() > haystack.length() {
    return false
  }
  for start = 0; start <= haystack.length() - needle.length(); start = start + 1 {
    let mut matches = true
    for offset = 0; offset < needle.length(); offset = offset + 1 {
      if haystack[start + offset] != needle[offset] {
        matches = false
        break
      }
    }
    if matches {
      return true
    }
  }
  false
}
