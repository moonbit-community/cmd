///|
fn adaptive_patterns() -> Array[Bytes] {
  Array::makei(16, number => {
    Bytes::makei(32, index => {
      if index == 28 {
        (98 + number).to_byte()
      } else {
        b'a'
      }
    })
  })
}

///|
async test "adaptive fixed counts preserve folding inversion and partial LF or NUL records" {
  let patterns = adaptive_patterns()
  for delimiter in [b'\n', b'\x00'] {
    for invert in [false, true] {
      for ignore_case in [false, true] {
        let ending = Bytes::from_array([delimiter])
        let miss = Bytes::make(8192, b'a')
        let data = miss +
          ending +
          miss +
          patterns[0] +
          ending +
          b"ZZZ" +
          ending +
          patterns[1]
        let input = @io.MemoryReader(writer => writer.write(data))
        defer input.close()
        let output : CapturedOutput = { bytes: [], }
        let errors : CapturedOutput = { bytes: [], }
        let options = {
          ..streaming_options(),
          count: true,
          invert,
          ignore_case,
          zero_terminated: delimiter == b'\x00',
          binary_mode: Text,
        }
        let sources = patterns.map(pattern => bytes_as_string(pattern))
        if ignore_case {
          for index in 0..<sources.length() {
            sources[index] = sources[index].to_upper()
          }
        }
        let matcher = compile_matcher(sources, options)
        assert_true(matcher is ManyFixed(_))
        assert_true(
          process_reader(
            input,
            "-",
            matcher,
            options,
            false,
            stdout=output,
            stderr=errors,
          ),
        )
        assert_eq(Bytes::from_array(output.bytes), b"2\n")
        assert_eq(errors.bytes.length(), 0)
      }
    }
  }
}

///|
async test "adaptive span output retains longest ties byte offsets and chunk boundaries" {
  let patterns = adaptive_patterns()
  patterns.push(patterns[0] + b"a")
  let options = {
    ..streaming_options(),
    only_matching: true,
    line_number: true,
    byte_offset: true,
    binary_mode: Text,
  }
  let matcher = compile_matcher(
    patterns.map(pattern => bytes_as_string(pattern)),
    options,
  )
  let input = @io.MemoryReader(writer => {
    writer.write(Bytes::make(65530, b'a') + patterns[0][0:6].to_owned())
    @async.sleep(1)
    writer.write(patterns[0][6:].to_owned() + b"a\n" + patterns[1])
  })
  defer input.close()
  let output : CapturedOutput = { bytes: [], }
  let errors : CapturedOutput = { bytes: [], }
  assert_true(
    process_reader(
      input,
      "-",
      matcher,
      options,
      false,
      stdout=output,
      stderr=errors,
    ),
  )
  assert_eq(
    Bytes::from_array(output.bytes),
    b"1:65530:" + patterns[0] + b"a\n2:65564:" + patterns[1] + b"\n",
  )
  assert_eq(errors.bytes.length(), 0)
}

///|
async test "adaptive sets containing delimiters cannot count cross-record matches" {
  let patterns = adaptive_patterns()
  for delimiter in [b'\n', b'\x00'] {
    let ending = Bytes::from_array([delimiter])
    let set = @bytere.LiteralSet::new([..patterns, b"x" + ending + b"y"]).unwrap()
    let input = @io.MemoryReader(writer => {
      writer.write(
        Bytes::make(8192, b'a') +
        ending +
        b"x" +
        ending +
        b"y" +
        ending +
        patterns[0],
      )
    })
    defer input.close()
    let output : CapturedOutput = { bytes: [], }
    let errors : CapturedOutput = { bytes: [], }
    let options = {
      ..streaming_options(),
      count: true,
      binary_mode: Text,
      zero_terminated: delimiter == b'\x00',
    }
    assert_true(
      process_reader(
        input,
        "-",
        ManyFixed(set),
        options,
        false,
        stdout=output,
        stderr=errors,
      ),
    )
    assert_eq(Bytes::from_array(output.bytes), b"1\n")
  }
}
