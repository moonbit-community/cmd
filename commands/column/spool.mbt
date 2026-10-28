///|
priv suberror LayoutError {
  LayoutError(String)
}

///|
priv suberror InputError {
  InputError(String)
}

///|
priv struct PageCache {
  file : @fs.File
  page_size : Int32
  pages : Array[(Int64, Bytes)]
  mut capacity : Int32
  mut next_page : Int32
}

///|
async fn PageCache::get(self : PageCache, page : Int64, size : Int64) -> Bytes {
  if self.peek(page) is Some(bytes) {
    return bytes
  }
  let position = page * self.page_size.to_int64()
  let length = (size - position).min(self.page_size.to_int64()).to_int()
  let bytes = self.file.read_exactly_at(length, position~)
  if self.pages.length() < self.capacity {
    self.pages.push((page, bytes))
  } else {
    self.pages[self.next_page] = (page, bytes)
    self.next_page = (self.next_page + 1) % self.capacity
  }
  bytes
}

///|
fn PageCache::peek(self : PageCache, page : Int64) -> Bytes? {
  for cached in self.pages {
    if cached.0 == page {
      return Some(cached.1)
    }
  }
  None
}

///|
priv struct Snapshot {
  data : PageCache
  index : PageCache
  data_writer : @stream.BlockWriter
  index_writer : @stream.BlockWriter
  table : Bool
  separator : FieldSeparator
  widths : Array[Int32]
  field_plans : Map[Int64, Bytes]
  mut field_plan_bytes : Int32
  mut records : Int64
  mut size : Int64
  mut longest : Int32
}

