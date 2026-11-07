///|
// Strategy: sort-spill
priv struct Run {
  path : String
  largest_entry : Int64
  level : Int32
}

///|
priv struct RunReader {
  file : @fs.File
  buffer : FixedArray[Byte]
  mut position : Int32
  mut available : Int32
  limit : Int64
  key_count : Int32
}

///|
fn entry_cost(entry : Entry) -> Int64 {
  // Include record/key payloads, sequence ID, entry/reference slots and key
  // descriptors. Runtime allocator and GC overhead are measured separately.
  let mut size = entry.record.length().to_int64() + 128
  for key in entry.keys {
    size += key.length().to_int64() + 16
  }
  size
}

///|
async fn RunReader::refill(self : RunReader) -> Bool {
  if self.position == self.available {
    self.available = self.file.read(self.buffer)
    self.position = 0
  }
  self.available > 0
}

///|
async fn RunReader::take(self : RunReader, length : Int32) -> Bytes {
  if length < 0 || length.to_int64() > self.limit {
    raise CliError("invalid temporary run record length")
  }
  let bytes = FixedArray::make(length, b'\x00')
  for copied = 0; copied < length; {
    if !self.refill() {
      raise CliError("incomplete temporary run")
    }
    let count = (length - copied).min(self.available - self.position)
    self.buffer.blit_to(
      bytes,
      src_offset=self.position,
      dst_offset=copied,
      len=count,
    )
    self.position += count
    continue copied + count
  }
  bytes.unsafe_reinterpret_as_bytes()
}

///|
fn read_size(bytes : Bytes, offset : Int32) -> Int32 {
  let mut result = 0
  for index in 0..<4 {
    result = result | (bytes[offset + index].to_int() << (index * 8))
  }
  result
}

///|
fn write_number(
  bytes : FixedArray[Byte],
  offset : Int32,
  value : Int64,
  length : Int32,
) -> Unit {
  for index in 0..<length {
    bytes[offset + index] = ((value >> (index * 8)) & 255).to_byte()
  }
}

///|
async fn RunReader::next(self : RunReader) -> Entry? {
  if self.buffered_next() is Some(entry) {
    return Some(entry)
  }
  if !self.refill() {
    return None
  }
  let header = self.take(12)
  let mut index : Int64 = 0
  for byte in 0..<8 {
    index = index | (header[byte].to_int64() << (byte * 8))
  }
  let record = self.take(read_size(header, 8))
  let keys : Array[Bytes] = []
  let mut cost = record.length().to_int64() + 128
  for _ in 0..<self.key_count {
    let key = self.take(read_size(self.take(4), 0))
    cost += key.length().to_int64() + 16
    if cost > self.limit {
      raise CliError("invalid temporary run entry size")
    }
    keys.push(key)
  }
  Some({ record, keys, index, })
}

///|
// Parse complete cached entries synchronously. A crossing record leaves the
// cursor untouched so the existing exact-read path handles refill and failure.
fn RunReader::buffered_next(self : RunReader) -> Entry? raise {
  let first = self.position
  if self.available - first < 12 {
    return None
  }
  let bytes = self.buffer.unsafe_reinterpret_as_bytes()
  let size = read_size(bytes, first + 8)
  if size < 0 || size.to_int64() > self.limit {
    raise CliError("invalid temporary run record length")
  }
  let start = first + 12
  if size > self.available - start {
    return None
  }
  let mut end = start + size
  let mut cost = size.to_int64() + 128
  for _ in 0..<self.key_count {
    if self.available - end < 4 {
      return None
    }
    let length = read_size(bytes, end)
    if length < 0 || length.to_int64() > self.limit {
      raise CliError("invalid temporary run record length")
    }
    end += 4
    if length > self.available - end {
      return None
    }
    cost += length.to_int64() + 16
    if cost > self.limit {
      raise CliError("invalid temporary run entry size")
    }
    end += length
  }
  let mut index : Int64 = 0
  for i in 0..<8 {
    index = index | (bytes[first + i].to_int64() << (i * 8))
  }
  let record = bytes[start:start + size].to_owned()
  let keys : Array[Bytes] = []
  let mut position = start + size
  for _ in 0..<self.key_count {
    let length = read_size(bytes, position)
    position += 4
    keys.push(bytes[position:position + length].to_owned())
    position += length
  }
  self.position = end
  Some({ record, keys, index, })
}

