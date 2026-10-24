///|
priv enum Digest {
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
priv struct DigestSpec {
  algorithm : Digest
  bits : Int32
}

///|
fn Digest::label(self : Digest) -> String {
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
fn Digest::default_bits(self : Digest) -> Int32 {
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
fn Digest::legacy(self : Digest) -> Bool {
  self is (Bsd | Sysv | Crc | Crc32b)
}

///|
fn named_algorithm(value : String) -> Digest? {
  match value {
    "bsd" => Some(Bsd)
    "sysv" => Some(Sysv)
    "crc" => Some(Crc)
    "crc32b" => Some(Crc32b)
    "md5" => Some(Fixed(Md5))
    "sha1" => Some(Fixed(Sha1))
    "sha224" => Some(Sha224)
    "sha256" => Some(Fixed(Sha256))
    "sha384" => Some(Sha384)
    "sha512" => Some(Fixed(Sha512))
    "sha2" => Some(Sha2)
    "sha3" => Some(Sha3)
    "blake2b" => Some(Blake2b)
    "sm3" => Some(Sm3)
    _ => None
  }
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
fn DigestSpec::tag(self : DigestSpec) -> String {
  match self.algorithm {
    Sha2 => "SHA\{self.bits}"
    Sha3 => "SHA3-\{self.bits}"
    Blake2b if self.bits != 512 => "BLAKE2b-\{self.bits}"
    _ => self.algorithm.label()
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
async fn digest_reader(
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

///|
async fn digest_source(spec : DigestSpec, path : String) -> (Bytes, UInt64) {
  if path == "-" {
    digest_reader(spec, @stdio.stdin)
  } else {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    if file.kind() is Directory {
      raise DigestError("Is a directory")
    }
    digest_reader(spec, file)
  }
}

///|
priv suberror DigestError {
  DigestError(String)
}

///|
fn error_message(error : Error) -> String {
  match error {
    DigestError(message) => message
    @os_error.OSError(_) as error if error.is_ENOENT() =>
      "No such file or directory"
    @os_error.OSError(_) as error if error.is_EACCES() => "Permission denied"
    @os_error.OSError(_) as error if error.is_ENOTDIR() => "Not a directory"
    _ => error.to_string()
  }
}
