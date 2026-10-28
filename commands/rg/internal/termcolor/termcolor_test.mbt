///|
fn parse_ok(s : String) -> @termcolor.Color {
  @termcolor.Color::parse(s) catch {
    e => abort(e.to_string())
  }
}

///|
fn parse_err(s : String) -> (@termcolor.ParseColorErrorKind, String) {
  try @termcolor.Color::parse(s) catch {
    e => (e.kind(), e.invalid())
  } noraise {
    c => abort("expected error, got \{Repr(c)}")
  }
}

///|
async fn ansi_bytes(f : async (@termcolor.Ansi) -> Unit) -> Bytes {
  let v = @termcolor.ByteVec::new()
  let w = @termcolor.Ansi::new(v)
  f(w) catch {
    e => abort(e.to_string())
  }
  v.to_bytes()
}

///|
test "simple_parse_ok" {
  assert_eq(parse_ok("green"), Green)
  assert_eq(parse_ok("GREEN"), Green)
}

///|
test "256_parse_ok" {
  assert_eq(parse_ok("7"), Ansi256(7))
  assert_eq(parse_ok("32"), Ansi256(32))
  assert_eq(parse_ok("0xFF"), Ansi256(0xFF))
}

///|
test "256_parse_err_out_of_range" {
  assert_eq(parse_err("256"), (InvalidAnsi256, "256"))
}

///|
test "rgb_parse_ok" {
  assert_eq(parse_ok("0,0,0"), Rgb(0, 0, 0))
  assert_eq(parse_ok("0,128,255"), Rgb(0, 128, 255))
  assert_eq(parse_ok("0x0,0x0,0x0"), Rgb(0, 0, 0))
  assert_eq(parse_ok("0x33,0x66,0xFF"), Rgb(0x33, 0x66, 0xFF))
}

///|
test "rgb_parse_err_out_of_range" {
  assert_eq(parse_err("0,0,256"), (InvalidRgb, "0,0,256"))
}

///|
test "rgb_parse_err_bad_format" {
  assert_eq(parse_err("0,0"), (InvalidRgb, "0,0"))
  assert_eq(parse_err("not_a_color"), (InvalidName, "not_a_color"))
}

///|
test "parse error messages" {
  let msg = (s : String) => {
    try @termcolor.Color::parse(s) catch {
      e => e.to_string()
    } noraise {
      _ => "ok"
    }
  }
  inspect(
    msg("nope"),
    content="unrecognized color name 'nope'. Choose from: black, blue, green, red, cyan, magenta, yellow, white",
  )
  inspect(
    msg("300"),
    content="unrecognized ansi256 color number, should be '[0-255]' (or a hex number), but is '300'",
  )
  inspect(
    msg("1,2,x"),
    content="unrecognized RGB color triple, should be '[0-255],[0-255],[0-255]' (or a hex triple), but is '1,2,x'",
  )
}

///|
async test "var_ansi_write_rgb" {
  let spec = @termcolor.ColorSpec::new()
    .set_reset(false)
    .set_fg(Some(Rgb(254, 253, 255)))
  assert_eq(ansi_bytes(w => w.set_color(spec)), b"\x1b[38;2;254;253;255m")
}

///|
async test "reset" {
  let spec = @termcolor.ColorSpec::new()
  assert_eq(ansi_bytes(w => w.set_color(spec)), b"\x1b[0m")
}

///|
async test "no_reset" {
  let spec = @termcolor.ColorSpec::new().set_reset(false)
  assert_eq(ansi_bytes(w => w.set_color(spec)), b"")
}

///|
async test "var_ansi_write_256" {
  let spec = @termcolor.ColorSpec::new()
    .set_reset(false)
    .set_bg(Some(Ansi256(7)))
  assert_eq(ansi_bytes(w => w.set_color(spec)), b"\x1b[48;5;7m")
  let spec = @termcolor.ColorSpec::new()
    .set_reset(false)
    .set_bg(Some(Ansi256(208)))
  assert_eq(ansi_bytes(w => w.set_color(spec)), b"\x1b[48;5;208m")
  let spec = @termcolor.ColorSpec::new()
    .set_reset(false)
    .set_fg(Some(Ansi256(0)))
  assert_eq(ansi_bytes(w => w.set_color(spec)), b"\x1b[38;5;0m")
}

