///|
priv suberror CksumError {
  CksumError(String)
}

///|
let crc_polynomial : UInt64 = 0x04C11DB7UL

///|
let crc_mask : UInt64 = 0xFFFFFFFFUL

///|
fn crc_update(crc : UInt64, byte : Byte) -> UInt64 {
  let mut value = (crc ^ (byte.to_uint64() << 24)) & crc_mask
  for _ in 0..<8 {
    value = if (value & 0x80000000UL) != 0UL {
      ((value << 1) ^ crc_polynomial) & crc_mask
    } else {
      (value << 1) & crc_mask
    }
  }
  value
}

///|
fn crc_length(crc : UInt64, length : UInt64) -> UInt64 {
  let mut value = crc
  let mut remaining = length
  while remaining != 0UL {
    value = crc_update(value, (remaining & 0xFFUL).to_byte())
    remaining = remaining >> 8
  }
  value ^ crc_mask
}

///|
async fn checksum_reader(
  reader : &@io.Reader,
) -> (UInt64, UInt64) raise CksumError {
  let mut crc : UInt64 = 0UL
  let mut length : UInt64 = 0UL
  while (reader.read_some(max_len=65536) catch {
          err => raise CksumError("\{err}")
        })
        is Some(chunk) {
    length += chunk.length().to_uint64()
    for byte in chunk {
      crc = crc_update(crc, byte)
    }
  }
  (crc_length(crc, length), length)
}

///|
async fn checksum_source(path : String) -> (UInt64, UInt64) raise CksumError {
  if path == "-" {
    checksum_reader(@stdio.stdin)
  } else {
    let file = @fs.open(path, mode=ReadOnly) catch {
      err => raise CksumError("\{err}")
    }
    defer file.close()
    checksum_reader(file)
  }
}

///|
fn help_message() -> String {
  let message =
    #|Usage: cksum [FILE]...
    #|
    #|Print CRC checksum and byte count for each FILE.
    #|With no FILE, or when FILE is -, read standard input.
    #|      --help       display this help and exit
    #|      --version    output version information and exit
    #|
    #|This release implements the POSIX CRC-32 form. GNU alternate
    #|algorithms and tagged output are not included in this strict subset.
  message
}

///|
async fn main {
  let parsed = @cli.parse(@env.args()[1:], [
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(option~, message~, ..) => {
      @stdio.stderr.write("cksum: \{message}: '\{option}'\n")
      @sys.exit(2)
      return
    }
  }
  if parsed.contains("help") {
    @stdio.stdout.write(help_message() + "\n")
    return
  }
  if parsed.contains("version") {
    @stdio.stdout.write("cksum (moonbit cmd) \{command_version}\n")
    return
  }
  if parsed.operands.is_empty() {
    let (checksum, length) = checksum_source("-") catch {
      CksumError(message) => {
        @stdio.stderr.write("cksum: standard input: \{message}\n")
        @sys.exit(1)
        return
      }
    }
    @stdio.stdout.write("\{checksum.to_string()} \{length.to_string()}\n")
    return
  }
  let sources = parsed.operands
  let mut failed = false
  for source in sources {
    let (checksum, length) = checksum_source(source) catch {
      CksumError(message) => {
        @stdio.stderr.write("cksum: '\{source}': \{message}\n")
        failed = true
        continue
      }
    }
    @stdio.stdout.write(
      "\{checksum.to_string()} \{length.to_string()} \{source}\n",
    )
  }
  if failed {
    @sys.exit(1)
  }
}
