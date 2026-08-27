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
                "\{display_name(left_name)} \{display_name(right_name)} differ: byte \{position}, line \{line}\n",
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
  let files : Array[String] = []
  let mut silent = false
  let mut verbose = false
  let mut limit : Int64? = None
  let mut skip_left : Int64 = 0
  let mut skip_right : Int64 = 0
  let mut options = true
  let mut i = 0
  while i < args.length() {
    let arg = args[i]
    if options && arg == "--" {
      options = false
    } else if options && (arg == "-s" || arg == "--silent" || arg == "--quiet") {
      silent = true
    } else if options && (arg == "-l" || arg == "--verbose") {
      verbose = true
    } else if options && (arg == "-n" || arg == "--bytes") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("cmp: missing byte limit\n")
        @sys.exit(2)
        return
      }
      i += 1
      limit = Some(
        parse_count(args[i], "byte limit") catch {
          CliError(message) => {
            @stdio.stderr.write(message + "\n")
            @sys.exit(2)
            return
          }
        },
      )
    } else if options && arg.has_prefix("--bytes=") {
      limit = Some(
        parse_count(arg[8:].to_owned(), "byte limit") catch {
          CliError(message) => {
            @stdio.stderr.write(message + "\n")
            @sys.exit(2)
            return
          }
        },
      )
    } else if options && (arg == "-i" || arg == "--ignore-initial") {
      if i + 1 >= args.length() {
        @stdio.stderr.write("cmp: missing skip value\n")
        @sys.exit(2)
        return
      }
      i += 1
      let skips = parse_skips(args[i]) catch {
        CliError(message) => {
          @stdio.stderr.write(message + "\n")
          @sys.exit(2)
          return
        }
      }
      skip_left = skips.0
      skip_right = skips.1
    } else if options && arg == "--help" {
      @stdio.stdout.write(
        "Usage: cmp [-s|-l] [-n LIMIT] [-i SKIP[:SKIP2]] FILE1 FILE2\n",
      )
      return
    } else if options && arg.has_prefix("-") && arg != "-" {
      @stdio.stderr.write("cmp: invalid option: '\{arg}'\n")
      @sys.exit(2)
      return
    } else {
      files.push(arg)
    }
    i += 1
  }
  if files.length() != 2 || (files[0] == "-" && files[1] == "-") {
    @stdio.stderr.write("cmp: expected two distinct input sources\n")
    @sys.exit(2)
    return
  }
  let different = try {
    if files[0] == "-" {
      let right = @fs.open(files[1], mode=ReadOnly)
      defer right.close()
      compare_readers(
        @stdio.stdin,
        right,
        files[0],
        files[1],
        silent,
        verbose,
        limit,
        skip_left,
        skip_right,
      )
    } else if files[1] == "-" {
      let left = @fs.open(files[0], mode=ReadOnly)
      defer left.close()
      compare_readers(
        left,
        @stdio.stdin,
        files[0],
        files[1],
        silent,
        verbose,
        limit,
        skip_left,
        skip_right,
      )
    } else {
      let left = @fs.open(files[0], mode=ReadOnly)
      defer left.close()
      let right = @fs.open(files[1], mode=ReadOnly)
      defer right.close()
      compare_readers(
        left,
        right,
        files[0],
        files[1],
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
