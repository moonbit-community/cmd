///|
pub suberror DecodeError { DecodeError(String) } derive(Debug)

///|
pub struct Reader {
  priv file : @fs.File
  priv decoder : Decoder
  priv input : FixedArray[Byte]
  priv mut input_pos : Int
  priv mut input_end : Int
  priv mut physical_end : Bool
  priv mut needs_input : Bool
  priv mut finished : Bool
  priv mut failure : String?
}

///|
pub async fn Reader::open(path : String, format : Format) -> Reader {
  { file: @fs.open(path, mode=ReadOnly), decoder: Decoder::new(format),
    input: FixedArray::make(65536, b'\x00'), input_pos: 0, input_end: 0,
    physical_end: false, needs_input: true, finished: false, failure: None }
}

///|
pub fn Reader::close(self : Reader) -> Unit { self.file.close() }

///|
pub async fn Reader::read(self : Reader, output : FixedArray[Byte], start : Int, len : Int) -> Int {
  if len == 0 { return 0 }
  if self.failure is Some(message) { raise DecodeError(message) }
  if self.finished { return 0 }
  for ;; {
    if self.needs_input && self.input_pos == self.input_end && !self.physical_end {
      self.input_end = self.file.read(self.input)
      self.input_pos = 0
      self.physical_end = self.input_end == 0
    }
    let input = self.input.unsafe_reinterpret_as_bytes()[self.input_pos:self.input_end]
    let result = self.decoder.step(input, output.mut_view(start~, end=start + len), end=self.physical_end)
    self.input_pos += result.consumed
    self.needs_input = result.status is NeedInput
    match result.status {
      Done => self.finished = true
      Failed(message) => self.failure = Some(message)
      _ => ()
    }
    if result.produced > 0 { return result.produced }
    if self.failure is Some(message) { raise DecodeError(message) }
    if self.finished { return 0 }
    if result.consumed == 0 && !self.needs_input {
      raise DecodeError("decoder made no progress")
    }
  }
}
