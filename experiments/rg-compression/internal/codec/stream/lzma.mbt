///|
/// Range decoding follows the public-domain LZMA format specification.
/// Twenty bytes suffice for one complete symbol, including its distance.
priv struct LzmaState {
  header : FixedArray[Byte]
  mut header_len : Int
  queue : FixedArray[Byte]
  mut queued : Int
  mut cursor : Int
  mut range : UInt
  mut code : UInt
  mut range_ready : Bool
  mut lc : Int
  mut lp : Int
  mut pb : Int
  mut expected : Int64?
  mut dictionary : FixedArray[Byte]
  mut dictionary_pos : Int
  mut filled : Int
  mut total : Int64
  mut previous : Byte
  mut state : Int
  reps : FixedArray[UInt]
  is_match : FixedArray[Int]
  is_rep : FixedArray[Int]
  rep_g0 : FixedArray[Int]
  rep_g1 : FixedArray[Int]
  rep_g2 : FixedArray[Int]
  rep0_long : FixedArray[Int]
  slots : FixedArray[Int]
  distances : FixedArray[Int]
  align_bits : FixedArray[Int]
  lengths : FixedArray[Int]
  rep_lengths : FixedArray[Int]
  mut literals : FixedArray[Int]
  mut literal : Byte?
  mut copy_len : Int
  mut copy_distance : Int
  mut ended : Bool
}

///|
fn LzmaState::new() -> LzmaState {
  { header: FixedArray::make(13, b'\x00'), header_len: 0,
    queue: FixedArray::make(20, b'\x00'), queued: 0, cursor: 0,
    range: 0xffffffffU, code: 0U, range_ready: false, lc: 0, lp: 0, pb: 0,
    expected: None, dictionary: FixedArray::make(1, b'\x00'), dictionary_pos: 0,
    filled: 0, total: 0L, previous: b'\x00', state: 0,
    reps: FixedArray::make(4, 0U), is_match: FixedArray::make(12 * 16, 1024),
    is_rep: FixedArray::make(12, 1024), rep_g0: FixedArray::make(12, 1024),
    rep_g1: FixedArray::make(12, 1024), rep_g2: FixedArray::make(12, 1024),
    rep0_long: FixedArray::make(12 * 16, 1024), slots: FixedArray::make(4 * 64, 1024),
    distances: FixedArray::make(114, 1024), align_bits: FixedArray::make(16, 1024),
    lengths: FixedArray::make(2 + 16 * 16 + 256, 1024),
    rep_lengths: FixedArray::make(2 + 16 * 16 + 256, 1024),
    literals: FixedArray::make(768, 1024), literal: None, copy_len: 0,
    copy_distance: 0, ended: false }
}

///|
fn LzmaState::configure(self : LzmaState, properties : Int, dictionary_size : UInt) -> Unit raise DecodeError {
  self.properties(properties)
  guard dictionary_size <= 2147483647U else { raise DecodeError("LZMA dictionary exceeds representable buffer length") }
  self.dictionary = FixedArray::make(dictionary_size.reinterpret_as_int().max(4096), b'\x00')
}

///|
fn LzmaState::properties(self : LzmaState, properties : Int) -> Unit raise DecodeError {
  guard properties < 225 else { raise DecodeError("invalid LZMA properties") }
  self.lc = properties % 9
  self.lp = (properties / 9) % 5
  self.pb = properties / 45
  self.literals = FixedArray::make(768 << (self.lc + self.lp), 1024)
}

///|
fn LzmaState::reset_models(self : LzmaState) -> Unit {
  for models in [self.is_match, self.is_rep, self.rep_g0, self.rep_g1, self.rep_g2,
    self.rep0_long, self.slots, self.distances, self.align_bits, self.lengths,
    self.rep_lengths, self.literals] {
    for i in 0..<models.length() { models[i] = 1024 }
  }
  for i in 0..<4 { self.reps[i] = 0U }
  self.state = 0
}

///|
fn LzmaState::reset_dictionary(self : LzmaState) -> Unit {
  self.dictionary_pos = 0
  self.filled = 0
  self.total = 0L
  self.previous = b'\x00'
}

