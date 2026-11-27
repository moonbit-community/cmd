///|
async fn flush_reverse(output : Output, pending : Array[Byte]) -> Unit {
  if !pending.is_empty() {
    output.write(Bytes::from_array(pending))
    pending.clear()
  }
}

///|
async fn reverse_stream(
  reader : &@io.BinaryReader,
  output : Output,
  opts : Options,
) -> Unit {
  if opts.style is Little || opts.style is Include {
    raise CliError(255, "xxd: Sorry, cannot revert this type of hexdump")
  }
  let base = match opts.seek {
    Some(seek) => if seek.negative { -seek.amount } else { seek.amount }
    None => 0L
  }
  let decoder = @codec.Decoder::new(opts.style, opts.cols, base)
  let pending : Array[Byte] = []
  let chunks = @stream.ChunkReader::new(reader)
  while chunks.read() is Some(chunk) {
    try {
      for byte in chunk {
        if (decoder.feed(byte) catch {
            @codec.DecodeError(message) => raise CliError(5, message)
          })
          is Some((target, value)) {
          let current = checked_add(
            output.position,
            pending.length().to_int64(),
            5,
            "xxd: output offset overflow.",
          )
          if target != current {
            flush_reverse(output, pending)
            output.seek(target)
          }
          if value is Some(value) {
            pending.push(value)
          }
        }
      }
    } catch {
      CliError(status, message) => {
        if status == 5 {
          flush_reverse(output, pending)
        }
        raise CliError(status, message)
      }
      error => raise error
    }
    flush_reverse(output, pending)
  }
}
