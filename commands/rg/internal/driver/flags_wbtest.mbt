///|
test "flags/test_after_context" {
  let mkctx = (lines : Int32) => ContextMode::default().set_after(lines)

  let args = low([])
  assert_eq(args.context, ContextMode::default())

  let args = low(["--after-context", "5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["--after-context=5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-A", "5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-A5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-A5", "-A10"])
  assert_eq(args.context, mkctx(10))

  let args = low(["-A5", "-A0"])
  assert_eq(args.context, mkctx(0))

  let args = low(["-A5", "--passthru"])
  assert_eq(args.context, ContextMode::Passthru)

  let args = low(["--passthru", "-A5"])
  assert_eq(args.context, mkctx(5))

  let n = "18446744073709551615"
  let args = low(["--after-context", n])
  assert_eq(args.context, mkctx(0x7FFFFFFF))
  let n = "18446744073709551616"
  let result = try_parse(["--after-context", n])
  assert_true(result is Err(_))
}

///|
test "flags/test_auto_hybrid_regex" {
  let args = low([])
  assert_eq(args.engine, EngineChoice::Default)

  let args = low(["--auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Auto)

  let args = low(["--auto-hybrid-regex", "--no-auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Default)

  let args = low(["--no-auto-hybrid-regex", "--auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Auto)

  let args = low(["--auto-hybrid-regex", "-P"])
  assert_eq(args.engine, EngineChoice::PCRE2)

  let args = low(["-P", "--auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Auto)

  let args = low(["--engine=auto", "--auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Auto)

  let args = low(["--engine=default", "--auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Auto)

  let args = low(["--auto-hybrid-regex", "--engine=default"])
  assert_eq(args.engine, EngineChoice::Default)
}

///|
test "flags/test_before_context" {
  let mkctx = (lines : Int32) => ContextMode::default().set_before(lines)

  let args = low([])
  assert_eq(args.context, ContextMode::default())

  let args = low(["--before-context", "5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["--before-context=5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-B", "5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-B5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-B5", "-B10"])
  assert_eq(args.context, mkctx(10))

  let args = low(["-B5", "-B0"])
  assert_eq(args.context, mkctx(0))

  let args = low(["-B5", "--passthru"])
  assert_eq(args.context, ContextMode::Passthru)

  let args = low(["--passthru", "-B5"])
  assert_eq(args.context, mkctx(5))

  let n = "18446744073709551615"
  let args = low(["--before-context", n])
  assert_eq(args.context, mkctx(0x7FFFFFFF))
  let n = "18446744073709551616"
  let result = try_parse(["--before-context", n])
  assert_true(result is Err(_))
}

///|
test "flags/test_binary" {
  let args = low([])
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["--binary"])
  assert_eq(args.binary, BinaryMode::SearchAndSuppress)

  let args = low(["--binary", "--no-binary"])
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["--no-binary", "--binary"])
  assert_eq(args.binary, BinaryMode::SearchAndSuppress)

  let args = low(["--binary", "-a"])
  assert_eq(args.binary, BinaryMode::AsText)

  let args = low(["-a", "--binary"])
  assert_eq(args.binary, BinaryMode::SearchAndSuppress)

  let args = low(["-a", "--no-binary"])
  assert_eq(args.binary, BinaryMode::Auto)
}

///|
test "flags/test_block_buffered" {
  let args = low([])
  assert_eq(args.buffer, BufferMode::Auto)

  let args = low(["--block-buffered"])
  assert_eq(args.buffer, BufferMode::Block)

  let args = low(["--block-buffered", "--no-block-buffered"])
  assert_eq(args.buffer, BufferMode::Auto)

  let args = low(["--block-buffered", "--line-buffered"])
  assert_eq(args.buffer, BufferMode::Line)
}

///|
test "flags/test_byte_offset" {
  let args = low([])
  assert_eq(args.byte_offset, false)

  let args = low(["--byte-offset"])
  assert_eq(args.byte_offset, true)

  let args = low(["-b"])
  assert_eq(args.byte_offset, true)

  let args = low(["--byte-offset", "--no-byte-offset"])
  assert_eq(args.byte_offset, false)

  let args = low(["--no-byte-offset", "-b"])
  assert_eq(args.byte_offset, true)
}

///|
test "flags/test_case_sensitive" {
  let args = low([])
  assert_eq(args.case, CaseMode::Sensitive)

  let args = low(["--case-sensitive"])
  assert_eq(args.case, CaseMode::Sensitive)

  let args = low(["-s"])
  assert_eq(args.case, CaseMode::Sensitive)
}

///|
test "flags/test_color" {
  let args = low([])
  assert_eq(args.color, ColorChoice::Auto)

  let args = low(["--color", "never"])
  assert_eq(args.color, ColorChoice::Never)

  let args = low(["--color", "auto"])
  assert_eq(args.color, ColorChoice::Auto)

  let args = low(["--color", "always"])
  assert_eq(args.color, ColorChoice::Always)

  let args = low(["--color", "ansi"])
  assert_eq(args.color, ColorChoice::Ansi)

  let args = low(["--color=never"])
  assert_eq(args.color, ColorChoice::Never)

  let args = low(["--color", "always", "--color", "never"])
  assert_eq(args.color, ColorChoice::Never)

  let args = low(["--color", "never", "--color", "always"])
  assert_eq(args.color, ColorChoice::Always)

  let result = try_parse(["--color", "foofoo"])
  assert_true(result is Err(_))

  let result = try_parse(["--color", "Always"])
  assert_true(result is Err(_))
}

///|
test "flags/test_colors" {
  let args = low([])
  assert_true(args.colors.is_empty())

  let args = low(["--colors", "match:fg:magenta"])
  assert_eq(args.colors, ["match:fg:magenta"])

  let args = low(["--colors", "match:fg:magenta", "--colors", "line:bg:yellow"])
  assert_eq(args.colors, ["match:fg:magenta", "line:bg:yellow"])

  let args = low(["--colors", "highlight:bg:240"])
  assert_eq(args.colors, ["highlight:bg:240"])

  let args = low([
    "--colors", "match:fg:magenta", "--colors", "highlight:bg:blue",
  ])
  assert_eq(args.colors, ["match:fg:magenta", "highlight:bg:blue"])
}

///|
test "flags/test_column" {
  let args = low([])
  assert_eq(args.column, None)

  let args = low(["--column"])
  assert_eq(args.column, Some(true))

  let args = low(["--column", "--no-column"])
  assert_eq(args.column, Some(false))

  let args = low(["--no-column", "--column"])
  assert_eq(args.column, Some(true))
}

///|
test "flags/test_context" {
  let mkctx = (lines : Int32) => ContextMode::default().set_both(lines)

  let args = low([])
  assert_eq(args.context, ContextMode::default())

  let args = low(["--context", "5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["--context=5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-C", "5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-C5"])
  assert_eq(args.context, mkctx(5))

  let args = low(["-C5", "-C10"])
  assert_eq(args.context, mkctx(10))

  let args = low(["-C5", "-C0"])
  assert_eq(args.context, mkctx(0))

  let args = low(["-C5", "--passthru"])
  assert_eq(args.context, ContextMode::Passthru)

  let args = low(["--passthru", "-C5"])
  assert_eq(args.context, mkctx(5))

  let n = "18446744073709551615"
  let args = low(["--context", n])
  assert_eq(args.context, mkctx(0x7FFFFFFF))
  {
    let n = "18446744073709551616"
    let result = try_parse(["--context", n])
    assert_true(result is Err(_))
  }

  // Test the interaction between -A/-B and -C. Basically, -A/-B always
  // partially overrides -C, regardless of where they appear relative to
  // each other. This behavior is also how GNU grep works, and it also makes
  // logical sense to me: -A/-B are the more specific flags.
  let args = low(["-A1", "-C5"])
  let mut mode = ContextMode::default()
  mode = mode.set_after(1)
  mode = mode.set_both(5)
  assert_eq(args.context, mode)
  assert_eq(args.context.get_limited(), (5, 1))

  let args = low(["-B1", "-C5"])
  let mut mode = ContextMode::default()
  mode = mode.set_before(1)
  mode = mode.set_both(5)
  assert_eq(args.context, mode)
  assert_eq(args.context.get_limited(), (1, 5))

  let args = low(["-A1", "-B2", "-C5"])
  let mut mode = ContextMode::default()
  mode = mode.set_before(2)
  mode = mode.set_after(1)
  mode = mode.set_both(5)
  assert_eq(args.context, mode)
  assert_eq(args.context.get_limited(), (2, 1))

  // These next three are like the ones above, but with -C before -A/-B. This
  // tests that -A and -B only partially override -C. That is, -C1 -A2 is
  // equivalent to -B1 -A2.
  let args = low(["-C5", "-A1"])
  let mut mode = ContextMode::default()
  mode = mode.set_after(1)
  mode = mode.set_both(5)
  assert_eq(args.context, mode)
  assert_eq(args.context.get_limited(), (5, 1))

  let args = low(["-C5", "-B1"])
  let mut mode = ContextMode::default()
  mode = mode.set_before(1)
  mode = mode.set_both(5)
  assert_eq(args.context, mode)
  assert_eq(args.context.get_limited(), (1, 5))

  let args = low(["-C5", "-A1", "-B2"])
  let mut mode = ContextMode::default()
  mode = mode.set_before(2)
  mode = mode.set_after(1)
  mode = mode.set_both(5)
  assert_eq(args.context, mode)
  assert_eq(args.context.get_limited(), (2, 1))
}

///|
test "flags/test_context_separator" {
  let getbytes = (x : Bytes?) => x

  let args = low([])
  assert_eq(Some(bs("--")), getbytes(args.context_separator))

  let args = low(["--context-separator", "XYZ"])
  assert_eq(Some(bs("XYZ")), getbytes(args.context_separator))

  let args = low(["--no-context-separator"])
  assert_eq(None, getbytes(args.context_separator))

  let args = low(["--context-separator", "XYZ", "--no-context-separator"])
  assert_eq(None, getbytes(args.context_separator))

  let args = low(["--no-context-separator", "--context-separator", "XYZ"])
  assert_eq(Some(bs("XYZ")), getbytes(args.context_separator))

  // This checks that invalid UTF-8 can be used. This case isn't too tricky
  // to handle, because it passes the invalid UTF-8 as an escape sequence
  // that is itself valid UTF-8. It doesn't become invalid UTF-8 until after
  // the argument is parsed and then unescaped.
  let args = low(["--context-separator", "\\xFF"])
  assert_eq(Some(b"\xFF"), getbytes(args.context_separator))

  // In this case, we specifically try to pass an invalid UTF-8 argument to
  // the flag. In theory we might be able to support this, but because we do
  // unescaping and because unescaping wants valid UTF-8, we do a UTF-8 check
  // on the value. Since we pass invalid UTF-8, it fails. This demonstrates
  // that the only way to use an invalid UTF-8 separator is by specifying an
  // escape sequence that is itself valid UTF-8.

}

///|
test "flags/test_count" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--count"])
  assert_eq(args.mode, Mode::Search(Count))

  let args = low(["-c"])
  assert_eq(args.mode, Mode::Search(Count))

  let args = low(["--count-matches", "--count"])
  assert_eq(args.mode, Mode::Search(Count))

  let args = low(["--count-matches", "-c"])
  assert_eq(args.mode, Mode::Search(Count))
}

///|
test "flags/test_count_matches" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--count-matches"])
  assert_eq(args.mode, Mode::Search(CountMatches))

  let args = low(["--count", "--count-matches"])
  assert_eq(args.mode, Mode::Search(CountMatches))

  let args = low(["-c", "--count-matches"])
  assert_eq(args.mode, Mode::Search(CountMatches))
}

///|
test "flags/test_crlf" {
  let args = low([])
  assert_eq(args.crlf, false)

  let args = low(["--crlf"])
  assert_eq(args.crlf, true)
  assert_eq(args.null_data, false)

  let args = low(["--crlf", "--null-data"])
  assert_eq(args.crlf, false)
  assert_eq(args.null_data, true)

  let args = low(["--null-data", "--crlf"])
  assert_eq(args.crlf, true)
  assert_eq(args.null_data, false)

  let args = low(["--null-data", "--no-crlf"])
  assert_eq(args.crlf, false)
  assert_eq(args.null_data, true)

  let args = low(["--null-data", "--crlf", "--no-crlf"])
  assert_eq(args.crlf, false)
  assert_eq(args.null_data, false)
}

///|
test "flags/test_debug" {
  let args = low([])
  assert_eq(args.logging, None)

  let args = low(["--debug"])
  assert_eq(args.logging, Some(LoggingMode::Debug))

  let args = low(["--trace", "--debug"])
  assert_eq(args.logging, Some(LoggingMode::Debug))
}

///|
test "flags/test_dfa_size_limit" {
  let args = low([])
  assert_eq(args.dfa_size_limit, None)
  {
    let args = low(["--dfa-size-limit", "9G"])
    assert_eq(args.dfa_size_limit, Some(9 * (1 << 30)))

    let args = low(["--dfa-size-limit=9G"])
    assert_eq(args.dfa_size_limit, Some(9 * (1 << 30)))

    let args = low(["--dfa-size-limit=9G", "--dfa-size-limit=0"])
    assert_eq(args.dfa_size_limit, Some(0))
  }

  let args = low(["--dfa-size-limit=0K"])
  assert_eq(args.dfa_size_limit, Some(0))

  let args = low(["--dfa-size-limit=0M"])
  assert_eq(args.dfa_size_limit, Some(0))

  let args = low(["--dfa-size-limit=0G"])
  assert_eq(args.dfa_size_limit, Some(0))

  let result = try_parse(["--dfa-size-limit", "9999999999999999999999"])
  assert_true(result is Err(_))

  let result = try_parse(["--dfa-size-limit", "9999999999999999G"])
  assert_true(result is Err(_))
}

///|
test "flags/test_encoding" {
  let args = low([])
  assert_eq(args.encoding, EncodingMode::Auto)

  let args = low(["--encoding", "auto"])
  assert_eq(args.encoding, EncodingMode::Auto)

  let args = low(["--encoding", "none"])
  assert_eq(args.encoding, EncodingMode::Disabled)

  let args = low(["--encoding=none"])
  assert_eq(args.encoding, EncodingMode::Disabled)

  let args = low(["-E", "none"])
  assert_eq(args.encoding, EncodingMode::Disabled)

  let args = low(["-Enone"])
  assert_eq(args.encoding, EncodingMode::Disabled)

  let args = low(["-E", "none", "--no-encoding"])
  assert_eq(args.encoding, EncodingMode::Auto)

  let args = low(["--no-encoding", "-E", "none"])
  assert_eq(args.encoding, EncodingMode::Disabled)

  let args = low(["-E", "utf-16"])
  let enc = @searcher.Encoding::new("utf-16")
  assert_eq(args.encoding, EncodingMode::Specific(enc))

  let args = low(["-E", "utf-16", "--no-encoding"])
  assert_eq(args.encoding, EncodingMode::Auto)

  let result = try_parse(["-E", "foo"])
  assert_true(result is Err(_))
}

///|
test "flags/test_engine" {
  let args = low([])
  assert_eq(args.engine, EngineChoice::Default)

  let args = low(["--engine", "pcre2"])
  assert_eq(args.engine, EngineChoice::PCRE2)

  let args = low(["--engine=pcre2"])
  assert_eq(args.engine, EngineChoice::PCRE2)

  let args = low(["--auto-hybrid-regex", "--engine=pcre2"])
  assert_eq(args.engine, EngineChoice::PCRE2)

  let args = low(["--engine=pcre2", "--auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Auto)

  let args = low(["--auto-hybrid-regex", "--engine=auto"])
  assert_eq(args.engine, EngineChoice::Auto)

  let args = low(["--auto-hybrid-regex", "--engine=default"])
  assert_eq(args.engine, EngineChoice::Default)

  let args = low(["--engine=pcre2", "--no-auto-hybrid-regex"])
  assert_eq(args.engine, EngineChoice::Default)
}

///|
test "flags/test_field_context_separator" {
  let args = low([])
  assert_eq(args.field_context_separator, bs("-"))

  let args = low(["--field-context-separator", "XYZ"])
  assert_eq(args.field_context_separator, bs("XYZ"))

  let args = low(["--field-context-separator=XYZ"])
  assert_eq(args.field_context_separator, bs("XYZ"))

  let args = low([
    "--field-context-separator", "XYZ", "--field-context-separator", "ABC",
  ])
  assert_eq(args.field_context_separator, bs("ABC"))

  let args = low(["--field-context-separator", "\\t"])
  assert_eq(args.field_context_separator, bs("\t"))

  let args = low(["--field-context-separator", "\\x00"])
  assert_eq(args.field_context_separator, bs("\u{0}"))

  // This checks that invalid UTF-8 can be used. This case isn't too tricky
  // to handle, because it passes the invalid UTF-8 as an escape sequence
  // that is itself valid UTF-8. It doesn't become invalid UTF-8 until after
  // the argument is parsed and then unescaped.
  let args = low(["--field-context-separator", "\\xFF"])
  assert_eq(args.field_context_separator, b"\xFF")

  // In this case, we specifically try to pass an invalid UTF-8 argument to
  // the flag. In theory we might be able to support this, but because we do
  // unescaping and because unescaping wants valid UTF-8, we do a UTF-8 check
  // on the value. Since we pass invalid UTF-8, it fails. This demonstrates
  // that the only way to use an invalid UTF-8 separator is by specifying an
  // escape sequence that is itself valid UTF-8.

}

///|
test "flags/test_field_match_separator" {
  let args = low([])
  assert_eq(args.field_match_separator, bs(":"))

  let args = low(["--field-match-separator", "XYZ"])
  assert_eq(args.field_match_separator, bs("XYZ"))

  let args = low(["--field-match-separator=XYZ"])
  assert_eq(args.field_match_separator, bs("XYZ"))

  let args = low([
    "--field-match-separator", "XYZ", "--field-match-separator", "ABC",
  ])
  assert_eq(args.field_match_separator, bs("ABC"))

  let args = low(["--field-match-separator", "\\t"])
  assert_eq(args.field_match_separator, bs("\t"))

  let args = low(["--field-match-separator", "\\x00"])
  assert_eq(args.field_match_separator, bs("\u{0}"))

  // This checks that invalid UTF-8 can be used. This case isn't too tricky
  // to handle, because it passes the invalid UTF-8 as an escape sequence
  // that is itself valid UTF-8. It doesn't become invalid UTF-8 until after
  // the argument is parsed and then unescaped.
  let args = low(["--field-match-separator", "\\xFF"])
  assert_eq(args.field_match_separator, b"\xFF")

  // In this case, we specifically try to pass an invalid UTF-8 argument to
  // the flag. In theory we might be able to support this, but because we do
  // unescaping and because unescaping wants valid UTF-8, we do a UTF-8 check
  // on the value. Since we pass invalid UTF-8, it fails. This demonstrates
  // that the only way to use an invalid UTF-8 separator is by specifying an
  // escape sequence that is itself valid UTF-8.

}

///|
test "flags/test_file" {
  let args = low([])
  assert_eq(args.patterns, [])

  let args = low(["--file", "foo"])
  assert_eq(args.patterns, [PatternSource::File("foo")])

  let args = low(["--file=foo"])
  assert_eq(args.patterns, [PatternSource::File("foo")])

  let args = low(["-f", "foo"])
  assert_eq(args.patterns, [PatternSource::File("foo")])

  let args = low(["-ffoo"])
  assert_eq(args.patterns, [PatternSource::File("foo")])

  let args = low(["--file", "-foo"])
  assert_eq(args.patterns, [PatternSource::File("-foo")])

  let args = low(["--file=-foo"])
  assert_eq(args.patterns, [PatternSource::File("-foo")])

  let args = low(["-f", "-foo"])
  assert_eq(args.patterns, [PatternSource::File("-foo")])

  let args = low(["-f-foo"])
  assert_eq(args.patterns, [PatternSource::File("-foo")])

  let args = low(["--file=foo", "--file", "bar"])
  assert_eq(args.patterns, [
    PatternSource::File("foo"),
    PatternSource::File("bar"),
  ])

  // We permit path arguments to be invalid UTF-8. So test that. Some of
  // these cases are tricky and depend on lexopt doing the right thing.
  //
  // We probably should add tests for this handling on Windows too, but paths
  // that are invalid UTF-16 appear incredibly rare in the Windows world.

}

///|
test "flags/test_files" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--files"])
  assert_eq(args.mode, Mode::Files)
}

///|
test "flags/test_files_with_matches" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--files-with-matches"])
  assert_eq(args.mode, Mode::Search(FilesWithMatches))

  let args = low(["-l"])
  assert_eq(args.mode, Mode::Search(FilesWithMatches))
}

///|
test "flags/test_files_without_match" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--files-without-match"])
  assert_eq(args.mode, Mode::Search(FilesWithoutMatch))

  let args = low(["--files-with-matches", "--files-without-match"])
  assert_eq(args.mode, Mode::Search(FilesWithoutMatch))

  let args = low(["--files-without-match", "--files-with-matches"])
  assert_eq(args.mode, Mode::Search(FilesWithMatches))
}

///|
test "flags/test_fixed_strings" {
  let args = low([])
  assert_eq(args.fixed_strings, false)

  let args = low(["--fixed-strings"])
  assert_eq(args.fixed_strings, true)

  let args = low(["-F"])
  assert_eq(args.fixed_strings, true)

  let args = low(["-F", "--no-fixed-strings"])
  assert_eq(args.fixed_strings, false)

  let args = low(["--no-fixed-strings", "-F"])
  assert_eq(args.fixed_strings, true)
}

///|
test "flags/test_follow" {
  let args = low([])
  assert_eq(args.follow, false)

  let args = low(["--follow"])
  assert_eq(args.follow, true)

  let args = low(["-L"])
  assert_eq(args.follow, true)

  let args = low(["-L", "--no-follow"])
  assert_eq(args.follow, false)

  let args = low(["--no-follow", "-L"])
  assert_eq(args.follow, true)
}

///|
test "flags/test_generate" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--generate", "man"])
  assert_eq(args.mode, Mode::Generate(Man))

  let args = low(["--generate", "complete-bash"])
  assert_eq(args.mode, Mode::Generate(CompleteBash))

  let args = low(["--generate", "complete-zsh"])
  assert_eq(args.mode, Mode::Generate(CompleteZsh))

  let args = low(["--generate", "complete-fish"])
  assert_eq(args.mode, Mode::Generate(CompleteFish))

  let args = low(["--generate", "complete-powershell"])
  assert_eq(args.mode, Mode::Generate(CompletePowerShell))

  let args = low(["--generate", "complete-bash", "--generate=man"])
  assert_eq(args.mode, Mode::Generate(Man))

  let args = low(["--generate", "man", "-l"])
  assert_eq(args.mode, Mode::Search(FilesWithMatches))

  // An interesting quirk of how the modes override each other that lets
  // you get back to the "default" mode of searching.
  let args = low(["--generate", "man", "--json", "--no-json"])
  assert_eq(args.mode, Mode::Search(Standard))
}

///|
test "flags/test_glob" {
  let args = low([])
  assert_eq(args.globs, [])

  let args = low(["--glob", "foo"])
  assert_eq(args.globs, ["foo"])

  let args = low(["--glob=foo"])
  assert_eq(args.globs, ["foo"])

  let args = low(["-g", "foo"])
  assert_eq(args.globs, ["foo"])

  let args = low(["-gfoo"])
  assert_eq(args.globs, ["foo"])

  let args = low(["--glob", "-foo"])
  assert_eq(args.globs, ["-foo"])

  let args = low(["--glob=-foo"])
  assert_eq(args.globs, ["-foo"])

  let args = low(["-g", "-foo"])
  assert_eq(args.globs, ["-foo"])

  let args = low(["-g-foo"])
  assert_eq(args.globs, ["-foo"])
}

///|
test "flags/test_glob_case_insensitive" {
  let args = low([])
  assert_eq(args.glob_case_insensitive, false)

  let args = low(["--glob-case-insensitive"])
  assert_eq(args.glob_case_insensitive, true)

  let args = low(["--glob-case-insensitive", "--no-glob-case-insensitive"])
  assert_eq(args.glob_case_insensitive, false)

  let args = low(["--no-glob-case-insensitive", "--glob-case-insensitive"])
  assert_eq(args.glob_case_insensitive, true)
}

///|
test "flags/test_heading" {
  let args = low([])
  assert_eq(args.heading, None)

  let args = low(["--heading"])
  assert_eq(args.heading, Some(true))

  let args = low(["--no-heading"])
  assert_eq(args.heading, Some(false))

  let args = low(["--heading", "--no-heading"])
  assert_eq(args.heading, Some(false))

  let args = low(["--no-heading", "--heading"])
  assert_eq(args.heading, Some(true))
}

///|
test "flags/test_help" {
  let args = low([])
  assert_eq(args.special, None)

  let args = low(["-h"])
  assert_eq(args.special, Some(SpecialMode::HelpShort))

  let args = low(["--help"])
  assert_eq(args.special, Some(SpecialMode::HelpLong))

  let args = low(["-h", "--help"])
  assert_eq(args.special, Some(SpecialMode::HelpLong))

  let args = low(["--help", "-h"])
  assert_eq(args.special, Some(SpecialMode::HelpShort))
}

///|
test "flags/test_hidden" {
  let args = low([])
  assert_eq(args.hidden, false)

  let args = low(["--hidden"])
  assert_eq(args.hidden, true)

  let args = low(["-."])
  assert_eq(args.hidden, true)

  let args = low(["-.", "--no-hidden"])
  assert_eq(args.hidden, false)

  let args = low(["--no-hidden", "-."])
  assert_eq(args.hidden, true)
}

///|
test "flags/test_hostname_bin" {
  let args = low([])
  assert_eq(args.hostname_bin, None)

  let args = low(["--hostname-bin", "foo"])
  assert_eq(args.hostname_bin, Some("foo"))

  let args = low(["--hostname-bin=foo"])
  assert_eq(args.hostname_bin, Some("foo"))
}

///|
test "flags/test_iglob" {
  let args = low([])
  assert_eq(args.iglobs, [])

  let args = low(["--iglob", "foo"])
  assert_eq(args.iglobs, ["foo"])

  let args = low(["--iglob=foo"])
  assert_eq(args.iglobs, ["foo"])

  let args = low(["--iglob", "-foo"])
  assert_eq(args.iglobs, ["-foo"])

  let args = low(["--iglob=-foo"])
  assert_eq(args.iglobs, ["-foo"])
}

///|
test "flags/test_ignore_case" {
  let args = low([])
  assert_eq(args.case, CaseMode::Sensitive)

  let args = low(["--ignore-case"])
  assert_eq(args.case, CaseMode::Insensitive)

  let args = low(["-i"])
  assert_eq(args.case, CaseMode::Insensitive)

  let args = low(["-i", "-s"])
  assert_eq(args.case, CaseMode::Sensitive)

  let args = low(["-s", "-i"])
  assert_eq(args.case, CaseMode::Insensitive)
}

///|
test "flags/test_ignore_file" {
  let args = low([])
  assert_eq(args.ignore_file, [])

  let args = low(["--ignore-file", "foo"])
  assert_eq(args.ignore_file, ["foo"])

  let args = low(["--ignore-file", "foo", "--ignore-file", "bar"])
  assert_eq(args.ignore_file, ["foo", "bar"])
}

///|
test "flags/test_ignore_file_case_insensitive" {
  let args = low([])
  assert_eq(args.ignore_file_case_insensitive, false)

  let args = low(["--ignore-file-case-insensitive"])
  assert_eq(args.ignore_file_case_insensitive, true)

  let args = low([
    "--ignore-file-case-insensitive", "--no-ignore-file-case-insensitive",
  ])
  assert_eq(args.ignore_file_case_insensitive, false)

  let args = low([
    "--no-ignore-file-case-insensitive", "--ignore-file-case-insensitive",
  ])
  assert_eq(args.ignore_file_case_insensitive, true)
}

///|
test "flags/test_include_zero" {
  let args = low([])
  assert_eq(args.include_zero, false)

  let args = low(["--include-zero"])
  assert_eq(args.include_zero, true)

  let args = low(["--include-zero", "--no-include-zero"])
  assert_eq(args.include_zero, false)
}

///|
test "flags/test_index" {
  if !false {
    assert_true(try_parse(["-X"]) is Err(_))
    return
  }

  let args = low([])
  assert_eq(args.index, 0)
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["-X"])
  assert_eq(args.index, 1)
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--index"])
  assert_eq(args.index, 1)

  let args = low(["-XX"])
  assert_eq(args.index, 2)

  let args = low(["-X", "--index"])
  assert_eq(args.index, 2)

  let result = try_parse(["-XXX"])
  assert_true(result is Err(_))
}

///|
test "flags/test_index_crud" {
  if !false {
    assert_true(try_parse(["--x-crud"]) is Err(_))
    return
  }

  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--x-crud"])
  assert_eq(args.mode, Mode::Index(IndexMode::Crud))

  let args = low(["--files", "--x-crud", "foo"])
  assert_eq(args.mode, Mode::Index(IndexMode::Crud))
  assert_eq(args.positional, ["foo"])

  let args = low(["--x-crud", "--files"])
  assert_eq(args.mode, Mode::Files)
}

///|
test "flags/test_index_force" {
  if !false {
    assert_true(try_parse(["--x-force"]) is Err(_))
    return
  }

  let args = low([])
  assert_eq(args.index_force, false)

  let args = low(["--x-force"])
  assert_eq(args.index_force, true)
}

///|
test "flags/test_index_path" {
  if !false {
    assert_true(try_parse(["--x-path"]) is Err(_))
    return
  }

  let args = low([])
  assert_eq(args.index_path, None)

  let args = low(["--x-path", "foo"])
  assert_eq(args.index_path, Some("foo"))

  let args = low(["--x-path=foo", "--x-path", "bar"])
  assert_eq(args.index_path, Some("bar"))
}

///|
test "flags/test_invert_match" {
  let args = low([])
  assert_eq(args.invert_match, false)

  let args = low(["--invert-match"])
  assert_eq(args.invert_match, true)

  let args = low(["-v"])
  assert_eq(args.invert_match, true)

  let args = low(["-v", "--no-invert-match"])
  assert_eq(args.invert_match, false)
}

///|
test "flags/test_json" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--json"])
  assert_eq(args.mode, Mode::Search(JSON))

  let args = low(["--json", "--no-json"])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--json", "--files", "--no-json"])
  assert_eq(args.mode, Mode::Files)

  let args = low(["--json", "-l", "--no-json"])
  assert_eq(args.mode, Mode::Search(FilesWithMatches))
}

///|
test "flags/test_line_buffered" {
  let args = low([])
  assert_eq(args.buffer, BufferMode::Auto)

  let args = low(["--line-buffered"])
  assert_eq(args.buffer, BufferMode::Line)

  let args = low(["--line-buffered", "--no-line-buffered"])
  assert_eq(args.buffer, BufferMode::Auto)

  let args = low(["--line-buffered", "--block-buffered"])
  assert_eq(args.buffer, BufferMode::Block)
}

///|
test "flags/test_line_number" {
  let args = low([])
  assert_eq(args.line_number, None)

  let args = low(["--line-number"])
  assert_eq(args.line_number, Some(true))

  let args = low(["-n"])
  assert_eq(args.line_number, Some(true))

  let args = low(["-n", "--no-line-number"])
  assert_eq(args.line_number, Some(false))
}

///|
test "flags/test_no_line_number" {
  let args = low([])
  assert_eq(args.line_number, None)

  let args = low(["--no-line-number"])
  assert_eq(args.line_number, Some(false))

  let args = low(["-N"])
  assert_eq(args.line_number, Some(false))

  let args = low(["-N", "--line-number"])
  assert_eq(args.line_number, Some(true))
}

///|
test "flags/test_line_regexp" {
  let args = low([])
  assert_eq(args.boundary, None)

  let args = low(["--line-regexp"])
  assert_eq(args.boundary, Some(BoundaryMode::Line))

  let args = low(["-x"])
  assert_eq(args.boundary, Some(BoundaryMode::Line))
}

///|
test "flags/test_max_columns" {
  let args = low([])
  assert_eq(args.max_columns, None)

  let args = low(["--max-columns", "5"])
  assert_eq(args.max_columns, Some(5))

  let args = low(["-M", "5"])
  assert_eq(args.max_columns, Some(5))

  let args = low(["-M5"])
  assert_eq(args.max_columns, Some(5))

  let args = low(["--max-columns", "5", "-M0"])
  assert_eq(args.max_columns, None)
}

///|
test "flags/test_max_columns_preview" {
  let args = low([])
  assert_eq(args.max_columns_preview, false)

  let args = low(["--max-columns-preview"])
  assert_eq(args.max_columns_preview, true)

  let args = low(["--max-columns-preview", "--no-max-columns-preview"])
  assert_eq(args.max_columns_preview, false)
}

///|
test "flags/test_max_count" {
  let args = low([])
  assert_eq(args.max_count, None)

  let args = low(["--max-count", "5"])
  assert_eq(args.max_count, Some(5))

  let args = low(["-m", "5"])
  assert_eq(args.max_count, Some(5))

  let args = low(["-m", "5", "--max-count=10"])
  assert_eq(args.max_count, Some(10))
  let args = low(["-m0"])
  assert_eq(args.max_count, Some(0))
}

///|
test "flags/test_max_depth" {
  let args = low([])
  assert_eq(args.max_depth, None)

  let args = low(["--max-depth", "5"])
  assert_eq(args.max_depth, Some(5))

  let args = low(["-d", "5"])
  assert_eq(args.max_depth, Some(5))

  let args = low(["--max-depth", "5", "--max-depth=10"])
  assert_eq(args.max_depth, Some(10))

  let args = low(["--max-depth", "0"])
  assert_eq(args.max_depth, Some(0))

  let args = low(["--maxdepth", "5"])
  assert_eq(args.max_depth, Some(5))
}

///|
test "flags/test_max_filesize" {
  let args = low([])
  assert_eq(args.max_filesize, None)

  let args = low(["--max-filesize", "1024"])
  assert_eq(args.max_filesize, Some(1024))

  let args = low(["--max-filesize", "1K"])
  assert_eq(args.max_filesize, Some(1024))

  let args = low(["--max-filesize", "1K", "--max-filesize=1M"])
  assert_eq(args.max_filesize, Some(1024 * 1024))
}

///|
test "flags/test_mmap" {
  let args = low([])
  assert_eq(args.mmap, MmapMode::Auto)

  let args = low(["--mmap"])
  assert_eq(args.mmap, MmapMode::AlwaysTryMmap)

  let args = low(["--no-mmap"])
  assert_eq(args.mmap, MmapMode::Never)

  let args = low(["--mmap", "--no-mmap"])
  assert_eq(args.mmap, MmapMode::Never)

  let args = low(["--no-mmap", "--mmap"])
  assert_eq(args.mmap, MmapMode::AlwaysTryMmap)
}

///|
test "flags/test_multiline" {
  let args = low([])
  assert_eq(args.multiline, false)

  let args = low(["--multiline"])
  assert_eq(args.multiline, true)

  let args = low(["-U"])
  assert_eq(args.multiline, true)

  let args = low(["-U", "--no-multiline"])
  assert_eq(args.multiline, false)
}

///|
test "flags/test_multiline_dotall" {
  let args = low([])
  assert_eq(args.multiline_dotall, false)

  let args = low(["--multiline-dotall"])
  assert_eq(args.multiline_dotall, true)

  let args = low(["--multiline-dotall", "--no-multiline-dotall"])
  assert_eq(args.multiline_dotall, false)
}

///|
test "flags/test_no_config" {
  let args = low([])
  assert_eq(args.no_config, false)

  let args = low(["--no-config"])
  assert_eq(args.no_config, true)
}

///|
test "flags/test_no_ignore" {
  let args = low([])
  assert_eq(args.no_ignore_dot, false)
  assert_eq(args.no_ignore_exclude, false)
  assert_eq(args.no_ignore_global, false)
  assert_eq(args.no_ignore_parent, false)
  assert_eq(args.no_ignore_vcs, false)

  let args = low(["--no-ignore"])
  assert_eq(args.no_ignore_dot, true)
  assert_eq(args.no_ignore_exclude, true)
  assert_eq(args.no_ignore_global, true)
  assert_eq(args.no_ignore_parent, true)
  assert_eq(args.no_ignore_vcs, true)

  let args = low(["--no-ignore", "--ignore"])
  assert_eq(args.no_ignore_dot, false)
  assert_eq(args.no_ignore_exclude, false)
  assert_eq(args.no_ignore_global, false)
  assert_eq(args.no_ignore_parent, false)
  assert_eq(args.no_ignore_vcs, false)
}

///|
test "flags/test_no_ignore_dot" {
  let args = low([])
  assert_eq(args.no_ignore_dot, false)

  let args = low(["--no-ignore-dot"])
  assert_eq(args.no_ignore_dot, true)

  let args = low(["--no-ignore-dot", "--ignore-dot"])
  assert_eq(args.no_ignore_dot, false)
}

///|
test "flags/test_no_ignore_exclude" {
  let args = low([])
  assert_eq(args.no_ignore_exclude, false)

  let args = low(["--no-ignore-exclude"])
  assert_eq(args.no_ignore_exclude, true)

  let args = low(["--no-ignore-exclude", "--ignore-exclude"])
  assert_eq(args.no_ignore_exclude, false)
}

///|
test "flags/test_no_ignore_files" {
  let args = low([])
  assert_eq(args.no_ignore_files, false)

  let args = low(["--no-ignore-files"])
  assert_eq(args.no_ignore_files, true)

  let args = low(["--no-ignore-files", "--ignore-files"])
  assert_eq(args.no_ignore_files, false)
}

///|
test "flags/test_no_ignore_global" {
  let args = low([])
  assert_eq(args.no_ignore_global, false)

  let args = low(["--no-ignore-global"])
  assert_eq(args.no_ignore_global, true)

  let args = low(["--no-ignore-global", "--ignore-global"])
  assert_eq(args.no_ignore_global, false)
}

///|
test "flags/test_no_ignore_messages" {
  let args = low([])
  assert_eq(args.no_ignore_messages, false)

  let args = low(["--no-ignore-messages"])
  assert_eq(args.no_ignore_messages, true)

  let args = low(["--no-ignore-messages", "--ignore-messages"])
  assert_eq(args.no_ignore_messages, false)
}

///|
test "flags/test_no_ignore_parent" {
  let args = low([])
  assert_eq(args.no_ignore_parent, false)

  let args = low(["--no-ignore-parent"])
  assert_eq(args.no_ignore_parent, true)

  let args = low(["--no-ignore-parent", "--ignore-parent"])
  assert_eq(args.no_ignore_parent, false)
}

///|
test "flags/test_no_ignore_vcs" {
  let args = low([])
  assert_eq(args.no_ignore_vcs, false)

  let args = low(["--no-ignore-vcs"])
  assert_eq(args.no_ignore_vcs, true)

  let args = low(["--no-ignore-vcs", "--ignore-vcs"])
  assert_eq(args.no_ignore_vcs, false)
}

///|
test "flags/test_no_messages" {
  let args = low([])
  assert_eq(args.no_messages, false)

  let args = low(["--no-messages"])
  assert_eq(args.no_messages, true)

  let args = low(["--no-messages", "--messages"])
  assert_eq(args.no_messages, false)
}

///|
test "flags/test_no_pcre2_unicode" {
  let args = low([])
  assert_eq(args.no_unicode, false)

  let args = low(["--no-pcre2-unicode"])
  assert_eq(args.no_unicode, true)

  let args = low(["--no-pcre2-unicode", "--pcre2-unicode"])
  assert_eq(args.no_unicode, false)
}

///|
test "flags/test_no_require_git" {
  let args = low([])
  assert_eq(args.no_require_git, false)

  let args = low(["--no-require-git"])
  assert_eq(args.no_require_git, true)

  let args = low(["--no-require-git", "--require-git"])
  assert_eq(args.no_require_git, false)
}

///|
test "flags/test_no_unicode" {
  let args = low([])
  assert_eq(args.no_unicode, false)

  let args = low(["--no-unicode"])
  assert_eq(args.no_unicode, true)

  let args = low(["--no-unicode", "--unicode"])
  assert_eq(args.no_unicode, false)

  let args = low(["--no-unicode", "--pcre2-unicode"])
  assert_eq(args.no_unicode, false)

  let args = low(["--no-pcre2-unicode", "--unicode"])
  assert_eq(args.no_unicode, false)
}

///|
test "flags/test_null" {
  let args = low([])
  assert_eq(args.null, false)

  let args = low(["--null"])
  assert_eq(args.null, true)

  let args = low(["-0"])
  assert_eq(args.null, true)
}

///|
test "flags/test_null_data" {
  let args = low([])
  assert_eq(args.null_data, false)

  let args = low(["--null-data"])
  assert_eq(args.null_data, true)

  let args = low(["--null-data", "--crlf"])
  assert_eq(args.null_data, false)
  assert_eq(args.crlf, true)

  let args = low(["--crlf", "--null-data"])
  assert_eq(args.null_data, true)
  assert_eq(args.crlf, false)

  let args = low(["--null-data", "--no-crlf"])
  assert_eq(args.null_data, true)
  assert_eq(args.crlf, false)
}

///|
test "flags/test_one_file_system" {
  let args = low([])
  assert_eq(args.one_file_system, false)

  let args = low(["--one-file-system"])
  assert_eq(args.one_file_system, true)

  let args = low(["--one-file-system", "--no-one-file-system"])
  assert_eq(args.one_file_system, false)
}

///|
test "flags/test_only_matching" {
  let args = low([])
  assert_eq(args.only_matching, false)

  let args = low(["--only-matching"])
  assert_eq(args.only_matching, true)

  let args = low(["-o"])
  assert_eq(args.only_matching, true)
}

///|
test "flags/test_path_separator" {
  let args = low([])
  assert_eq(args.path_separator, None)

  let args = low(["--path-separator", "/"])
  assert_eq(args.path_separator, Some(b'/'))

  let args = low(["--path-separator", "\\"])
  assert_eq(args.path_separator, Some(b'\\'))

  let args = low(["--path-separator", "\\x00"])
  assert_eq(args.path_separator, Some(0))

  let args = low(["--path-separator", "\\0"])
  assert_eq(args.path_separator, Some(0))

  let args = low(["--path-separator", "\u{0}"])
  assert_eq(args.path_separator, Some(0))

  let args = low(["--path-separator", "\u{0}"])
  assert_eq(args.path_separator, Some(0))

  let args = low(["--path-separator", "\\x00", "--path-separator=/"])
  assert_eq(args.path_separator, Some(b'/'))

  let result = try_parse(["--path-separator", "foo"])
  assert_true(result is Err(_))

  let result = try_parse(["--path-separator", "\\\\x00"])
  assert_true(result is Err(_))
}

///|
test "flags/test_passthru" {
  let args = low([])
  assert_eq(args.context, ContextMode::default())

  let args = low(["--passthru"])
  assert_eq(args.context, ContextMode::Passthru)

  let args = low(["--passthrough"])
  assert_eq(args.context, ContextMode::Passthru)
}

///|
test "flags/test_pcre2" {
  let args = low([])
  assert_eq(args.engine, EngineChoice::Default)

  let args = low(["--pcre2"])
  assert_eq(args.engine, EngineChoice::PCRE2)

  let args = low(["-P"])
  assert_eq(args.engine, EngineChoice::PCRE2)

  let args = low(["-P", "--no-pcre2"])
  assert_eq(args.engine, EngineChoice::Default)

  let args = low(["--engine=auto", "-P", "--no-pcre2"])
  assert_eq(args.engine, EngineChoice::Default)

  let args = low(["-P", "--engine=auto"])
  assert_eq(args.engine, EngineChoice::Auto)
}

///|
test "flags/test_pcre2_version" {
  let args = low([])
  assert_eq(args.special, None)

  let args = low(["--pcre2-version"])
  assert_eq(args.special, Some(SpecialMode::VersionPCRE2))
}

///|
test "flags/test_pre" {
  let args = low([])
  assert_eq(args.pre, None)

  let args = low(["--pre", "foo/bar"])
  assert_eq(args.pre, Some("foo/bar"))

  let args = low(["--pre", ""])
  assert_eq(args.pre, None)

  let args = low(["--pre", "foo/bar", "--pre", ""])
  assert_eq(args.pre, None)

  let args = low(["--pre", "foo/bar", "--pre="])
  assert_eq(args.pre, None)

  let args = low(["--pre", "foo/bar", "--no-pre"])
  assert_eq(args.pre, None)
}

///|
test "flags/test_pre_glob" {
  let args = low([])
  assert_eq(args.pre_glob, [])

  let args = low(["--pre-glob", "*.pdf"])
  assert_eq(args.pre_glob, ["*.pdf"])

  let args = low(["--pre-glob", "*.pdf", "--pre-glob=foo"])
  assert_eq(args.pre_glob, ["*.pdf", "foo"])
}

///|
test "flags/test_pretty" {
  let args = low([])
  assert_eq(args.color, ColorChoice::Auto)
  assert_eq(args.heading, None)
  assert_eq(args.line_number, None)

  let args = low(["--pretty"])
  assert_eq(args.color, ColorChoice::Always)
  assert_eq(args.heading, Some(true))
  assert_eq(args.line_number, Some(true))

  let args = low(["-p"])
  assert_eq(args.color, ColorChoice::Always)
  assert_eq(args.heading, Some(true))
  assert_eq(args.line_number, Some(true))
}

///|
test "flags/test_quiet" {
  let args = low([])
  assert_eq(args.quiet, false)

  let args = low(["--quiet"])
  assert_eq(args.quiet, true)

  let args = low(["-q"])
  assert_eq(args.quiet, true)

  // flags like -l and --json cannot override -q, regardless of order
  let args = low(["-q", "--json"])
  assert_eq(args.quiet, true)

  let args = low(["-q", "--files-with-matches"])
  assert_eq(args.quiet, true)

  let args = low(["-q", "--files-without-match"])
  assert_eq(args.quiet, true)

  let args = low(["-q", "--count"])
  assert_eq(args.quiet, true)

  let args = low(["-q", "--count-matches"])
  assert_eq(args.quiet, true)
}

///|
test "flags/test_regex_size_limit" {
  let args = low([])
  assert_eq(args.regex_size_limit, None)
  {
    let args = low(["--regex-size-limit", "9G"])
    assert_eq(args.regex_size_limit, Some(9 * (1 << 30)))

    let args = low(["--regex-size-limit=9G"])
    assert_eq(args.regex_size_limit, Some(9 * (1 << 30)))

    let args = low(["--regex-size-limit=9G", "--regex-size-limit=0"])
    assert_eq(args.regex_size_limit, Some(0))
  }

  let args = low(["--regex-size-limit=0K"])
  assert_eq(args.regex_size_limit, Some(0))

  let args = low(["--regex-size-limit=0M"])
  assert_eq(args.regex_size_limit, Some(0))

  let args = low(["--regex-size-limit=0G"])
  assert_eq(args.regex_size_limit, Some(0))

  let result = try_parse(["--regex-size-limit", "9999999999999999999999"])
  assert_true(result is Err(_))

  let result = try_parse(["--regex-size-limit", "9999999999999999G"])
  assert_true(result is Err(_))
}

///|
test "flags/test_regexp" {
  let args = low([])
  assert_eq(args.patterns, [])

  let args = low(["--regexp", "foo"])
  assert_eq(args.patterns, [PatternSource::Regexp("foo")])

  let args = low(["--regexp=foo"])
  assert_eq(args.patterns, [PatternSource::Regexp("foo")])

  let args = low(["-e", "foo"])
  assert_eq(args.patterns, [PatternSource::Regexp("foo")])

  let args = low(["-efoo"])
  assert_eq(args.patterns, [PatternSource::Regexp("foo")])

  let args = low(["--regexp", "-foo"])
  assert_eq(args.patterns, [PatternSource::Regexp("-foo")])

  let args = low(["--regexp=-foo"])
  assert_eq(args.patterns, [PatternSource::Regexp("-foo")])

  let args = low(["-e", "-foo"])
  assert_eq(args.patterns, [PatternSource::Regexp("-foo")])

  let args = low(["-e-foo"])
  assert_eq(args.patterns, [PatternSource::Regexp("-foo")])

  let args = low(["--regexp=foo", "--regexp", "bar"])
  assert_eq(args.patterns, [
    PatternSource::Regexp("foo"),
    PatternSource::Regexp("bar"),
  ])

  // While we support invalid UTF-8 arguments in general, patterns must be
  // valid UTF-8.

  // Check that combining -e/--regexp and -f/--file works as expected.
  let args = low(["-efoo", "-fbar"])
  assert_eq(args.patterns, [
    PatternSource::Regexp("foo"),
    PatternSource::File("bar"),
  ])

  let args = low(["-efoo", "-fbar", "-equux"])
  assert_eq(args.patterns, [
    PatternSource::Regexp("foo"),
    PatternSource::File("bar"),
    PatternSource::Regexp("quux"),
  ])
}

///|
test "flags/test_replace" {
  let args = low([])
  assert_eq(args.replace, None)

  let args = low(["--replace", "foo"])
  assert_eq(args.replace, Some(bs("foo")))

  let args = low(["--replace", "-foo"])
  assert_eq(args.replace, Some(bs("-foo")))

  let args = low(["-r", "foo"])
  assert_eq(args.replace, Some(bs("foo")))

  let args = low(["-r", "foo", "-rbar"])
  assert_eq(args.replace, Some(bs("bar")))

  let args = low(["-r", "foo", "-r", ""])
  assert_eq(args.replace, Some(bs("")))
}

///|
test "flags/test_search_zip" {
  let args = low([])
  assert_eq(args.search_zip, false)

  let args = low(["--search-zip"])
  assert_eq(args.search_zip, true)

  let args = low(["-z"])
  assert_eq(args.search_zip, true)

  let args = low(["-z", "--no-search-zip"])
  assert_eq(args.search_zip, false)

  let args = low(["--pre=foo", "--no-search-zip"])
  assert_eq(args.pre, Some("foo"))
  assert_eq(args.search_zip, false)

  let args = low(["--pre=foo", "--search-zip"])
  assert_eq(args.pre, None)
  assert_eq(args.search_zip, true)

  let args = low(["--pre=foo", "-z", "--no-search-zip"])
  assert_eq(args.pre, None)
  assert_eq(args.search_zip, false)
}

///|
test "flags/test_smart_case" {
  let args = low([])
  assert_eq(args.case, CaseMode::Sensitive)

  let args = low(["--smart-case"])
  assert_eq(args.case, CaseMode::Smart)

  let args = low(["-S"])
  assert_eq(args.case, CaseMode::Smart)

  let args = low(["-S", "-s"])
  assert_eq(args.case, CaseMode::Sensitive)

  let args = low(["-S", "-i"])
  assert_eq(args.case, CaseMode::Insensitive)

  let args = low(["-s", "-S"])
  assert_eq(args.case, CaseMode::Smart)

  let args = low(["-i", "-S"])
  assert_eq(args.case, CaseMode::Smart)
}

///|
test "flags/test_sort_files" {
  let args = low([])
  assert_eq(args.sort, None)

  let args = low(["--sort-files"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: false, kind: SortModeKind::Path, }),
  )

  let args = low(["--sort-files", "--no-sort-files"])
  assert_eq(args.sort, None)

  let args = low(["--sort", "created", "--sort-files"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: false, kind: SortModeKind::Path, }),
  )

  let args = low(["--sort-files", "--sort", "created"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: false, kind: SortModeKind::Created, }),
  )

  let args = low(["--sortr", "created", "--sort-files"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: false, kind: SortModeKind::Path, }),
  )

  let args = low(["--sort-files", "--sortr", "created"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: true, kind: SortModeKind::Created, }),
  )

  let args = low(["--sort=path", "--no-sort-files"])
  assert_eq(args.sort, None)

  let args = low(["--sortr=path", "--no-sort-files"])
  assert_eq(args.sort, None)
}

///|
test "flags/test_sort" {
  let args = low([])
  assert_eq(args.sort, None)

  let args = low(["--sort", "path"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: false, kind: SortModeKind::Path, }),
  )

  let args = low(["--sort", "path", "--sort=created"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: false, kind: SortModeKind::Created, }),
  )

  let args = low(["--sort=none"])
  assert_eq(args.sort, None)

  let args = low(["--sort", "path", "--sort=none"])
  assert_eq(args.sort, None)
}

///|
test "flags/test_sortr" {
  let args = low([])
  assert_eq(args.sort, None)

  let args = low(["--sortr", "path"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: true, kind: SortModeKind::Path, }),
  )

  let args = low(["--sortr", "path", "--sortr=created"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: true, kind: SortModeKind::Created, }),
  )

  let args = low(["--sortr=none"])
  assert_eq(args.sort, None)

  let args = low(["--sortr", "path", "--sortr=none"])
  assert_eq(args.sort, None)

  let args = low(["--sort=path", "--sortr=path"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: true, kind: SortModeKind::Path, }),
  )

  let args = low(["--sortr=path", "--sort=path"])
  assert_eq(
    args.sort,
    Some(SortMode::{ reverse: false, kind: SortModeKind::Path, }),
  )
}