///|
fn LzmaState::raw_step(self : LzmaState, input : BytesView, output : MutArrayView[Byte], end~ : Bool) -> Step {
  let mut ip = 0
  let mut op = 0
  fn result(status : Status) -> Step { { consumed: ip, produced: op, status } }
  try {
    for ;; {
      let required = if self.range_ready { 20 } else { 5 }
      while self.queued < required && ip < input.length() {
        self.queue[self.queued] = input[ip]
        self.queued += 1
        ip += 1
      }
      if !self.range_ready {
        if self.queued < 5 { return result(if end { Failed("truncated LZMA2 range header") } else { NeedInput }) }
        if self.queue[0] != b'\x00' { return result(Failed("invalid LZMA2 range header")) }
        for i in 1..<5 { self.code = (self.code << 8) | self.queue[i].to_uint() }
        self.queued = 0
        self.range_ready = true
        continue
      }
      while op < output.length() && (self.literal is Some(_) || self.copy_len > 0) {
        let byte = match self.literal {
          Some(byte) => { self.literal = None; byte }
          None => { self.copy_len -= 1; self.history((self.copy_distance - 1).reinterpret_as_uint()) }
        }
        self.emit(byte)
        output[op] = byte
        op += 1
      }
      if self.expected == Some(self.total) && self.copy_len == 0 && self.literal is None {
        if self.code != 0U || self.queued > 0 || ip < input.length() { return result(Failed("LZMA2 compressed size or range termination mismatch")) }
        return result(Done)
      }
      if op == output.length() { return result(NeedOutput) }
      if self.queued < 20 && !end { return result(NeedInput) }
      self.cursor = 0
      self.symbol()
      if self.ended { return result(Failed("LZMA end marker is forbidden inside LZMA2")) }
      let remaining = self.queued - self.cursor
      for i in 0..<remaining { self.queue[i] = self.queue[i + self.cursor] }
      self.queued = remaining
    }
  } catch { DecodeError(message) => result(Failed(message)) }
}

///|
fn LzmaState::normalize(self : LzmaState) -> Unit raise DecodeError {
  if self.range < 0x01000000U {
    guard self.cursor < self.queued else { raise DecodeError("truncated LZMA range code") }
    self.range = self.range << 8
    self.code = (self.code << 8) | self.queue[self.cursor].to_uint()
    self.cursor += 1
  }
}

///|
fn LzmaState::bit(self : LzmaState, models : FixedArray[Int], index : Int) -> Int raise DecodeError {
  let probability = models[index]
  let bound = (self.range >> 11) * probability.reinterpret_as_uint()
  let bit = if self.code < bound {
    self.range = bound
    models[index] = probability + ((2048 - probability) >> 5)
    0
  } else {
    self.range -= bound
    self.code -= bound
    models[index] = probability - (probability >> 5)
    1
  }
  self.normalize()
  bit
}

///|
fn LzmaState::tree(self : LzmaState, models : FixedArray[Int], offset : Int, count : Int, reverse~ : Bool = false) -> Int raise DecodeError {
  let mut node = 1
  let mut result = 0
  for i in 0..<count {
    let bit = self.bit(models, offset + node)
    node = (node << 1) | bit
    result = if reverse { result | (bit << i) } else { (result << 1) | bit }
  }
  result
}

///|
fn LzmaState::direct(self : LzmaState, count : Int) -> UInt raise DecodeError {
  let mut result = 0U
  for _ in 0..<count {
    self.range = self.range >> 1
    result = result << 1
    if self.code >= self.range { self.code -= self.range; result = result | 1U }
    self.normalize()
  }
  result
}

///|
fn LzmaState::length(self : LzmaState, models : FixedArray[Int], position : Int) -> Int raise DecodeError {
  if self.bit(models, 0) == 0 { return 2 + self.tree(models, 2 + position * 8, 3) }
  if self.bit(models, 1) == 0 { return 10 + self.tree(models, 2 + 128 + position * 8, 3) }
  18 + self.tree(models, 2 + 256, 8)
}

///|
fn LzmaState::history(self : LzmaState, distance : UInt) -> Byte raise DecodeError {
  guard distance < self.filled.reinterpret_as_uint() else { raise DecodeError("invalid LZMA match distance") }
  let at = self.dictionary_pos - distance.reinterpret_as_int() - 1
  self.dictionary[if at < 0 { at + self.dictionary.length() } else { at }]
}

///|
fn LzmaState::symbol(self : LzmaState) -> Unit raise DecodeError {
  let position = self.total.to_int() & ((1 << self.pb) - 1)
  if self.bit(self.is_match, self.state * 16 + position) == 0 {
    let context = ((self.total.to_int() & ((1 << self.lp) - 1)) << self.lc) +
      (self.previous.to_int() >> (8 - self.lc))
    let base = context * 768
    let mut symbol = 1
    if self.state >= 7 {
      let mut match_byte = self.history(self.reps[0]).to_int()
      while symbol < 256 {
        let expected = (match_byte >> 7) & 1
        match_byte = match_byte << 1
        let bit = self.bit(self.literals, base + ((1 + expected) << 8) + symbol)
        symbol = (symbol << 1) | bit
        if bit != expected { break }
      }
    }
    while symbol < 256 { symbol = (symbol << 1) | self.bit(self.literals, base + symbol) }
    self.literal = Some((symbol - 256).to_byte())
    self.state = if self.state < 4 { 0 } else if self.state < 10 { self.state - 3 } else { self.state - 6 }
    return
  }
  if self.bit(self.is_rep, self.state) == 1 {
    if self.bit(self.rep_g0, self.state) == 0 {
      if self.bit(self.rep0_long, self.state * 16 + position) == 0 {
        self.copy_len = 1
        self.copy_distance = self.reps[0].reinterpret_as_int() + 1
        self.state = if self.state < 7 { 9 } else { 11 }
        ignore(self.history(self.reps[0]))
        return
      }
    } else {
      let distance = if self.bit(self.rep_g1, self.state) == 0 { self.reps[1] } else {
        let distance = if self.bit(self.rep_g2, self.state) == 0 { self.reps[2] } else {
          let distance = self.reps[3]
          self.reps[3] = self.reps[2]
          distance
        }
        self.reps[2] = self.reps[1]
        distance
      }
      self.reps[1] = self.reps[0]
      self.reps[0] = distance
    }
    self.copy_len = self.length(self.rep_lengths, position)
    self.state = if self.state < 7 { 8 } else { 11 }
  } else {
    self.reps[3] = self.reps[2]
    self.reps[2] = self.reps[1]
    self.reps[1] = self.reps[0]
    self.copy_len = self.length(self.lengths, position)
    self.state = if self.state < 7 { 7 } else { 10 }
    let slot = self.tree(self.slots, (self.copy_len - 2).min(3) * 64, 6)
    self.reps[0] = if slot < 4 { slot.reinterpret_as_uint() } else {
      let direct = (slot >> 1) - 1
      let base = (2U | (slot & 1).reinterpret_as_uint()) << direct
      if slot < 14 {
        base + self.tree(self.distances, base.reinterpret_as_int() - slot - 1, direct, reverse=true).reinterpret_as_uint()
      } else {
        base + (self.direct(direct - 4) << 4) + self.tree(self.align_bits, 0, 4, reverse=true).reinterpret_as_uint()
      }
    }
    if self.reps[0] == 0xffffffffU {
      self.copy_len = 0
      guard self.code == 0U else { raise DecodeError("invalid LZMA end marker") }
      self.ended = true
      return
    }
  }
  ignore(self.history(self.reps[0]))
  self.copy_distance = self.reps[0].reinterpret_as_int() + 1
}

