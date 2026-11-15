///|
priv struct InputGroup {
  values : Array[String]
  bytes : Int64
}

///|
priv struct BatchReader {
  input : ItemReader
  program : String
  prefix : Array[String]
  prefix_bytes : Int64
  max_args : Int32
  max_lines : Int32
  max_bytes : Int64
  replace : String?
  eof : String?
  no_empty : Bool
  mut pending : InputGroup?
  mut emitted : Bool
}

///|
async fn BatchReader::group(self : BatchReader) -> InputGroup? {
  if self.pending is Some(group) {
    self.pending = None
    return Some(group)
  }
  while self.input.next() is Some(raw) {
    if self.input.mode is Delimited(_) {
      let item = input_item(raw[:])
      return Some({ values: [item.value], bytes: item.size, })
    }
    let text = input_text(raw)
    let values = if self.replace is Some(_) {
      let value = text.trim().to_owned()
      if value.is_empty() {
        continue
      }
      [value]
    } else if self.input.mode is Lines {
      parse_words(text)
    } else {
      [text]
    }
    if self.eof is Some(marker) && values.any(value => value == marker) {
      self.input.ended = true
      return None
    }
    if !values.is_empty() {
      return Some({ values, bytes: @process.arguments_bytes(values), })
    }
  }
  None
}

///|
async fn BatchReader::next(self : BatchReader) -> Array[String]? {
  if self.replace is Some(marker) {
    guard self.group() is Some(group) else { return self.empty() }
    let arguments = replace_arguments(self.prefix, marker, group.values[0])
    if @process.argument_bytes(self.program) +
      @process.arguments_bytes(arguments) >
      self.max_bytes {
      raise XargsError("argument list too long")
    }
    self.emitted = true
    return Some(arguments)
  }
  let values : Array[String] = []
  let mut bytes = self.prefix_bytes
  let mut lines = 0
  while self.group() is Some(group) {
    let over_args = self.max_args > 0 &&
      values.length() + group.values.length() > self.max_args
    let over_bytes = bytes + group.bytes > self.max_bytes
    if over_args || over_bytes {
      if values.is_empty() ||
        (over_bytes && self.max_lines > 0 && self.input.mode is Delimited(_)) {
        raise XargsError("argument line too long")
      }
      self.pending = Some(group)
      break
    }
    values.append(group.values)
    bytes += group.bytes
    lines += 1
    if (self.max_args > 0 && values.length() == self.max_args) ||
      (self.max_lines > 0 && lines == self.max_lines) {
      break
    }
  }
  if values.is_empty() {
    return self.empty()
  }
  self.emitted = true
  Some(self.prefix + values)
}

///|
fn BatchReader::empty(self : BatchReader) -> Array[String]? {
  if self.emitted || self.no_empty {
    return None
  }
  self.emitted = true
  Some(self.prefix)
}

///|
fn stop_on_status(status : Int32) -> Bool {
  status == 124 || status == 125 || status == 126 || status == 127
}

///|
async fn run_stream(
  batches : BatchReader,
  max_procs : Int32,
  execute : async (Array[String]) -> ChildOutcome,
  approve~ : async (Array[String]) -> Bool = _ => true,
) -> Int32 {
  let slots = @semaphore.Semaphore(max_procs)
  let result = Ref(0)
  let failure : Ref[Error?] = Ref(None)
  let producer : Ref[@async.Task[Unit]?] = Ref(None)
  @async.with_task_group() <| group => {
    producer.val = Some(
      group.spawn(() => {
        try {
          while !stop_on_status(result.val) {
            slots.acquire()
            let mut dispatched = false
            defer (if !dispatched { slots.release() })
            if stop_on_status(result.val) {
              break
            }
            guard batches.next() is Some(arguments) else { break }
            if !approve(arguments) {
              continue
            }
            group.spawn_bg(() => {
              defer slots.release()
              let status = execute(arguments)
              result.val = combine_status(result.val, status)
              if stop_on_status(result.val) && producer.val is Some(task) {
                task.cancel()
              }
            })
            dispatched = true
          }
        } catch {
          error => if !stop_on_status(result.val) { failure.val = Some(error) }
        }
      }),
    )
  }
  if failure.val is Some(error) {
    raise error
  }
  result.val
}