///|
test "flags/test_stats" {
  let args = low([])
  assert_eq(args.stats, false)

  let args = low(["--stats"])
  assert_eq(args.stats, true)

  let args = low(["--stats", "--no-stats"])
  assert_eq(args.stats, false)
}

///|
test "flags/test_stop_on_nonmatch" {
  let args = low([])
  assert_eq(args.stop_on_nonmatch, false)

  let args = low(["--stop-on-nonmatch"])
  assert_eq(args.stop_on_nonmatch, true)

  let args = low(["--stop-on-nonmatch", "-U"])
  assert_eq(args.multiline, true)
  assert_eq(args.stop_on_nonmatch, false)

  let args = low(["-U", "--stop-on-nonmatch"])
  assert_eq(args.multiline, false)
  assert_eq(args.stop_on_nonmatch, true)

  let args = low(["--stop-on-nonmatch", "--no-multiline"])
  assert_eq(args.multiline, false)
  assert_eq(args.stop_on_nonmatch, true)
}

///|
test "flags/test_text" {
  let args = low([])
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["--text"])
  assert_eq(args.binary, BinaryMode::AsText)

  let args = low(["-a"])
  assert_eq(args.binary, BinaryMode::AsText)

  let args = low(["-a", "--no-text"])
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["-a", "--binary"])
  assert_eq(args.binary, BinaryMode::SearchAndSuppress)

  let args = low(["--binary", "-a"])
  assert_eq(args.binary, BinaryMode::AsText)

  let args = low(["-a", "--no-binary"])
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["--binary", "--no-text"])
  assert_eq(args.binary, BinaryMode::Auto)
}

