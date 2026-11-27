///|
pub(all) enum Field {
  Literal(String)
  Name
  Kind
  Size
  Access
  Modify
  Change
}

///|
pub fn parse(format : String) -> Array[Field] raise {
  let fields = []
  let mut start = 0
  let mut index = 0
  while index < format.length() {
    if format[index] != '%' {
      index += 1
      continue
    }
    if index > start {
      fields.push(Literal(format[start:index].to_owned()))
    }
    index += 1
    guard index < format.length() else {
      raise Failure("incomplete format directive")
    }
    fields.push(
      match format[index] {
        '%' => Literal("%")
        'n' => Name
        'F' => Kind
        's' => Size
        'X' => Access
        'Y' => Modify
        'Z' => Change
        _ =>
          raise Failure(
            "unsupported format directive: %" +
            format[index:index + 1].to_owned(),
          )
      },
    )
    index += 1
    start = index
  }
  if start < format.length() {
    fields.push(Literal(format[start:].to_owned()))
  }
  fields
}

///|
pub async fn render(
  fields : ArrayView[Field],
  path : String,
  follow~ : Bool,
) -> String {
  let kind = @fs.kind(path, follow_symlink=follow)
  let output = StringBuilder()
  let mut size = None
  for field in fields {
    if (field is Size || (field is Kind && kind is Regular)) && size is None {
      let entry = if follow { @fs.realpath(path) } else { path }
      size = Some(
        @fs.file_size(entry) catch {
          @os_error.OsError(OperationNotSupported, ..) =>
            raise Failure("entry size is unavailable")
          error => raise error
        },
      )
    }
    match field {
      Name => output.write_string(path)
      Literal(text) => output.write_string(text)
      Size => output.write_object(size.unwrap())
      Kind =>
        output.write_string(
          match kind {
            Regular =>
              if size == Some(0L) {
                "regular empty file"
              } else {
                "regular file"
              }
            Directory => "directory"
            SymLink => "symbolic link"
            Socket => "socket"
            Pipe => "fifo"
            BlockDevice => "block special file"
            CharDevice | Console => "character special file"
            _ => "unknown"
          },
        )
      Access =>
        output.write_object(@fs.atime(path, follow_symlink=follow).sec())
      Modify =>
        output.write_object(@fs.mtime(path, follow_symlink=follow).sec())
      Change =>
        output.write_object(@fs.ctime(path, follow_symlink=follow).sec())
    }
  }
  output.to_string()
}
