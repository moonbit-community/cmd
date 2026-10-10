///|
pub(all) enum Algorithm {
  Md5
  Sha1
  Sha512
}

///|
fn Algorithm::label(self : Algorithm) -> String {
  match self {
    Md5 => "MD5"
    Sha1 => "SHA1"
    Sha512 => "SHA512"
  }
}

///|
fn Algorithm::command(self : Algorithm) -> String {
  self.label().to_lower() + "sum"
}

///|
fn Algorithm::hex_length(self : Algorithm) -> Int {
  match self {
    Md5 => 32
    Sha1 => 40
    Sha512 => 128
  }
}

///|
// x exposes SHA-1 only as a one-shot function. Keep a single block in memory
// here so sha1sum supports arbitrarily long streams like the other algorithms.
priv struct Sha1State {
  words : FixedArray[UInt]
  block : FixedArray[Byte]
  mut used : Int
  mut length : UInt64
}

///|
fn Sha1State::new() -> Sha1State {
  {
    words: [0x67452301U, 0xEFCDAB89U, 0x98BADCFEU, 0x10325476U, 0xC3D2E1F0U],
    block: FixedArray::make(64, b'\x00'),
    used: 0,
    length: 0UL,
  }
}

///|
fn rotate(value : UInt, amount : Int) -> UInt {
  (value << amount) | (value >> (32 - amount))
}

///|
fn Sha1State::compress(self : Sha1State) -> Unit {
  let schedule = FixedArray::make(80, 0U)
  for i in 0..<16 {
    let offset = i * 4
    schedule[i] = (self.block[offset].to_uint() << 24) |
      (self.block[offset + 1].to_uint() << 16) |
      (self.block[offset + 2].to_uint() << 8) |
      self.block[offset + 3].to_uint()
  }
  for i in 16..<80 {
    schedule[i] = rotate(
      schedule[i - 3] ^ schedule[i - 8] ^ schedule[i - 14] ^ schedule[i - 16],
      1,
    )
  }
  let mut a = self.words[0]
  let mut b = self.words[1]
  let mut c = self.words[2]
  let mut d = self.words[3]
  let mut e = self.words[4]
  for i in 0..<80 {
    let (mix, constant) = if i < 20 {
      ((b & c) | (b.lnot() & d), 0x5A827999U)
    } else if i < 40 {
      (b ^ c ^ d, 0x6ED9EBA1U)
    } else if i < 60 {
      ((b & c) | (b & d) | (c & d), 0x8F1BBCDCU)
    } else {
      (b ^ c ^ d, 0xCA62C1D6U)
    }
    let next = rotate(a, 5) + mix + e + constant + schedule[i]
    e = d
    d = c
    c = rotate(b, 30)
    b = a
    a = next
  }
  self.words[0] += a
  self.words[1] += b
  self.words[2] += c
  self.words[3] += d
  self.words[4] += e
}

///|
fn Sha1State::update(self : Sha1State, input : BytesView) -> Unit {
  self.length += input.length().to_uint64()
  for byte in input {
    self.block[self.used] = byte
    self.used += 1
    if self.used == 64 {
      self.compress()
      self.used = 0
    }
  }
}

///|
fn Sha1State::finalize(self : Sha1State) -> String {
  let bit_length = self.length * 8UL
  self.block[self.used] = b'\x80'
  self.used += 1
  if self.used > 56 {
    for i in self.used..<64 {
      self.block[i] = b'\x00'
    }
    self.compress()
    self.used = 0
  }
  for i in self.used..<56 {
    self.block[i] = b'\x00'
  }
  for i in 0..<8 {
    self.block[56 + i] = (bit_length >> (56 - 8 * i)).to_byte()
  }
  self.compress()
  let result = FixedArray::make(20, b'\x00')
  for i in 0..<20 {
    result[i] = (self.words[i / 4] >> (24 - i % 4 * 8)).to_byte()
  }
  @crypto.bytes_to_hex_string(result)
}

///|
async fn digest_reader(algorithm : Algorithm, reader : &@io.Reader) -> String {
  match algorithm {
    Md5 => {
      let state = @crypto.MD5::new()
      while reader.read_some(max_len=65536) is Some(chunk) {
        state.update(chunk)
      }
      @crypto.bytes_to_hex_string(state.finalize())
    }
    Sha1 => {
      let state = Sha1State::new()
      while reader.read_some(max_len=65536) is Some(chunk) {
        state.update(chunk)
      }
      state.finalize()
    }
    Sha512 => {
      let state = @crypto.SHA512::new()
      while reader.read_some(max_len=65536) is Some(chunk) {
        state.update(chunk)
      }
      @crypto.bytes_to_hex_string(state.finalize())
    }
  }
}

///|
async fn digest_source(algorithm : Algorithm, path : String) -> String {
  if path == "-" {
    digest_reader(algorithm, @stdio.stdin)
  } else {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    digest_reader(algorithm, file)
  }
}
