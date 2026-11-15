///|
async fn random_seed(source : String?) -> Bytes {
  guard source is Some(path) else {
    return match @env.rand(16) {
      Some(seed) => seed
      None => raise @order.CliError("sort: secure random source is unavailable")
    }
  }
  if path == "" {
    raise @order.CliError("sort: open failed: '': No such file or directory")
  }
  let file = @fs.open(path, mode=ReadOnly) catch {
    @os_error.OSError(_) as error =>
      raise @order.CliError("sort: open failed: \{path}: \{os_message(error)}")
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
        raise @order.CliError("sort: '\{path}': \{os_message(error)}")
      error => raise error
    }
    if count == 0 {
      raise @order.CliError("sort: '\{path}': end of file")
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
