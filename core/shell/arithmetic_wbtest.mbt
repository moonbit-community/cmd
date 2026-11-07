///|
priv struct ShellTestOutput {
  bytes : Array[Byte]
}

///|
impl @io.Writer for ShellTestOutput with fn write_once(
  self,
  data,
  offset~,
  len~,
) {
  for index in offset..<(offset + len) {
    self.bytes.push(data[index])
  }
  len
}

///|
fn ShellTestOutput::text(self : ShellTestOutput) -> String raise {
  @utf8.decode(Bytes::from_array(self.bytes))
}

///|
async test "arithmetic assignments are right associative and update shell state" {
  let (status, output) = capture(
    "a=2; printf '%s|%s|%s\\n' $((a=b=7)) \"$a\" \"$b\"; printf '%s|%s\\n' $((a+=b=3)) \"$a\"",
  )
  assert_eq((status, output), (0, "7|7|7\n10|10\n"))
  assert_eq(capture("a=3; printf '%s|%s' $((a<<=\n2)) \"$a\""), (0, "12|12"))
}

///|
async test "assignment word expansion preserves effects and temporary prefix scope" {
  for
    (source, expected) in [
      ("a=1; b=$((a=5)); printf '%s|%s' \"$a\" \"$b\"", "5|5"),
      ("a=1; b=$((a=5)) true; printf '%s|%s' \"$a\" \"${b-unset}\"", "5|unset"),
      ("a=1; a=$((a=5)) true; printf '%s' \"$a\"", "5"),
      (
        "a=1; a=2 b=$((a+=1)) true; printf '%s|%s' \"$a\" \"${b-unset}\"", "1|unset",
      ),
      ("a=1; a=2 b=$((a+=1)); printf '%s|%s' \"$a\" \"$b\"", "3|3"),
      ("a=1; b=$((a=5)) printf '%s|' \"$a\"; printf '%s' \"$a\"", "1|5"),
    ] {
    assert_eq(capture(source), (0, expected))
  }
}

///|
test "arithmetic compound assignments retain every operator" {
  let context = Session::new(env={}).context
  context.env["a"] = "12"
  for
    (expression, expected) in [
      ("a-=2", 10L),
      ("a*=3", 30L),
      ("a/=4", 7L),
      ("a%=4", 3L),
      ("a<<=3", 24L),
      ("a>>=1", 12L),
      ("a|=3", 15L),
      ("a&=6", 6L),
      ("a^=5", 3L),
    ] {
    assert_eq(evaluate_arithmetic(expression, context), expected)
    assert_eq(context.env.get("a"), Some(expected.to_string()))
  }
}

///|
async test "arithmetic conditional and logical operators suppress inactive effects" {
  let (status, output) = capture(
    "a=3; printf '%s|%s|%s|%s|%s\\n' $((0 && (a=9))) $((1 || (a=8))) $((1 ? a : 1/0)) $((0 ? (a=7) : a*2)) \"$a\"",
  )
  assert_eq((status, output), (0, "0|1|3|6|3\n"))
}

///|
async test "project arithmetic increment extension distinguishes prefix and postfix" {
  let (status, output) = capture(
    "a=2; printf '%s|%s|%s|%s|%s|%s|%s|%s\\n' $((a++)) \"$a\" $((++a)) \"$a\" $((a--)) \"$a\" $((--a)) \"$a\"",
  )
  assert_eq((status, output), (0, "2|3|4|4|4|3|2|2\n"))
}

///|
test "arithmetic parses signed variable values and rejects non lvalues" {
  let context = Session::new(env={ "hex": "-0x10", "octal": "+010" }).context
  assert_eq(evaluate_arithmetic("hex + octal", context), -8L)
  assert_eq(evaluate_arithmetic("", context), 0L)
  for source in ["1=2", "(a)=2", "++1", "1++", "a+", "1?2", "0 && (1=2)"] {
    try evaluate_arithmetic(source, context) catch {
      ShellError(_) => ()
    } noraise {
      _ => fail("invalid arithmetic syntax must fail: " + source)
    }
  }
}

///|
test "arithmetic syntax errors retain earlier active assignment effects" {
  let context = Session::new(env={}).context
  for source in ["(a=7) +", "a=7,"] {
    context.env["a"] = "1"
    try evaluate_arithmetic(source, context) catch {
      ShellError(_) => ()
    } noraise {
      _ => fail("expected a syntax failure")
    }
    assert_eq(context.env.get("a"), Some("7"))
  }
  context.env["a"] = "1"
  try evaluate_arithmetic("0 && ((a=7) + )", context) catch {
    ShellError(_) => ()
  } noraise {
    _ => fail("inactive branches still require valid syntax")
  }
  assert_eq(context.env.get("a"), Some("1"))
}

///|
async test "arithmetic failure preserves earlier output and interactive recovery" {
  let output : ShellTestOutput = { bytes: [], }
  let errors : ShellTestOutput = { bytes: [], }
  let failed = Session::new(env={}, output~, error=errors)
  assert_eq(
    failed.feed("printf before; printf '%s' $((1/0)); printf wrong"),
    Exit(2),
  )
  assert_eq(output.text(), "before")
  assert_eq(errors.text(), "sh: arithmetic division by zero\n")
  errors.bytes.clear()
  let session = Session::new(env={}, interactive=true, output~, error=errors)
  assert_eq(session.feed("a=4; : $((a+=2))"), Completed(0))
  assert_eq(session.feed(": $((1/0))"), Completed(2))
  assert_eq(session.feed("test \"$a\" = 6"), Completed(0))
  assert_eq(errors.text(), "sh: arithmetic division by zero\n")
}
