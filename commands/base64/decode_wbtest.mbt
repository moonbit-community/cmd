///|
async test "base64 GNU 9.11 decoding preserves prefixes with fragmented producers" {
  // Coreutils v9.11 tests/basenc/base64.pl supplies the padding vectors.
  // Producer writes vary; the public reader may coalesce those writes.
  for
    (input, expected, invalid) in [
      (b"aQ", b"i", false),
      (b"Zzw", b"g<", false),
      (b"MTIzNA==MTIzNA", b"12341234", false),
      (b"MTIzNA==\nMTIzNA", b"12341234", false),
      (b"YQ==YQ==", b"aa", false),
      (b"a", b"", true),
      (b"Zz=", b"g", true),
      (b"Z===", b"", true),
      (b"SB==", b"H", true),
      (b"SGVsbG9=", b"Hello", true),
      (b"MTIzNA=", b"1234", true),
      (b"MTIzNA=\n", b"1234", true),
      (b"Zm9v!!!!", b"foo", true),
      (b"Zm9vYQ=", b"fooa", true),
    ] {
    for chunk_size in [1, 2, 3, 4, 5, 64] {
      let reader = @io.MemoryReader(writer => {
        for start = 0; start < input.length(); start = start + chunk_size {
          writer.write(input[start:(start + chunk_size).min(input.length())])
        }
      })
      defer reader.close()
      let output : EncodingOutput = { bytes: [], calls: 0, fail_after: 100, }
      let rejected = try {
        decode_stream(reader, false, writer=output)
        false
      } catch {
        CliError(message) => {
          assert_eq(message, "base64: invalid input")
          true
        }
        error => raise error
      }
      assert_eq(rejected, invalid)
      assert_eq(Bytes::from_array(output.bytes), expected)
    }
  }
}

///|
async test "base64 failure-prefix output errors are never replayed" {
  for input in [b"Zm9vYmFy!!!!", b"Zm9vYmFy", b"Zm9vYmF"] {
    let reader = @io.MemoryReader(writer => writer.write(input))
    defer reader.close()
    let output : EncodingOutput = { bytes: [], calls: 0, fail_after: 1, }
    assert_true(
      try {
        decode_stream(reader, false, writer=output)
        false
      } catch {
        error => {
          assert_true("\{error}".contains("encoding write failed"))
          true
        }
      },
    )
    assert_eq(Bytes::from_array(output.bytes), b"foo")
    assert_eq(output.calls, 2)
  }
}

///|
async test "base64 quantum survives the public read chunk boundary" {
  // The stream helper limits each read to 65536 bytes. A leading LF shifts
  // the four-symbol quantum across that bound even if the producer coalesces.
  let encoded : Array[Byte] = [b'\n']
  let expected : Array[Byte] = []
  for _ in 0..<20000 {
    encoded.append([b'Z', b'm', b'9', b'v'])
    expected.append([b'f', b'o', b'o'])
  }
  encoded.append([b'Y', b'Q', b'=', b'='])
  expected.push(b'a')
  let reader = @io.MemoryReader(writer => {
    writer.write(Bytes::from_array(encoded))
  })
  defer reader.close()
  let output : EncodingOutput = { bytes: [], calls: 0, fail_after: 100000, }
  decode_stream(reader, false, writer=output)
  assert_eq(Bytes::from_array(output.bytes), Bytes::from_array(expected))
}