///|
fn LzmaState::emit(self : LzmaState, byte : Byte) -> Unit raise DecodeError {
  if self.total == 9223372036854775807L { raise DecodeError("LZMA output length overflow") }
  if self.expected is Some(size) && self.total >= size { raise DecodeError("LZMA output exceeds declared size") }
  self.dictionary[self.dictionary_pos] = byte
  self.dictionary_pos = (self.dictionary_pos + 1) % self.dictionary.length()
  self.filled = (self.filled + 1).min(self.dictionary.length())
  self.total += 1L
  self.previous = byte
}

///|
fn LzmaState::step(self : LzmaState, input : BytesView, output : MutArrayView[Byte], end~ : Bool) -> Step {
  let mut ip = 0
  let mut op = 0
  fn result(status : Status) -> Step { { consumed: ip, produced: op, status } }
  try {
    while self.header_len < 13 && ip < input.length() {
      self.header[self.header_len] = input[ip]
      self.header_len += 1
      ip += 1
      if self.header_len == 13 {
        let mut dictionary = 0U
        let mut expected = 0UL
        for i in 0..<4 { dictionary = dictionary | (self.header[1 + i].to_uint() << (i * 8)) }
        for i in 0..<8 { expected = expected | (self.header[5 + i].to_uint64() << (i * 8)) }
        if expected != 0xffffffffffffffffUL {
          guard expected <= 9223372036854775807UL else { raise DecodeError("LZMA declared size overflow") }
          self.expected = Some(expected.reinterpret_as_int64())
        }
        self.configure(self.header[0].to_int(), dictionary)
      }
    }
    if self.header_len < 13 { return result(if end { Failed("truncated LZMA header") } else { NeedInput }) }
    for ;; {
      if self.ended {
        if self.expected is Some(size) && self.total != size { return result(Failed("LZMA uncompressed size mismatch")) }
        if self.queued > 0 || ip < input.length() { return result(Failed("trailing data after LZMA stream")) }
        return result(if end { Done } else { NeedInput })
      }
      let required = if self.range_ready { 20 } else { 5 }
      while self.queued < required && ip < input.length() {
        self.queue[self.queued] = input[ip]
        self.queued += 1
        ip += 1
      }
      if !self.range_ready {
        if self.queued < 5 { return result(if end { Failed("truncated LZMA range header") } else { NeedInput }) }
        if self.queue[0] != b'\x00' { return result(Failed("invalid LZMA range header")) }
        for i in 1..<5 { self.code = (self.code << 8) | self.queue[i].to_uint() }
        self.queued = 0
        self.range_ready = true
        continue
      }
      while op < output.length() && (self.literal is Some(_) || self.copy_len > 0) {
        let byte = match self.literal {
          Some(byte) => { self.literal = None; byte }
          None => { self.copy_len -= 1; self.history((self.copy_distance - 1).reinterpret_as_uint()) }
        }
        self.emit(byte)
        output[op] = byte
        op += 1
      }
      if op == output.length() { return result(NeedOutput) }
      if self.expected == Some(self.total) && self.code == 0U { self.ended = true; continue }
      if self.queued < 20 && !end { return result(NeedInput) }
      self.cursor = 0
      self.symbol()
      let remaining = self.queued - self.cursor
      for i in 0..<remaining { self.queue[i] = self.queue[i + self.cursor] }
      self.queued = remaining
    }
  } catch {
    DecodeError(message) => result(Failed(message))
  }
}
