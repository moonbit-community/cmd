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
  let output = if profile == CurlProfile &&
    (response.code < 200 || response.code >= 400) {
    match output {
      FileOutput(path~, mode~, remove_on_error~, ..) =>
        FileOutput(path~, mode~, content_disposition=false, remove_on_error~)
      _ => output
    }
  } else {
    output
  }
  let buffered = profile == CurlProfile && output is FileOutput(..)
  let exclusive = buffered &&
    output is FileOutput(content_disposition=true, ..) &&
    response.headers.get("Content-Disposition") is Some(disposition) &&
    content_disposition_filename(disposition) is Some(filename) &&
    filename != "" &&
    @fsops.basename(filename) != "." &&
    @fsops.basename(filename) != ".."
  let deferred_open = buffered && !exclusive
  {
    output,
    response,
    deferred_open,
    buffered,
    sink: if deferred_open {
      None
    } else {
      Some(open_sink(output, response, exclusive~))
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

///|
fn output_path(output : TransferOutput, response : @http.Response) -> String? {
  match output {
    FileOutput(path~, content_disposition=true, ..) =>
      match response.headers.get("Content-Disposition") {
        Some(value) =>
          match content_disposition_filename(value) {
            Some(name) => Some(@fsops.basename(name))
            None => Some(path)
          }
        None => Some(path)
      }
    FileOutput(path~, ..) => Some(path)
    StandardOutput | DiscardOutput => None
  }
}

///|
priv enum OutputSink {
  StdoutSink
  DiscardSink
  FileSink(String, @fs.File, Bool)
}

///|
async fn open_sink(
  output : TransferOutput,
  response : @http.Response,
  exclusive~ : Bool = false,
) -> OutputSink {
  match output {
    StandardOutput => StdoutSink
    DiscardOutput => DiscardSink
    FileOutput(mode~, remove_on_error~, ..) => {
      let path = output_path(output, response).unwrap()
      let opened = try {
        if exclusive {
          (path, @fsops.open_output(path, CreateNew))
        } else {
          match mode {
            Truncate => (path, @fsops.open_output(path, CreateOrTruncate))
            Append => (path, @fsops.open_output(path, AppendOrCreate))
            Unique => @fsops.open_unique_numbered_output(path)
          }
        }
      } catch {
        err =>
          raise transfer_error(
            OutputFailure,
            "cannot open output '\{path}': \{err}",
          )
      }
      FileSink(opened.0, opened.1, remove_on_error)
    }
  }
}

///|
fn OutputSink::path(self : OutputSink) -> String? {
  match self {
    FileSink(path, _, _) => Some(path)
    StdoutSink | DiscardSink => None
  }
}

///|
fn OutputSink::close(self : OutputSink) -> Unit {
  match self {
    FileSink(_, file, _) => file.close()
    StdoutSink | DiscardSink => ()
  }
}

///|
async fn OutputSink::write(self : OutputSink, chunk : Bytes) -> Unit {
  match self {
    StdoutSink =>
      @stdio.stdout.write(chunk) catch {
        err =>
          raise transfer_error(
            OutputFailure,
            "cannot write standard output: \{err}",
          )
      }
    DiscardSink => ()
    FileSink(path, file, _) =>
      file.write(chunk) catch {
        err =>
          raise transfer_error(
            OutputFailure,
            "cannot write output '\{path}': \{err}",
          )
      }
  }
}

///|
async fn OutputSink::cleanup_after_error(self : OutputSink) -> Unit {
  match self {
    FileSink(path, _, true) => @fsops.cleanup_file_if_exists(path)
    FileSink(_, _, false) | StdoutSink | DiscardSink => ()
  }
}
