///|
test "normal edits retain byte records and missing line terminators" {
  assert_eq(
    normal(edits(lines(b"a"), lines(b"a\n"))),
    b"1c1\n< a\n\\ No newline at end of file\n---\n> a\n",
  )
  assert_eq(normal(edits(lines(b""), lines(b"a\n"))), b"0a1\n> a\n")
  assert_eq(normal(edits(lines(b"a\n"), lines(b""))), b"1d0\n< a\n")
}

///|
test "record views and comparison classes preserve arbitrary bytes" {
  let data = b"\xff\x00A\r\n\x80b"
  let records = lines(data)
  assert_eq(records.length(), 2)
  assert_eq(records[0].value, data[:4])
  assert_eq(records[0].value.start_offset(), 0)
  assert_eq(records[1].value.start_offset(), 5)
  assert_eq(records[1].value.data(), data)
  assert_eq(
    comparison_key(records[1], compare_options()).value.start_offset(),
    5,
  )
  assert_true(records[0].terminated)
  assert_true(!records[1].terminated)
  let options = compare_options(ignore_case=true, strip_trailing_cr=true)
  assert_eq(comparison_key(records[0], options), Line::{
    value: b"\xff\x00a"[:],
    terminated: true,
  })
  assert_eq(
    normal(edits(lines(b"\xff\x00a\n"), lines(b"\x80\x00b"))),
    b"1c1\n< \xff\x00a\n---\n> \x80\x00b\n\\ No newline at end of file\n",
  )
  assert_eq(
    normal(
      edits(
        lines(b"\xff A\r\nnext\n"),
        lines(b"\xffa\nnew\n"),
        options=compare_options(ignore_case=true, ignore_all_space=true),
      ),
    ),
    b"2c2\n< next\n---\n> new\n",
  )
}

///|
test "comparison class hashes follow view bytes and normalized terminators" {
  let classes : Map[Line, Int32] = Map([])
  classes[lines(b"prefix\na\n")[1]] = 7
  assert_eq(classes.get(lines(b"a\n")[0]), Some(7))
  assert_eq(classes.get(lines(b"a")[0]), None)
  assert_eq(
    classes.get(
      comparison_key(
        lines(b"A\r\n")[0],
        compare_options(ignore_case=true, strip_trailing_cr=true),
      ),
    ),
    Some(7),
  )
  assert_eq(
    classes.get(
      comparison_key(
        lines(b"a \t")[0],
        compare_options(ignore_trailing_space=true),
      ),
    ),
    Some(7),
  )
}

///|
test "edit scripts reconstruct both sides with minimum edit count" {
  for mask in 0..<256 {
    let a = Array::makei(4, i => Line::{
      value: if (mask & (1 << i)) == 0 {
        b"a"[:]
      } else {
        b"b"[:]
      },
      terminated: true,
    })
    let b = Array::makei(4, i => Line::{
      value: if (mask & (1 << (i + 4))) == 0 {
        b"a"[:]
      } else {
        b"b"[:]
      },
      terminated: true,
    })
    let changes = edits(a, b)
    let left : Array[Line] = []
    let right : Array[Line] = []
    let mut cost = 0
    for change in changes {
      match change {
        Equal(line) => {
          left.push(line)
          right.push(line)
        }
        Remove(line) => {
          left.push(line)
          cost += 1
        }
        Add(line) => {
          right.push(line)
          cost += 1
        }
      }
    }
    assert_eq(left, a)
    assert_eq(right, b)
    let dp = Array::makei(5, _ => Array::make(5, 0))
    for i in 0..<5 {
      dp[i][0] = i
      dp[0][i] = i
    }
    for i in 1..<5 {
      for j in 1..<5 {
        dp[i][j] = if a[i - 1] == b[j - 1] {
          dp[i - 1][j - 1]
        } else {
          1 + Int32::min(dp[i - 1][j], dp[i][j - 1])
        }
      }
    }
    assert_eq(cost, dp[4][4])
  }
}

///|
test "comparison keys preserve the selected C whitespace and case rules" {
  let all = compare_options(
    ignore_case=true,
    ignore_all_space=true,
    strip_trailing_cr=true,
  )
  assert_eq(comparison_key(lines(b"A B \r\n")[0], all), lines(b"ab\n")[0])
  let changes = compare_options(ignore_space_change=true)
  assert_eq(
    comparison_key(lines(b" a \tb  \n")[0], changes),
    lines(b" a b\n")[0],
  )
  assert_true(
    comparison_key(lines(b"ab\n")[0], changes) !=
    comparison_key(lines(b"a b\n")[0], changes),
  )
  let trailing = compare_options(ignore_trailing_space=true)
  assert_eq(comparison_key(lines(b"a \t")[0], trailing), lines(b"a\n")[0])
  assert_eq(comparison_key(lines(b"a\n")[0], trailing), lines(b"a\n")[0])
  assert_true(
    comparison_key(lines(b"A\n")[0], compare_options(ignore_case=true)) !=
    comparison_key(lines(b"a")[0], compare_options(ignore_case=true)),
  )
}

