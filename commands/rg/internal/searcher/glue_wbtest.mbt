///|
let sherlock : String = "For the Doctor Watsons of this world, as opposed to the Sherlock\nHolmeses, success in the province of detective work must always\nbe, to a very large extent, the result of luck. Sherlock Holmes\ncan extract a clew from a wisp of straw or a flake of cigar ash;\nbut Doctor Watson has to have it taken out for him and dusted,\nand exhibited clearly, with a label attached."

///|
let code : String = "extern crate snap;\n\nuse std::io;\n\nfn main() {\n    let stdin = io::stdin();\n    let stdout = io::stdout();\n\n    // Wrap the stdin reader in a Snappy reader.\n    let mut rdr = snap::Reader::new(stdin.lock());\n    let mut wtr = stdout.lock();\n    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n}\n"

///|
async test "basic1" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "basic2" {
  let exp = "\nbyte count:366\n"
  SearcherTester::new(sherlock, "NADA")
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "basic3" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "a")
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "basic4" {
  let haystack = "a\nb\n\nc\n\n\nd\n"
  let byte_count = haystack.length()
  let exp = "0:a\n\nbyte count:\{byte_count}\n"
  SearcherTester::new(haystack, "a")
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "invert1" {
  let exp = "65:Holmeses, success in the province of detective work must always\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .line_number(false)
  .invert_match(true)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "line_number1" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n\nbyte count:366\n"
  let exp_line = "1:0:For the Doctor Watsons of this world, as opposed to the Sherlock\n3:129:be, to a very large extent, the result of luck. Sherlock Holmes\n\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_line)
  .run()
}

///|
async test "line_number_invert1" {
  let exp = "65:Holmeses, success in the province of detective work must always\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  let exp_line = "2:65:Holmeses, success in the province of detective work must always\n4:193:can extract a clew from a wisp of straw or a flake of cigar ash;\n5:258:but Doctor Watson has to have it taken out for him and dusted,\n6:321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .invert_match(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_line)
  .run()
}

///|
async test "multi_line_overlap1" {
  let haystack = "xxx\nabc\ndefxxxabc\ndefxxx\nxxx"
  let byte_count = haystack.length()
  let exp = "4:abc\n8:defxxxabc\n18:defxxx\n\nbyte count:\{byte_count}\n"

  SearcherTester::new(haystack, "abc\ndef")
  .by_line(false)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "multi_line_overlap2" {
  let haystack = "xxx\nabc\ndefabc\ndefxxx\nxxx"
  let byte_count = haystack.length()
  let exp = "4:abc\n8:defabc\n15:defxxx\n\nbyte count:\{byte_count}\n"

  SearcherTester::new(haystack, "abc\ndef")
  .by_line(false)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "empty_line1" {
  let exp = "\nbyte count:0\n"
  SearcherTester::new("", "^$")
  .expected_no_line_number(exp)
  .expected_with_line_number(exp)
  .run()
}

///|
async test "empty_line2" {
  let exp = "0:\n\nbyte count:1\n"
  let exp_line = "1:0:\n\nbyte count:1\n"

  SearcherTester::new("\n", "^$")
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_line)
  .run()
}

///|
async test "empty_line3" {
  let exp = "0:\n1:\n\nbyte count:2\n"
  let exp_line = "1:0:\n2:1:\n\nbyte count:2\n"

  SearcherTester::new("\n\n", "^$")
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_line)
  .run()
}

///|
async test "empty_line4" {
  // See: https://github.com/BurntSushi/ripgrep/issues/441
  let haystack = "a\nb\n\nc\n\n\nd\n"
  let byte_count = haystack.length()
  let exp = "4:\n7:\n8:\n\nbyte count:\{byte_count}\n"
  let exp_line = "3:4:\n5:7:\n6:8:\n\nbyte count:\{byte_count}\n"

  SearcherTester::new(haystack, "^$")
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_line)
  .run()
}

///|
async test "empty_line5" {
  // See: https://github.com/BurntSushi/ripgrep/issues/441
  // This is like empty_line4, but lacks the trailing line terminator.
  let haystack = "a\nb\n\nc\n\n\nd"
  let byte_count = haystack.length()
  let exp = "4:\n7:\n8:\n\nbyte count:\{byte_count}\n"
  let exp_line = "3:4:\n5:7:\n6:8:\n\nbyte count:\{byte_count}\n"

  SearcherTester::new(haystack, "^$")
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_line)
  .run()
}

