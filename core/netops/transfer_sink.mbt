///|
priv struct TransferSink {
  output : TransferOutput
  response : @http.Response
  deferred_open : Bool
  buffered : Bool
  mut sink : OutputSink?
  mut started : Bool
  pending : Array[Byte]
  mut committed : Int64
  mut write_uncertain : Bool
}

///|
async fn TransferSink::new(
  output : TransferOutput,
  response : @http.Response,
  profile : TransferProfile,
) -> TransferSink {
  let deferred_open = profile == CurlProfile && output is FileOutput(..)
  {
    output,
    response,
    deferred_open,
    buffered: deferred_open,
    sink: if deferred_open {
      None
    } else {
      Some(open_sink(output, response))
    },
    started: false,
    pending: [],
    committed: 0L,
    write_uncertain: false,
  }
}

///|
async fn[T] TransferSink::with_scope(
  self : TransferSink,
  run : async () -> T,
) -> T {
  defer self.close()
  run()
}

///|
fn TransferSink::path(self : TransferSink) -> String? {
  match self.sink {
    Some(sink) => sink.path()
    None => None
  }
}

///|
async fn TransferSink::start(
  self : TransferSink,
  observer : (async (TransferEvent) -> Unit)?,
  response_offset : Int64,
) -> Unit {
  if !self.started {
    if self.sink is None {
      self.sink = Some(open_sink(self.output, self.response))
    }
    self.started = true
    emit(observer, OutputStarted(path=self.path(), response_offset~))
  }
}

///|
async fn TransferSink::write_now(self : TransferSink, chunk : Bytes) -> Unit {
  let sink = self.sink.unwrap()
  errdefer {
    self.write_uncertain = true
  }
  sink.write(chunk)
  if !(sink is DiscardSink) {
    self.committed += chunk.length().to_int64()
  }
}

///|
async fn TransferSink::flush(self : TransferSink) -> Unit {
  if !self.pending.is_empty() {
    let bytes = Bytes::from_array(self.pending.copy())
    // A failed write may have effects; never replay that uncertain tail.
    self.pending.clear()
    self.write_now(bytes)
  }
}

///|
async fn TransferSink::write(self : TransferSink, chunk : Bytes) -> Unit {
  if !self.buffered {
    self.write_now(chunk)
    return
  }
  let mut position = 0
  while position < chunk.length() {
    let length = (4096 - self.pending.length()).min(chunk.length() - position)
    for byte in chunk[position:position + length] {
      self.pending.push(byte)
    }
    position += length
    if self.pending.length() == 4096 {
      self.flush()
    }
  }
}

///|
async fn TransferSink::flush_after_failure(self : TransferSink) -> Unit {
  if !self.write_uncertain {
    self.flush() catch {
      _ => ()
    }
  }
}

///|
fn TransferSink::close(self : TransferSink) -> Unit {
  if self.sink is Some(sink) {
    sink.close()
  }
}

///|
async fn TransferSink::cleanup_after_error(self : TransferSink) -> Unit {
  if self.sink is Some(sink) {
    sink.cleanup_after_error()
  }
}
