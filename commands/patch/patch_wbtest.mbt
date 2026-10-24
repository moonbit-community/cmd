///|
test "patch unified exact hunk applies to bytes for dry run or output stream" {
  let patch = b"--- a/file\n+++ b/file\n@@ -1,3 +1,3 @@\n one\n-two\n+TWO\n three\n"
  let files = parse_patch(patch)
  assert_eq(files.length(), 1)
  let output = apply_hunks(b"one\ntwo\nthree\n", files[0].hunks, false, 0).data
  assert_eq(output, b"one\nTWO\nthree\n")
}

///|
test "patch reverse and no final newline preserve records" {
  let patch = b"--- old\n+++ new\n@@ -1 +1 @@\n-old\n+new\n\\ No newline at end of file\n"
  let files = parse_patch(patch)
  assert_eq(apply_hunks(b"old\n", files[0].hunks, false, 0).data, b"new")
  assert_eq(apply_hunks(b"new", files[0].hunks, true, 0).data, b"old\n")
}

///|
test "patch context format converts to common hunk model" {
  let patch = b"*** old\n--- new\n***************\n*** 1,3 ****\n  one\n! two\n  three\n--- 1,3 ----\n  one\n! TWO\n  three\n"
  let files = parse_patch(patch)
  assert_eq(files.length(), 1)
  assert_eq(
    apply_hunks(b"one\ntwo\nthree\n", files[0].hunks, false, 0).data,
    b"one\nTWO\nthree\n",
  )
}

///|
test "patch rejects malformed metadata and unsafe paths" {
  try parse_patch(b"--- a\n+++ b\n@@ -1 +1 @@\n-old\n") catch {
    PatchError(message) => assert_true(message.contains("incomplete"))
    err => fail("unexpected parse error: \{err}")
  } noraise {
    _ => fail("expected malformed patch")
  }
  try stripped("../../escape", Some(0)) catch {
    PatchError(message) => assert_true(message.contains("unsafe"))
  } noraise {
    _ => fail("expected unsafe path")
  }
  assert_eq(stripped("a/b/file", Some(1)), "b/file")
  try
    parse_patch(
      b"old mode 100644\nnew mode 100755\n*** old\n--- new\n***************\n*** 1 ****\n! old\n--- 1 ----\n! new\n",
    )
  catch {
    PatchError(message) => assert_true(message.contains("mode"))
    err => fail("unexpected metadata parse error: \{err}")
  } noraise {
    _ => fail("expected unsupported mode metadata")
  }
}

///|
test "patch rejected hunk preserves unchanged input" {
  let patch = parse_patch(b"--- a\n+++ b\n@@ -1 +1 @@\n-old\n+new\n")
  let result = apply_hunks(b"other\n", patch[0].hunks, false, 2)
  assert_eq(result.data, b"other\n")
  assert_true(result.results is [Rejected(position=1, output_delta=0)])
}

///|
test "patch offset ties prefer later candidate and keep subsequent displacement" {
  let patch = parse_patch(
      b"--- a\n+++ b\n@@ -2 +2 @@\n-a\n+A\n@@ -4 +4 @@\n-b\n+B\n",
    )[0]
  let result = apply_hunks(b"a\nx\na\nx\nb\n", patch.hunks, false, 0)
  assert_eq(result.data, b"a\nx\nA\nx\nB\n")
  assert_true(
    result.results
    is [
      Applied(position=3, offset=1, fuzz=0),
      Applied(position=5, offset=1, fuzz=0),
    ],
  )
}

///|
test "patch fuzz preserves ignored context bytes and tries exact first" {
  let patch = parse_patch(
      b"--- a\n+++ b\n@@ -1,3 +1,3 @@\n before\n-old\n+new\n after\n",
    )[0]
  let result = apply_hunks(b"changed\nold\nafter\n", patch.hunks, false, 2)
  assert_eq(result.data, b"changed\nnew\nafter\n")
  assert_true(result.results is [Applied(position=1, offset=0, fuzz=1)])
  let exact = apply_hunks(
    b"changed\nold\nafter\nbefore\nold\nafter\n",
    patch.hunks,
    false,
    2,
  )
  assert_true(exact.results is [Applied(position=4, offset=3, fuzz=0)])
}

