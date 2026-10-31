///|
using @checksum {type Algorithm, type Digest, type DigestSpec}

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
fn digest_tag(spec : DigestSpec) -> String {
  match spec.algorithm {
    Sha2 => "SHA\{spec.bits}"
    Sha3 => "SHA3-\{spec.bits}"
    Blake2b if spec.bits != 512 => "BLAKE2b-\{spec.bits}"
    _ => spec.algorithm.label()
  }
}

///|
async fn digest_source(spec : DigestSpec, path : String) -> (Bytes, UInt64) {
  if path == "-" {
    @checksum.digest_reader(spec, @stdio.stdin)
  } else {
    let file = @fs.open(path, mode=ReadOnly)
    defer file.close()
    if file.kind() is Directory {
      raise DigestError("Is a directory")
    }
    @checksum.digest_reader(spec, file)
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

///|
fn legacy_number(bytes : Bytes) -> UInt32 {
  let mut value = 0U
  for byte in bytes {
    value = (value << 8) | byte.to_uint()
  }
  value
}
