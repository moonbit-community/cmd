///|
// Replay uses only the emitted token contract, including overlapping copies.
fn replay_deflate_tokens(
  tokens : Array[DeflateToken],
  output : Array[Byte],
) -> Unit raise {
  for token in tokens {
    match token {
      Literal(byte) => output.push(byte)
      Copy(length, distance) => {
        assert_true(length >= 3 && length <= 258)
        assert_true(distance >= 1 && distance <= 32768)
        assert_true(distance <= output.length())
        for _ in 0..<length {
          output.push(output[output.length() - distance])
        }
      }
    }
  }
}

///|
fn deflate_token_at(
  tokens : Array[DeflateToken],
  offset : Int32,
) -> DeflateToken? {
  let mut position = 0
  for token in tokens {
    if position == offset {
      return Some(token)
    }
    position += match token {
      Literal(_) => 1
      Copy(length, _) => length
    }
  }
  None
}

///|
test "deflate LZ tokens replay literals overlap and maximum chunk" {
  let payload = Bytes::makei(65536, index => {
    if index < 40000 {
      b'a'
    } else {
      (index % 251).to_byte()
    }
  })
  for level in 1..<=9 {
    let lz = DeflateLz::new(level)
    assert_true(lz.tokenize(b"").is_empty())
    let tokens = lz.tokenize(payload)
    assert_true(tokens[0] is Literal(b'a'))
    assert_true(tokens[1] is Copy(258, 1))
    let output : Array[Byte] = []
    replay_deflate_tokens(tokens, output)
    assert_eq(Bytes::from_array(output), payload)
    assert_eq(lz.history.length(), 32768)
  }
}

///|
test "deflate LZ carries pending hashes and copy interiors across chunks" {
  let lz = DeflateLz::new(1)
  let output : Array[Byte] = []
  replay_deflate_tokens(lz.tokenize(b"ab"), output)
  assert_true(lz.tokenize(b"").is_empty())
  let tail = lz.tokenize(b"cabc")
  assert_true(tail[0] is Literal(b'c'))
  assert_true(tail[1] is Copy(3, 3))
  replay_deflate_tokens(tail, output)
  assert_eq(Bytes::from_array(output), b"abcabc")
  let lz = DeflateLz::new(1)
  let tokens = lz.tokenize(b"abcXYabcZbcZ")
  assert_true(deflate_token_at(tokens, 5) is Some(Copy(3, 5)))
  assert_true(deflate_token_at(tokens, 9) is Some(Copy(3, 3)))
  let output : Array[Byte] = []
  replay_deflate_tokens(tokens, output)
  assert_eq(Bytes::from_array(output), b"abcXYabcZbcZ")
}

///|
test "deflate LZ includes full window distance beyond 32 bit positions" {
  let lz = DeflateLz::new(9)
  // Exercise absolute-position conversion without allocating several GiB.
  lz.offset = 4294967296L
  lz.next_insert = lz.offset
  let window = b"\xfe\xfd\xfc" + Bytes::make(32765, b'\x00')
  let output : Array[Byte] = []
  replay_deflate_tokens(lz.tokenize(window), output)
  let repeated = window[:258].to_owned()
  let tokens = lz.tokenize(repeated)
  assert_true(tokens[0] is Copy(258, 32768))
  replay_deflate_tokens(tokens, output)
  assert_eq(Bytes::from_array(output), window + repeated)
  assert_eq(lz.offset, 4295000322L)
  assert_eq(lz.history.length(), 32768)
}

///|
test "deflate LZ level controls bounded search and lazy token choice" {
  let prefix = b"abc0123456789|abcA|abcB|abcC|abcD|abcE|!"
  let payload = prefix + b"abc0123456789"
  let fast = DeflateLz::new(1).tokenize(payload)
  let deeper = DeflateLz::new(2).tokenize(payload)
  assert_true(deflate_token_at(fast, prefix.length()) is Some(Copy(3, _)))
  assert_true(deflate_token_at(deeper, prefix.length()) is Some(Copy(13, _)))
  let prefix = b"abcXbcdefghijklmnopQ"
  let payload = prefix + b"abcdefghijklmnop"
  for level in 1..<=9 {
    let tokens = DeflateLz::new(level).tokenize(payload)
    if level <= 3 {
      assert_true(deflate_token_at(tokens, prefix.length()) is Some(Copy(3, _)))
    } else {
      assert_true(
        deflate_token_at(tokens, prefix.length()) is Some(Literal(b'a')),
      )
      assert_true(
        deflate_token_at(tokens, prefix.length() + 1) is Some(Copy(15, _)),
      )
    }
    let output : Array[Byte] = []
    replay_deflate_tokens(tokens, output)
    assert_eq(Bytes::from_array(output), payload)
  }
}

///|
test "deflate LZ streaming replay survives varying small and large chunks" {
  let payload = Bytes::makei(150003, index => {
    if index % 101 < 50 {
      (index % 7).to_byte()
    } else {
      (index % 251).to_byte()
    }
  })
  for level in [1, 6, 9] {
    let lz = DeflateLz::new(level)
    let output : Array[Byte] = []
    let mut position = 0
    let mut chunk = 0
    while position < payload.length() {
      let size = [1, 2, 257, 65536, 32768][chunk % 5]
      let end = (position + size).min(payload.length())
      replay_deflate_tokens(
        lz.tokenize(payload[position:end].to_owned()),
        output,
      )
      assert_eq(output.length(), end)
      assert_true(lz.history.length() <= 32768)
      position = end
      chunk += 1
    }
    assert_eq(Bytes::from_array(output), payload)
  }
}
