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
  for cached in self.pages {
    if cached.0 == page {
      return cached.1
    }
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
priv struct Snapshot {
  data : PageCache
  index : PageCache
  data_writer : @io.BufferedWriter[@fs.File]
  index_writer : @io.BufferedWriter[@fs.File]
  table : Bool
  separator : String?
  widths : Array[Int32]
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
  let root = @fs.tmpdir(prefix="cli-column-")
  defer @fs.rmdir(root, recursive=true)
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
    data_writer: @io.BufferedWriter::new(data, size=65536),
    index_writer: @io.BufferedWriter::new(index, size=65536),
    table,
    separator,
    widths: [],
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
async fn Snapshot::append(self : Snapshot, line : String) -> Unit {
  let bytes = @utf8.encode(line)
  if self.records == 576460752303423487L ||
    self.size > 9223372036854775807L - bytes.length().to_int64() {
    raise LayoutError("temporary snapshot exceeds 64-bit offsets")
  }
  let entry = Buffer(size_hint=16)
  entry.write_int64_le(self.size)
  entry.write_int64_le(bytes.length().to_int64())
  self.data_writer.write(bytes)
  self.index_writer.write(entry.contents())
  self.records += 1
  self.size += bytes.length().to_int64()
  if self.table {
    for i, field in split_fields(line, self.separator) {
      while self.widths.length() <= i {
        self.widths.push(0)
      }
      self.widths[i] = self.widths[i].max(display_width(field, table=true))
    }
  } else {
    self.longest = self.longest.max(display_width(line))
  }
}

///|
async fn Snapshot::consume(self : Snapshot, input : &@io.Reader) -> Unit {
  let scanner = @stream.LineScanner::new(input)
  for ;; {
    let record = scanner.next() catch {
      err => raise InputError(err.to_string())
    }
    guard record is Some(record) else { break }
    if input_line(record.data) is Some(line) {
      self.append(line)
    }
  }
}

///|
async fn Snapshot::finish(self : Snapshot) -> Unit {
  self.data_writer.flush()
  self.index_writer.flush()
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
async fn write_spaces(output : &@io.Writer, count : Int32) -> Unit {
  let spaces = "                                                                "
  for remaining = count; remaining > 0; {
    let length = remaining.min(spaces.length())
    output.write(spaces[:length])
    continue remaining - length
  }
}

///|
async fn Snapshot::render_table(
  self : Snapshot,
  output : &@io.Writer,
  output_separator : String,
) -> Unit {
  for record = 0L; record < self.records; record = record + 1 {
    let row = split_fields(self.line(record), self.separator)
    for index in 0..<self.widths.length() {
      let field = row.get(index).unwrap_or("")
      output.write(field)
      if index + 1 < self.widths.length() {
        write_spaces(
          output,
          self.widths[index] - display_width(field, table=true),
        )
        output.write(output_separator)
      }
    }
    output.write("\n")
  }
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
