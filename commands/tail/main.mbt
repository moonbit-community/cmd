///|
priv suberror CliError {
  CliError(String)
}

///|
/// `Last(n)` selects the final n units; `FromStart(k)` selects from the k-th
/// unit (1-based) to the end, mirroring tail's `-n +K` syntax.
priv enum CountSpec {
  Last(Int64)
  FromStart(Int64)
}

///|
let chunk_size : Int = 65536

///|
/// The follow loop keeps the descriptor open so renames do not switch it to a
/// different file. The offset is the next byte that has not been emitted.
priv struct FollowFile {
  file : @fs.File
  name : String
  source_index : Int
  mut offset : Int64
}

///|
fn parse_spec(text : String) -> CountSpec raise CliError {
  let (from_start, digits) = if text is ['+', .. rest] {
    (true, rest)
  } else {
    (false, text)
  }
  let n = @string.parse_int64(digits) catch {
    _ => raise CliError("tail: invalid count: '\{text}'")
  }
  if n < 0 {
    raise CliError("tail: invalid count: '\{text}'")
  }
  if from_start {
    FromStart(if n < 1 { 1 } else { n })
  } else {
    Last(n)
  }
}

///|
/// Parse GNU tail's follow polling interval and convert seconds to the
/// millisecond unit used by the async runtime.
fn parse_sleep_interval(text : String) -> Int raise CliError {
  if text is ['-', ..] {
    raise CliError("tail: invalid sleep interval: '\{text}'")
  }
  let seconds = @string.parse_double(text) catch {
    _ => raise CliError("tail: invalid sleep interval: '\{text}'")
  }
  if seconds < 0.0 || seconds.is_nan() || seconds.is_inf() {
    raise CliError("tail: invalid sleep interval: '\{text}'")
  }
  let milliseconds = (seconds * 1000.0).ceil()
  if milliseconds >= 2147483647.0 {
    2147483647
  } else {
    let rounded = milliseconds.to_int()
    if rounded < 1 {
      1
    } else {
      rounded
    }
  }
}

///|
/// Select lines from an in-memory buffer (used for streamed input after the
/// ring buffer has trimmed it down). A trailing newline terminates the final
/// line rather than starting an empty one.
fn select_lines(data : Bytes, spec : CountSpec) -> BytesView {
  match spec {
    Last(n) => {
      if n <= 0 || data.length() == 0 {
        return data[0:0]
      }
      let mut i = if data[data.length() - 1] is b'\n' {
        data.length() - 2
      } else {
        data.length() - 1
      }
      let mut newlines : Int64 = 0
      while i >= 0 {
        if data[i] is b'\n' {
          newlines += 1
          if newlines == n {
            return data[i + 1:]
          }
        }
        i -= 1
      }
      data
    }
    FromStart(k) => {
      if k <= 1 {
        return data
      }
      let mut seen : Int64 = 0
      for i in 0..<data.length() {
        if data[i] is b'\n' {
          seen += 1
          if seen == k - 1 {
            return data[i + 1:]
          }
        }
      }
      data[data.length():]
    }
  }
}

///|
fn select_bytes(data : Bytes, spec : CountSpec) -> BytesView {
  let len = data.length().to_int64()
  match spec {
    Last(n) => {
      let start = if n >= len { 0 } else { (len - n).to_int() }
      data[start:]
    }
    FromStart(k) => {
      let start = if k - 1 > len { data.length() } else { (k - 1).to_int() }
      data[start:]
    }
  }
}

///|
fn count_newlines(chunk : Bytes) -> Int {
  let mut n = 0
  for b in chunk {
    if b is b'\n' {
      n += 1
    }
  }
  n
}

///|
fn concat_chunks(chunks : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  for chunk in chunks {
    for b in chunk {
      out.push(b)
    }
  }
  Bytes::from_array(out)
}

///|
/// Stream file bytes in [start, end) to stdout in fixed-size chunks.
async fn stream_range(file : @fs.File, start : Int64, end : Int64) -> Unit {
  let mut pos = start
  while pos < end {
    let len = if end - pos < chunk_size.to_int64() {
      (end - pos).to_int()
    } else {
      chunk_size
    }
    @stdio.stdout.write(file.read_exactly_at(len, position=pos))
    pos += len.to_int64()
  }
}

