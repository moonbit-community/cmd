///|
test "C byte quoting keeps shell and C maybe decisions distinct" {
  for style in [Shell, ShellAlways] {
    assert_eq(quote_name("a'$'b", style, false), ("'a'\\''$'\\''b'", 13, true))
  }
  assert_eq(quote_name("é", Literal, true), ("??", 2, false))
  assert_eq(quote_name("é", Literal, false), ("é", 0, false))
  assert_eq(quote_name("a b", CMaybe, false), ("a b", 3, false))
  assert_eq(
    quote_name("back\\slash", CMaybe, false),
    ("back\\slash", 10, false),
  )
  assert_eq(quote_name("a=b", Shell, false), ("'a=b'", 5, true))
  assert_eq(quote_name("bell\u0007", Shell, false), ("bell\u0007", 4, false))
  assert_eq(
    quote_name("line\nname", ShellEscape, true),
    ("'line'$'\\n''name'", 17, true),
  )
  assert_eq(
    quote_name("single'quote", ShellAlways, false),
    ("\"single'quote\"", 14, true),
  )
  assert_eq(quote_name("é", CQuote, false), ("\"\\303\\251\"", 10, true))
  assert_eq(quote_name("a:b", Escape, false, extra=":"), ("a\\:b", 4, false))
  assert_eq(
    quote_name("a@b", CMaybe, false, extra="=>@|"),
    ("\"a@b\"", 5, true),
  )
}

///|
async test "column and comma layouts use strict per column width and GNU tab stops" {
  let names = ["a", "bb", "ccc", "dddd", "eeeee", "f", "gg", "hhh"].map(text => DisplayName::{
    text,
    width: text.length(),
    color: None,
    suffix: "",
    pad: false,
  })
  let options = ls_options(parse_arguments(["-C", "-w20", "-T0"]))
  let render = async fn(options : LsOptions) {
    let out = @buffer.Buffer()
    write_layout(names, options, None, Ref(false), bytes => {
      out.write_bytes(bytes[:])
    })
    out.to_bytes()
  }
  assert_eq(render(options), b"a    dddd   gg\nbb   eeeee  hhh\nccc  f\n")
  assert_eq(
    render({ ..options, layout: Across, }),
    b"a     bb     ccc\ndddd  eeeee  f\ngg    hhh\n",
  )
  assert_eq(
    render({ ..options, layout: Commas, }),
    b"a, bb, ccc, dddd,\neeeee, f, gg, hhh\n",
  )
  assert_eq(
    render({ ..options, width: 0L, }),
    b"a  bb  ccc  dddd  eeeee  f  gg  hhh\n",
  )
  assert_eq(
    render({ ..options, width: 9223372036854775807L, }),
    b"a  bb  ccc  dddd  eeeee  f  gg  hhh\n",
  )
  assert_eq(
    render({ ..options, tabsize: 4UL, }),
    b"a\t dddd\tgg\nbb\t eeeee\thhh\nccc  f\n",
  )
}

///|
async test "unlimited layout emits bounded output batches without retaining the full listing" {
  let names = Array::make(10000, DisplayName::{
    text: "abcdefghij",
    width: 10,
    color: None,
    suffix: "",
    pad: false,
  })
  let mut calls = 0
  let mut total = 0
  let mut maximum = 0
  write_layout(
    names,
    ls_options(parse_arguments(["-C", "-w0"])),
    None,
    Ref(false),
    bytes => {
      calls += 1
      total += bytes.length()
      maximum = maximum.max(bytes.length())
    },
  )
  assert_true(calls > 1)
  assert_eq(total, 119999)
  assert_true(maximum <= 65548)
}

