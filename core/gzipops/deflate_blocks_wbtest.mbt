///|
fn deflate_test_u16(bytes : Bytes, offset : Int32) -> Int32 {
  bytes[offset].to_int() | (bytes[offset + 1].to_int() << 8)
}

///|
// Expand according to the wire alphabet, independently of the encoder's runs.
fn deflate_test_expand_runs(runs : Array[DeflateRun]) -> Array[Int32] raise {
  let lengths : Array[Int32] = []
  for run in runs {
    let (value, count) = match run.symbol {
      0..<=15 => {
        assert_eq(run.width, 0)
        assert_eq(run.extra, 0U)
        (run.symbol, 1)
      }
      16 => {
        assert_eq(run.width, 2)
        assert_true(run.extra <= 3U)
        guard lengths.last() is Some(previous) else {
          fail("repeat 16 requires a previous code length")
        }
        (previous, run.extra.reinterpret_as_int() + 3)
      }
      17 => {
        assert_eq(run.width, 3)
        assert_true(run.extra <= 7U)
        (0, run.extra.reinterpret_as_int() + 3)
      }
      18 => {
        assert_eq(run.width, 7)
        assert_true(run.extra <= 127U)
        (0, run.extra.reinterpret_as_int() + 11)
      }
      _ => fail("invalid code-length symbol")
    }
    for _ in 0..<count {
      lengths.push(value)
    }
  }
  lengths
}

///|
test "deflate fixed final abc matches the independent raw stream" {
  let bits = DeflateBits::new()
  let table = deflate_fixed_table()
  let tokens = [Literal(b'a'), Literal(b'b'), Literal(b'c')]
  bits.put(3U, 3)
  bits.tokens(table, tokens)
  bits.code(table.literal[256])
  assert_eq(deflate_token_bits(table, tokens), Some(31))
  assert_eq(bits.bytes.length() * 8 + bits.count, 34)
  bits.align()
  assert_eq(bits.drain(), b"\x4b\x4c\x4a\x06\x00")
}

///|
test "deflate stored boundaries align LEN NLEN and preserve the payload" {
  for size in [0, 65535, 65536] {
    let input = Bytes::makei(size, index => (index % 251).to_byte())
    let counts = if size == 65536 { [65535, 1] } else { [size] }
    for pending in [0, 1, 5, 6, 7] {
      for finish in [false, true] {
        let bits = DeflateBits::new()
        let prefix = (1U << pending) - 1U
        bits.put(prefix, pending)
        bits.stored(input[:], finish~)
        assert_eq(bits.count, 0)
        let bytes = bits.drain()
        let first_header = if finish && size <= 65535 { 1U } else { 0U }
        assert_eq(bytes[0], (prefix | (first_header << pending)).to_byte())
        let mut position = (pending + 3 + 7) / 8
        if position == 2 {
          assert_eq(bytes[1], b'\x00')
        }
        let mut consumed = 0
        for block, count in counts {
          if block > 0 {
            assert_eq(bytes[position], if finish { b'\x01' } else { b'\x00' })
            position += 1
          }
          assert_eq(deflate_test_u16(bytes, position), count)
          assert_eq(deflate_test_u16(bytes, position + 2), count ^ 0xffff)
          position += 4
          assert_eq(
            bytes[position:position + count].to_owned(),
            input[consumed:consumed + count].to_owned(),
          )
          position += count
          consumed += count
        }
        assert_eq(consumed, size)
        assert_eq(position, bytes.length())
        assert_eq(
          bytes.length() * 8 - pending,
          deflate_stored_bits(size, pending),
        )
      }
    }
  }
}

///|
test "deflate code length repeat symbols cover their wire boundaries" {
  for count in [0, 1, 2, 3, 10, 11, 138, 139, 140, 141, 276] {
    let lengths = Array::make(count, 0)
    let runs = deflate_length_runs(lengths)
    assert_eq(deflate_test_expand_runs(runs), lengths)
    if count >= 11 {
      assert_eq(runs[0].symbol, 18)
    } else if count >= 3 {
      assert_eq(runs[0].symbol, 17)
    }
  }
  for count in [1, 2, 3, 4, 6, 7, 8, 10, 13] {
    let lengths = Array::make(count, 7)
    let runs = deflate_length_runs(lengths)
    assert_eq(deflate_test_expand_runs(runs), lengths)
    assert_eq(runs.any(run => run.symbol == 16), count >= 4)
  }
}

///|
async test "deflate dynamic header repeats across the literal distance boundary" {
  let tokens = [Literal(b'\xff')]
  let plan = deflate_dynamic(tokens)
  // Literal 255 and EOB have one-bit codes; the two dummy distance codes do too.
  let expected = Array::make(255, 0)
  expected.append([1, 1, 1, 1])
  assert_eq(plan.literal_count, 257)
  assert_eq(plan.distance_count, 2)
  assert_eq(deflate_test_expand_runs(plan.runs), expected)
  let repeat = plan.runs[plan.runs.length() - 1]
  assert_eq(repeat.symbol, 16)
  assert_eq(repeat.extra, 0U)
  let bits = DeflateBits::new()
  bits.dynamic_header(plan, finish=true)
  assert_eq(bits.bytes.length() * 8 + bits.count, plan.header_bits)
  bits.tokens(plan.table, tokens)
  bits.code(plan.table.literal[256])
  assert_eq(
    bits.bytes.length() * 8 + bits.count,
    plan.header_bits + deflate_token_bits(plan.table, tokens).unwrap(),
  )
  bits.align()
  let output : Collected = { bytes: [], }
  let raw = bits.drain()
  let input = cursor(raw)
  defer input.close()
  let reader = Bits::new(input)
  let (_, size) = inflate(reader, output, false)
  assert_true(reader.next_byte() is None)
  assert_eq(size, 1U)
  assert_eq(Bytes::from_array(output.bytes), b"\xff")
}
