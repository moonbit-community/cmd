///|
test "output paths" {
  inspect(with_extension("docs/main.typ", "pdf"), content="docs/main.pdf")
  inspect(with_extension("main", "svg"), content="main.svg")
  inspect(with_extension("a.b/main.typ", ""), content="a.b/main")
  inspect(with_extension(".hidden", "pdf"), content=".hidden.pdf")
  @debug.debug_inspect(
    path_extension("out.PDF"),
    content=(
      #|Some("PDF")
    ),
  )
  @debug.debug_inspect(path_extension("dir.x/out"), content="None")
  @debug.debug_inspect(path_extension(".pdf"), content="None")
}

///|
test "page templates" {
  inspect(has_indexable_template("page-{p}.png"), content="true")
  inspect(has_indexable_template("page-{t}.png"), content="false")
  inspect(
    format_template("page-{0p}-of-{t}.png", 3, 12),
    content="page-03-of-12.png",
  )
  inspect(format_template("{p}-{n}.svg", 7, 100), content="7-007.svg")
}

///|
test "relative paths" {
  @debug.debug_inspect(
    diff_paths("/a/b/c.typ", "/a/b"),
    content=(
      #|Some("c.typ")
    ),
  )
  @debug.debug_inspect(
    diff_paths("/a/x/c.typ", "/a/b"),
    content=(
      #|Some("../x/c.typ")
    ),
  )
  @debug.debug_inspect(
    diff_paths("/a/b", "/a/b"),
    content=(
      #|Some("")
    ),
  )
  @debug.debug_inspect(
    diff_paths("/a", "/a/b/c"),
    content=(
      #|Some("../..")
    ),
  )
  @debug.debug_inspect(diff_paths("rel", "/a"), content="None")
}

///|
test "make dependency escaping" {
  inspect(munge("a b:c$d#e"), content="a\\ b\\:c$$d\\#e")
  inspect(munge("x\\ y"), content="x\\\\\\ y")
}

///|
test "page ranges" {
  let show = (s : String) => {
    try parse_pages(s) catch {
      Invalid(msg) => msg
      _ => "?"
    } noraise {
      r => "\{@debug.to_string(r.start)}..\{@debug.to_string(r.end)}"
    }
  }
  inspect(show("3"), content="Some(3)..Some(3)")
  inspect(show("2-5"), content="Some(2)..Some(5)")
  inspect(show("4-"), content="Some(4)..None")
  inspect(show(" -2"), content="None..Some(2)")
  inspect(
    show("0"),
    content="invalid value '0' for '--pages <PAGES>': page numbers start at one",
  )
  inspect(
    show("3-1"),
    content="invalid value '3-1' for '--pages <PAGES>': page range must end at a page after the start",
  )
  inspect(
    show("1-2-3"),
    content="invalid value '1-2-3' for '--pages <PAGES>': page range must have a single hyphen",
  )
  inspect(
    show("x"),
    content="invalid value 'x' for '--pages <PAGES>': not a valid page number",
  )
}

///|
test "integers" {
  let show = (s : String) => {
    try parse_i64(s) catch {
      @kit.StrError(msg) => msg
    } noraise {
      v => v.to_string()
    }
  }
  inspect(show("-1700000000"), content="-1700000000")
  inspect(show("+5"), content="5")
  inspect(show("9223372036854775807"), content="9223372036854775807")
  inspect(show("-9223372036854775808"), content="-9223372036854775808")
  inspect(
    show("9223372036854775808"),
    content="number too large to fit in target type",
  )
  inspect(
    show("18446744073709551616"),
    content="number too large to fit in target type",
  )
  inspect(
    show("-9223372036854775809"),
    content="number too small to fit in target type",
  )
  inspect(show("1x"), content="invalid digit found in string")
  inspect(show(""), content="cannot parse integer from empty string")
}

///|
test "shell escape" {
  inspect(shell_escape("query(heading)"), content="'query(heading)'")
  inspect(shell_escape("--aaa=bbb-ccc"), content="--aaa=bbb-ccc")
  inspect(shell_escape("it's!"), content="'it'\\''s'\\!''")
  inspect(shell_escape(""), content="''")
}

///|
test "argument parsing" {
  let parse = (argv : Array[String]) => {
    try parse_args(argv) catch {
      Usage(msg, usage) => "usage error: \{msg} | \{usage}"
      Invalid(msg) => "invalid: \{msg}"
      Display(_) => "display"
      MissingSubcommand => "missing subcommand"
    } noraise {
      args =>
        match args.command {
          Compile(c) =>
            "compile \{c.input.to_string()} \{@debug.to_string(c.output.map(o => o.to_string()))} inputs=\{@debug.to_string(c.world.inputs)} pages=\{@debug.to_string(c.pages.map(p => p.length()))} pretty=\{@debug.to_string(c.pretty)}"
          _ => "other"
        }
    }
  }
  inspect(
    parse([
      "c", "a.typ", "--input", "k = v", "-i", "x=1", "--pages=1,3-", "--pretty",
    ]),
    content=(
      #|compile a.typ None inputs=[("k", "v"), ("x", "1")] pages=Some(2) pretty=Some(true)
    ),
  )
  inspect(
    parse(["compile", "--", "-", "out.svg"]),
    content=(
      #|compile stdin Some("out.svg") inputs=[] pages=None pretty=None
    ),
  )
  inspect(
    parse(["compile", "-"]),
    content="usage error: the following required arguments were not provided:\n  <OUTPUT> | typst compile <INPUT> <OUTPUT>",
  )
  inspect(parse([]), content="missing subcommand")
  inspect(parse(["--help"]), content="display")
  inspect(
    parse(["bogus"]),
    content="usage error: unrecognized subcommand 'bogus' | typst [OPTIONS] <COMMAND>",
  )
  inspect(
    parse(["compile", "a.typ", "--pretty=maybe"]),
    content="invalid: invalid value 'maybe' for '--pretty[=<PRETTY>]'\n  [possible values: true, false]",
  )
}
