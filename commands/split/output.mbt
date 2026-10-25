///|
priv struct Piece {
  name : String
  mut file : @fs.File?
  input : @io.PipeWrite?
  task : @async.Task[(Int32, Int32?)]?
  mut broken : Bool
}

///|
priv struct Outputs {
  names : Names
  group : @async.TaskGroup[Unit]
  active : Map[String, Piece]
}

///|
fn Outputs::new(options : Options, group : @async.TaskGroup[Unit]) -> Outputs {
  { names: Names::new(options), group, active: Map([]), }
}

///|
async fn Outputs::open(self : Outputs) -> Piece {
  let name = self.names.next()
  let piece = if self.names.options.filter is Some(source) {
    let (reader, writer) = @io.pipe()
    let environment = @env.get_env_vars()
    environment["FILE"] = name
    let task = self.group.spawn(() => {
      defer reader.close()
      let session = @shell.Session::new(
        name="split-filter",
        env=environment,
        input=reader,
        output=@stdio.stdout,
        error=@stdio.stderr,
      )
      let status = try {
        match session.feed(source) {
          Completed(status) | Exit(status) => status
          NeedMoreInput => {
            ignore(session.finish())
            2
          }
        }
      } catch {
        @shell.ShellError(message) => {
          @stdio.stderr.write("sh: \{message}\n")
          2
        }
        error => raise error
      }
      (status, session.last_signal())
    })
    Piece::{
      name,
      file: None,
      input: Some(writer),
      task: Some(task),
      broken: false,
    }
  } else {
    if @fs.exists(name) {
      raise SplitError(1, "existing output is unsupported: \{name}")
    }
    let file = @fs.open(name, mode=WriteOnly, create_mode=CreateNew)
    Piece::{ name, file: Some(file), input: None, task: None, broken: false, }
  }
  self.active[name] = piece
  piece
}

///|
async fn Piece::write(self : Piece, bytes : BytesView) -> Unit {
  if self.broken {
    return
  }
  if self.input is Some(writer) {
    writer.write(bytes) catch {
      @io.PipeClosed => self.broken = true
      error => raise error
    }
  } else {
    if self.file is None {
      self.file = Some(
        @fs.open(
          self.name,
          mode=WriteOnly,
          create_mode=OpenExisting,
          append=true,
        ),
      )
    }
    self.file.unwrap().write(bytes)
  }
}

///|
fn Piece::suspend(self : Piece) -> Unit {
  if self.file is Some(file) {
    file.close()
    self.file = None
  }
}

///|
async fn Outputs::finish(self : Outputs, piece : Piece) -> Unit {
  piece.suspend()
  if piece.input is Some(writer) {
    writer.close()
  }
  if piece.task is Some(task) {
    let (status, signal) = task.wait()
    if status != 0 && !(status == 141 && signal == Some(13)) {
      let name = @quoting.shell_escape(@utf8.encode(piece.name)[:], colon=true)
      raise SplitError(
        status,
        "with FILE=\{name}, exit \{status} from command: \{self.names.options.filter.unwrap_or("")}",
      )
    }
  }
  self.active.remove(piece.name)
}

///|
fn Outputs::close(self : Outputs) -> Unit {
  for piece in self.active.values() {
    piece.suspend()
    if piece.input is Some(writer) {
      writer.close()
    }
  }
}

///|
async fn write_piece(
  outputs : Outputs,
  piece : Ref[Piece?],
  bytes : BytesView,
) -> Unit {
  if bytes.is_empty() {
    return
  }
  if piece.val is None {
    piece.val = Some(outputs.open())
  }
  piece.val.unwrap().write(bytes)
}

///|
async fn finish_piece(
  outputs : Outputs,
  piece : Ref[Piece?],
  elide : Bool,
) -> Unit {
  if piece.val is None && !elide {
    piece.val = Some(outputs.open())
  }
  if piece.val is Some(value) {
    outputs.finish(value)
    piece.val = None
  }
}
