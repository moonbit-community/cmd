///|
pub fn compile_lines(
  bytes : Bytes,
  colors : Bool,
) -> Array[Format] raise FormatError {
  let formats = []
  let mut start = 0
  for index in 0..<=bytes.length() {
    if index == bytes.length() || bytes[index] == b'\n' {
      let mut first = start
      while first < index && format_space(bytes[first]) {
        first += 1
      }
      if first < index && bytes[first] != b'#' {
        formats.push(compile_format(bytes[first:index], colors))
      }
      start = index + 1
    }
  }
  formats
}