///|
async fn write_entry(writer : &@io.Writer, entry : Entry) -> Unit {
  let header = FixedArray::make(12, b'\x00')
  write_number(header, 0, entry.index, 8)
  write_number(header, 8, entry.record.length().to_int64(), 4)
  writer.write(header.unsafe_reinterpret_as_bytes())
  writer.write(entry.record)
  for key in entry.keys {
    write_number(header, 0, key.length().to_int64(), 4)
    writer.write(header.unsafe_reinterpret_as_bytes()[:4])
    writer.write(key)
  }
}

///|
priv struct HeapEntry {
  entry : Entry
  reader : MergeReader
}

///|
priv enum MergeReader {
  RunInput(RunReader)
  SourceInput(SourceReader)
}

///|
priv struct SourceReader {
  scanner : @stream.LineScanner
  source : String
  index : Int64
  specs : Array[KeySpec]
  global : Modifiers
  separator : Byte?
  seed : Bytes
}

///|
async fn MergeReader::next(self : MergeReader) -> Entry? {
  match self {
    RunInput(reader) => reader.next()
    SourceInput(reader) => {
      let line = reader.scanner.next() catch {
        @os_error.OSError(_) as error =>
          raise CliError(
            "sort: read failed: \{reader.source}: \{os_message(error)}",
          )
        error => raise error
      }
      line.map(line => {
        make_entry(
          line.data,
          reader.index,
          reader.specs,
          reader.global,
          reader.separator,
          seed=reader.seed,
        )
      })
    }
  }
}

///|
fn heap_push(
  heap : Array[HeapEntry],
  item : HeapEntry,
  compare : (Entry, Entry) -> Int32,
) -> Unit {
  heap.push(item)
  let mut child = heap.length() - 1
  while child > 0 {
    let parent = (child - 1) / 2
    if compare(heap[parent].entry, item.entry) <= 0 {
      break
    }
    heap[child] = heap[parent]
    child = parent
  }
  heap[child] = item
}

///|
fn heap_pop(
  heap : Array[HeapEntry],
  compare : (Entry, Entry) -> Int32,
) -> HeapEntry {
  let first = heap[0]
  let last = heap.pop().unwrap()
  if !heap.is_empty() {
    let mut parent = 0
    while parent * 2 + 1 < heap.length() {
      let mut child = parent * 2 + 1
      if child + 1 < heap.length() &&
        compare(heap[child + 1].entry, heap[child].entry) < 0 {
        child += 1
      }
      if compare(last.entry, heap[child].entry) <= 0 {
        break
      }
      heap[parent] = heap[child]
      parent = child
    }
    heap[parent] = last
  }
  first
}

///|
async fn merge_runs(
  runs : ArrayView[Run],
  key_count : Int32,
  compare : (Entry, Entry) -> Int32,
  emit : async (Entry) -> Unit,
) -> Unit {
  let files : Array[@fs.File] = []
  defer (for file in files {
    file.close()
  })
  let heap : Array[HeapEntry] = []
  for run in runs {
    let file = @fs.open(run.path, mode=ReadOnly)
    files.push(file)
    let reader : RunReader = {
      file,
      buffer: FixedArray::make(65536, b'\x00'),
      position: 0,
      available: 0,
      limit: run.largest_entry.max(12),
      key_count,
    }
    if reader.next() is Some(entry) {
      heap_push(heap, { entry, reader: RunInput(reader), }, compare)
    }
  }
  while !heap.is_empty() {
    let item = heap_pop(heap, compare)
    emit(item.entry)
    if item.reader.next() is Some(entry) {
      heap_push(heap, { entry, reader: item.reader, }, compare)
    }
  }
}