///|
test "patch unequal context anchors start and end until fuzz permits search" {
  let patch = parse_patch(
      b"--- a\n+++ b\n@@ -1,3 +1,3 @@\n-old\n+new\n a\n b\n",
    )[0]
  let input = b"prefix\nold\na\nb\n"
  assert_true(
    apply_hunks(input, patch.hunks, false, 1).results
    is [Rejected(position=1, output_delta=0)],
  )
  assert_true(
    apply_hunks(input, patch.hunks, false, 2).results
    is [Applied(position=2, offset=1, fuzz=2)],
  )
}

///|
test "patch mixed results keep later hunks and reject adjusted unified ranges" {
  let patch = parse_patch(
      b"--- a\tstamp\n+++ b\tstamp2\n@@ -1 +1,2 @@ first\n-one\n+ONE\n+extra\n@@ -3 +4 @@ later\n-absent\n+THREE\n@@ -5 +6 @@ last\n-five\n+FIVE\n",
    )[0]
  let result = apply_hunks(
    b"one\ntwo\nthree\nfour\nfive\n",
    patch.hunks,
    false,
    0,
  )
  assert_eq(result.data, b"ONE\nextra\ntwo\nthree\nfour\nFIVE\n")
  assert_true(
    result.results
    is [
      Applied(position=1, offset=0, fuzz=0),
      Rejected(position=4, output_delta=1),
      Applied(position=6, offset=0, fuzz=0),
    ],
  )
  assert_eq(
    reject_bytes(patch, result.results, false),
    b"--- a\tstamp\n+++ b\tstamp2\n@@ -4 +5 @@ later\n-absent\n+THREE\n",
  )
}

///|
test "patch context rejects retain replacement markers and reverse headers" {
  let patch = parse_patch(
      b"*** old\toldstamp\n--- new\tnewstamp\n*************** fn\n*** 1,3 ****\n  one\n! two\n  three\n--- 1,3 ----\n  one\n! TWO\n  three\n",
    )[0]
  let result = apply_hunks(b"other\n", patch.hunks, true, 0)
  assert_eq(
    reject_bytes(patch, result.results, true),
    b"*** new\tnewstamp\n--- old\toldstamp\n*************** fn\n*** 1,3 ****\n  one\n! TWO\n  three\n--- 1,3 ----\n  one\n! two\n  three\n",
  )
}

///|
test "patch rejects keep no-newline markers and insertion coordinates" {
  let patch = parse_patch(
      b"--- old\n+++ new\n@@ -2 +2 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n",
    )[0]
  let result = apply_hunks(b"other\n", patch.hunks, false, 0)
  assert_eq(
    reject_bytes(patch, result.results, false),
    b"--- old\n+++ new\n@@ -2 +2 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n",
  )
  let insertion = parse_patch(b"--- old\n+++ new\n@@ -0,0 +1 @@\n+first\n")[0]
  assert_eq(
    apply_hunks(b"old\n", insertion.hunks, false, 2).data,
    b"first\nold\n",
  )
  let beyond = parse_patch(b"--- old\n+++ new\n@@ -100,0 +101 @@\n+tail\n")[0]
  let appended = apply_hunks(b"one\n", beyond.hunks, false, 2)
  assert_eq(appended.data, b"one\ntail\n")
  assert_true(appended.results is [Applied(position=101, offset=0, fuzz=0)])
}

///|
test "patch batch reverse selection checks both directions within each fuzz tier" {
  let patch = parse_patch(
      b"--- old\n+++ new\n@@ -1,3 +1,3 @@\n before\n-old\n+new\n after\n",
    )[0]
  assert_true(batch_reverse(b"before\nnew\nafter\n", patch.hunks[0], false, 2))
  assert_true(!batch_reverse(b"before\nold\nafter\n", patch.hunks[0], true, 2))
  assert_true(!batch_reverse(b"before\nold\nafter\n", patch.hunks[0], false, 2))
  assert_true(
    batch_reverse(b"different\nnew\nafter\n", patch.hunks[0], false, 2),
  )
}

///|
test "patch later hunk cannot reuse an already changed input region" {
  let patch = parse_patch(
      b"--- old\n+++ new\n@@ -1 +1 @@\n-old\n+ONE\n@@ -1 +1 @@\n-old\n+TWO\n",
    )[0]
  let result = apply_hunks(b"old\nold\n", patch.hunks, false, 0)
  assert_eq(result.data, b"ONE\nTWO\n")
  assert_true(
    result.results
    is [
      Applied(position=1, offset=0, fuzz=0),
      Applied(position=2, offset=1, fuzz=0),
    ],
  )
}
