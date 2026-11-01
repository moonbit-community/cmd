///|
fn encode_bytes(input : Bytes, wrap : Int32) -> Bytes {
  let encoder = Base32Encoder::new(wrap)
  encoder.encode(input[:]) + encoder.finish()
}

///|
test "base32 RFC 4648 vectors" {
  assert_eq(encode_bytes(b"", 0), b"")
  assert_eq(encode_bytes(b"f", 0), b"MY======")
  assert_eq(encode_bytes(b"fo", 0), b"MZXQ====")
  assert_eq(encode_bytes(b"foo", 0), b"MZXW6===")
  assert_eq(encode_bytes(b"foob", 0), b"MZXW6YQ=")
  assert_eq(encode_bytes(b"fooba", 0), b"MZXW6YTB")
  assert_eq(encode_bytes(b"foobar", 0), b"MZXW6YTBOI======")
}

///|
test "base32 decode vectors and wrapping" {
  let one : Array[Byte] = []
  decode_block(b"MY======".to_array(), one)
  assert_eq(Bytes::from_array(one), b"f")
  let three : Array[Byte] = []
  decode_block(b"MZXW6===".to_array(), three)
  assert_eq(Bytes::from_array(three), b"foo")
  let six : Array[Byte] = []
  decode_block(b"MZXW6YTB".to_array(), six)
  decode_block(b"OI======".to_array(), six)
  assert_eq(Bytes::from_array(six), b"foobar")
  assert_eq(encode_bytes(b"foobar", 8), b"MZXW6YTB\nOI======\n")
  assert_eq(encode_bytes(b"foobar", 0), b"MZXW6YTBOI======")
}

///|
test "base32 rejects lowercase and preserves decoded prefix" {
  let lowercase = try decode_block(b"my======".to_array(), []) catch {
    CliError(_) => b"rejected"
  } noraise {
    _ => b"accepted"
  }
  assert_eq(lowercase, b"rejected")
  let tail : Array[Byte] = []
  decode_block(b"MZ======".to_array(), tail)
  assert_eq(Bytes::from_array(tail), b"f")
  let prefix : Array[Byte] = []
  let result = try decode_block(b"MY=XXXXX".to_array(), prefix) catch {
    CliError(_) => b"rejected"
  } noraise {
    _ => b"accepted"
  }
  assert_eq(result, b"rejected")
  assert_eq(Bytes::from_array(prefix), b"f")
}

///|
test "base32 byte encoding preserves every byte and wrap boundaries" {
  // Frozen GNU coreutils 9.11 output for the ascending 0..255 byte vector.
  let expected = b"AAAQEAYEAUDAOCAJBIFQYDIOB4IBCEQTCQKRMFYYDENBWHA5DYPSAIJCEMSCKJRHFAUSUKZMFUXC6MBRGIZTINJWG44DSOR3HQ6T4P2AIFBEGRCFIZDUQSKKJNGE2TSPKBIVEU2UKVLFOWCZLJNVYXK6L5QGCYTDMRSWMZ3INFVGW3DNNZXXA4LSON2HK5TXPB4XU634PV7H7AEBQKBYJBMGQ6EITCULRSGY5D4QSGJJHFEVS2LZRGM2TOOJ3HU7UCQ2FI5EUWTKPKFJVKV2ZLNOV6YLDMVTWS23NN5YXG5LXPF5X274BQOCYPCMLRWHZDE4VS6MZXHM7UGR2LJ5JVOW27MNTWW33TO55X7A4HROHZHF43T6R2PK5PWO33XP6DY7F47U6X3PP6HZ7L57Z7P674======"
  let input = Bytes::makei(256, i => i.to_byte())
  assert_eq(encode_bytes(input, 0), expected)
  for wrap in [1, 3, 7, 8, 9, 76, 412, 416, 417, 2147483647] {
    let output = encode_bytes(input, wrap)
    let mut column = 0
    let mut index = 0
    for byte in output {
      if byte == b'\n' {
        assert_true(column == wrap || index == expected.length())
        column = 0
      } else {
        assert_eq(byte, expected[index])
        index += 1
        column += 1
      }
    }
    assert_eq(index, expected.length())
    assert_eq(column, 0)
    assert_eq(encode_bytes(b"", wrap), b"")
  }
}

///|
async test "base32 whole input acceptance retains fragments and read failures" {
  let input = Bytes::makei(65539, i => (i % 251).to_byte())
  let reader = @io.MemoryReader(writer => {
    writer.write(input[:1])
    writer.write(input[1:65536])
    writer.write(input[65536:])
  })
  defer reader.close()
  assert_eq(read_input(reader), input)
  let failed = @io.MemoryReader(writer => {
    writer.write(b"accepted prefix")
    fail("base32 late read error")
  })
  defer failed.close()
  assert_true(
    try {
      ignore(read_input(failed))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "base32 complete group windows preserve padding across the 64 KiB boundary" {
  for tail in 0..<5 {
    let input = Bytes::make(65535 + tail, b'\x00')
    let suffix = match tail {
      0 => b""
      1 => b"AA======"
      2 => b"AAAA===="
      3 => b"AAAAA==="
      _ => b"AAAAAAA="
    }
    assert_eq(encode_bytes(input, 0), Bytes::make(104856, b'A') + suffix)
  }
}
