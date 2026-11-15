///|
pub struct Decoder {
  priv style : Style
  priv cols : Int32
  priv base : Int64
  priv mut want : Int64
  priv mut column : Int32
  priv mut ignore_garbage : Bool
  priv mut skip_line : Bool
  priv mut first : Int32
  priv mut second : Int32
  priv mut third : Int32
  priv mut bits : Int32
  priv mut bit_count : Int32
}

///|
pub fn Decoder::new(style : Style, cols : Int32, base : Int64) -> Decoder {
  {
    style,
    cols,
    base,
    want: 0L,
    column: cols,
    ignore_garbage: true,
    skip_line: false,
    first: -1,
    second: 0,
    third: 0,
    bits: 0,
    bit_count: 0,
  }
}

///|
fn Decoder::newline(self : Decoder) -> Unit {
  if !(self.style is Plain) {
    self.want = 0L
  }
  self.column = self.cols
  self.ignore_garbage = true
  self.skip_line = false
}

///|
pub fn Decoder::feed(
  self : Decoder,
  byte : Byte,
) -> (Int64, Byte?)? raise DecodeError {
  if byte == b'\r' {
    return None
  }
  if self.skip_line {
    if byte == b'\n' {
      self.newline()
    }
    return None
  }
  if self.style is Plain && byte is (b' ' | b'\n' | b'\t') {
    return None
  }
  if self.style is Bits {
    self.first = hex_val(byte)
    if self.first < 0 && self.ignore_garbage {
      return None
    }
    if byte is (b'0' | b'1') {
      self.bits = (self.bits << 1) | (byte.to_int() - 0x30)
      self.bit_count += 1
    }
  } else {
    self.third = self.second
    self.second = self.first
    self.first = hex_val(byte)
    if self.first < 0 && self.ignore_garbage {
      return None
    }
  }
  self.ignore_garbage = false
  if !(self.style is Plain) && self.column >= self.cols {
    if self.first < 0 {
      self.column = 0
      if self.style is Bits {
        self.bit_count = 0
      }
    } else {
      if self.want > (9223372036854775807L - self.first.to_int64()) / 16L {
        raise DecodeError("xxd: addressed offset overflow.")
      }
      self.want = self.want * 16L + self.first.to_int64()
    }
    return None
  }
  let target = checked_offset(self.base, self.want)
  let mut result : Byte? = None
  if self.style is Bits {
    if self.bit_count == 8 {
      result = Some(self.bits.to_byte())
      self.bits = 0
      self.bit_count = 0
    }
  } else if self.second >= 0 && self.first >= 0 {
    result = Some(((self.second << 4) | self.first).to_byte())
    self.first = -1
  } else if self.first < 0 && self.second < 0 && self.third < 0 {
    self.skip_line = true
  }
  if result is Some(_) {
    self.want = checked_offset(self.want, 1L)
    if !(self.style is Plain) {
      self.column += 1
      if self.column >= self.cols {
        self.skip_line = true
      }
    }
  }
  if byte == b'\n' {
    self.newline()
  }
  Some((target, result))
}
