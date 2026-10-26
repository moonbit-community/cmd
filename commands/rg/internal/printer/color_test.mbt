///|
fn parse_spec_err(s : String) -> String {
  try @printer.UserColorSpec::parse(s) catch {
    e => e.to_string()
  } noraise {
    _ => "ok"
  }
}

///|
/// The example from the `UserColorSpec` documentation.
test "user color spec to color spec" {
  let user_spec1 = @printer.UserColorSpec::parse("path:fg:blue")
  let user_spec2 = @printer.UserColorSpec::parse("match:bg:0xff,0x7f,0x00")
  let spec1 = user_spec1.to_color_spec()
  let spec2 = user_spec2.to_color_spec()
  assert_eq(spec1.fg(), Some(Blue))
  assert_eq(spec2.bg(), Some(Rgb(0xFF, 0x7F, 0x00)))
}

///|
test "color specs merge" {
  let specs = @printer.ColorSpecs::new([
    @printer.UserColorSpec::parse("path:fg:red"),
    @printer.UserColorSpec::parse("PATH:style:bold"),
    @printer.UserColorSpec::parse("line:fg:green"),
    @printer.UserColorSpec::parse("line:none"),
    @printer.UserColorSpec::parse("match:bg:7"),
    @printer.UserColorSpec::parse("match:style:intense"),
    @printer.UserColorSpec::parse("match:style:nointense"),
    @printer.UserColorSpec::parse("column:style:underline"),
    @printer.UserColorSpec::parse("highlight:style:italic"),
  ])
  let path = @termcolor.ColorSpec::new().set_fg(Some(Red)).set_bold(true)
  assert_eq(specs.path(), path)
  assert_true(specs.line().is_none())
  assert_eq(
    specs.matched(),
    @termcolor.ColorSpec::new().set_bg(Some(Ansi256(7))),
  )
  assert_eq(specs.column(), @termcolor.ColorSpec::new().set_underline(true))
  assert_eq(specs.highlight(), @termcolor.ColorSpec::new().set_italic(true))
  let defaults = @printer.ColorSpecs::default_with_color()
  assert_eq(defaults.path().fg(), Some(Magenta))
  assert_eq(defaults.line().fg(), Some(Green))
  assert_eq(defaults.matched().fg(), Some(Red))
  assert_true(defaults.matched().bold())
  assert_true(defaults.column().is_none())
  assert_true(@printer.ColorSpecs::default().matched().is_none())
}

///|
test "color spec parse errors" {
  inspect(
    parse_spec_err("foo:fg:blue"),
    content="unrecognized output type 'foo'. Choose from: path, line, column, match, highlight.",
  )
  inspect(
    parse_spec_err("path:fgg:blue"),
    content="unrecognized spec type 'fgg'. Choose from: fg, bg, style, none.",
  )
  inspect(
    parse_spec_err("path:fg:purple"),
    content="unrecognized color name 'purple'. Choose from: black, blue, green, red, cyan, magenta, yellow, white",
  )
  inspect(
    parse_spec_err("path:style:blink"),
    content="unrecognized style attribute 'blink'. Choose from: nobold, bold, nointense, intense, nounderline, underline, noitalic, italic.",
  )
  inspect(
    parse_spec_err("path"),
    content="invalid color spec format: 'path'. Valid format is '(path|line|column|match|highlight):(fg|bg|style):(value)'.",
  )
  inspect(
    parse_spec_err("path:fg"),
    content="invalid color spec format: 'path:fg'. Valid format is '(path|line|column|match|highlight):(fg|bg|style):(value)'.",
  )
  inspect(
    parse_spec_err("a:b:c:d"),
    content="invalid color spec format: 'a:b:c:d'. Valid format is '(path|line|column|match|highlight):(fg|bg|style):(value)'.",
  )
  inspect(
    parse_spec_err("match:style:"),
    content="unrecognized style attribute ''. Choose from: nobold, bold, nointense, intense, nounderline, underline, noitalic, italic.",
  )
  inspect(
    parse_spec_err("match:fg:"),
    content="unrecognized ansi256 color number, should be '[0-255]' (or a hex number), but is ''",
  )
  inspect(parse_spec_err("match:none"), content="ok")
  inspect(parse_spec_err("match:none:ignored"), content="ok")
  let err = try @printer.UserColorSpec::parse("path:fg:300") catch {
    e => e
  } noraise {
    _ => fail("expected error")
  }
  assert_eq(
    err,
    UnrecognizedColor(
      "300", "unrecognized ansi256 color number, should be '[0-255]' (or a hex number), but is '300'",
    ),
  )
}

///|
test "stats json" {
  let stats = @printer.Stats::new()
  stats.add_elapsed(33916)
  stats.add_searches(1)
  stats.add_searches_with_match(1)
  stats.add_bytes_searched(367)
  stats.add_bytes_printed(529)
  stats.add_matched_lines(2)
  stats.add_matches(2)
  let out = @termcolor.ByteVec::new()
  stats.write_json(@printer.JsonWriter::new(out))
  assert_eq(
    contents(out),
    "{\"elapsed\":{\"secs\":0,\"nanos\":33916,\"human\":\"0.000034s\"},\"searches\":1,\"searches_with_match\":1,\"bytes_searched\":367,\"bytes_printed\":529,\"matched_lines\":2,\"matches\":2}",
  )
  // The sorted form, as embedded in ripgrep's `summary` JSON message.
  let out = @termcolor.ByteVec::new()
  stats.write_json(@printer.JsonWriter::new(out), sorted_keys=true)
  assert_eq(
    contents(out),
    "{\"bytes_printed\":529,\"bytes_searched\":367,\"elapsed\":{\"human\":\"0.000034s\",\"nanos\":33916,\"secs\":0},\"matched_lines\":2,\"matches\":2,\"searches\":1,\"searches_with_match\":1}",
  )
  let sum = stats + stats
  assert_eq(sum.matches(), 4)
  assert_eq(sum.elapsed(), 67832)
  stats.add_stats(sum)
  assert_eq(stats.searches(), 3)
}
