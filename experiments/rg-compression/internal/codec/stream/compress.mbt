///|
/// Unix compress uses width-sized groups of eight LSB-first LZW codes.
/// Width changes and CLEAR discard the remainder of the current group.
priv struct CompressState {
  mut header : Int
  mut block_mode : Bool
  mut max_bits : Int
  mut width : Int
  mut next_code : Int
  mut old_code : Int
  mut first : Byte
  mut bits : UInt64
  mut bit_count : Int
  mut group_codes : Int
  mut padding : Int
  mut stack_len : Int
  prefix : FixedArray[Int]
  suffix : FixedArray[Byte]
  stack : FixedArray[Byte]
  mut finished : Bool
}

///|
fn CompressState::new() -> CompressState {
  { header: 0, block_mode: false, max_bits: 16, width: 9, next_code: 256,
    old_code: -1, first: b'\x00', bits: 0UL, bit_count: 0, group_codes: 0,
    padding: 0, stack_len: 0, prefix: FixedArray::make(65536, 0),
    suffix: FixedArray::makei(65536, i => (i & 255).to_byte()),
    stack: FixedArray::make(65536, b'\x00'), finished: false }
}

///|
fn CompressState::take(self : CompressState, input : BytesView, pos : Ref[Int], width : Int) -> Int? {
  while self.bit_count < width && pos.val < input.length() {
    self.bits = self.bits | (input[pos.val].to_uint64() << self.bit_count)
    self.bit_count += 8
    pos.val += 1
  }
  if self.bit_count < width { return None }
  let code = (self.bits & ((1UL << width) - 1UL)).to_int()
  self.bits = self.bits >> width
  self.bit_count -= width
  Some(code)
}

///|
fn CompressState::step(self : CompressState, input : BytesView, output : MutArrayView[Byte], end~ : Bool) -> Step {
  if self.finished { return { consumed: 0, produced: 0, status: Done } }
  let ip = Ref(0)
  let mut op = 0
  fn result(status : Status) -> Step { { consumed: ip.val, produced: op, status } }
  while self.header < 3 {
    if ip.val == input.length() {
      return result(if end { Failed("truncated Unix compress header") } else { NeedInput })
    }
    let byte = input[ip.val].to_int()
    ip.val += 1
    match self.header {
      0 if byte != 0x1f => return result(Failed("invalid Unix compress magic"))
      1 if byte != 0x9d => return result(Failed("invalid Unix compress magic"))
      2 => {
        self.max_bits = byte & 31
        self.block_mode = (byte & 128) != 0
        if self.max_bits < 9 || self.max_bits > 16 || (byte & 96) != 0 {
          return result(Failed("invalid Unix compress flags"))
        }
        self.next_code = if self.block_mode { 257 } else { 256 }
      }
      _ => ()
    }
    self.header += 1
  }
  for ;; {
    while self.stack_len > 0 && op < output.length() {
      self.stack_len -= 1
      output[op] = self.stack[self.stack_len]
      op += 1
    }
    if op == output.length() { return result(NeedOutput) }
    if self.width < self.max_bits && self.next_code > (1 << self.width) - 1 {
      self.padding = if self.group_codes == 0 { 0 } else { (8 - self.group_codes) * self.width }
      self.width += 1
      self.group_codes = 0
    }
    while self.padding > 0 {
      let count = self.padding.min(24)
      if self.take(input, ip, count) is None {
        return result(if end { Failed("truncated Unix compress alignment") } else { NeedInput })
      }
      self.padding -= count
    }
    guard self.take(input, ip, self.width) is Some(code) else {
      if end {
        if self.bit_count >= 8 { return result(Failed("truncated Unix compress code")) }
        self.finished = true
        return result(Done)
      }
      return result(NeedInput)
    }
    self.group_codes = (self.group_codes + 1) & 7
    if self.block_mode && code == 256 {
      self.padding = if self.group_codes == 0 { 0 } else { (8 - self.group_codes) * self.width }
      self.width = 9
      self.group_codes = 0
      self.next_code = 257
      self.old_code = -1
      continue
    }
    if self.old_code < 0 {
      if code >= 256 { return result(Failed("invalid initial Unix compress code")) }
      self.first = code.to_byte()
      self.stack[0] = self.first
      self.stack_len = 1
      self.old_code = code
      continue
    }
    let original = code
    let mut cursor = code
    if cursor == self.next_code {
      self.stack[self.stack_len] = self.first
      self.stack_len += 1
      cursor = self.old_code
    } else if cursor > self.next_code {
      return result(Failed("invalid Unix compress dictionary code"))
    }
    while cursor >= 256 {
      if cursor >= self.next_code || self.stack_len >= self.stack.length() - 1 {
        return result(Failed("invalid Unix compress dictionary chain"))
      }
      self.stack[self.stack_len] = self.suffix[cursor]
      self.stack_len += 1
      let parent = self.prefix[cursor]
      if parent >= cursor { return result(Failed("cyclic Unix compress dictionary")) }
      cursor = parent
    }
    self.first = cursor.to_byte()
    self.stack[self.stack_len] = self.first
    self.stack_len += 1
    if self.next_code < (1 << self.max_bits) {
      self.prefix[self.next_code] = self.old_code
      self.suffix[self.next_code] = self.first
      self.next_code += 1
    }
    self.old_code = original
  }
}
