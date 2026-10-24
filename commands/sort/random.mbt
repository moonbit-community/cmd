///|
async fn random_seed(source : String?) -> Bytes {
  guard source is Some(path) else {
    return match @env.rand(16) {
      Some(seed) => seed
      None => raise CliError("sort: secure random source is unavailable")
    }
  }
  let file = @fs.open(path, mode=ReadOnly) catch {
    @os_error.OSError(_) as error => {
      let name = if path == "" { "''" } else { path }
      raise CliError("sort: open failed: \{name}: \{os_message(error)}")
    }
    error => raise error
  }
  defer file.close()
  read_random_seed(file, path)
}

///|
async fn read_random_seed(reader : &@io.Reader, path : String) -> Bytes {
  let seed = FixedArray::make(16, b'\x00')
  let mut used = 0
  while used < 16 {
    let count = reader.read(seed, offset=used, max_len=16 - used) catch {
      @os_error.OSError(_) as error =>
        raise CliError("sort: '\{path}': \{os_message(error)}")
      error => raise error
    }
    if count == 0 {
      raise CliError("sort: '\{path}': end of file")
    }
    used += count
  }
  seed.unsafe_reinterpret_as_bytes()
}

///|
fn os_message(error : @os_error.OSError) -> String {
  if error.is_ENOENT() {
    "No such file or directory"
  } else if error.is_EACCES() {
    "Permission denied"
  } else if error.is_ENOTDIR() {
    "Not a directory"
  } else if error.is_EEXIST() {
    "File exists"
  } else {
    error.to_string()
  }
}

///|
fn random_key(seed : Bytes, key : Bytes) -> Bytes {
  let state = @crypto.MD5::new()
  state.update(seed)
  state.update(key)
  Bytes::from_array(state.finalize())
}

///|
fn prepared_key(key : Bytes, modifiers : Modifiers, seed : Bytes) -> Bytes {
  let effective = transformed_key(key, modifiers)
  if modifiers.mode != Random {
    return effective
  }
  let digest = random_key(seed, effective)
  let encoded = FixedArray::make(16 + effective.length(), b'\x00')
  for index in 0..<16 {
    encoded[index] = digest[index]
  }
  for index in 0..<effective.length() {
    encoded[index + 16] = effective[index]
  }
  encoded.unsafe_reinterpret_as_bytes()
}
