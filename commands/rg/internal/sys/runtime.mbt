///|
pub fn args() -> Array[String] {
  @env.args()
}

///|
pub fn current_dir() -> String? {
  @env.current_dir()
}

///|
pub fn env_var(name : String) -> String? {
  @env.get_env_var(name)
}

///|
pub fn env_vars() -> Array[(String, String)] {
  let pairs = []
  for key, value in @env.get_env_vars() {
    pairs.push((key, value))
  }
  pairs
}

///|
pub fn exit(code : Int32) -> Unit {
  @exit.exit(code)
}

///|
pub fn is_windows() -> Bool {
  @async.platform is Windows
}

///|
pub fn now_nanos() -> Int64 {
  @async.now() * 1000000L
}

///|
pub fn hostname() -> String? {
  match @env.get_env_var("HOSTNAME") {
    Some(name) => Some(name)
    None => @env.get_env_var("COMPUTERNAME")
  }
}

///|
pub fn mmap_supported() -> Bool {
  false
}

///|
pub fn is_tty(_fd : Int32) -> Capability[Bool] {
  Unavailable("terminal detection requires a released public MoonBit API")
}

///|
pub fn stdin_is_readable() -> Capability[Bool] {
  Unavailable(
    "stdin type detection requires a released public MoonBit API; specify a path or -",
  )
}

///|
pub async fn read_fd(
  fd : Int32,
  buf : FixedArray[Byte],
  start : Int32,
  len : Int32,
) -> Int32 {
  guard fd == 0 else {
    raise IOError::other(Unsupported, "use File::read for file handles")
  }
  @stdio.stdin.read(buf, offset=start, max_len=len) catch {
    e => raise io_error(e)
  }
}

///|
pub async fn write_fd(
  fd : Int32,
  buf : FixedArray[Byte],
  start : Int32,
  len : Int32,
) -> Unit {
  let bytes = Bytes::from_array(buf[start:start + len])
  match fd {
    1 => @stdio.stdout.write(bytes) catch { e => raise io_error(e) }
    2 => @stdio.stderr.write(bytes) catch { e => raise io_error(e) }
    _ =>
      raise IOError::other(
        Unsupported,
        "unsupported standard output descriptor",
      )
  }
}
