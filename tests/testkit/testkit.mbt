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
/// Resolve a release or debug Wasm command artifact.
pub fn wasm_path(root : String, command : String) -> String {
  @path.Path(root)
  .join(Path("cli"))
  .join(Path(command))
  .join(Path(command + ".wasm"))
  .to_string()
}

///|
pub fn normalize_lf(text : String) -> String {
  text.replace_all(old="\r\n", new="\n").replace_all(old="\r", new="\n")
}

///|
pub fn ends_with_newline(bytes : Bytes) -> Bool {
  bytes.has_suffix(b"\n") && !bytes.has_suffix(b"\n\n")
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
  let timeout_ms = if program == "docker" ||
    program == "moonx" ||
    program.has_suffix("/moonx") ||
    program.has_suffix("\\moonx.exe") {
    120000
  } else {
    15000
  }
  let result = run_with_deadline(
    program,
    args,
    timeout_ms,
    stdin=stdin.unwrap_or(b""),
    cwd?,
    extra_env~,
    inherit_env~,
  )
  if result.cleanup_error is Some(error) {
    fail("process cleanup failed: " + error)
  }
  if result.timed_out {
    fail("runner deadline expired for " + program)
  }
  result.output
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

///|
/// Use the fixture owner's identity in Linux containers so mode-restricted
/// oracle output remains observable and removable by the runner.
pub async fn docker_user() -> String {
  let uid = run("id", ["-u"], stdin=b"")
  let gid = run("id", ["-g"], stdin=b"")
  guard uid.status == 0 && gid.status == 0 else {
    fail("cannot identify Docker fixture owner")
  }
  let uid = @utf8.decode(uid.stdout).trim().to_owned()
  let gid = @utf8.decode(gid.stdout).trim().to_owned()
  guard !uid.is_empty() && !gid.is_empty() else {
    fail("empty Docker fixture owner")
  }
  uid + ":" + gid
}
