///|
using @program {
  type PatternRef,
  type Address,
  type Command,
  type Space,
  type PreparedPattern,
}

///|
fn[T] fail(message : String) -> T raise @program.SedError {
  raise @program.SedError(message)
}