///|
test "flags/test_threads" {
  let args = low([])
  assert_eq(args.threads, None)

  let args = low(["--threads", "5"])
  assert_eq(args.threads, Some(5))

  let args = low(["-j", "5"])
  assert_eq(args.threads, Some(5))

  let args = low(["-j5"])
  assert_eq(args.threads, Some(5))

  let args = low(["-j5", "-j10"])
  assert_eq(args.threads, Some(10))

  let args = low(["-j5", "-j0"])
  assert_eq(args.threads, None)
}

///|
test "flags/test_trace" {
  let args = low([])
  assert_eq(args.logging, None)

  let args = low(["--trace"])
  assert_eq(args.logging, Some(LoggingMode::Trace))

  let args = low(["--debug", "--trace"])
  assert_eq(args.logging, Some(LoggingMode::Trace))
}

///|
test "flags/test_trim" {
  let args = low([])
  assert_eq(args.trim, false)

  let args = low(["--trim"])
  assert_eq(args.trim, true)

  let args = low(["--trim", "--no-trim"])
  assert_eq(args.trim, false)
}

///|
test "flags/test_type" {
  let select = (name : String) => TypeChange::Select(name)

  let args = low([])
  assert_eq(args.type_changes, [])

  let args = low(["--type", "rust"])
  assert_eq(args.type_changes, [select("rust")])

  let args = low(["-t", "rust"])
  assert_eq(args.type_changes, [select("rust")])

  let args = low(["-trust"])
  assert_eq(args.type_changes, [select("rust")])

  let args = low(["-trust", "-tpython"])
  assert_eq(args.type_changes, [select("rust"), select("python")])

  let args = low(["-tabcdefxyz"])
  assert_eq(args.type_changes, [select("abcdefxyz")])
}

