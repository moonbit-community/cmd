///|
/// UTF-8 bytes occupied by an argument, including its terminating NUL.
/// This is argv payload accounting, not a platform ARG_MAX or environment limit.
pub fn argument_bytes(argument : String) -> Int64 {
  @utf8.encode(argument[:]).length().to_int64() + 1L
}

///|
/// Sum argv payload bytes. Callers can retain the sum while extending a batch.
pub fn arguments_bytes(arguments : ArrayView[String]) -> Int64 {
  let mut size = 0L
  for argument in arguments {
    size += argument_bytes(argument)
  }
  size
}