///|
test "display values reject earlier invalid occurrences and preserve unlimited width" {
  assert_eq(parse_dimension("0x14"), Some((20UL, false)))
  assert_eq(parse_dimension("08"), None)
  assert_eq(parse_dimension("18446744073709551616"), Some((0UL, true)))
  assert_eq(
    ls_options(parse_arguments(["-C", "-w18446744073709551616000"])).width,
    0L,
  )
  assert_true(
    invalid_display_option(parse_arguments(["-w-1", "-w20"])) is Some((_, 2)),
  )
  assert_true(
    invalid_display_option(parse_arguments(["--quoting-style=bogus", "-Q"]))
    is Some((_, 1)),
  )
  assert_true(
    invalid_display_option(parse_arguments(["--color=bogus", "--color=never"]))
    is Some((_, 1)),
  )
  assert_true(
    invalid_display_option(parse_arguments(["--quoting-style=sh"]))
    is Some((message, 1)) &&
    message.has_prefix("ls: ambiguous argument 'sh'"),
  )
  assert_true(ls_options(parse_arguments(["-Cxm1"])).layout == Lines)
  assert_true(ls_options(parse_arguments(["-bNQ"])).quoting == CQuote)
  assert_false(
    ls_options(parse_arguments(["-q", "--show-control-chars"])).hide_controls,
  )
}

///|
async test "color suffix precedence preserves bytes and exact case exceptions" {
  let (parsed, warning) = parse_colors(
    "lc=<:rc=>:ec=!:fi=F:ex=0:su=0:sg=0:ca=0:mh=0:*.txt=T:*.TXT=U:*.gz=G:*.tar.gz=A:*.gz=Z:*.bin=\\xff^@",
  )
  assert_eq(warning, "")
  let palette = parsed.unwrap()
  let entry = name => LsEntry::{
    name,
    path: name,
    kind: Some(Regular),
    timestamp: None,
    size: None,
  }
  assert_eq(entry_color(entry("lower.txt"), palette), Some(b"T"))
  assert_eq(entry_color(entry("upper.TXT"), palette), Some(b"U"))
  assert_eq(entry_color(entry("mixed.TxT"), palette), Some(b"F"))
  assert_eq(entry_color(entry("archive.tar.gz"), palette), Some(b"Z"))
  assert_eq(entry_color(entry("raw.bin"), palette), Some(b"\xff\x00"))
  assert_true(parse_colors("xx=invalid").0 is None)
  assert_true(parse_colors("lc=\\").0 is None)
}

///|
test "color refuses only enabled metadata categories relevant to the entry kind" {
  let palette = defaults()
  require_color_metadata(Some(Pipe), palette)
  require_color_metadata(Some(BlockDevice), palette)
  try require_color_metadata(Some(Regular), palette) catch {
    @fsops.FsOpError(message) => assert_true(message.contains("su,sg,ex"))
  } noraise {
    _ => fail("mode bits must not be inferred from effective access")
  }
  for key in ["su", "sg", "ex", "ca", "mh"] {
    palette.codes[key] = b"0"
  }
  require_color_metadata(Some(Regular), palette)
  try require_color_metadata(Some(Directory), palette) catch {
    @fsops.FsOpError(message) => assert_true(message.contains("tw,ow,st"))
  } noraise {
    _ => fail("directory mode categories require a public mode reader")
  }
}

///|
async test "type and target color uses public file kind without executable guessing" {
  if @async.platform is Windows {
    return
  }
  let root = @fs.tmpdir(prefix="mooncmd-ls-color")
  defer (@fs.rmdir(root, recursive=true) catch { _ => () })
  @fs.write_file(root + "/plain", "")
  @fs.symlink(target="plain", root + "/link.txt")
  @fs.symlink(target="missing", root + "/orphan")
  let palette = parse_colors(
    "fi=F:ln=target:or=O:*.txt=T:ex=0:su=0:sg=0:ca=0:mh=0:tw=0:ow=0:st=0",
  ).0.unwrap()
  let entry = name => LsEntry::{
    name,
    path: root + "/" + name,
    kind: Some(SymLink),
    timestamp: None,
    size: None,
  }
  assert_eq(entry_color(entry("link.txt"), palette), Some(b"T"))
  assert_eq(entry_color(entry("orphan"), palette), Some(b"O"))
  for
    (kind, expected) in [
      (@fs.FileKind::Pipe, b"33"),
      (Socket, b"01;35"),
      (BlockDevice, b"01;33"),
      (CharDevice, b"01;33"),
    ] {
    assert_eq(
      entry_color({ ..entry("kind"), kind: Some(kind), }, palette),
      Some(expected),
    )
  }
}
