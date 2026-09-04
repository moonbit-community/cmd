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
async fn run_with_pipe(
  program : String,
  args : Array[String],
  data : Bytes,
  cwd : String?,
  extra_env : Map[String, String],
  inherit_env : Bool,
) -> (Int, &@io.Data, &@io.Data) {
  let (input, writer) = @process.write_to_process()
  @async.with_task_group() <| group => {
    let result = group.spawn(() => {
      match cwd {
        Some(cwd) =>
          @process.collect_output(
            program,
            args,
            extra_env~,
            inherit_env~,
            stdin=input,
            cwd~,
            no_console_window=true,
          )
        None =>
          @process.collect_output(
            program,
            args,
            extra_env~,
            inherit_env~,
            stdin=input,
            no_console_window=true,
          )
      }
    })
    group.spawn_bg(() => {
      defer writer.close()
      writer.write(data)
    })
    result.wait()
  }
}

///|

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
  let (status, stdout, stderr) = match stdin {
    Some(data) =>
      run_with_pipe(program, args, data, cwd, extra_env, inherit_env)
    None =>
      match cwd {
        Some(cwd) =>
          @process.collect_output(
            program,
            args,
            extra_env~,
            inherit_env~,
            cwd~,
            no_console_window=true,
          )
        None =>
          @process.collect_output(
            program,
            args,
            extra_env~,
            inherit_env~,
            no_console_window=true,
          )
      }
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