///|
test "flags/test_type_add" {
  let args = low([])
  assert_eq(args.type_changes, [])

  let args = low(["--type-add", "foo"])
  assert_eq(args.type_changes, [TypeChange::Add("foo")])

  let args = low(["--type-add", "foo", "--type-add=bar"])
  assert_eq(args.type_changes, [TypeChange::Add("foo"), TypeChange::Add("bar")])
}

///|
test "flags/test_type_clear" {
  let args = low([])
  assert_eq(args.type_changes, [])

  let args = low(["--type-clear", "foo"])
  assert_eq(args.type_changes, [TypeChange::Clear("foo")])

  let args = low(["--type-clear", "foo", "--type-clear=bar"])
  assert_eq(args.type_changes, [
    TypeChange::Clear("foo"),
    TypeChange::Clear("bar"),
  ])
}

///|
test "flags/test_type_not" {
  let select = (name : String) => TypeChange::Select(name)
  let negate = (name : String) => TypeChange::Negate(name)

  let args = low([])
  assert_eq(args.type_changes, [])

  let args = low(["--type-not", "rust"])
  assert_eq(args.type_changes, [negate("rust")])

  let args = low(["-T", "rust"])
  assert_eq(args.type_changes, [negate("rust")])

  let args = low(["-Trust"])
  assert_eq(args.type_changes, [negate("rust")])

  let args = low(["-Trust", "-Tpython"])
  assert_eq(args.type_changes, [negate("rust"), negate("python")])

  let args = low(["-Tabcdefxyz"])
  assert_eq(args.type_changes, [negate("abcdefxyz")])

  let args = low(["-Trust", "-ttoml", "-Tjson"])
  assert_eq(args.type_changes, [negate("rust"), select("toml"), negate("json")])
}