///|
async fn merge_input_sources(
  sources : ArrayView[String],
  delimiter : Byte,
  specs : Array[KeySpec],
  global : Modifiers,
  separator : Byte?,
  seed : Bytes,
  compare : (Entry, Entry) -> Int32,
  emit : async (Entry) -> Unit,
  first_index~ : Int64 = 0,
) -> Unit {
  let files : Array[@fs.File] = []
  defer (for file in files {
    file.close()
  })
  let heap : Array[HeapEntry] = []
  for index, source in sources {
    let input : &@io.Reader = if source == "-" {
      let reader : &@io.Reader = @stdio.stdin
      reader
    } else {
      let file = @fs.open(source, mode=ReadOnly)
      files.push(file)
      if file.kind() is Directory {
        raise CliError("sort: read failed: \{source}: Is a directory")
      }
      let reader : &@io.Reader = file
      reader
    }
    let reader = SourceInput({
      scanner: @stream.LineScanner::new(input, delimiter~),
      source,
      index: first_index + index.to_int64(),
      specs,
      global,
      separator,
      seed,
    })
    if reader.next() is Some(entry) {
      heap_push(heap, { entry, reader, }, compare)
    }
  }
  while !heap.is_empty() {
    let item = heap_pop(heap, compare)
    emit(item.entry)
    if item.reader.next() is Some(entry) {
      heap_push(heap, { entry, reader: item.reader, }, compare)
    }
  }
}

///|
priv struct Spool {
  directories : Array[String]
  roots : Array[@tempio.Directory?]
  mut next : Int64
}

///|
async fn Spool::path(self : Spool) -> String {
  let slot = (self.next % self.roots.length().to_int64()).to_int()
  let root = match self.roots[slot] {
    Some(root) => root
    None => {
      let root = @tempio.Directory::new(
        prefix="cli-sort-",
        parent=self.directories.get(slot),
      ) catch {
        @tempio.TemporaryError(message) => raise CliError("sort: " + message)
        error => raise error
      }
      self.roots[slot] = Some(root)
      root
    }
  }
  let path = root.path() + "/run-" + self.next.to_string()
  self.next += 1
  path
}

