///|
// RFC 7693, unkeyed BLAKE2b. Keep the last full block until finalization so
// messages ending on a block boundary receive the final-block flag correctly.
priv struct Blake2bState {
  h : FixedArray[UInt64]
  block : FixedArray[Byte]
  words : FixedArray[UInt64]
  work : FixedArray[UInt64]
  output_length : Int32
  mut used : Int32
  mut count_low : UInt64
  mut count_high : UInt64
}

///|
let blake_iv : FixedArray[UInt64] = [
  0x6a09e667f3bcc908UL, 0xbb67ae8584caa73bUL, 0x3c6ef372fe94f82bUL, 0xa54ff53a5f1d36f1UL,
  0x510e527fade682d1UL, 0x9b05688c2b3e6c1fUL, 0x1f83d9abfb41bd6bUL, 0x5be0cd19137e2179UL,
]

///|
let blake_sigma : FixedArray[FixedArray[Int32]] = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
  [14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3],
  [11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4],
  [7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8],
  [9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13],
  [2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9],
  [12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11],
  [13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10],
  [6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5],
  [10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0],
]

///|
fn Blake2bState::new(output_length : Int32) -> Blake2bState {
  let h = FixedArray::makei(8, i => blake_iv[i])
  h[0] = h[0] ^ (0x01010000UL | output_length.to_uint64())
  {
    h,
    block: FixedArray::make(128, b'\x00'),
    words: FixedArray::make(16, 0UL),
    work: FixedArray::make(16, 0UL),
    output_length,
    used: 0,
    count_low: 0UL,
    count_high: 0UL,
  }
}

///|
fn rotate_right(value : UInt64, bits : Int32) -> UInt64 {
  (value >> bits) | (value << (64 - bits))
}

///|
fn Blake2bState::mix(
  self : Blake2bState,
  a : Int32,
  b : Int32,
  c : Int32,
  d : Int32,
  x : UInt64,
  y : UInt64,
) -> Unit {
  let v = self.work
  v[a] = v[a] + v[b] + x
  v[d] = rotate_right(v[d] ^ v[a], 32)
  v[c] += v[d]
  v[b] = rotate_right(v[b] ^ v[c], 24)
  v[a] = v[a] + v[b] + y
  v[d] = rotate_right(v[d] ^ v[a], 16)
  v[c] += v[d]
  v[b] = rotate_right(v[b] ^ v[c], 63)
}

///|
fn Blake2bState::compress(self : Blake2bState, last : Bool) -> Unit {
  for i in 0..<16 {
    let mut value = 0UL
    for j in 0..<8 {
      value = value | (self.block[i * 8 + j].to_uint64() << (j * 8))
    }
    self.words[i] = value
    self.work[i] = if i < 8 { self.h[i] } else { blake_iv[i - 8] }
  }
  self.work[12] = self.work[12] ^ self.count_low
  self.work[13] = self.work[13] ^ self.count_high
  if last {
    self.work[14] = self.work[14].lnot()
  }
  let m = self.words
  for round in 0..<12 {
    let s = blake_sigma[round % 10]
    self.mix(0, 4, 8, 12, m[s[0]], m[s[1]])
    self.mix(1, 5, 9, 13, m[s[2]], m[s[3]])
    self.mix(2, 6, 10, 14, m[s[4]], m[s[5]])
    self.mix(3, 7, 11, 15, m[s[6]], m[s[7]])
    self.mix(0, 5, 10, 15, m[s[8]], m[s[9]])
    self.mix(1, 6, 11, 12, m[s[10]], m[s[11]])
    self.mix(2, 7, 8, 13, m[s[12]], m[s[13]])
    self.mix(3, 4, 9, 14, m[s[14]], m[s[15]])
  }
  for i in 0..<8 {
    self.h[i] = self.h[i] ^ self.work[i] ^ self.work[i + 8]
  }
}

///|
fn Blake2bState::count(self : Blake2bState, amount : Int32) -> Unit {
  let previous = self.count_low
  self.count_low += amount.to_uint64()
  if self.count_low < previous {
    self.count_high += 1UL
  }
}

///|
fn Blake2bState::update(self : Blake2bState, bytes : BytesView) -> Unit {
  let mut offset = 0
  while offset < bytes.length() {
    if self.used == 128 {
      self.count(128)
      self.compress(false)
      self.used = 0
    }
    let amount = (128 - self.used).min(bytes.length() - offset)
    for i in 0..<amount {
      self.block[self.used + i] = bytes[offset + i]
    }
    self.used += amount
    offset += amount
  }
}

///|
fn Blake2bState::finalize(self : Blake2bState) -> Bytes {
  self.count(self.used)
  for i in self.used..<128 {
    self.block[i] = b'\x00'
  }
  self.compress(true)
  Bytes::makei(self.output_length, i => (self.h[i / 8] >> (i % 8 * 8)).to_byte())
}
