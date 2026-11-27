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
    @os_error.OsError(_, ..) as error =>
      raise @order.CliError("sort: open failed: \{path}: \{os_message(error)}")
    error => raise error
  }
  defer file.close()
  read_random_seed(file, path)
}

///|
async fn read_random_seed(reader : &@io.BinaryReader, path : String) -> Bytes {
  let seed = FixedArray::make(16, b'\x00')
  let mut used = 0
  while used < 16 {
    let count = reader.read_into(seed.mut_view(start=used)) catch {
      @io.ReaderError::TransportError(@os_error.OsError(_, ..) as error, ..) =>
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
fn os_message(error : @os_error.OsError) -> String {
  let @os_error.OsError(kind, ..) = error
  match kind {
    NotFound => "No such file or directory"
    AccessDenied => "Permission denied"
    NotDirectory => "Not a directory"
    AlreadyExists => "File exists"
    _ => error.to_string()
  }
}