///|
test "flags/test_type_list" {
  let args = low([])
  assert_eq(args.mode, Mode::Search(Standard))

  let args = low(["--type-list"])
  assert_eq(args.mode, Mode::Types)
}

///|
test "flags/test_unrestricted" {
  let args = low([])
  assert_eq(args.no_ignore_vcs, false)
  assert_eq(args.hidden, false)
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["--unrestricted"])
  assert_eq(args.no_ignore_vcs, true)
  assert_eq(args.hidden, false)
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["--unrestricted", "-u"])
  assert_eq(args.no_ignore_vcs, true)
  assert_eq(args.hidden, true)
  assert_eq(args.binary, BinaryMode::Auto)

  let args = low(["-uuu"])
  assert_eq(args.no_ignore_vcs, true)
  assert_eq(args.hidden, true)
  assert_eq(args.binary, BinaryMode::SearchAndSuppress)

  let result = try_parse(["-uuuu"])
  assert_true(result is Err(_))
}

///|
test "flags/test_version" {
  let args = low([])
  assert_eq(args.special, None)

  let args = low(["-V"])
  assert_eq(args.special, Some(SpecialMode::VersionShort))

  let args = low(["--version"])
  assert_eq(args.special, Some(SpecialMode::VersionLong))

  let args = low(["-V", "--version"])
  assert_eq(args.special, Some(SpecialMode::VersionLong))

  let args = low(["--version", "-V"])
  assert_eq(args.special, Some(SpecialMode::VersionShort))
}

