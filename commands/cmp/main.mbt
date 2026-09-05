///|
priv suberror CliError {
  CliError(String)
}

///|
fn parse_count(text : String, option : String) -> Int64 raise CliError {
  let value = @string.parse_int64(text) catch {
    _ => raise CliError("cmp: invalid \{option}: '\{text}'")
  }
  if value < 0 {
    raise CliError("cmp: invalid \{option}: '\{text}'")
  }
  value
}

///|
fn parse_skips(text : String) -> (Int64, Int64) raise CliError {
  let parts : Array[String] = text.split(":").map(v => v.to_owned()).collect()
  match parts {
    [one] => {
      let value = parse_count(one, "skip")
      (value, value)
    }
    [left, right] => (parse_count(left, "skip"), parse_count(right, "skip"))
    _ => raise CliError("cmp: invalid skip: '\{text}'")
  }
}

///|
async fn drop_bytes(reader : &@io.Reader, count : Int64) -> Unit {
  let mut remaining = count
  while remaining > 0 {
    let request = if remaining > 0x3FFF_FFFF {
      0x3FFF_FFFF
    } else {
      remaining.to_int()
    }
    let dropped = reader.drop(request)
    if dropped < request {
      return
    }
    remaining -= dropped.to_int64()
  }
}

///|
async fn compare_readers(
  left : &@io.Reader,
  right : &@io.Reader,
  left_name : String,
  right_name : String,
  silent : Bool,
  verbose : Bool,
  limit : Int64?,
  skip_left : Int64,
  skip_right : Int64,
) -> Bool {
  drop_bytes(left, skip_left)
  drop_bytes(right, skip_right)
  let mut left_chunk : Bytes? = None
  let mut right_chunk : Bytes? = None
  let mut left_pos = 0
  let mut right_pos = 0
  let mut compared : Int64 = 0
  let mut line : Int64 = 1
  let mut different = false
  while limit is None || compared < limit.unwrap() {
    if left_chunk is None || left_pos >= left_chunk.unwrap().length() {
      left_chunk = left.read_some(max_len=65536)
      left_pos = 0
    }
    if right_chunk is None || right_pos >= right_chunk.unwrap().length() {
      right_chunk = right.read_some(max_len=65536)
      right_pos = 0
    }
    match (left_chunk, right_chunk) {
      (None, None) => break
      (None, Some(_)) | (Some(_), None) => {
        different = true
        if !silent {
          let shorter = if left_chunk is None { left_name } else { right_name }
          @stdio.stderr.write(
            "cmp: EOF on \{display_name(shorter)} after byte \{compared}, line \{line}\n",
          )
        }
        break
      }
      (Some(a), Some(b)) => {
        let left_available = a.length() - left_pos
        let right_available = b.length() - right_pos
        let mut take = if left_available < right_available {
          left_available
        } else {
          right_available
        }
        match limit {
          Some(maximum) if maximum - compared < take.to_int64() =>
            take = (maximum - compared).to_int()
          _ => ()
        }
        for offset in 0..<take {
          let left_byte = a[left_pos + offset]
          let right_byte = b[right_pos + offset]
          if left_byte != right_byte {
            different = true
            let position = compared + offset.to_int64() + 1
            if !silent && !verbose {
              @stdio.stdout.write(
                "\{display_name(left_name)} \{display_name(right_name)} differ: char \{position}, line \{line}\n",
              )
              return true
            }
            if verbose && !silent {
              @stdio.stdout.write(
                "\{pad_left(position.to_string(), 6)} \{pad_left(left_byte.to_int().to_string(radix=8), 3)} \{pad_left(right_byte.to_int().to_string(radix=8), 3)}\n",
              )
            }
          }
          if left_byte == b'\n' {
            line += 1
          }
        }
        left_pos += take
        right_pos += take
        compared += take.to_int64()
      }
    }
  }
  different
}

///|
fn display_name(path : String) -> String {
  if path == "-" {
    "standard input"
  } else {
    path
  }
}

///|
fn pad_left(text : String, width : Int) -> String {
  if text.length() >= width {
    text
  } else {
    " ".repeat(width - text.length()) + text
  }
}

///|
async fn main {
  let args = @env.args()[1:]
  let parsed = @cli.parse(args, [
    @cli.flag("silent", short='s'),
    @cli.flag("quiet"),
    @cli.flag("verbose", short='l'),
    @cli.option("bytes", short='n'),
    @cli.option("ignore-initial", short='i'),
    @cli.flag("help"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("cmp: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(
      "Usage: cmp [-s|-l] [-n LIMIT] [-i SKIP[:SKIP2]] FILE1 FILE2\n",
    )
    return
  }
  let files = parsed.operands
  let silent = parsed.contains("silent") || parsed.contains("quiet")
  let verbose = parsed.contains("verbose")
  if silent && verbose {
    @stdio.stderr.write("cmp: options -l and -s are incompatible\n")
    @sys.exit(2)
    return
  }
  let limit = match parsed.last_value("bytes") {
    Some(value) =>
      Some(
        parse_count(value, "byte limit") catch {
          CliError(message) => {
            @stdio.stderr.write(message + "\n")
            @sys.exit(2)
            return
          }
        },
      )
    None => None
  }
  let (skip_left, skip_right) = match parsed.last_value("ignore-initial") {
    Some(value) =>
      parse_skips(value) catch {
        CliError(message) => {
          @stdio.stderr.write(message + "\n")
          @sys.exit(2)
          return
        }
      }
    None => (0L, 0L)
  }
  if files.length() < 1 || files.length() > 2 {
    @stdio.stderr.write("cmp: expected two distinct input sources\n")
    @sys.exit(2)
    return
  }
  let sources = if files.length() == 1 { [files[0], "-"] } else { files }
  if sources[0] == "-" && sources[1] == "-" {
    @stdio.stderr.write("cmp: expected two distinct input sources\n")
    @sys.exit(2)
    return
  }
  let different = try {
    if sources[0] == "-" {
      let right = @fs.open(sources[1], mode=ReadOnly)
      defer right.close()
      compare_readers(
        @stdio.stdin,
        right,
        sources[0],
        sources[1],
        silent,
        verbose,
        limit,
        skip_left,
        skip_right,
      )
    } else if sources[1] == "-" {
      let left = @fs.open(sources[0], mode=ReadOnly)
      defer left.close()
      compare_readers(
        left,
        @stdio.stdin,
        sources[0],
        sources[1],
        silent,
        verbose,
        limit,
        skip_left,
        skip_right,
      )
    } else {
      let left = @fs.open(sources[0], mode=ReadOnly)
      defer left.close()
      let right = @fs.open(sources[1], mode=ReadOnly)
      defer right.close()
      compare_readers(
        left,
        right,
        sources[0],
        sources[1],
        silent,
        verbose,
        limit,
        skip_left,
        skip_right,
      )
    }
  } catch {
    err => {
      @stdio.stderr.write("cmp: \{err}\n")
      @sys.exit(2)
      return
    }
  }
  if different {
    @sys.exit(1)
  }
}
