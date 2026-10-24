///|
pub let chunk_size : Int32 = 65536

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
  delimiter : Bytes
  buffer : FixedArray[Byte]
  chunk : Bytes
  mut offset : Int32
  mut limit : Int32
  mut eof : Bool
}

///|
pub fn LineScanner::new(
  reader : &@io.Reader,
  delimiter~ : Byte = b'\n',
) -> LineScanner {
  let buffer = FixedArray::make(chunk_size, b'\x00')
  {
    reader,
    pending: [],
    delimiter: Bytes::from_array([delimiter]),
    buffer,
    chunk: buffer.unsafe_reinterpret_as_bytes(),
    offset: 0,
    limit: 0,
    eof: false,
  }
}

///|
pub async fn LineScanner::next(self : LineScanner) -> Line? {
  for ;; {
    let start = self.offset
    if self.chunk[start:self.limit].find(self.delimiter[:]) is Some(relative) {
      let index = start + relative
      let data = if self.pending.is_empty() {
        self.chunk[start:index].to_owned()
      } else {
        for byte in self.chunk[start:index] {
          self.pending.push(byte)
        }
        let data = Bytes::from_array(self.pending)
        self.pending.clear()
        data
      }
      self.offset = index + 1
      return Some({ data, terminated: true, })
    }
    for byte in self.chunk[start:self.limit] {
      self.pending.push(byte)
    }
    self.offset = self.limit
    if self.eof {
      if self.pending.is_empty() {
        return None
      }
      let data = Bytes::from_array(self.pending)
      self.pending.clear()
      return Some({ data, terminated: false, })
    }
    self.limit = self.reader.read(self.buffer, max_len=chunk_size)
    self.offset = 0
    self.eof = self.limit == 0
  }
}

///|
pub extend Line with Eq::{not_equal, equal}

///|
pub extend Line with @debug.Debug::{to_repr}