///|
async fn with_snapshot(
  table~ : Bool,
  separator~ : String?,
  action : async (Snapshot) -> Bool,
) -> Bool {
  let directory = @tempio.Directory::new(prefix="cli-column-")
  defer directory.close()
  let root = directory.path()
  let data = @fs.open(
    root + "/records",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer data.close()
  let index = @fs.open(
    root + "/index",
    mode=ReadWrite,
    create_mode=CreateNew,
    permission=0o600,
  )
  defer index.close()
  action({
    data: {
      file: data,
      page_size: 65536,
      pages: [],
      capacity: 16,
      next_page: 0,
    },
    index: {
      file: index,
      page_size: 4096,
      pages: [],
      capacity: 16,
      next_page: 0,
    },
    data_writer: @stream.BlockWriter::new(data),
    index_writer: @stream.BlockWriter::new(index),
    table,
    separator: FieldSeparator::new(separator),
    widths: [],
    field_plans: Map([]),
    field_plan_bytes: 0,
    records: 0,
    size: 0,
    longest: 0,
  })
}

///|
fn index_number(bytes : Bytes, offset : Int32) -> Int64 {
  let mut value : Int64 = 0
  for i in 0..<8 {
    value = value | (bytes[offset + i].to_int64() << (i * 8))
  }
  value
}

///|
async fn Snapshot::consume(self : Snapshot, input : &@io.Reader) -> Unit {
  let scanner = @stream.RecordReader::new(input)
  let pending = SpoolBatch::new()
  for ;; {
    let records = scanner.next_batch() catch {
      err => raise InputError(err.to_string())
    }
    guard records is Some(records) else { break }
    while !self.stage_records(records, pending) {
      pending.flush(self.data_writer, self.index_writer)
    }
    // Commit complete records before the next read can fail.
    pending.flush(self.data_writer, self.index_writer)
  }
}

///|
async fn Snapshot::finish(self : Snapshot) -> Unit {
  self.data_writer.flush()
  self.index_writer.flush()
}

///|
async fn Snapshot::record_bytes(self : Snapshot, record : Int64) -> BytesView {
  // Grid rendering grows this bounded cache for its interleaved cursors,
  // without retaining an offset entry for every input record.
  let page = record / 256
  let bytes = self.index.get(page, self.records * 16)
  let slot = (record % 256).to_int() * 16
  let position = index_number(bytes, slot)
  let length = index_number(bytes, slot + 8).to_int()
  let first = self.data.get(position / 65536, self.size)
  let start = (position % 65536).to_int()
  if length <= first.length() - start {
    return first[start:start + length]
  }
  let line = Buffer(size_hint=length)
  for copied = 0; copied < length; {
    let offset = position + copied.to_int64()
    let bytes = self.data.get(offset / 65536, self.size)
    let start = (offset % 65536).to_int()
    let count = (length - copied).min(bytes.length() - start)
    line.write_bytes(bytes[start:start + count])
    continue copied + count
  }
  line.to_bytes()[:]
}

///|
fn Snapshot::cached_record_bytes(self : Snapshot, record : Int64) -> BytesView? {
  guard self.index.peek(record / 256) is Some(entry) else { return None }
  let slot = (record % 256).to_int() * 16
  let position = index_number(entry, slot)
  let length = index_number(entry, slot + 8).to_int()
  if length == 0 {
    return Some(b""[:])
  }
  guard self.data.peek(position / 65536) is Some(bytes) else { return None }
  let start = (position % 65536).to_int()
  guard length <= bytes.length() - start else { return None }
  Some(bytes[start:start + length])
}

///|
async fn Snapshot::line(self : Snapshot, record : Int64) -> String {
  // Grid rendering grows this bounded cache for its interleaved cursors,
  // without retaining an offset entry for every input record.
  let page = record / 256
  let bytes = self.index.get(page, self.records * 16)
  let slot = (record % 256).to_int() * 16
  let position = index_number(bytes, slot)
  let length = index_number(bytes, slot + 8).to_int()
  let first = self.data.get(position / 65536, self.size)
  let start = (position % 65536).to_int()
  if length <= first.length() - start {
    return @utf8.decode(first[start:start + length])
  }
  let line = Buffer(size_hint=length)
  for copied = 0; copied < length; {
    let offset = position + copied.to_int64()
    let bytes = self.data.get(offset / 65536, self.size)
    let start = (offset % 65536).to_int()
    let count = (length - copied).min(bytes.length() - start)
    line.write_bytes(bytes[start:start + count])
    continue copied + count
  }
  @utf8.decode(line.contents())
}

///|
fn grid_shape(
  records : Int64,
  longest : Int32,
  width : Int32,
) -> (Int64, Int64, Int64) {
  let stride = (longest.to_int64() / 8 + 1) * 8
  let columns = if longest >= width {
    1L
  } else {
    (width.to_int64() / stride).max(1).min(records)
  }
  let rows = records / columns + (if records % columns == 0 { 0L } else { 1L })
  (stride, columns, rows)
}

///|
async fn Snapshot::render_grid(
  self : Snapshot,
  output : &@io.Writer,
  width : Int32,
  fill_rows : Bool,
) -> Unit {
  if self.records == 0 {
    return
  }
  let (stride, columns, rows) = grid_shape(self.records, self.longest, width)
  let capacity = columns.max(16).min(256).to_int()
  self.data.capacity = capacity
  self.index.capacity = capacity
  for row = 0L; row < rows; row = row + 1 {
    let mut position : Int64 = 0
    let mut end_column = stride
    for column = 0L; column < columns; column = column + 1 {
      let index = if fill_rows {
        row * columns + column
      } else {
        row + column * rows
      }
      if index >= self.records {
        break
      }
      if column > 0 {
        while (position / 8 + 1) * 8 <= end_column {
          output.write("\t")
          position = (position / 8 + 1) * 8
        }
        end_column += stride
      }
      let line = self.line(index)
      output.write(line)
      position += display_width(line).to_int64()
    }
    output.write("\n")
  }
}

///|
async fn run_layout(
  paths : Array[String],
  table~ : Bool,
  separator~ : String?,
  output_separator~ : String,
  width~ : Int32,
  fill_rows~ : Bool,
) -> Bool {
  with_snapshot(table~, separator~, snapshot => {
    let mut failed = false
    if paths.is_empty() {
      snapshot.consume(@stdio.stdin) catch {
        InputError(message) => {
          @stdio.stderr.write("column: \{message}\n")
          failed = true
        }
        err => raise err
      }
    } else {
      for path in paths {
        // util-linux treats '-' as a filename; omitted operands select stdin.
        let file = @fs.open(path, mode=ReadOnly) catch {
          err => {
            @stdio.stderr.write("column: \{path}: \{err}\n")
            failed = true
            continue
          }
        }
        defer file.close()
        snapshot.consume(file) catch {
          InputError(message) => {
            @stdio.stderr.write("column: \{path}: \{message}\n")
            failed = true
          }
          err => raise err
        }
      }
    }
    snapshot.finish()
    let output = @io.BufferedWriter::new(@stdio.stdout, size=65536)
    if table {
      snapshot.render_table(output, output_separator)
    } else {
      snapshot.render_grid(output, width, fill_rows)
    }
    output.flush()
    failed
  })
}
