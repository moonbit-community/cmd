///|
priv struct FindBatch {
  command : Array[String]
  values : Array[String]
  base : Int64
  copies : Int64
  limit : Int64
  mut bytes : Int64
}

///|
fn FindBatch::new(
  command : Array[String],
  limit~ : Int64 = 65536L,
) -> FindBatch {
  let mut base = 0L
  let mut copies = 0L
  for argument in command {
    if argument == "{}" {
      copies += 1L
    } else {
      base += @process.argument_bytes(argument)
    }
  }
  { command, values: [], base, copies, limit, bytes: base, }
}

///|
async fn execute_find_batch(argv : Array[String]) -> Bool {
  let code = run_find_child(argv)
  if code < 0 {
    @stdio.stderr.write("find: '\{argv[0]}' terminated by signal \{-code}\n")
  }
  code == 0
}

///|
async fn FindBatch::flush(
  self : FindBatch,
  execute~ : async (Array[String]) -> Bool = execute_find_batch,
) -> Bool {
  guard !self.values.is_empty() else { return true }
  let argv : Array[String] = []
  for argument in self.command {
    if argument == "{}" {
      argv.append(self.values)
    } else {
      argv.push(argument)
    }
  }
  // Consume the batch before execution: a failed invocation is never replayed.
  self.values.clear()
  self.bytes = self.base
  execute(argv)
}

///|
async fn FindBatch::push(
  self : FindBatch,
  path : String,
  execute~ : async (Array[String]) -> Bool = execute_find_batch,
) -> Bool {
  let cost = @process.argument_bytes(path) * self.copies
  if self.base + cost > self.limit {
    @stdio.stderr.write(
      "find: argument exceeds \{self.limit} byte execution limit: '\{path}'\n",
    )
    return false
  }
  let succeeded = if self.bytes + cost > self.limit {
    self.flush(execute~)
  } else {
    true
  }
  self.values.push(path)
  self.bytes += cost
  succeeded
}