///|
async test "ansi styles and intense colors" {
  let spec = @termcolor.ColorSpec::new()
    .set_fg(Some(Red))
    .set_bg(Some(Blue))
    .set_bold(true)
    .set_dimmed(true)
    .set_italic(true)
    .set_underline(true)
    .set_strikethrough(true)
  assert_eq(
    ansi_bytes(w => w.set_color(spec)),
    b"\x1b[0m\x1b[1m\x1b[2m\x1b[3m\x1b[4m\x1b[9m\x1b[31m\x1b[44m",
  )
  let spec = @termcolor.ColorSpec::new()
    .set_fg(Some(Magenta))
    .set_bg(Some(White))
    .set_intense(true)
  assert_eq(
    ansi_bytes(w => w.set_color(spec)),
    b"\x1b[0m\x1b[38;5;13m\x1b[48;5;15m",
  )
}

///|
fn all_attributes() -> Array[@termcolor.ColorSpec] {
  let result = []
  let bools = [false, true]
  for fg in [None, Some(@termcolor.Color::Red)] {
    for bg in [None, Some(@termcolor.Color::Red)] {
      for bold in bools {
        for underline in bools {
          for intense in bools {
            for italic in bools {
              for strikethrough in bools {
                for dimmed in bools {
                  let color = @termcolor.ColorSpec::new()
                  color
                  .set_fg(fg)
                  .set_bg(bg)
                  .set_bold(bold)
                  .set_underline(underline)
                  .set_intense(intense)
                  .set_italic(italic)
                  .set_dimmed(dimmed)
                  .set_strikethrough(strikethrough)
                  |> ignore
                  result.push(color)
                }
              }
            }
          }
        }
      }
    }
  }
  result
}

///|
test "is_none" {
  for i, color in all_attributes() {
    assert_eq(i == 0, color.is_none())
  }
}

///|
test "clear" {
  for color in all_attributes() {
    let color1 = color.clone()
    color1.clear()
    assert_true(color1.is_none())
  }
}

///|
async test "ansi_hyperlink" {
  let got = ansi_bytes(w => {
    w.set_hyperlink(@termcolor.HyperlinkSpec::open(b"https://example.com"))
    w.write_bytes(b"label")
    w.set_hyperlink(@termcolor.HyperlinkSpec::close())
  })
  assert_eq(got, b"\x1b]8;;https://example.com\x1b\\label\x1b]8;;\x1b\\")
}

///|
async test "buffer and no color" {
  let buf = @termcolor.Buffer::ansi()
  buf.set_color(@termcolor.ColorSpec::new().set_fg(Some(Green)))
  buf.write_bytes(b"x")
  buf.reset()
  assert_eq(buf.to_bytes(), b"\x1b[0m\x1b[32mx\x1b[0m")
  assert_true(buf.supports_color())
  let buf = @termcolor.Buffer::no_color()
  buf.set_color(@termcolor.ColorSpec::new().set_fg(Some(Green)))
  buf.write_bytes(b"x")
  buf.reset()
  assert_eq(buf.to_bytes(), b"x")
  assert_false(buf.supports_color())
  let v = @termcolor.ByteVec::new(capacity=1)
  let w = @termcolor.NoColor::new(v)
  w.set_color(@termcolor.ColorSpec::new().set_fg(Some(Green)))
  w.write_bytes(b"hello ")
  w.write_slice([b'a', b'b', b'c', b'd'], 1, 3)
  w.reset()
  assert_eq(v.to_bytes(), b"hello bc")
  assert_false(w.supports_hyperlinks())
}
