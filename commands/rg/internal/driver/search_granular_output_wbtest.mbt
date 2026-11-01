///|
async test "buffered granular records preserve extraction replacement limits and failures" {
  for
    input in [
      b"hit hit\n  hit\t hit\nlast hit",
      b"hit\r\nhit hit\r\n",
      b"\xef\xbb\xbfhit hit\nhit",
      b"hit\nhit\x00hit\n",
      b"hit " + Bytes::make(65537, b'x') + b" hit\nhit",
    ] {
    for
      (only_matching, per_match, replacement) in [
        (true, false, None),
        (false, true, None),
        (false, false, None),
        (true, false, Some(b"[$0]")),
        (false, true, Some(b"$0-$0")),
      ] {
      for
        term in [
          @matcher.LineTerminator::byte(b'\n'),
          @matcher.LineTerminator::crlf(),
          @matcher.LineTerminator::byte(b'\x00'),
        ] {
        for
          (budget, max_columns, line_buffered) in [
            (0, None, false),
            (1, None, false),
            (31, None, false),
            (8191, None, false),
            (1000000, None, false),
            (1000000, Some(8L), false),
            (1000000, None, true),
          ] {
          let reference = span_output(
            input,
            "hit",
            false,
            only_matching~,
            per_match~,
            replacement~,
            term~,
            budget~,
            max_columns~,
            line_buffered~,
            partial=3,
            line_numbers=true,
            byte_offsets=true,
            column=true,
            path=Some("nested/file"),
            path_terminator=Some(b'\x00'),
            trim_ascii=true,
          )
          let buffered = span_output(
            input,
            "hit",
            true,
            only_matching~,
            per_match~,
            replacement~,
            term~,
            budget~,
            max_columns~,
            line_buffered~,
            partial=3,
            line_numbers=true,
            byte_offsets=true,
            column=true,
            path=Some("nested/file"),
            path_terminator=Some(b'\x00'),
            trim_ascii=true,
          )
          assert_eq(buffered, reference)
        }
      }
    }
  }
  for pattern in ["", "h.t", "(h)(it)", "^", "$"] {
    for only_matching in [true, false] {
      for heading in [true, false] {
        assert_eq(
          span_output(
            b"hit hit\nno\nhit",
            pattern,
            true,
            only_matching~,
            heading~,
            column=true,
            line_numbers=true,
            path=Some("file"),
          ),
          span_output(
            b"hit hit\nno\nhit",
            pattern,
            false,
            only_matching~,
            heading~,
            column=true,
            line_numbers=true,
            path=Some("file"),
          ),
        )
      }
    }
  }
}