///|
test "blank suppression applies to changes without deleting source records" {
  let options = compare_options(ignore_blank_lines=true)
  assert_eq(
    normal(edits(lines(b"a\nb\n"), lines(b"a\n\nb\n"), options~), options~),
    b"",
  )
  assert_eq(
    normal(
      edits(lines(b"a\nold\n\nb\n"), lines(b"a\nnew\nb\n"), options~),
      options~,
    ),
    b"2,3c2\n< old\n< \n---\n> new\n",
  )
  let spaces = compare_options(
    ignore_blank_lines=true,
    ignore_space_change=true,
  )
  assert_eq(
    normal(
      edits(lines(b"a\n \t\nb\n"), lines(b"a\nb\n"), options=spaces),
      options=spaces,
    ),
    b"",
  )
}

///|
test "trailing CR input stripping includes displayed lines but not unterminated CR" {
  let options = compare_options(strip_trailing_cr=true)
  assert_eq(
    normal(
      edits(lines(b"a\r\nold\r\n"), lines(b"a\nnew\n"), options~),
      options~,
    ),
    b"2c2\n< old\n---\n> new\n",
  )
  assert_true(
    comparison_key(lines(b"a\r")[0], options) !=
    comparison_key(lines(b"a")[0], options),
  )
  assert_eq(comparison_key(lines(b"a\r\r\n")[0], options), lines(b"a\r\n")[0])
  assert_eq(
    normal(
      edits(lines(b"a\r\nb\r\na\r\na\r\n"), lines(b"b\na\na\na\n"), options~),
      options~,
    ),
    b"1d0\n< a\n2a2\n> a\n",
  )
}

///|
test "repeated records choose GNU-compatible aligned change groups" {
  assert_eq(
    unified(
      edits(lines(b"x\na\na\na\ny\n"), lines(b"x\na\na\ny\n")),
      3,
      "a",
      "b",
    ),
    b"--- a\n+++ b\n@@ -1,5 +1,4 @@\n x\n a\n a\n-a\n y\n",
  )
  assert_eq(
    unified(
      edits(lines(b"a\nb\na\nb\nc\n"), lines(b"b\na\nb\na\nc\n")),
      3,
      "a",
      "b",
    ),
    b"--- a\n+++ b\n@@ -1,5 +1,5 @@\n-a\n b\n a\n b\n+a\n c\n",
  )
  assert_eq(
    normal(edits(lines(b"a\n\na\n\n"), lines(b"a\n\n\na\n"))),
    b"3d2\n< a\n4a4\n> a\n",
  )
}

///|
test "large unmatched bodies and common edges need no edit trace" {
  let left = Array::makei(4096, i => Line::{
    value: @bytere.bytes("left-\{i}")[:],
    terminated: true,
  })
  let right = Array::makei(4096, i => Line::{
    value: @bytere.bytes("right-\{i}")[:],
    terminated: true,
  })
  let changes = edits(left, right)
  assert_eq(changes.length(), 8192)
  assert_true(changes[0] is Remove(_))
  assert_true(changes[8191] is Add(_))
  let prefix = "same\n".repeat(10000)
  let result = edits(
    lines(@bytere.bytes(prefix + "old\nend\n")),
    lines(@bytere.bytes(prefix + "new\nend\n")),
  )
  assert_eq(normal(result), b"10001c10001\n< old\n---\n> new\n")
}

///|
test "output context bounds equivalent changes at identical file edges" {
  let left = lines(b"a\nb\na\na\n")
  let right = lines(b"b\na\na\na\n")
  assert_eq(normal(edits(left, right)), b"1d0\n< a\n2a2\n> a\n")
  assert_eq(normal(edits(left, right, context=3)), b"1d0\n< a\n4a4\n> a\n")
  assert_eq(
    normal(edits(lines(b"b\na\na\na\n"), lines(b"a\na\na\na\n"))),
    b"1c1\n< b\n---\n> a\n",
  )
  assert_eq(
    normal(edits(lines(b"a\na\na\na\n"), lines(b"b\na\na\na\n"))),
    b"1c1\n< a\n---\n> b\n",
  )
}

///|
test "directory headers quote operands and retain original option spelling" {
  assert_eq(
    command_prefix([
      "-rN", "--label", "old file", "--label=new", "left", "right",
    ]),
    "diff -rN --label 'old file' --label=new",
  )
  assert_eq(quoted("a'b"), "'a'\\''b'")
  assert_eq(directory_operand("left space/a file"), "\"left space/a file\"")
  assert_eq(directory_operand("a\tb"), "\"a\\tb\"")
  assert_eq(directory_operand("caf\u00e9"), "\"caf\\303\\251\"")
  assert_eq(path_parts("left/name"), ("left", "name"))
}

///|
test "diagnostic paths use GNU C shell escaping" {
  assert_eq(diagnostic_path("plain/name"), "plain/name")
  assert_eq(diagnostic_path("missing left"), "'missing left'")
  assert_eq(diagnostic_path("missing'quote"), "\"missing'quote\"")
  assert_eq(
    diagnostic_path("missing'quote=complex"),
    "'missing'\\''quote=complex'",
  )
  assert_eq(diagnostic_path("tab\there"), "'tab'$'\\t''here'")
  assert_eq(diagnostic_path("line\nhere"), "'line'$'\\n''here'")
  assert_eq(diagnostic_path("é"), "''$'\\303\\251'")
  assert_eq(diagnostic_path("#missing"), "'#missing'")
  assert_eq(directory_operand("has space"), "\"has space\"")
}
