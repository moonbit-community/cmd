///|
pub(all) enum Size {
  Exact(Int64)
  Add(Int64)
  Subtract(Int64)
  AtMost(Int64)
  AtLeast(Int64)
  RoundDown(Int64)
  RoundUp(Int64)
}

///|
pub fn parse(text : String) -> Size raise {
  guard !text.is_empty() else { raise Failure("invalid size") }
  let start = if text[0] is ('+' | '-' | '<' | '>' | '/' | '%') { 1 } else { 0 }
  let mut end = start
  while end < text.length() && text[end] >= '0' && text[end] <= '9' {
    end += 1
  }
  guard start != end else { raise Failure("invalid size: " + text) }
  let base = @string.parse_int64(text[start:end])
  let multiplier = match text[end:] {
    "" => 1L
    "K" | "KiB" => 1024L
    "kB" | "KB" => 1000L
    "M" | "MiB" => 1048576L
    "MB" => 1000000L
    "G" | "GiB" => 1073741824L
    "GB" => 1000000000L
    "T" | "TiB" => 1099511627776L
    "TB" => 1000000000000L
    _ => raise Failure("invalid size: " + text)
  }
  guard base <= 9223372036854775807L / multiplier else {
    raise Failure("size overflow")
  }
  let value = base * multiplier
  match text[0] {
    '+' => Add(value)
    '-' => Subtract(value)
    '<' => AtMost(value)
    '>' => AtLeast(value)
    '/' | '%' if value == 0 => raise Failure("rounding unit must be positive")
    '/' => RoundDown(value)
    '%' => RoundUp(value)
    _ => Exact(value)
  }
}

///|
pub fn target(request : Size, old : Int64) -> Int64 raise {
  match request {
    Exact(n) => n
    Add(n) => {
      guard n <= 9223372036854775807L - old else {
        raise Failure("size overflow")
      }
      old + n
    }
    Subtract(n) => (old - n).max(0L)
    AtMost(n) => old.min(n)
    AtLeast(n) => old.max(n)
    RoundDown(n) => old - old % n
    RoundUp(n) =>
      if old % n == 0L {
        old
      } else {
        target(Add(n - old % n), old)
      }
  }
}

///|
pub async fn apply(request : Size, path : String, no_create~ : Bool) -> Unit {
  let existing = try @fs.kind(path) catch {
    @os_error.OsError(NotFound, ..) => None
    error => raise error
  } noraise {
    kind => Some(kind)
  }
  match existing {
    None if no_create => return
    None | Some(Regular) => ()
    _ => raise Failure("expected a regular file")
  }
  let mode : @fs.CreateMode = match (request, no_create) {
    (Exact(0L), true) => TruncateExisting
    (Exact(0L), false) => CreateOrTruncate
    (_, true) => OpenExisting
    (_, false) => OpenOrCreate
  }
  let file = @fs.open(path, mode=WriteOnly, create_mode=mode, permission=0o666) catch {
    @os_error.OsError(NotFound, ..) if no_create => return
    error => raise error
  }
  defer file.close()
  if request is Exact(0L) {
    return
  }
  guard file.kind() is Regular else { raise Failure("expected a regular file") }
  let old = file.size()
  let length = target(request, old)
  guard length >= old else {
    raise Failure("shrinking this open file requires handle truncation")
  }
  if length > old {
    file.at(length - 1L).write(b"\x00")
  }
}
