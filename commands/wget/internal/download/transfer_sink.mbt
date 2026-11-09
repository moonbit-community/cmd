///|
priv struct TransferSink {
  sink : OutputSink
  mut started : Bool
  mut committed : Int64
  mut write_uncertain : Bool
}

///|
async fn TransferSink::new(
  output : TransferOutput,
  response : Response,
) -> TransferSink {
  {
    sink: open_sink(output, response),
    started: false,
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
  self.sink.path()
}

///|
async fn TransferSink::start(
  self : TransferSink,
  observer : (async (TransferEvent) -> Unit)?,
  response_offset : Int64,
) -> Unit {
  if !self.started {
    self.started = true
    emit(observer, OutputStarted(path=self.path(), response_offset~))
  }
}

///|
async fn TransferSink::write(self : TransferSink, chunk : Bytes) -> Unit {
  errdefer {
    self.write_uncertain = true
  }
  self.sink.write(chunk)
  if !(self.sink is DiscardSink) {
    self.committed += chunk.length().to_int64()
  }
}

///|
fn TransferSink::close(self : TransferSink) -> Unit {
  self.sink.close()
}

///|
async fn TransferSink::cleanup_after_error(self : TransferSink) -> Unit {
  self.sink.cleanup_after_error()
}

///|
fn output_path(output : TransferOutput, response : Response) -> String? {
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
  response : Response,
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
            Unique => open_unique_numbered_output(path)
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
    FileSink(path, _, true) => cleanup_file_if_exists(path)
    FileSink(_, _, false) | StdoutSink | DiscardSink => ()
  }
}
