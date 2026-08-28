///|
pub let chunk_size : Int = 65536

///|
pub async fn read_chunk(reader : &@io.Reader) -> Bytes? {
  reader.read_some(max_len=chunk_size)
}

///|
pub(all) struct Line {
  data : Bytes
  terminated : Bool
} derive(Eq, Debug)

///|
pub struct LineScanner {
  reader : &@io.Reader
  pending : Array[Byte]
  mut eof : Bool
}

///|
pub fn LineScanner::new(reader : &@io.Reader) -> LineScanner {
  { reader, pending: [], eof: false, }
}

///|
fn LineScanner::take(
  self : LineScanner,
  length : Int,
  terminated : Bool,
) -> Line {
  let data = Bytes::from_array(self.pending[0:length].to_owned())
  let consumed = length + (if terminated { 1 } else { 0 })
  let remaining = self.pending[consumed:].to_owned()
  self.pending.clear()
  self.pending.append(remaining)
  { data, terminated, }
}

///|
pub async fn LineScanner::next(self : LineScanner) -> Line? {
  for ;; {
    for index, byte in self.pending {
      if byte is b'\n' {
        return Some(self.take(index, true))
      }
    }
    if self.eof {
      if self.pending.is_empty() {
        return None
      }
      return Some(self.take(self.pending.length(), false))
    }
    match read_chunk(self.reader) {
      Some(chunk) =>
        for byte in chunk {
          self.pending.push(byte)
        }
      None => self.eof = true
    }
  }
}