///|
/// GNU-style tail for seekable files: find the start of the selection by
/// scanning backward (or forward for +K) in fixed-size chunks, then stream
/// it out. Memory stays bounded by the chunk size for any file size.
async fn tail_file(
  file : @fs.File,
  spec : CountSpec,
  bytes_mode : Bool,
) -> Int64 {
  let size = file.size()
  if bytes_mode {
    let start : Int64 = match spec {
      Last(n) => if n >= size { 0 } else { size - n }
      FromStart(k) => if k - 1 > size { size } else { k - 1 }
    }
    stream_range(file, start, size)
    return size
  }
  match spec {
    Last(n) => {
      if n <= 0 || size == 0 {
        return size
      }
      let mut newlines : Int64 = 0
      let mut start : Int64 = 0
      let mut found = false
      let mut pos = size
      let mut at_file_end = true
      while pos > 0 && !found {
        let len = if pos < chunk_size.to_int64() {
          pos.to_int()
        } else {
          chunk_size
        }
        let chunk = file.read_exactly_at(len, position=pos - len.to_int64())
        let mut idx = chunk.length() - 1
        if at_file_end && chunk[idx] is b'\n' {
          // The trailing newline terminates the last line rather than
          // starting an empty one.
          idx -= 1
        }
        at_file_end = false
        while idx >= 0 {
          if chunk[idx] is b'\n' {
            newlines += 1
            if newlines == n {
              start = pos - len.to_int64() + idx.to_int64() + 1
              found = true
              break
            }
          }
          idx -= 1
        }
        pos -= len.to_int64()
      }
      stream_range(file, start, size)
      size
    }
    FromStart(k) => {
      if k <= 1 {
        stream_range(file, 0, size)
        return size
      }
      // Scan forward for the (k-1)-th newline, then stream the rest.
      let mut seen : Int64 = 0
      let mut pos : Int64 = 0
      while pos < size {
        let len = if size - pos < chunk_size.to_int64() {
          (size - pos).to_int()
        } else {
          chunk_size
        }
        let chunk = file.read_exactly_at(len, position=pos)
        for i in 0..<chunk.length() {
          if chunk[i] is b'\n' {
            seen += 1
            if seen == k - 1 {
              stream_range(file, pos + i.to_int64() + 1, size)
              return size
            }
          }
        }
        pos += len.to_int64()
      }
      size
    }
  }
}

///|
async fn read_chunk(r : &@io.Reader, buf : FixedArray[Byte]) -> Bytes? {
  let n = r.read(buf)
  if n == 0 {
    None
  } else {
    Some(Bytes::from_array(buf[0:n]))
  }
}

///|
/// Tail an unseekable stream (stdin, pipes). `Last` keeps a ring of chunks
/// holding just the bytes of the selection, so memory is bounded by the
/// output size plus one chunk; `FromStart` writes through once the start
/// point has passed, buffering nothing.
async fn tail_stream(
  r : &@io.Reader,
  spec : CountSpec,
  bytes_mode : Bool,
) -> Unit {
  let buf : FixedArray[Byte] = FixedArray::make(chunk_size, 0)
  match spec {
    Last(n) => {
      if n <= 0 {
        // Drain the input like GNU tail, producing no output.
        while true {
          if read_chunk(r, buf) is None {
            break
          }
        }
        return
      }
      let chunks : Array[Bytes] = []
      let counts : Array[Int64] = []
      let mut total_newlines : Int64 = 0
      let mut total_bytes : Int64 = 0
      for ;; {
        match read_chunk(r, buf) {
          Some(chunk) => {
            chunks.push(chunk)
            total_bytes += chunk.length().to_int64()
            if bytes_mode {
              while chunks.length() > 1 &&
                    total_bytes - chunks[0].length().to_int64() >= n {
                total_bytes -= chunks[0].length().to_int64()
                ignore(chunks.remove(0))
              }
            } else {
              let c = count_newlines(chunk).to_int64()
              counts.push(c)
              total_newlines += c
              // Keep more than n newlines beyond the dropped prefix so the
              // last n lines stay fully buffered. (Written as `> n` rather
              // than `>= n + 1`, which would overflow for n = INT64_MAX.)
              while chunks.length() > 1 && total_newlines - counts[0] > n {
                total_newlines -= counts[0]
                ignore(chunks.remove(0))
                ignore(counts.remove(0))
              }
            }
          }
          None => break
        }
      }
      let data = concat_chunks(chunks)
      if bytes_mode {
        @stdio.stdout.write(select_bytes(data, spec))
      } else {
        @stdio.stdout.write(select_lines(data, spec))
      }
    }
    FromStart(k) =>
      if bytes_mode {
        let mut to_skip : Int64 = if k > 1 { k - 1 } else { 0 }
        for ;; {
          match read_chunk(r, buf) {
            Some(chunk) =>
              if to_skip >= chunk.length().to_int64() {
                to_skip -= chunk.length().to_int64()
              } else if to_skip > 0 {
                @stdio.stdout.write(chunk[to_skip.to_int():])
                to_skip = 0
              } else {
                @stdio.stdout.write(chunk)
              }
            None => break
          }
        }
      } else {
        let mut remaining : Int64 = if k > 1 { k - 1 } else { 0 }
        for ;; {
          match read_chunk(r, buf) {
            Some(chunk) => {
              if remaining == 0 {
                @stdio.stdout.write(chunk)
                continue
              }
              let mut emitted = false
              for i in 0..<chunk.length() {
                if chunk[i] is b'\n' {
                  remaining -= 1
                  if remaining == 0 {
                    @stdio.stdout.write(chunk[i + 1:])
                    emitted = true
                    break
                  }
                }
              }
              ignore(emitted)
            }
            None => break
          }
        }
      }
  }
}

