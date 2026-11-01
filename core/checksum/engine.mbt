///|
pub(all) enum Digest {
  Bsd
  Sysv
  Crc
  Crc32b
  Fixed(Algorithm)
  Sha224
  Sha384
  Sha2
  Sha3
  Blake2b
  Sm3
}

///|
pub(all) struct DigestSpec {
  algorithm : Digest
  bits : Int32
}

///|
pub fn Digest::label(self : Digest) -> String {
  match self {
    Bsd => "BSD"
    Sysv => "SYSV"
    Crc => "CRC"
    Crc32b => "CRC32B"
    Fixed(algorithm) => algorithm.label()
    Sha224 => "SHA224"
    Sha384 => "SHA384"
    Sha2 => "SHA2"
    Sha3 => "SHA3"
    Blake2b => "BLAKE2b"
    Sm3 => "SM3"
  }
}

///|
pub fn Digest::default_bits(self : Digest) -> Int32 {
  match self {
    Bsd | Sysv => 16
    Crc | Crc32b => 32
    Fixed(algorithm) => algorithm.hex_length() * 4
    Sha224 => 224
    Sha384 => 384
    Sha2 | Sha3 | Blake2b => 512
    Sm3 => 256
  }
}

///|
pub fn Digest::legacy(self : Digest) -> Bool {
  self is (Bsd | Sysv | Crc | Crc32b)
}

///|
fn sha2_digest(bits : Int32) -> Digest {
  match bits {
    224 => Sha224
    256 => Fixed(Sha256)
    384 => Sha384
    _ => Fixed(Sha512)
  }
}

///|
priv struct Hasher {
  update : (Bytes) -> Unit
  finish : () -> Bytes
}

///|
fn fixed_hasher(algorithm : Algorithm) -> Hasher {
  match algorithm {
    Md5 => {
      let state = @crypto.MD5::new()
      {
        update: bytes => state.update(bytes),
        finish: () => state.finalize().unsafe_reinterpret_as_bytes(),
      }
    }
    Sha1 => {
      let state = Sha1State::new()
      {
        update: bytes => state.update(bytes[:]),
        finish: () => state.finalize_bytes(),
      }
    }
    Sha256 => {
      let state = @crypto.SHA256::new()
      {
        update: bytes => state.update(bytes),
        finish: () => state.finalize().unsafe_reinterpret_as_bytes(),
      }
    }
    Sha512 => {
      let state = @crypto.SHA512::new()
      {
        update: bytes => state.update(bytes),
        finish: () => state.finalize().unsafe_reinterpret_as_bytes(),
      }
    }
  }
}

///|
fn make_hasher(spec : DigestSpec) -> Hasher {
  match spec.algorithm {
    Fixed(algorithm) => fixed_hasher(algorithm)
    Sha224 => {
      let state = @crypto.SHA224::new()
      {
        update: bytes => state.update(bytes),
        finish: () => state.finalize().unsafe_reinterpret_as_bytes(),
      }
    }
    Sha384 => {
      let state = @mooncry.sha384_new()
      {
        update: bytes => @mooncry.sha384_update(state, bytes),
        finish: () => @mooncry.sha384_finalize(state),
      }
    }
    Sha2 => make_hasher({ algorithm: sha2_digest(spec.bits), bits: spec.bits, })
    Sha3 => {
      let state = match spec.bits {
        224 => @mooncry.sha3_224_new()
        256 => @mooncry.sha3_256_new()
        384 => @mooncry.sha3_384_new()
        _ => @mooncry.sha3_512_new()
      }
      {
        update: bytes => @mooncry.sha3_update(state, bytes),
        finish: () => @mooncry.sha3_finalize(state),
      }
    }
    Blake2b => {
      let state = Blake2bState::new(spec.bits / 8)
      {
        update: bytes => state.update(bytes[:]),
        finish: () => state.finalize(),
      }
    }
    Sm3 => {
      let state = @crypto.SM3::new()
      {
        update: bytes => state.update(bytes),
        finish: () => state.finalize().unsafe_reinterpret_as_bytes(),
      }
    }
    _ => {
      let state = LegacyState::new(spec.algorithm)
      {
        update: bytes => state.update(bytes[:]),
        finish: () => state.finalize(),
      }
    }
  }
}

///|
pub async fn digest_reader(
  spec : DigestSpec,
  reader : &@io.Reader,
) -> (Bytes, UInt64) {
  let hasher = make_hasher(spec)
  let mut length = 0UL
  while reader.read_some(max_len=65536) is Some(chunk) {
    (hasher.update)(chunk)
    length += chunk.length().to_uint64()
  }
  let result = (hasher.finish)()
  (result[:spec.bits / 8].to_owned(), length)
}
