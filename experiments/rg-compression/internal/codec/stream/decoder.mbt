///|
pub(all) enum Format { Gzip; Bzip2; Brotli; Lz4; Zstd; Xz; Lzma; Compress } derive(Debug, Eq)

///|
pub(all) enum Status { NeedInput; NeedOutput; Done; Failed(String) } derive(Debug, Eq)

///|
pub(all) struct Step { consumed : Int; produced : Int; status : Status } derive(Debug, Eq)

///|
priv enum Engine {
  Gzip(@gzip.Decoder)
  Bzip2(@bzip2.Inflater)
  Brotli(@brotli.Inflater)
  Lz4(@lz4.Inflater)
  Zstd(@zstd.Inflater)
  Compress(CompressState)
  Lzma(LzmaState)
  Xz(XzState)
}

///|
priv enum Signal { Await; Data(BytesView); End; Error(String) }

///|
pub struct Decoder {
  priv mut engine : Engine
  priv mut needs_input : Bool
  priv mut stream_end : Bool
  priv mut pending : Bytes
  priv mut position : Int
  priv mut failure : String?
}

///|
pub fn Decoder::new(format : Format) -> Decoder {
  let engine = match format {
    Gzip => Engine::Gzip(@gzip.Decoder())
    Bzip2 => Engine::Bzip2(@bzip2.Inflater::new())
    Brotli => Engine::Brotli(@brotli.Inflater::new())
    Lz4 => Engine::Lz4(@lz4.Inflater::new())
    Zstd => Engine::Zstd(@zstd.Inflater::new())
    Compress => Engine::Compress(CompressState::new())
    Lzma => Engine::Lzma(LzmaState::new())
    Xz => Engine::Xz(XzState::new())
  }
  { engine, needs_input: true, stream_end: false, pending: b"", position: 0, failure: None }
}

///|
fn Decoder::fail(self : Decoder, message : String, consumed~ : Int = 0) -> Step {
  self.failure = Some(message)
  { consumed, produced: 0, status: Failed(message) }
}

///|
fn Decoder::drain(self : Decoder, output : MutArrayView[Byte], consumed : Int) -> Step {
  let count = (self.pending.length() - self.position).min(output.length())
  for i in 0..<count { output[i] = self.pending[self.position + i] }
  self.position += count
  if self.position == self.pending.length() { self.pending = b""; self.position = 0 }
  { consumed, produced: count, status: NeedOutput }
}

///|
/// Input and output are borrowed only for this call. Counts describe accepted prefixes.
pub fn Decoder::step(self : Decoder, input : BytesView, output : MutArrayView[Byte], end~ : Bool = false) -> Step {
  if self.failure is Some(message) { return { consumed: 0, produced: 0, status: Failed(message) } }
  if self.engine is Engine::Compress(state) {
    let result = state.step(input, output, end~)
    if result.status is Failed(message) { self.failure = Some(message) }
    return result
  }
  if self.engine is Engine::Lzma(state) {
    let result = state.step(input, output, end~)
    if result.status is Failed(message) { self.failure = Some(message) }
    return result
  }
  if self.engine is Engine::Xz(state) {
    let result = state.step(input, output, end~)
    if result.status is Failed(message) { self.failure = Some(message) }
    return result
  }
  if self.engine is Engine::Gzip(decoder) {
    let status = try decoder.step(input, output, end~) catch {
      @gzip.GzipError(_, message) => {
        self.failure = Some(message)
        return { consumed: decoder.last_consumed(), produced: decoder.last_produced(), status: Failed(message) }
      }
    }
    return { consumed: decoder.last_consumed(), produced: decoder.last_produced(),
      status: match status { NeedMoreInput => NeedInput; NeedMoreOutput => NeedOutput; Done => Done } }
  }
  if !self.pending.is_empty() { return self.drain(output, 0) }
  if output.length() == 0 { return { consumed: 0, produced: 0, status: NeedOutput } }
  if self.stream_end {
    if input.is_empty() {
      return { consumed: 0, produced: 0, status: if end { Done } else { NeedInput } }
    }
    match self.engine {
      Engine::Zstd(_) => { self.engine = Engine::Zstd(@zstd.Inflater::new()); self.stream_end = false }
      _ => return self.fail("trailing data after compressed stream")
    }
  }
  let mut consumed = 0
  if self.needs_input {
    match self.engine {
      Engine::Bzip2(d) => { d.src(input); if end { d.finish() } }
      Engine::Brotli(d) => d.src(input)
      Engine::Lz4(d) => { d.src(input); if end { d.finish() } }
      Engine::Zstd(d) => d.src(input)
      _ => ()
    }
    consumed = input.length()
    self.needs_input = false
  }
  let signal : Signal = match self.engine {
    Engine::Bzip2(d) => match d.decode() { Await => Await; Data(data) => Data(data); End => End; Error(e) => Error("\{Repr(e)}") }
    Engine::Brotli(d) => match d.decode() { Await => Await; Data(data) => Data(data); End => End; Error(e) => Error("\{Repr(e)}") }
    Engine::Lz4(d) => match d.decode() { Await => Await; Data(data) => Data(data); End => End; Error(e) => Error("\{Repr(e)}") }
    Engine::Zstd(d) => match d.decode() { Await => Await; Data(data) => Data(data); End => End; Error(e) => Error("\{Repr(e)}") }
    _ => Error("invalid decoder state")
  }
  match signal {
    Error(message) => self.fail(message, consumed~)
    Data(data) => {
      self.pending = data.to_owned()
      self.position = 0
      self.drain(output, consumed)
    }
    Await => {
      self.needs_input = true
      if end { self.fail("truncated compressed stream", consumed~) } else {
        { consumed, produced: 0, status: NeedInput }
      }
    }
    End => {
      self.stream_end = true
      self.needs_input = true
      { consumed, produced: 0, status: if end { Done } else { NeedInput } }
    }
  }
}
