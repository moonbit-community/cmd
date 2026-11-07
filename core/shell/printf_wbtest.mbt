///|
async test "printf retains Linux buffer allocation across preceding builtin output" {
  let field = String::make(8191, ' ') + "y"
  let warning = "sh: printf: bad: expected numeric value\n"
  assert_eq(capture("printf '%8192s%d' y bad 2>&1"), (1, field + warning + "0"))
  assert_eq(
    capture("printf x; printf '%8192s%d' y bad 2>&1"),
    (1, "x" + warning + field + "0"),
  )
  assert_eq(
    capture("echo x; printf '%8192s%d' y bad 2>&1"),
    (1, "x\n" + warning + field + "0"),
  )
  for prefix in ["printf '%s' ''", "printf '%.0s' x", "printf '%b' '\\c'"] {
    assert_eq(
      capture(prefix + "; printf '%8192s%d' y bad 2>&1"),
      (1, field + warning + "0"),
    )
  }
}

///|
async test "printf drains large output before later errors with a bounded Linux profile buffer" {
  let chunk = String::make(8193, 'x')
  let output : ShellTestOutput = { bytes: [], }
  let session = Session::new(env={}, output~, error=output)
  assert_eq(printf_builtin(["%s%d", chunk, "bad"], session.context), 1)
  assert_eq(output.text(), chunk + "sh: printf: bad: expected numeric value\n0")
  output.bytes.clear()
  let args = ["%s"]
  for _ in 0..<100 {
    args.push(String::make(1024, 'a'))
  }
  assert_eq(printf_builtin(args, session.context), 0)
  assert_eq(output.text(), String::make(102400, 'a'))
}

///|
async test "printf uses distinct format and percent b escape rules with raw bytes" {
  for
    (source, expected) in [
      ("printf '\\0102|\\377|\\cX'", b"\x082|\xff|\\cX"),
      ("printf '%bBAD' '\\0102\\377\\cwrong'", b"B\xff"),
      ("printf '[%5.2b]after' 'a\\000b\\cwrong'", b"[   a\x00"),
      ("printf '%c|%.1s|%5.2s' 'é' 'é' 'éa'", b"\xc3|\xc3|   \xc3\xa9"),
    ] {
    let output : ShellTestOutput = { bytes: [], }
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(env={}, output~, error=errors)
    assert_eq(session.feed(source), Completed(0))
    assert_eq(Bytes::from_array(output.bytes), expected)
    assert_eq(errors.text(), "")
  }
}

///|
async test "printf flags precision stars and binary64 floats match fixed examples" {
  for
    (source, expected) in [
      (
        "printf '%+#08x|%+08d|%#.0o|%.0d|% 6.4d' 42 -12 0 0 7", "0x00002a|-0000012|0||  0007",
      ),
      ("printf '%*.*s|%0*.*d' -5 2 abcd 6 3 7", "ab   |   007"),
      (
        "printf '%+.2f|%#.0f|%.2e|%.3g|%a|%A' 1.125 2 12.5 12345 3 0.5", "+1.12|2.|1.25e+01|1.23e+04|0x1.8p+1|0X1P-1",
      ),
      ("printf '%d|%d|%d|%d' '' \"'\" \"'é\" \"'AB\"", "0|0|195|65"),
    ] {
    assert_eq(capture(source), (0, expected))
  }
}

///|
async test "printf numeric errors preserve converted prefixes and nonzero status" {
  for
    (source, expected, diagnostic) in [
      (
        "printf 'before%dafter' ' '", "before0after", "sh: printf:  : expected numeric value\n",
      ),
      (
        "printf '%d|%x|%.1f' 12oops 0x1Z 2.5tail", "12|1|2.5", "sh: printf: 12oops: not completely converted\nsh: printf: 0x1Z: not completely converted\nsh: printf: 2.5tail: not completely converted\n",
      ),
      (
        "printf '%d|%u' 9223372036854775808 -18446744073709551616", "9223372036854775807|18446744073709551615",
        "sh: printf: 9223372036854775808: Numerical result out of range\nsh: printf: -18446744073709551616: Numerical result out of range\n",
      ),
    ] {
    let output : ShellTestOutput = { bytes: [], }
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(env={}, output~, error=errors)
    assert_eq(session.feed(source), Completed(1))
    assert_eq(output.text(), expected)
    assert_eq(errors.text(), diagnostic)
  }
}

///|
async test "printf merged diagnostics precede buffered output on conversion failures" {
  assert_eq(
    capture("printf 'before%dafter' ' ' 2>&1"),
    (1, "sh: printf:  : expected numeric value\nbefore0after"),
  )
  assert_eq(
    capture("printf 'X%d' 1 2bad 2>&1"),
    (1, "sh: printf: 2bad: not completely converted\nX1X2"),
  )
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(env={}, output~, error=errors)
  assert_eq(session.feed("printf 'prefix%s/%q' yes wrong"), Completed(2))
  assert_eq(output.text(), "prefixyes/")
  assert_eq(errors.text(), "sh: printf: unsupported conversion '%q'\n")
}

///|
priv struct PartialPrintfWriter {
  bytes : Array[Byte]
  mut calls : Int32
}

///|
impl @io.Writer for PartialPrintfWriter with fn write_once(
  self,
  data,
  offset~,
  len~,
) {
  self.calls += 1
  if len > 0 {
    self.bytes.push(data[offset])
  }
  raise ShellError("injected partial write failure")
}

///|
async test "printf never replays output after a writer raises a public shell error" {
  let output : PartialPrintfWriter = { bytes: [], calls: 0, }
  let errors : ShellTestOutput = { bytes: [], }
  let session = Session::new(env={}, output~, error=errors)
  try printf_builtin(["prefix%d", "bad"], session.context) catch {
    ShellError(message) => assert_eq(message, "injected partial write failure")
    err => raise err
  } noraise {
    _ => fail("injected write error was hidden")
  }
  assert_eq(output.calls, 1)
  assert_eq(Bytes::from_array(output.bytes), b"p")
  assert_eq(errors.text(), "sh: printf: bad: expected numeric value\n")
}

///|
async test "printf option termination distinguishes literal leading hyphens" {
  for value in ["--help", "-%s"] {
    let output : ShellTestOutput = { bytes: [], }
    let errors : ShellTestOutput = { bytes: [], }
    let session = Session::new(env={}, output~, error=errors)
    assert_eq(printf_builtin([value, "foo"], session.context), 2)
    assert_eq(output.text(), "")
    assert_eq(errors.text(), "sh: printf: unsupported option '\{value}'\n")
  }
  assert_eq(capture("printf -- '-%s' foo"), (0, "-foo"))
  assert_eq(capture("printf -"), (0, "-"))
}