///|
async fn Spool::write_run(
  self : Spool,
  entries : Array[Entry],
  compare : (Entry, Entry) -> Int32,
) -> Run {
  entries.sort_by(compare)
  let path = self.path()
  let file = @fs.open(
    path,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  let writer = @io.BufferedWriter::new(file, size=65536)
  let mut largest_entry : Int64 = 0
  for entry in entries {
    largest_entry = largest_entry.max(entry_cost(entry))
    write_entry(writer, entry)
  }
  writer.flush()
  { path, largest_entry, level: 0, }
}

///|
async fn Spool::merge(
  self : Spool,
  runs : ArrayView[Run],
  key_count : Int32,
  compare : (Entry, Entry) -> Int32,
) -> Run {
  let path = self.path()
  {
    let file = @fs.open(
      path,
      mode=WriteOnly,
      create_mode=CreateNew,
      permission=0o600,
    )
    defer file.close()
    let writer = @io.BufferedWriter::new(file, size=65536)
    merge_runs(runs, key_count, compare, entry => write_entry(writer, entry))
    writer.flush()
  }
  let mut largest_entry : Int64 = 0
  let mut level = 0
  for run in runs {
    largest_entry = largest_entry.max(run.largest_entry)
    level = level.max(run.level)
    @fs.remove(run.path)
  }
  { path, largest_entry, level: level + 1, }
}

///|
async fn Spool::merge_sources(
  self : Spool,
  sources : ArrayView[String],
  delimiter : Byte,
  specs : Array[KeySpec],
  global : Modifiers,
  separator : Byte?,
  seed : Bytes,
  first_index : Int64,
  compare : (Entry, Entry) -> Int32,
) -> Run {
  let path = self.path()
  let file = @fs.open(
    path,
    mode=WriteOnly,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer file.close()
  let writer = @io.BufferedWriter::new(file, size=65536)
  let mut largest_entry : Int64 = 0
  merge_input_sources(
    sources,
    delimiter,
    specs,
    global,
    separator,
    seed,
    compare,
    entry => {
      largest_entry = largest_entry.max(entry_cost(entry))
      write_entry(writer, entry)
    },
    first_index~,
  )
  writer.flush()
  { path, largest_entry, level: 0, }
}

///|
fn merge_count(
  runs : ArrayView[Run],
  budget : Int64,
  fan_in~ : Int32 = 16,
) -> Int32 {
  let mut count = 0
  let mut retained : Int64 = 0
  for run in runs[:runs.length().min(fan_in)] {
    if run.largest_entry > budget - retained {
      if count >= 2 {
        break
      }
      // A merge must advance even when its first two records exceed the
      // selected budget; saturating the estimate avoids offset overflow.
      retained = budget
    } else {
      retained += run.largest_entry
    }
    count += 1
  }
  count
}

///|
async fn compact_runs(
  spool : Spool,
  runs : Array[Run],
  key_count : Int32,
  compare : (Entry, Entry) -> Int32,
  budget : Int64,
  fan_in~ : Int32 = 16,
) -> Unit {
  for level in 0..<64 {
    for ;; {
      let indices : Array[Int32] = []
      for index, run in runs {
        if run.level == level {
          indices.push(index)
        }
        if indices.length() == fan_in {
          break
        }
      }
      if indices.length() < fan_in {
        break
      }
      let group = indices.map(index => runs[index])
      let count = merge_count(group, budget, fan_in~)
      let merged = spool.merge(group[:count], key_count, compare)
      for index = count - 1; index >= 0; index = index - 1 {
        runs.remove(indices[index]) |> ignore
      }
      runs.push(merged)
    }
  }
}

///|
async fn scan_source(
  path : String,
  delimiter : Byte,
  accept : async (@stream.RecordBatch) -> Bool,
) -> Bool {
  let file = if path == "-" {
    None
  } else {
    Some(@fs.open(path, mode=ReadOnly))
  }
  defer (if file is Some(file) { file.close() })
  if file is Some(file) && file.kind() is Directory {
    raise CliError("sort: read failed: \{path}: Is a directory")
  }
  let reader : &@io.Reader = match file {
    Some(file) => {
      let reader : &@io.Reader = file
      reader
    }
    None => {
      let reader : &@io.Reader = @stdio.stdin
      reader
    }
  }
  let scanner = @stream.RecordReader::new(reader, delimiter~)
  for ;; {
    let next = scanner.next_batch() catch {
      @os_error.OSError(_) as error =>
        raise CliError("sort: read failed: \{path}: \{os_message(error)}")
      error => raise error
    }
    guard next is Some(batch) else { break }
    if !accept(batch) {
      return false
    }
  }
  true
}

///|
async fn sort_sources(
  sources : Array[String],
  output : &@io.Writer,
  delimiter : Byte,
  specs : Array[KeySpec],
  global : Modifiers,
  separator : Byte?,
  unique~ : Bool,
  stable~ : Bool = false,
  merge~ : Bool = false,
  check~ : Bool = false,
  diagnose~ : Bool = false,
  budget~ : Int64 = 67108864,
  seed~ : Bytes = b"",
  output_path~ : String? = None,
  fan_in~ : Int32 = 16,
  temporary_directories~ : Array[String] = [],
) -> Int32 {
  let compare = entry_comparator(specs, global, !unique && !stable)
  let key_count = if specs.is_empty() {
    if transforms_key(global) || global.mode == Random {
      1
    } else {
      0
    }
  } else {
    specs.length()
  }
  let (run_limit, fan_in) = merge_budget(budget, fan_in)
  let spool : Spool = {
    directories: temporary_directories,
    roots: Array::make(temporary_directories.length().max(1), None),
    next: 0,
  }
  // The published core interface exposes close as cancellable. The command
  // owns cleanup protection even when the workspace annotation is stronger.
  defer @async.protect_from_cancel(() => {
    for root in spool.roots {
      if root is Some(root) {
        root.close()
      }
    }
  })
  let runs : Array[Run] = []
  let input : SortInput = {
    specs,
    global,
    separator,
    seed,
    sequence: 0,
    retained: 0,
    entries: [],
  }
  let mut previous : Entry? = None
  for source in (if merge && !check { [] } else { sources }) {
    let complete = scan_source(source, delimiter, batch => {
      if check {
        while batch.next() is Some(line) {
          let entry = input.entry(line.data)
          if previous is Some(old) &&
            (
              compare_entries(old, entry, specs, global, !stable) > 0 ||
              (unique && compare_entries(old, entry, specs, global, false) == 0)
            ) {
            if diagnose {
              let record = @utf8.decode(entry.record) catch { _ => "" }
              @stdio.stderr.write(
                "sort: -:\{input.sequence}: disorder: \{record}\n",
              )
            }
            return false
          }
          previous = Some(entry)
        }
        return true
      }
      while input.batch(batch, run_limit) is Some(entry) {
        runs.push(spool.write_run(input.entries, compare))
        input.entries = []
        input.retained = 0
        // Level carries bound the run directory by O(log records).
        compact_runs(spool, runs, key_count, compare, run_limit, fan_in~)
        input.admit(entry)
      }
      true
    })
    if !complete {
      return 1
    }
  }
  if check {
    return 0
  }
  let mut entries = input.entries
  // Named merge output is not opened for truncation or writing until every
  // source has been consumed into owned runs. Preflight may create it empty.
  if merge && (sources.length() > fan_in || output_path is Some(_)) {
    for first = 0; first < sources.length(); first = first + fan_in {
      runs.push(
        spool.merge_sources(
          sources[first:(first + fan_in).min(sources.length())],
          delimiter,
          specs,
          global,
          separator,
          seed,
          first.to_int64(),
          compare,
        ),
      )
      compact_runs(spool, runs, key_count, compare, run_limit, fan_in~)
    }
  }
  let target = match output_path {
    Some(path) =>
      Some(@fs.open(path, mode=WriteOnly, create_mode=TruncateExisting))
    None => None
  }
  defer (if target is Some(file) { file.close() })
  let sink : &@io.Writer = match target {
    Some(file) => {
      let writer : &@io.Writer = file
      writer
    }
    None => output
  }
  let writer = @stream.BlockWriter::new(sink)
  let emitter : SortedOutput = {
    writer,
    delimiter,
    unique,
    specs,
    global,
    previous: None,
  }
  let emit : async (Entry) -> Unit = entry => emitter.emit(entry)
  if merge && sources.length() <= fan_in && output_path is None {
    merge_input_sources(
      sources[:],
      delimiter,
      specs,
      global,
      separator,
      seed,
      compare,
      emit,
    )
    writer.flush()
    return 0
  }
  if !merge && runs.is_empty() {
    entries.sort_by(compare)
    emitter.emit_entries(entries[:])
    writer.flush()
    return 0
  } else if !merge && !entries.is_empty() {
    runs.push(spool.write_run(entries, compare))
    entries = []
  }
  while runs.length() > fan_in ||
        merge_count(runs, run_limit, fan_in~) < runs.length() {
    let count = merge_count(runs, run_limit, fan_in~)
    let merged = spool.merge(runs[:count], key_count, compare)
    let remaining = runs[count:].to_owned()
    runs.clear()
    runs.append(remaining)
    runs.push(merged)
  }
  merge_runs(runs, key_count, compare, emit)
  writer.flush()
  0
}
