///|
fn low(args : Array[String]) -> LowArgs {
  parse_low_raw(args) catch {
    e => abort(e.message())
  }
}

///|
fn try_parse(args : Array[String]) -> Result[LowArgs, String] {
  try parse_low_raw(args) catch {
    e => Err(e.message())
  } noraise {
    a => Ok(a)
  }
}

///|
fn bs(s : String) -> Bytes {
  @utf8.encode(s)
}

///|
fn ContextMode::get_limited(self : ContextMode) -> (Int32, Int32) {
  match self {
    Passthru => abort("context mode is passthru")
    Limited(l) => l.get()
  }
}
