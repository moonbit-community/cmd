///|
let crc_table : FixedArray[UInt32] = FixedArray::makei(256, i => {
  let mut value = i.reinterpret_as_uint() << 24
  for _ in 0..<8 {
    value = if (value & 0x80000000U) != 0U {
      (value << 1) ^ 0x04C11DB7U
    } else {
      value << 1
    }
  }
  value
})

///|
let crc32b_table : FixedArray[UInt32] = FixedArray::makei(256, i => {
  let mut value = i.reinterpret_as_uint()
  for _ in 0..<8 {
    value = if (value & 1U) != 0U {
      (value >> 1) ^ 0xEDB88320U
    } else {
      value >> 1
    }
  }
  value
})

///|
fn crc_update(value : UInt32, byte : Byte) -> UInt32 {
  (value << 8) ^
  crc_table[((value >> 24) ^ byte.to_uint()).reinterpret_as_int() & 255]
}

///|
fn crc_length(value : UInt32, length : UInt64) -> UInt32 {
  let mut crc = value
  let mut rest = length
  while rest != 0UL {
    crc = crc_update(crc, rest.to_byte())
    rest = rest >> 8
  }
  crc.lnot()
}

///|
priv struct LegacyState {
  algorithm : Digest
  mut value : UInt32
  mut length : UInt64
}

///|
fn LegacyState::new(algorithm : Digest) -> LegacyState {
  {
    algorithm,
    value: if algorithm is Crc32b {
      0xFFFFFFFFU
    } else {
      0U
    },
    length: 0UL,
  }
}

///|
fn LegacyState::update(self : LegacyState, bytes : BytesView) -> Unit {
  self.length += bytes.length().to_uint64()
  for byte in bytes {
    self.value = match self.algorithm {
      Bsd =>
        (((self.value >> 1) | ((self.value & 1U) << 15)) + byte.to_uint()) &
        65535U
      Sysv => self.value + byte.to_uint()
      Crc => crc_update(self.value, byte)
      _ =>
        (self.value >> 8) ^
        crc32b_table[((self.value ^ byte.to_uint()) & 255U).reinterpret_as_int()]
    }
  }
}

///|
fn LegacyState::finalize(self : LegacyState) -> Bytes {
  let value = match self.algorithm {
    Bsd => self.value
    Sysv => {
      let folded = (self.value & 65535U) + (self.value >> 16)
      (folded & 65535U) + (folded >> 16)
    }
    Crc => crc_length(self.value, self.length)
    _ => self.value.lnot()
  }
  let size = if self.algorithm is (Bsd | Sysv) { 2 } else { 4 }
  Bytes::makei(size, i => (value >> ((size - i - 1) * 8)).to_byte())
}
