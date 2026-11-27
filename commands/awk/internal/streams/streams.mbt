///|
priv enum Source {
  File(@fs.File)
  Memory(Bytes)
}

///|
priv struct Reader {
  source : Source
  mut offset : Int32
  mut carry : Bytes
}

///|
fn Reader::new(source : Source) -> Reader {
  { source, offset: 0, carry: b"", }
}

///|
fn Reader::close(self : Reader) -> Unit {
  if self.source is File(file) {
    file.close()
  }
}

///|
fn Reader::next(self : Reader) -> String? raise {
  let bytes = match self.source {
    File(file) => {
      let block : FixedArray[Byte] = FixedArray::make(16384, b'\x00')
      let count = file.read_into(block.mut_view())
      Bytes::from_array(block[:count])
    }
    Memory(data) => {
      let end = (self.offset + 16384).min(data.length())
      let chunk = data[self.offset:end].to_owned()
      self.offset = end
      chunk
    }
  }
  if bytes.is_empty() {
    guard self.carry.is_empty() else { raise Failure("invalid UTF-8 input") }
    return None
  }
  let data = if self.carry.is_empty() {
    bytes
  } else {
    let buffer = @buffer.Buffer()
    buffer.write_bytesview(self.carry)
    buffer.write_bytesview(bytes)
    buffer.to_bytes()
  }
  let mut start = data.length() - 1
  while start > 0 && (data[start].to_int() & 0xc0) == 0x80 {
    start -= 1
  }
  let head = data[start].to_int()
  let width = if head >= 0xf0 && head <= 0xf4 {
    4
  } else if head >= 0xe0 && head <= 0xef {
    3
  } else if head >= 0xc2 && head <= 0xdf {
    2
  } else {
    1
  }
  let end = if data.length() - start < width { start } else { data.length() }
  self.carry = data[end:].to_owned()
  if end == 0 {
    return self.next()
  }
  Some(
    @utf8.decode(data[:end], ignore_bom=false) catch {
      _ => raise Failure("invalid UTF-8 input")
    },
  )
}

///|
pub struct Host {
  priv mut stdin : Reader?
  priv mut current : Reader?
  priv readers : Map[String, Reader]
  priv writers : Map[String, @fs.File]
  priv mut events : Array[(Bool, String)]
  priv mut fatal : String?
}

///|
pub fn Host::new() -> Host {
  {
    stdin: None,
    current: None,
    readers: Map([]),
    writers: Map([]),
    events: [],
    fatal: None,
  }
}

///|
pub fn Host::stage_stdin(self : Host, bytes : Bytes) -> Unit {
  self.stdin = Some(Reader::new(Memory(bytes)))
}

///|
fn Host::open(self : Host, name : String) -> Reader raise {
  if name == "-" || name == "/dev/stdin" {
    guard self.stdin is Some(reader) else {
      raise Failure("standard input is unavailable during this operation")
    }
    reader
  } else {
    Reader::new(File(@fs.open(name, mode=ReadOnly)))
  }
}

///|
pub fn Host::input(self : Host, request : @awk.InputRequest) -> @awk.InputReply {
  match request {
    Open(name) => {
      self.current = Some(
        self.open(name) catch {
          err => return Failed(name + ": " + self.diagnostic(err))
        },
      )
      Ready
    }
    Read =>
      match
        (self.current.unwrap().next() catch {
          err => return Failed(self.diagnostic(err))
        }) {
        Some(text) => Chunk(text)
        None => End
      }
    Close => {
      if self.current is Some(reader) {
        reader.close()
      }
      self.current = None
      Ready
    }
  }
}

///|
pub fn Host::output(self : Host, text : String) -> String? {
  self.events.push((false, text))
  None
}

///|
pub async fn Host::flush(self : Host) -> Unit {
  if self.events.is_empty() {
    return
  }
  let events = self.events
  self.events = []
  for event in events {
    let (error, text) = event
    if error {
      @stdio.stderr.text.write(text)
    } else {
      @stdio.stdout.text.write(text)
    }
  }
}

///|
pub fn Host::diagnostic(self : Host, error : Error) -> String {
  self.fatal.unwrap_or(
    match error {
      @awk.Invalid(message) | @awk.InputFailure(message) | Failure(message) =>
        message
      _ => error.to_string()
    },
  )
}

///|
pub fn Host::io(self : Host, request : @awk.IORequest) -> @awk.IOReply {
  match request {
    OpenReader(_, true) | OpenWriter(_, "|") | Execute(_) => {
      self.fatal = Some(
        "process pipes and system() are unavailable in this awk profile",
      )
      IOEnd
    }
    OpenReader(name, false) => {
      self.readers[name] = self.open(name) catch {
        err => return IOFailed(name + ": " + self.diagnostic(err))
      }
      IOReady
    }
    ReadReader(name) =>
      match
        (self.readers[name].next() catch {
          err => return IOFailed(self.diagnostic(err))
        }) {
        Some(text) => IOData(text)
        None => IOEnd
      }
    OpenWriter(name, mode) => {
      self.writers[name] = @fs.open(
        name,
        mode=WriteOnly,
        create_mode=if mode == ">>" { OpenOrCreate } else { CreateOrTruncate },
        append=mode == ">>",
      ) catch {
        err => return IOFailed(name + ": " + self.diagnostic(err))
      }
      IOReady
    }
    WriteWriter("/dev/stderr", text) => {
      self.events.push((true, text))
      IOReady
    }
    WriteWriter(name, text) => {
      self.writers[name].write(@utf8.encode(text)) catch {
        err => return IOFailed(name + ": " + self.diagnostic(err))
      }
      IOReady
    }
    CloseStream(name) => {
      if self.readers.get(name) is Some(reader) {
        reader.close()
        self.readers.remove(name)
      }
      if self.writers.get(name) is Some(file) {
        file.close()
        self.writers.remove(name)
      }
      IOStatus(0)
    }
    FlushStream(name) =>
      IOStatus(
        if name == "" ||
          name == "-" ||
          name == "/dev/stdout" ||
          name == "/dev/stderr" ||
          self.writers.contains(name) {
          0
        } else {
          -1
        },
      )
  }
}
