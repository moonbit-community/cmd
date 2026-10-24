///|
test "sort random digests match fixed GNU MD5 vectors" {
  let seed = b"0123456789abcdef"
  for
    (key, expected) in [
      (b"", "4032af8d61035123906e58e067140cc5"),
      (b"alpha", "16bbed75e05f0bd8d2f4be426563653c"),
      (b"beta", "5c6e4e1952b2b2637de49a3668b4c9d8"),
      (b"zeta", "2e4fa3360e0514bab54b6f4286f5f892"),
    ] {
    assert_eq(@crypto.bytes_to_hex_string(random_key(seed, key)), expected)
  }
}

///|
async test "sort random seed consumes exactly sixteen bytes" {
  let seed = b"0123456789abcdef"
  let reader = @io.MemoryReader(writer => writer.write(seed + b"tail"))
  defer reader.close()
  assert_eq(read_random_seed(reader, "seed"), seed)
  assert_eq(reader.read_all().binary(), b"tail")
  for short in [b"", b"0123456789abcde"] {
    let reader = @io.MemoryReader(writer => writer.write(short))
    defer reader.close()
    try read_random_seed(reader, "short") |> ignore catch {
      CliError(message) => assert_eq(message, "sort: 'short': end of file")
      error => raise error
    } noraise {
      _ => fail("short random seed must fail")
    }
  }
}