///|
/// Read the bytes observed by one follow pass. A short read is valid when a
/// writer truncates the file while the pass is in progress; returning the
/// actual position lets the next pass recover without skipping data.
async fn stream_available(file : @fs.File, start : Int64, end : Int64) -> Int64 {
  let buf : FixedArray[Byte] = FixedArray::make(chunk_size, 0)
  let mut pos = start
  while pos < end {
    let len = if end - pos < chunk_size.to_int64() {
      (end - pos).to_int()
    } else {
      chunk_size
    }
    let n = file.read_at(buf, position=pos, len~)
    if n == 0 {
      return pos
    }
    @stdio.stdout.write(Bytes::from_array(buf[0:n]))
    pos += n.to_int64()
    if n < len {
      return pos
    }
  }
  pos
}

///|
/// Follow regular files by polling their already-open descriptors. A smaller
/// size means the file was truncated in place, so the next pass starts again
/// at byte zero. Cancellation closes every descriptor through the defer.
async fn follow_files(
  files : Array[FollowFile],
  interval_ms : Int,
  show_headers : Bool,
  last_source_index : Int,
) -> Unit {
  defer (for state in files {
    state.file.close()
  })
  let mut last_output = last_source_index
  for ;; {
    @async.sleep(interval_ms)
    for index in 0..<files.length() {
      let file = files[index].file
      let offset = files[index].offset
      let size = file.size()
      let start : Int64 = if size < offset { 0 } else { offset }
      if size > start {
        if show_headers && files[index].source_index != last_output {
          @stdio.stdout.write("\n==> \{files[index].name} <==\n")
          last_output = files[index].source_index
        }
        files[index].offset = stream_available(file, start, size)
      } else if size < offset {
        files[index].offset = 0
      }
    }
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("quiet", short='q'),
    @cli.flag("verbose", short='v'),
    @cli.flag("follow", short='f'),
    @cli.option("lines", short='n'),
    @cli.option("bytes", short='c'),
    @cli.option("sleep-interval", short='s'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("tail: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: tail [-f] [-qv] [-s SEC] [-n NUM|-c NUM] [FILE...]\n",
    )
    return
  }
  let quiet = parsed.contains("quiet")
  let verbose = parsed.contains("verbose")
  let follow = parsed.contains("follow")
  if parsed.contains("lines") && parsed.contains("bytes") {
    @stdio.stderr.write("tail: lines and bytes are mutually exclusive\n")
    @sys.exit(2)
    return
  }
  let (spec, bytes_mode) = try {
    match parsed.last_value("bytes") {
      Some(text) => (parse_spec(text), true)
      None =>
        match parsed.last_value("lines") {
          Some(text) => (parse_spec(text), false)
          None => (Last(10), false)
        }
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
  }
  let interval_ms = try {
    match parsed.last_value("sleep-interval") {
      Some(text) => parse_sleep_interval(text)
      None => 1000
    }
  } catch {
    CliError(msg) => {
      @stdio.stderr.write("\{msg}\n")
      @sys.exit(2)
      return
    }
  }
  let files = parsed.operands
  let sources = if files.is_empty() { ["-"] } else { files }
  let show_headers = (sources.length() > 1 || verbose) && !quiet
  let mut failed = false
  let follow_states : Array[FollowFile] = []
  for index, path in sources {
    if show_headers {
      let name = if path == "-" { "standard input" } else { path }
      let prefix = if index > 0 { "\n" } else { "" }
      @stdio.stdout.write("\{prefix}==> \{name} <==\n")
    }
    try {
      if path == "-" {
        tail_stream(@stdio.stdin, spec, bytes_mode)
      } else {
        let file = @fs.open(path, mode=ReadOnly)
        errdefer file.close()
        if file.kind() is Regular {
          let offset = tail_file(file, spec, bytes_mode)
          if follow {
            follow_states.push({
              file,
              name: path,
              source_index: index,
              offset,
            })
          } else {
            file.close()
          }
        } else {
          // Named pipes and devices are not seekable; stream them instead.
          tail_stream(file, spec, bytes_mode)
          file.close()
        }
      }
    } catch {
      err => {
        @stdio.stderr.write("tail: \{err}\n")
        failed = true
      }
    }
  }
  if follow && !follow_states.is_empty() {
    follow_files(follow_states, interval_ms, show_headers, sources.length() - 1)
  }
  if failed {
    @sys.exit(1)
  }
}
