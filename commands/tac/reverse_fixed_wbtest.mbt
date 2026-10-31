///|
fn reverse_fixed_oracle(
  data : Bytes,
  separator : Bytes,
  before : Bool,
) -> Bytes {
  let output = @buffer.Buffer()
  let mut search_end = data.length()
  let mut end = data.length()
  while data[:search_end].rev_find(separator) is Some(start) {
    let boundary = start + (if before { 0 } else { separator.length() })
    output.write_bytes(data[boundary:end])
    end = boundary
    search_end = start
  }
  output.write_bytes(data[:end])
  output.to_bytes()
}

///|
async test "tac fixed batches preserve rightmost nonoverlapping matches across reads" {
  for bits in 0..<64 {
    let data = Bytes::makei(6, index => {
      if (bits & (1 << index)) == 0 {
        b'a'
      } else {
        b'b'
      }
    })
    for separator in [b"ab", b"aba", b"aa", b"abababa"] {
      for before in [false, true] {
        let expected = reverse_fixed_oracle(data, separator, before)
        for size in [1, 3] {
          assert_eq(reversed(data, separator, before, size~), expected)
        }
      }
    }
  }
}

///|
async test "tac fixed ranges spanning later blocks stay outside the local batch" {
  for length in [3, 65535, 65536, 65537, 131073] {
    let separator = Bytes::make(length, b'a') + b"b"
    let data = b"first" + separator + b"middle" + separator + b"last"
    for before in [false, true] {
      assert_eq(
        reversed(data, separator, before, size=65536),
        reverse_fixed_oracle(data, separator, before),
      )
    }
  }
}

///|
async test "tac zero-prefix skips preserve sparse dense and crossing reverse matches" {
  for separator in [b"ab", b"aba", b"aaaaab", b"aa"] {
    let cases = [
      Bytes::make(131101, b'x'),
      Bytes::make(65535, b'x') +
      separator +
      Bytes::make(65537, b'x') +
      separator,
      Bytes::make(65535, b'a') + b"b" + Bytes::make(65538, b'a') + b"b",
      @utf8.encode("ababa".repeat(27000)),
    ]
    for data in cases {
      for before in [false, true] {
        let expected = reverse_fixed_oracle(data, separator, before)
        for size in [33, 65536] {
          assert_eq(reversed(data, separator, before, size~), expected)
        }
      }
    }
  }
}
