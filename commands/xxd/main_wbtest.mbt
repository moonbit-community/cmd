///|
fn decoded(
  text : Bytes,
  style : Style,
  cols : Int32,
  base~ : Int64 = 0L,
) -> Array[(Int64, Byte)] raise CliError {
  let decoder = ReverseDecoder::new(style, cols, base)
  let result = []
  for byte in text {
    if decoder.feed(byte) is Some((position, Some(byte))) {
      result.push((position, byte))
    }
  }
  result
}

///|
test "xxd include output is stable and addressed dumps preserve holes" {
  assert_eq(include_name("fixture.bin", Some("fixture")), Some("fixture"))
  assert_eq(include_name("-", None), None)
  assert_eq(include_name("1-file.bin", None), Some("__1_file_bin"))
  assert_eq(include_name("éfile", None), Some("__file"))
  assert_eq(decoded(b"00000002: 4142  ;AB\n", Normal, 16), [
    (2L, b'A'),
    (3L, b'B'),
  ])
}

///|
test "xxd malformed addressed lines follow loose upstream offsets" {
  assert_eq(decoded(b"00000000: zz\n", Normal, 16), [])
  assert_eq(decoded(b"not a dump\n", Normal, 16), [])
  let decoder = ReverseDecoder::new(Normal, 16, 0L)
  let mut first = None
  for byte in b"not a dump\n" {
    if decoder.feed(byte) is Some((offset, _)) && first is None {
      first = Some(offset)
    }
  }
  assert_eq(first, Some(10L))
  assert_eq(decoded(b"xyz\n", Normal, 16), [])
}

///|
test "xxd styles grouping case and EBCDIC preserve source bytes" {
  let bits = options(parse_args(["-b"]))
  assert_eq(
    dump_line(b"A"[:].to_array(), bits, 0L),
    b"00000000: 01000001                                               A\n",
  )
  let little = options(parse_args(["-e", "-c6"]))
  assert_eq(
    dump_line(b"012345"[:].to_array(), little, 0L),
    b"00000000: 33323130     3534   012345\n",
  )
  let grouped = options(parse_args(["-g3", "-c6", "-u", "-E"]))
  assert_eq(
    dump_line(b"AZ\x81\x82\x83\xff"[:].to_array(), grouped, 0L),
    b"00000000: 415A81 8283FF  .!abc.\n",
  )
}

///|
test "xxd ordered mode selection and autoskip toggles" {
  assert_true(options(parse_args(["-b", "-e"])).style is Little)
  assert_true(options(parse_args(["-e", "-b"])).style is Bits)
  assert_true(options(parse_args(["-b", "-ps"])).style is Plain)
  assert_true(options(parse_args(["-p", "-b"])).style is Bits)
  assert_true(!options(parse_args(["-a", "-a"])).autoskip)
  assert_true(options(parse_args(["-a", "-a", "-a"])).autoskip)
  assert_eq(options(parse_args(["-g", ""])).group, 16)
  assert_eq(options(parse_args(["-g", "no"])).group, 16)
  assert_eq(options(parse_args(["-b", "-c0"])).cols, 6)
  assert_eq(options(parse_args(["-p", "-c0"])).cols, 0)
  let message = try {
    ignore(options(parse_args(["-e", "-g3"])))
    ""
  } catch {
    CliError(_, message) => message
    error => raise error
  }
  assert_eq(
    message, "xxd: number of octets per group must be a power of 2 with -e.",
  )
}

///|
test "xxd seek syntax uses wide offsets and display wrapping" {
  let forward = parse_seek("+0x10")
  assert_true(forward.relative && !forward.negative)
  assert_eq(forward.amount, 16L)
  let backwards = parse_seek("+-4")
  assert_true(backwards.relative && backwards.negative)
  assert_eq(backwards.amount, 4L)
  let opts = options(parse_args(["-o-2", "-c1"]))
  assert_eq(
    dump_line(b"A"[:].to_array(), opts, 0L),
    b"fffffffffffffffe: 41  A\n",
  )
  assert_eq(
    dump_line(b"A"[:].to_array(), options(parse_args(["-c1"])), 4294967296L),
    b"100000000: 41  A\n",
  )
}

///|
test "xxd reverse bits plain garbage and address adjustment" {
  assert_eq(decoded(b"00000000: 01000001 01000010  AB\n", Bits, 6), [
    (0L, b'A'),
    (1L, b'B'),
  ])
  assert_eq(decoded(b"41 42\n43", Plain, 30), [
    (0L, b'A'),
    (1L, b'B'),
    (2L, b'C'),
  ])
  assert_eq(decoded(b"41z 4", Plain, 30), [(0L, b'A')])
  assert_eq(decoded(b"00000002: 41\n", Normal, 16, base=4L), [(6L, b'A')])
  assert_eq(decoded(b"00000002: 41\n", Normal, 16, base=-2L), [(0L, b'A')])
}