///|
async test "empty_line6" {
  // See: https://github.com/BurntSushi/ripgrep/issues/441
  // This is like empty_line4, but includes an empty line at the end.
  let haystack = "a\nb\n\nc\n\n\nd\n\n"
  let byte_count = haystack.length()
  let exp = "4:\n7:\n8:\n11:\n\nbyte count:\{byte_count}\n"
  let exp_line = "3:4:\n5:7:\n6:8:\n8:11:\n\nbyte count:\{byte_count}\n"

  SearcherTester::new(haystack, "^$")
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_line)
  .run()
}

///|
async test "big1" {
  let haystack = StringBuilder()
  haystack.write_string("a\n")
  // Pick an arbitrary number above the capacity.
  for _ in 0..<(4 * (DEFAULT_BUFFER_CAPACITY + 7)) {
    haystack.write_string("zzz\n")
  }
  haystack.write_string("a\n")
  let haystack = haystack.to_string()

  let byte_count = haystack.length()
  let exp = "0:a\n1048690:a\n\nbyte count:\{byte_count}\n"

  SearcherTester::new(haystack, "a")
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "big_error_one_line" {
  let haystack = StringBuilder()
  haystack.write_string("a\n")
  // Pick an arbitrary number above the capacity.
  for _ in 0..<(4 * (DEFAULT_BUFFER_CAPACITY + 7)) {
    haystack.write_string("zzz\n")
  }
  haystack.write_string("a\n")
  let haystack = haystack.to_string()

  let matcher = TestMatcher::new("a")
  let sink = KitchenSink::new()
  let searcher = SearcherBuilder::new()
    .heap_limit(Some(3)) // max line length is 4, one byte short
    .build()
  let result = try
    searcher.search_reader(
      matcher,
      SliceReader::from_bytes(@utf8.encode(haystack)),
      sink,
    )
  catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(result)
}

///|
async test "big_error_multi_line" {
  let haystack = StringBuilder()
  haystack.write_string("a\n")
  // Pick an arbitrary number above the capacity.
  for _ in 0..<(4 * (DEFAULT_BUFFER_CAPACITY + 7)) {
    haystack.write_string("zzz\n")
  }
  haystack.write_string("a\n")
  let haystack = haystack.to_string()

  let matcher = TestMatcher::new("a")
  let sink = KitchenSink::new()
  let searcher = SearcherBuilder::new()
    .multi_line(true)
    .heap_limit(Some(haystack.length())) // actually need one more byte
    .build()
  let result = try
    searcher.search_reader(
      matcher,
      SliceReader::from_bytes(@utf8.encode(haystack)),
      sink,
    )
  catch {
    _ => true
  } noraise {
    _ => false
  }
  assert_true(result)
}

///|
async test "binary1" {
  let haystack = "\u{0}a"
  let exp = "\nbyte count:0\nbinary offset:0\n"

  SearcherTester::new(haystack, "a")
  .binary_detection(BinaryQuit(0))
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "binary2" {
  let haystack = "a\u{0}"
  let exp = "\nbyte count:0\nbinary offset:1\n"

  SearcherTester::new(haystack, "a")
  .binary_detection(BinaryQuit(0))
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "binary3" {
  let haystack = StringBuilder()
  haystack.write_string("a\n")
  for _ in 0..<DEFAULT_BUFFER_CAPACITY {
    haystack.write_string("zzz\n")
  }
  haystack.write_string("a\n")
  haystack.write_string("zzz\n")
  haystack.write_string("a\u{0}a\n")
  haystack.write_string("zzz\n")
  haystack.write_string("a\n")
  let haystack = haystack.to_string()

  // The line buffered searcher has slightly different semantics here.
  // Namely, it will *always* detect binary data in the current buffer
  // before searching it. Thus, the total number of bytes searched is
  // smaller than below.
  let exp = "0:a\n\nbyte count:262146\nbinary offset:262153\n"
  // In contrast, the slice readers (for multi line as well) will only
  // look for binary data in the initial chunk of bytes. After that
  // point, it only looks for binary data in matches. Note though that
  // the binary offset remains the same. (See the binary4 test for a case
  // where the offset is explicitly different.)
  let exp_slice = "0:a\n262146:a\n\nbyte count:262153\nbinary offset:262153\n"

  SearcherTester::new(haystack, "a")
  .binary_detection(BinaryQuit(0))
  .line_number(false)
  .auto_heap_limit(false)
  .expected_no_line_number(exp)
  .expected_slice_no_line_number(exp_slice)
  .run()
}

///|
async test "binary4" {
  let haystack = StringBuilder()
  haystack.write_string("a\n")
  for _ in 0..<DEFAULT_BUFFER_CAPACITY {
    haystack.write_string("zzz\n")
  }
  haystack.write_string("a\n")
  // The Read searcher will detect binary data here, but since this is
  // beyond the initial buffer size and doesn't otherwise contain a
  // match, the Slice reader won't detect the binary data until the next
  // line (which is a match).
  haystack.write_string("b\u{0}b\n")
  haystack.write_string("a\u{0}a\n")
  haystack.write_string("a\n")
  let haystack = haystack.to_string()

  let exp = "0:a\n\nbyte count:262146\nbinary offset:262149\n"
  // The binary offset for the Slice readers corresponds to the binary
  // data in `a\x00a\n` since the first line with binary data
  // (`b\x00b\n`) isn't part of a match, and is therefore undetected.
  let exp_slice = "0:a\n262146:a\n\nbyte count:262153\nbinary offset:262153\n"

  SearcherTester::new(haystack, "a")
  .binary_detection(BinaryQuit(0))
  .line_number(false)
  .auto_heap_limit(false)
  .expected_no_line_number(exp)
  .expected_slice_no_line_number(exp_slice)
  .run()
}

///|
async test "passthru_sherlock1" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .passthru(true)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "passthru_sherlock_invert1" {
  let exp = "0-For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n129-be, to a very large extent, the result of luck. Sherlock Holmes\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .passthru(true)
  .line_number(false)
  .invert_match(true)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock1" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n\nbyte count:366\n"
  let exp_lines = "1:0:For the Doctor Watsons of this world, as opposed to the Sherlock\n2-65-Holmeses, success in the province of detective work must always\n3:129:be, to a very large extent, the result of luck. Sherlock Holmes\n4-193-can extract a clew from a wisp of straw or a flake of cigar ash;\n\nbyte count:366\n"
  // before and after + line numbers
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(1)
  .before_context(1)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(1)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .before_context(1)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock_invert1" {
  let exp = "0-For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n129-be, to a very large extent, the result of luck. Sherlock Holmes\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  let exp_lines = "1-0-For the Doctor Watsons of this world, as opposed to the Sherlock\n2:65:Holmeses, success in the province of detective work must always\n3-129-be, to a very large extent, the result of luck. Sherlock Holmes\n4:193:can extract a clew from a wisp of straw or a flake of cigar ash;\n5:258:but Doctor Watson has to have it taken out for him and dusted,\n6:321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  // before and after + line numbers
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(1)
  .before_context(1)
  .line_number(true)
  .invert_match(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // before
  SearcherTester::new(sherlock, "Sherlock")
  .before_context(1)
  .line_number(false)
  .invert_match(true)
  .expected_no_line_number(exp)
  .run()

  // after
  let exp = "65:Holmeses, success in the province of detective work must always\n129-be, to a very large extent, the result of luck. Sherlock Holmes\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(1)
  .line_number(false)
  .invert_match(true)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock2" {
  let exp = "65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  let exp_lines = "2-65-Holmeses, success in the province of detective work must always\n3:129:be, to a very large extent, the result of luck. Sherlock Holmes\n4:193:can extract a clew from a wisp of straw or a flake of cigar ash;\n5-258-but Doctor Watson has to have it taken out for him and dusted,\n6:321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  // before + after + line numbers
  SearcherTester::new(sherlock, " a ")
  .after_context(1)
  .before_context(1)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // before
  SearcherTester::new(sherlock, " a ")
  .before_context(1)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // after
  let exp = "129:be, to a very large extent, the result of luck. Sherlock Holmes\n193:can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, " a ")
  .after_context(1)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock_invert2" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n129-be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  let exp_lines = "1:0:For the Doctor Watsons of this world, as opposed to the Sherlock\n2:65:Holmeses, success in the province of detective work must always\n3-129-be, to a very large extent, the result of luck. Sherlock Holmes\n4-193-can extract a clew from a wisp of straw or a flake of cigar ash;\n5:258:but Doctor Watson has to have it taken out for him and dusted,\n6-321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  // before + after + line numbers
  SearcherTester::new(sherlock, " a ")
  .after_context(1)
  .before_context(1)
  .line_number(true)
  .invert_match(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // before
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n--\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n\nbyte count:366\n"
  SearcherTester::new(sherlock, " a ")
  .before_context(1)
  .line_number(false)
  .invert_match(true)
  .expected_no_line_number(exp)
  .run()

  // after
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n129-be, to a very large extent, the result of luck. Sherlock Holmes\n--\n258:but Doctor Watson has to have it taken out for him and dusted,\n321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, " a ")
  .after_context(1)
  .line_number(false)
  .invert_match(true)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock3" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n\nbyte count:366\n"
  let exp_lines = "1:0:For the Doctor Watsons of this world, as opposed to the Sherlock\n2-65-Holmeses, success in the province of detective work must always\n3:129:be, to a very large extent, the result of luck. Sherlock Holmes\n4-193-can extract a clew from a wisp of straw or a flake of cigar ash;\n5-258-but Doctor Watson has to have it taken out for him and dusted,\n\nbyte count:366\n"
  // before and after + line numbers
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(2)
  .before_context(2)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .before_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock4" {
  let exp = "129-be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  let exp_lines = "3-129-be, to a very large extent, the result of luck. Sherlock Holmes\n4-193-can extract a clew from a wisp of straw or a flake of cigar ash;\n5:258:but Doctor Watson has to have it taken out for him and dusted,\n6-321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  // before and after + line numbers
  SearcherTester::new(sherlock, "dusted")
  .after_context(2)
  .before_context(2)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  let exp = "258:but Doctor Watson has to have it taken out for him and dusted,\n321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "dusted")
  .after_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "129-be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258:but Doctor Watson has to have it taken out for him and dusted,\n\nbyte count:366\n"
  SearcherTester::new(sherlock, "dusted")
  .before_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock5" {
  let exp = "0-For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n129-be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  let exp_lines = "1-0-For the Doctor Watsons of this world, as opposed to the Sherlock\n2:65:Holmeses, success in the province of detective work must always\n3-129-be, to a very large extent, the result of luck. Sherlock Holmes\n4-193-can extract a clew from a wisp of straw or a flake of cigar ash;\n5-258-but Doctor Watson has to have it taken out for him and dusted,\n6:321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  // before and after + line numbers
  SearcherTester::new(sherlock, "success|attached")
  .after_context(2)
  .before_context(2)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  let exp = "65:Holmeses, success in the province of detective work must always\n129-be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n--\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "success|attached")
  .after_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "0-For the Doctor Watsons of this world, as opposed to the Sherlock\n65:Holmeses, success in the province of detective work must always\n--\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n321:and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "success|attached")
  .before_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_sherlock6" {
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  let exp_lines = "1:0:For the Doctor Watsons of this world, as opposed to the Sherlock\n2-65-Holmeses, success in the province of detective work must always\n3:129:be, to a very large extent, the result of luck. Sherlock Holmes\n4-193-can extract a clew from a wisp of straw or a flake of cigar ash;\n5-258-but Doctor Watson has to have it taken out for him and dusted,\n6-321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  // before and after + line numbers
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(3)
  .before_context(3)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n193-can extract a clew from a wisp of straw or a flake of cigar ash;\n258-but Doctor Watson has to have it taken out for him and dusted,\n321-and exhibited clearly, with a label attached.\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .after_context(3)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "0:For the Doctor Watsons of this world, as opposed to the Sherlock\n65-Holmeses, success in the province of detective work must always\n129:be, to a very large extent, the result of luck. Sherlock Holmes\n\nbyte count:366\n"
  SearcherTester::new(sherlock, "Sherlock")
  .before_context(3)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_code1" {
  // before and after
  let exp = "33-\n34-fn main() {\n46:    let stdin = io::stdin();\n75-    let stdout = io::stdout();\n106-\n107:    // Wrap the stdin reader in a Snappy reader.\n156:    let mut rdr = snap::Reader::new(stdin.lock());\n207-    let mut wtr = stdout.lock();\n240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n\nbyte count:307\n"
  let exp_lines = "4-33-\n5-34-fn main() {\n6:46:    let stdin = io::stdin();\n7-75-    let stdout = io::stdout();\n8-106-\n9:107:    // Wrap the stdin reader in a Snappy reader.\n10:156:    let mut rdr = snap::Reader::new(stdin.lock());\n11-207-    let mut wtr = stdout.lock();\n12-240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n\nbyte count:307\n"
  // before and after + line numbers
  SearcherTester::new(code, "stdin")
  .after_context(2)
  .before_context(2)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  let exp = "46:    let stdin = io::stdin();\n75-    let stdout = io::stdout();\n106-\n107:    // Wrap the stdin reader in a Snappy reader.\n156:    let mut rdr = snap::Reader::new(stdin.lock());\n207-    let mut wtr = stdout.lock();\n240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n\nbyte count:307\n"
  SearcherTester::new(code, "stdin")
  .after_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "33-\n34-fn main() {\n46:    let stdin = io::stdin();\n75-    let stdout = io::stdout();\n106-\n107:    // Wrap the stdin reader in a Snappy reader.\n156:    let mut rdr = snap::Reader::new(stdin.lock());\n\nbyte count:307\n"
  SearcherTester::new(code, "stdin")
  .before_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_code2" {
  let exp = "34-fn main() {\n46-    let stdin = io::stdin();\n75:    let stdout = io::stdout();\n106-\n107-    // Wrap the stdin reader in a Snappy reader.\n156-    let mut rdr = snap::Reader::new(stdin.lock());\n207:    let mut wtr = stdout.lock();\n240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n305-}\n\nbyte count:307\n"
  let exp_lines = "5-34-fn main() {\n6-46-    let stdin = io::stdin();\n7:75:    let stdout = io::stdout();\n8-106-\n9-107-    // Wrap the stdin reader in a Snappy reader.\n10-156-    let mut rdr = snap::Reader::new(stdin.lock());\n11:207:    let mut wtr = stdout.lock();\n12-240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n13-305-}\n\nbyte count:307\n"
  // before and after + line numbers
  SearcherTester::new(code, "stdout")
  .after_context(2)
  .before_context(2)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  let exp = "75:    let stdout = io::stdout();\n106-\n107-    // Wrap the stdin reader in a Snappy reader.\n--\n207:    let mut wtr = stdout.lock();\n240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n305-}\n\nbyte count:307\n"
  SearcherTester::new(code, "stdout")
  .after_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "34-fn main() {\n46-    let stdin = io::stdin();\n75:    let stdout = io::stdout();\n--\n107-    // Wrap the stdin reader in a Snappy reader.\n156-    let mut rdr = snap::Reader::new(stdin.lock());\n207:    let mut wtr = stdout.lock();\n\nbyte count:307\n"
  SearcherTester::new(code, "stdout")
  .before_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "context_code3" {
  let exp = "20-use std::io;\n33-\n34:fn main() {\n46-    let stdin = io::stdin();\n75-    let stdout = io::stdout();\n106-\n107-    // Wrap the stdin reader in a Snappy reader.\n156:    let mut rdr = snap::Reader::new(stdin.lock());\n207-    let mut wtr = stdout.lock();\n240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n\nbyte count:307\n"
  let exp_lines = "3-20-use std::io;\n4-33-\n5:34:fn main() {\n6-46-    let stdin = io::stdin();\n7-75-    let stdout = io::stdout();\n8-106-\n9-107-    // Wrap the stdin reader in a Snappy reader.\n10:156:    let mut rdr = snap::Reader::new(stdin.lock());\n11-207-    let mut wtr = stdout.lock();\n12-240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n\nbyte count:307\n"
  // before and after + line numbers
  SearcherTester::new(code, "fn main|let mut rdr")
  .after_context(2)
  .before_context(2)
  .line_number(true)
  .expected_no_line_number(exp)
  .expected_with_line_number(exp_lines)
  .run()

  // after
  let exp = "34:fn main() {\n46-    let stdin = io::stdin();\n75-    let stdout = io::stdout();\n--\n156:    let mut rdr = snap::Reader::new(stdin.lock());\n207-    let mut wtr = stdout.lock();\n240-    io::copy(&mut rdr, &mut wtr).expect(\"I/O operation failed\");\n\nbyte count:307\n"
  SearcherTester::new(code, "fn main|let mut rdr")
  .after_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()

  // before
  let exp = "20-use std::io;\n33-\n34:fn main() {\n--\n106-\n107-    // Wrap the stdin reader in a Snappy reader.\n156:    let mut rdr = snap::Reader::new(stdin.lock());\n\nbyte count:307\n"
  SearcherTester::new(code, "fn main|let mut rdr")
  .before_context(2)
  .line_number(false)
  .expected_no_line_number(exp)
  .run()
}

///|
async test "regression_2260" {
  let matcher = @grep_regex.RegexMatcherBuilder::new()
    .line_terminator(Some(b'\n'))
    .build("^\\w+$")
  let searcher = SearcherBuilder::new().line_number(true).build()
  let mut matched = false
  searcher.search_bytes(
    matcher,
    b"GATC\n",
    Lossy::new((_, _) => {
      matched = true
      true
    }),
  )
  assert_true(matched)
}
