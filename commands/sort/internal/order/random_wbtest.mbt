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