///|
test "flags/test_vimgrep" {
  let args = low([])
  assert_eq(args.vimgrep, false)

  let args = low(["--vimgrep"])
  assert_eq(args.vimgrep, true)
}

///|
test "flags/test_with_filename" {
  let args = low([])
  assert_eq(args.with_filename, None)

  let args = low(["--with-filename"])
  assert_eq(args.with_filename, Some(true))

  let args = low(["-H"])
  assert_eq(args.with_filename, Some(true))
}

///|
test "flags/test_with_filename_no" {
  let args = low([])
  assert_eq(args.with_filename, None)

  let args = low(["--no-filename"])
  assert_eq(args.with_filename, Some(false))

  let args = low(["-I"])
  assert_eq(args.with_filename, Some(false))

  let args = low(["-I", "-H"])
  assert_eq(args.with_filename, Some(true))

  let args = low(["-H", "-I"])
  assert_eq(args.with_filename, Some(false))
}

///|
test "flags/test_word_regexp" {
  let args = low([])
  assert_eq(args.boundary, None)

  let args = low(["--word-regexp"])
  assert_eq(args.boundary, Some(BoundaryMode::Word))

  let args = low(["-w"])
  assert_eq(args.boundary, Some(BoundaryMode::Word))

  let args = low(["-x", "-w"])
  assert_eq(args.boundary, Some(BoundaryMode::Word))

  let args = low(["-w", "-x"])
  assert_eq(args.boundary, Some(BoundaryMode::Line))
}

