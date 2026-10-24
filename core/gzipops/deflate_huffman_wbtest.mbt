///|
fn deflate_test_kraft(lengths : Array[Int32], max_bits : Int32) -> Unit raise {
  let mut occupied = 0
  for length in lengths {
    assert_true(length >= 0 && length <= max_bits)
    if length > 0 {
      occupied += 1 << (max_bits - length)
    }
  }
  assert_eq(occupied, 1 << max_bits)
}

///|
// Independent exhaustive assignment of all length vectors for small alphabets.
fn deflate_test_optimal_cost(
  weights : Array[Int32],
  max_bits : Int32,
  symbol : Int32,
  remaining : Int32,
) -> Int32 {
  if symbol == weights.length() {
    return if remaining == 0 { 0 } else { 1000000000 }
  }
  let mut best = 1000000000
  for length in 1..<=max_bits {
    let width = 1 << (max_bits - length)
    if width <= remaining {
      let cost = weights[symbol] * length +
        deflate_test_optimal_cost(
          weights,
          max_bits,
          symbol + 1,
          remaining - width,
        )
      best = best.min(cost)
    }
  }
  best
}

///|
test "deflate canonical codes follow RFC 1951 symbol and bit order" {
  let codes = deflate_codes([2, 1, 3, 3])
  assert_eq(codes.map(code => code.length), [2, 1, 3, 3])
  assert_eq(codes.map(code => code.bits), [1U, 0U, 3U, 7U])
  let codes = deflate_codes([3, 3, 3, 3, 3, 2, 4, 4])
  assert_eq(codes.map(code => code.bits), [2U, 6U, 1U, 5U, 3U, 0U, 7U, 15U])
  assert_eq(deflate_codes([0, 1, 0, 1]).map(code => code.bits), [0U, 0U, 0U, 1U])
  assert_eq(deflate_reverse_bits(1U, 15), 0x4000U)
  assert_eq(deflate_reverse_bits(0x6000U, 15), 3U)
  assert_eq(deflate_reverse_bits(7U, 0), 0U)
}

///|
test "deflate empty and singleton alphabets use the smallest unused dummies" {
  let empty = deflate_code_lengths([0, 0, 0, 0], 7)
  assert_eq(empty, [1, 1, 0, 0])
  deflate_test_kraft(empty, 7)
  let singleton = deflate_code_lengths([0, 0, 7, 0], 15)
  assert_eq(singleton, [1, 0, 1, 0])
  deflate_test_kraft(singleton, 15)
  assert_eq(deflate_code_lengths([0, 2, 0, 9], 1), [0, 1, 0, 1])
}

///|
test "deflate package merge respects binding literal and code-length limits" {
  let weights = [
    1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597,
  ]
  for (frequencies, max_bits) in [(weights, 15), (weights[:9].to_owned(), 7)] {
    let lengths = deflate_code_lengths(frequencies, max_bits)
    deflate_test_kraft(lengths, max_bits)
    assert_true(lengths.all(length => length > 0))
    assert_true(lengths.contains(max_bits))
  }
  let lengths = deflate_code_lengths(Array::make(286, 1), 15)
  deflate_test_kraft(lengths, 15)
  assert_eq(lengths.filter(length => length == 8).length(), 226)
  assert_eq(lengths.filter(length => length == 9).length(), 60)
}

///|
test "deflate package merge has optimal cost across small positive alphabets" {
  for symbols in 2..<=5 {
    let mut combinations = 1
    for _ in 0..<symbols {
      combinations *= 3
    }
    for combination in 0..<combinations {
      let mut digits = combination
      let frequencies = Array::makei(symbols, _ => {
        let weight = digits % 3 + 1
        digits /= 3
        weight
      })
      for max_bits in 2..<=4 {
        if symbols > 1 << max_bits {
          continue
        }
        let lengths = deflate_code_lengths(frequencies, max_bits)
        deflate_test_kraft(lengths, max_bits)
        let mut cost = 0
        for symbol, length in lengths {
          assert_true(length > 0)
          cost += frequencies[symbol] * length
        }
        assert_eq(
          cost,
          deflate_test_optimal_cost(frequencies, max_bits, 0, 1 << max_bits),
        )
      }
    }
  }
}
