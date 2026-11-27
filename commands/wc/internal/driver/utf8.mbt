///|
async fn count_utf8(
  reader : &@io.BinaryReader,
  counts : Counts,
  selection : Selection,
  posix~ : Bool,
) -> Unit {
  let decoder = @textwidth.Decoder(Utf8)
  let mut in_word = false
  let mut column = 0L
  defer {
    counts.max_line_length = counts.max_line_length.max(column)
  }
  fn consume(ch : Char?, _ : BytesView) {
    if selection.chars && ch is Some(_) {
      counts.chars += 1
    }
    if selection.lines && ch is Some('\n') {
      counts.lines += 1
    }
    if selection.max_line_length {
      match ch {
        Some('\n' | '\r' | '\u000c') => {
          counts.max_line_length = counts.max_line_length.max(column)
          column = 0
        }
        Some('\t') => column += 8 - column % 8
        _ => column += @textwidth.cells(ch, fallback=0).to_int64()
      }
    }
    if selection.words {
      let space = match ch {
        Some('\u00a0' | '\u2007' | '\u202f' | '\u2060') => !posix
        Some('\u0085') => false
        Some(c) => c.is_whitespace()
        None => false
      }
      if !space && !in_word {
        counts.words += 1
      }
      in_word = !space
    }
  }
  let buffer = FixedArray::make(1048576, b'\x00')
  let data = buffer.unsafe_reinterpret_as_bytes()
  while reader.read_into(buffer.mut_view()) is n && n > 0 {
    if selection.bytes {
      counts.bytes += n.to_int64()
    }
    decoder.feed(data[:n], consume)
  }
  decoder.feed(b"", consume, eof=true)
}