///|
test "hyperlink_format" {
  let fmt = (s : String) => @printer.HyperlinkFormat::parse(s).to_string()
  let args = parse_low_raw([])
  assert_eq(fmt("none"), fmt(args.hyperlink_format))
  let args = parse_low_raw(["--hyperlink-format", "default"])
  assert_eq(fmt("file://{host}{path}"), fmt(args.hyperlink_format))
  let args = parse_low_raw(["--hyperlink-format", "file"])
  assert_eq(fmt("file://{host}{path}"), fmt(args.hyperlink_format))
  let args = parse_low_raw([
    "--hyperlink-format", "file", "--hyperlink-format=grep+",
  ])
  assert_eq(fmt("grep+://{path}:{line}"), fmt(args.hyperlink_format))
  let args = parse_low_raw(["--hyperlink-format", "file://{host}{path}#{line}"])
  assert_eq(fmt("file://{host}{path}#{line}"), fmt(args.hyperlink_format))
  let failed = try {
    parse_low_raw(["--hyperlink-format", "file://heythere"]) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "number overflow is reported before later invalid digits" {
  // Like Rust's integer parsing, the first problem wins.
  let msg = try {
    parse_low_raw(["--max-count=184467440737095516160x"]) |> ignore
    ""
  } catch {
    RgError(m) => m
  }
  assert_true(msg.contains("number too large to fit in target type"))
}

///|
test "debug_os_string escapes like Rust" {
  assert_eq(debug_os_string("a\u{A0}b"), "\"a\\u{a0}b\"")
  assert_eq(debug_os_string("x\u{301}"), "\"x\\u{301}\"")
  assert_eq(debug_os_string("é日本😀"), "\"é日本😀\"")
  assert_eq(debug_os_string(@osstr.decode(b"a\xFF")), "\"a\\xFF\"")
  assert_eq(debug_os_string("\"\\\n"), "\"\\\"\\\\\\n\"")
}
