///|
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
  reader : RunReader
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
  mut root : String?
  mut next : Int64
}

///|
async fn Spool::path(self : Spool) -> String {
  let root = match self.root {
    Some(root) => root
    None => {
      let root = @fs.tmpdir(prefix="cli-sort-")
      self.root = Some(root)
      root
    }
  }
  let path = root + "/run-" + self.next.to_string()
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
fn merge_count(runs : ArrayView[Run], budget : Int64) -> Int32 {
  let mut count = 0
  let mut retained : Int64 = 0
  for run in runs[:runs.length().min(16)] {
    if count >= 2 && retained + run.largest_entry > budget {
      break
    }
    retained += run.largest_entry
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
) -> Unit {
  for level in 0..<64 {
    for ;; {
      let indices : Array[Int32] = []
      for index, run in runs {
        if run.level == level {
          indices.push(index)
        }
        if indices.length() == 16 {
          break
        }
      }
      if indices.length() < 16 {
        break
      }
      let group = indices.map(index => runs[index])
      let count = merge_count(group, budget)
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
  accept : async (Bytes) -> Bool,
) -> Bool {
  let file = if path == "-" {
    None
  } else {
    Some(@fs.open(path, mode=ReadOnly))
  }
  defer (if file is Some(file) { file.close() })
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
  let scanner = @stream.LineScanner::new(reader, delimiter~)
  while scanner.next() is Some(line) {
    if !accept(line.data) {
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
  check~ : Bool = false,
  diagnose~ : Bool = false,
  budget~ : Int64 = 67108864,
) -> Int32 {
  let compare = (left : Entry, right : Entry) => {
    let order = compare_entries(left, right, specs, global, !unique)
    if order == 0 {
      left.index.compare(right.index)
    } else {
      order
    }
  }
  let key_count = if specs.is_empty() {
    if transforms_key(global) {
      1
    } else {
      0
    }
  } else {
    specs.length()
  }
  // Reserve input/output and sixteen merge buffers plus the bounded run index.
  let reserve : Int64 = 22 * 65536
  let run_limit = (budget - reserve).max(1)
  let spool : Spool = { root: None, next: 0, }
  defer (if spool.root is Some(root) { @fs.rmdir(root, recursive=true) })
  let runs : Array[Run] = []
  let mut entries : Array[Entry] = []
  let mut retained : Int64 = 0
  let mut sequence : Int64 = 0
  let mut previous : Entry? = None
  for source in sources {
    let complete = scan_source(source, delimiter, record => {
      let entry = make_entry(record, sequence, specs, global, separator)
      sequence += 1
      if check {
        if previous is Some(old) &&
          (
            compare_entries(old, entry, specs, global, true) > 0 ||
            (unique && compare_entries(old, entry, specs, global, false) == 0)
          ) {
          if diagnose {
            let record = @utf8.decode(record) catch { _ => "" }
            @stdio.stderr.write("sort: -:\{sequence}: disorder: \{record}\n")
          }
          return false
        }
        previous = Some(entry)
        return true
      }
      let cost = entry_cost(entry)
      if !entries.is_empty() && retained + cost > run_limit {
        runs.push(spool.write_run(entries, compare))
        entries = []
        retained = 0
        // Level carries bound the run directory by O(log records).
        compact_runs(spool, runs, key_count, compare, run_limit)
      }
      entries.push(entry)
      retained += cost
      true
    })
    if !complete {
      return 1
    }
  }
  if check {
    return 0
  }
  let writer = @io.BufferedWriter::new(output, size=65536)
  let emit : async (Entry) -> Unit = entry => {
    if previous is Some(old) &&
      unique &&
      compare_entries(old, entry, specs, global, false) == 0 {
      return
    }
    writer.write(entry.record)
    writer.write(if delimiter == b'\x00' { b"\x00" } else { b"\n" })
    if unique {
      previous = Some({
        record: b"",
        keys: if entry.keys.is_empty() {
          [entry.record]
        } else {
          entry.keys
        },
        index: entry.index,
      })
    }
  }
  if runs.is_empty() {
    entries.sort_by(compare)
    for entry in entries {
      emit(entry)
    }
  } else {
    if !entries.is_empty() {
      runs.push(spool.write_run(entries, compare))
      entries = []
    }
    while runs.length() > 16 || merge_count(runs, run_limit) < runs.length() {
      let count = merge_count(runs, run_limit)
      let merged = spool.merge(runs[:count], key_count, compare)
      let remaining = runs[count:].to_owned()
      runs.clear()
      runs.append(remaining)
      runs.push(merged)
    }
    merge_runs(runs, key_count, compare, emit)
  }
  writer.flush()
  0
}
