///|
async test "sort random seed consumes exactly sixteen bytes" {
  let seed = b"0123456789abcdef"
  let reader = @io.MemoryReader(writer => writer.write(seed + b"tail"))
  defer reader.close()
  assert_eq(read_random_seed(reader, "seed"), seed)
  assert_eq(reader.read_all(), b"tail")
  for short in [b"", b"0123456789abcde"] {
    let reader = @io.MemoryReader(writer => writer.write(short))
    defer reader.close()
    try read_random_seed(reader, "short") |> ignore catch {
      @order.CliError(message) =>
        assert_eq(message, "sort: 'short': end of file")
      error => raise error
    } noraise {
      _ => fail("short random seed must fail")
    }
  }
}
