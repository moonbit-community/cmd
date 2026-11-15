///|
fn dump_line(data : ArrayView[Byte], opts : Options, offset : Int64) -> Bytes {
  @codec.dump_line(
    data,
    {
      style: opts.style,
      cols: opts.cols,
      group: opts.group,
      upper: opts.upper,
      ebcdic: opts.ebcdic,
      display_offset: opts.display_offset,
    },
    offset,
  )
}
