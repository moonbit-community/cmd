///|
/// A decimal representation of a finite binary value: value = 0.digits * 10^exp,
/// with no leading or trailing zero digits. An empty digit array means zero.
priv struct Dec {
  neg : Bool
  digs : Array[Int32]
  exp : Int32
}

///|
fn dec_of_dyadic(coefficient : BigInt, exponent : Int32) -> Dec {
  if coefficient.is_zero() {
    return { neg: false, digs: [], exp: 0, }
  }
  let (n, point) = if exponent >= 0 {
    (coefficient << exponent, 0)
  } else {
    (
      coefficient * BigInt::from_int(5).pow(BigInt::from_int(-exponent)),
      -exponent,
    )
  }
  let digs = n.to_string().iter().map(c => c.to_int() - 0x30).collect()
  let exp = digs.length() - point
  while digs.length() > 0 && digs[digs.length() - 1] == 0 {
    ignore(digs.pop())
  }
  { neg: false, digs, exp, }
}

///|
/// True when dropping digits[k..] rounds the kept prefix upward, using
/// round-half-even on the exact expansion like C printf.
fn rounds_up(digs : Array[Int32], k : Int32) -> Bool {
  if k >= digs.length() {
    return false
  }
  let first = digs[k]
  if first > 5 {
    return true
  }
  if first < 5 {
    return false
  }
  for i in (k + 1)..<digs.length() {
    if digs[i] != 0 {
      return true
    }
  }
  // Exact tie: round to make the last kept digit even.
  k > 0 && digs[k - 1] % 2 == 1
}

///|
/// Round to at most k significant digits (half-even on the exact expansion).
fn dec_round_sig(d : Dec, k : Int32) -> Dec {
  if d.digs.length() <= k {
    return d
  }
  let kept : Array[Int32] = []
  for i in 0..<k {
    kept.push(d.digs[i])
  }
  let mut exp = d.exp
  if rounds_up(d.digs, k) {
    let mut idx = k - 1
    let mut carry = true
    while carry && idx >= 0 {
      if kept[idx] == 9 {
        kept[idx] = 0
        idx -= 1
      } else {
        kept[idx] += 1
        carry = false
      }
    }
    if carry {
      // 999... rounded up to 1000...: a single leading 1, one place higher.
      kept.clear()
      kept.push(1)
      exp += 1
    }
  }
  while kept.length() > 0 && kept[kept.length() - 1] == 0 {
    ignore(kept.pop())
  }
  if kept.is_empty() {
    { neg: d.neg, digs: [], exp: 0, }
  } else {
    { neg: d.neg, digs: kept, exp, }
  }
}

///|
/// Fixed-point rendering of the magnitude with `p` fraction digits.
fn fmt_f(d : Dec, p : Int32, alt : Bool) -> String {
  let d2 = if d.digs.is_empty() {
    d
  } else {
    let k = d.exp + p
    if k < 0 {
      { neg: d.neg, digs: [], exp: 0, }
    } else if k == 0 {
      // The value sits entirely below the rounding place; it rounds up to
      // one unit in the last place only past the halfway point (a tie
      // rounds toward the even 0).
      if rounds_up(d.digs, 0) {
        { neg: d.neg, digs: [1], exp: -p + 1, }
      } else {
        { neg: d.neg, digs: [], exp: 0, }
      }
    } else {
      dec_round_sig(d, k)
    }
  }
  let sb = StringBuilder()
  let int_count = if d2.exp > 0 { d2.exp } else { 0 }
  if int_count == 0 {
    sb.write_char('0')
  } else {
    for i in 0..<int_count {
      let digit = if i < d2.digs.length() { d2.digs[i] } else { 0 }
      sb.write_char((0x30 + digit).unsafe_to_char())
    }
  }
  if p > 0 || alt {
    sb.write_char('.')
  }
  for pos in 1..<=p {
    let i = d2.exp - 1 + pos
    let digit = if i >= 0 && i < d2.digs.length() { d2.digs[i] } else { 0 }
    sb.write_char((0x30 + digit).unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Scientific rendering of the magnitude with `p` mantissa fraction digits.
fn fmt_e(d : Dec, p : Int32, alt : Bool, upper : Bool) -> String {
  let sb = StringBuilder()
  if d.digs.is_empty() {
    sb.write_char('0')
    if p > 0 || alt {
      sb.write_char('.')
    }
    for _ in 0..<p {
      sb.write_char('0')
    }
    sb.write_string(if upper { "E+00" } else { "e+00" })
    return sb.to_string()
  }
  let d2 = dec_round_sig(d, p + 1)
  sb.write_char((0x30 + d2.digs[0]).unsafe_to_char())
  if p > 0 || alt {
    sb.write_char('.')
  }
  for j in 1..<=p {
    let digit = if j < d2.digs.length() { d2.digs[j] } else { 0 }
    sb.write_char((0x30 + digit).unsafe_to_char())
  }
  let e10 = d2.exp - 1
  sb.write_char(if upper { 'E' } else { 'e' })
  sb.write_char(if e10 < 0 { '-' } else { '+' })
  let mag = if e10 < 0 { -e10 } else { e10 }
  let etext = mag.to_string()
  if etext.length() < 2 {
    sb.write_char('0')
  }
  sb.write_string(etext)
  sb.to_string()
}

///|
/// Strip the trailing fraction zeros %g produces (and a bare trailing point).
fn strip_g(s : String) -> String {
  let chars : Array[Char] = s.iter().collect()
  let mut split = chars.length()
  for i in 0..<chars.length() {
    if chars[i] == 'e' || chars[i] == 'E' {
      split = i
      break
    }
  }
  let mut has_point = false
  for i in 0..<split {
    if chars[i] == '.' {
      has_point = true
      break
    }
  }
  if !has_point {
    return s
  }
  let mut end = split
  while end > 0 && chars[end - 1] == '0' {
    end -= 1
  }
  if end > 0 && chars[end - 1] == '.' {
    end -= 1
  }
  let sb = StringBuilder()
  for i in 0..<end {
    sb.write_char(chars[i])
  }
  for i in split..<chars.length() {
    sb.write_char(chars[i])
  }
  sb.to_string()
}

///|
/// General rendering of the magnitude with `p0` significant digits.
fn fmt_g(d : Dec, p0 : Int32, alt : Bool, upper : Bool) -> String {
  let precision = if p0 == 0 { 1 } else { p0 }
  let d2 = dec_round_sig(d, precision)
  let x = if d2.digs.is_empty() { 0 } else { d2.exp - 1 }
  let s = if x < -4 || x >= precision {
    fmt_e(d2, precision - 1, alt, upper)
  } else {
    fmt_f(d2, precision - 1 - x, alt)
  }
  if alt {
    s
  } else {
    strip_g(s)
  }
}
