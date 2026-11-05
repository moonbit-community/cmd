// Tests of what `watch` adds that needs no file system events: its
// arguments, its configuration, the status texts and the export cache.

///|
/// The watch command of an argument list, or the error.
fn watch_command(argv : Array[String]) -> Result[WatchCommand, String] {
  try parse_args(["watch", ..argv]) catch {
    Usage(msg, usage) => Err("usage error: \{msg} | \{usage}")
    Invalid(msg) => Err("invalid: \{msg}")
    Display(_) => Err("display")
    MissingSubcommand => Err("missing subcommand")
  } noraise {
    { command: Watch(command), .. } => Ok(command)
    _ => Err("another command")
  }
}

///|
/// The configuration of a watch command, or the error.
fn watch_config(argv : Array[String]) -> Result[CompileConfig, String] {
  match watch_command(argv) {
    Err(err) => Err(err)
    Ok(command) =>
      try CompileConfig::watching(command) catch {
        HintedFailure(msg) => Err(msg.message)
      } noraise {
        config => Ok(config)
      }
  }
}

///|
fn describe(command : Result[WatchCommand, String]) -> String {
  match command {
    Err(err) => err
    Ok(command) => {
      let port = match command.server.port {
        Some(port) => port.to_string()
        None => "none"
      }
      "no_fullscreen=\{command.no_fullscreen} no_serve=\{command.server.no_serve} no_reload=\{command.server.no_reload} port=\{port}"
    }
  }
}

///|
test "watch arguments" {
  inspect(
    describe(watch_command(["a.typ"])),
    content="no_fullscreen=false no_serve=false no_reload=false port=none",
  )
  inspect(
    describe(
      watch_command([
        "a.typ", "--no-fullscreen", "--no-serve", "--no-reload", "--port", "3001",
      ]),
    ),
    content="no_fullscreen=true no_serve=true no_reload=true port=3001",
  )
  inspect(
    describe(watch_command(["--port=65535", "a.typ"])),
    content="no_fullscreen=false no_serve=false no_reload=false port=65535",
  )
  // The messages of the upstream executable.
  inspect(
    describe(watch_command(["a.typ", "--port", "abc"])),
    content="invalid: invalid value 'abc' for '--port <PORT>': invalid digit found in string",
  )
  inspect(
    describe(watch_command(["a.typ", "--port", "70000"])),
    content="invalid: invalid value '70000' for '--port <PORT>': 70000 is not in 0..=65535",
  )
  inspect(
    describe(watch_command(["a.typ", "--port", ""])),
    content="invalid: invalid value '' for '--port <PORT>': cannot parse integer from empty string",
  )
  inspect(
    describe(watch_command(["a.typ", "--port"])),
    content="invalid: a value is required for '--port <PORT>' but none was supplied",
  )
  inspect(
    describe(watch_command(["a.typ", "--no-serve", "--no-serve"])),
    content="usage error: the argument '--no-serve' cannot be used multiple times | typst watch [OPTIONS] <INPUT> [OUTPUT]",
  )
  // They are arguments of `watch` alone.
  inspect(
    parse_result(["compile", "a.typ", "--no-fullscreen"]),
    content=(
      #|usage error: unexpected argument '--no-fullscreen' found
      #|
      #|  tip: to pass '--no-fullscreen' as a value, use '-- --no-fullscreen' | typst compile <INPUT> [OUTPUT]
    ),
  )
}

///|
test "watch configuration" {
  let check = (argv : Array[String]) => {
    match watch_config(argv) {
      Err(err) => err
      Ok(config) =>
        "watching=\{config.watching} fullscreen=\{config.fullscreen} output=\{config.output.to_string()}"
    }
  }
  inspect(
    check(["dir/a.typ"]),
    content="watching=true fullscreen=true output=dir/a.pdf",
  )
  inspect(
    check(["a.typ", "b.svg", "--no-fullscreen"]),
    content="watching=true fullscreen=false output=b.svg",
  )
  inspect(
    check(["a.typ", "-"]),
    content="cannot write document to stdout in watch mode",
  )
  inspect(
    check(["a.typ", "--deps", "-"]),
    content="cannot write dependencies to stdout in watch mode",
  )
  // Upstream serves HTML and bundles over HTTP unless told not to; this
  // port cannot.
  inspect(
    check(["a.typ", "a.html"]),
    content="the built-in HTTP server for HTML export is not supported by this build; pass `--no-serve`",
  )
  inspect(
    check(["a.typ", "--format", "bundle"]),
    content="the built-in HTTP server for HTML export is not supported by this build; pass `--no-serve`",
  )
  inspect(
    check(["a.typ", "a.html", "--no-serve"]),
    content="watching=true fullscreen=true output=a.html",
  )
  inspect(
    check(["a.typ", "-", "--format", "html"]),
    content="cannot write document to stdout in watch mode",
  )
  // `compile` is not watching, and its status is never printed.
  let compiling = CompileConfig::new(
    match parse_args(["compile", "a.typ"]) {
      { command: Compile(args), .. } => args
      _ => fail("not a compile command")
    },
  )
  inspect(compiling.watching, content="false")
  inspect(compiling.fullscreen, content="true")
}

///|
/// What a status prints, with the time of day replaced.
fn status_text(
  status : Status,
  argv : Array[String],
  color : Bool,
) -> String raise {
  guard watch_config(argv) is Ok(config) else { fail("no configuration") }
  let out = @kit.ColorWriter::new(color)
  if config.fullscreen {
    status.print_fullscreen(out, config)
  } else {
    status.print_message(out)
    if !(status is Compiling) {
      out.write("\n")
    }
  }
  let text = out.take()
  // `[HH:MM:SS]`.
  guard text.find("] ") is Some(end) else { fail("no time of day") }
  guard text[:end].rev_find("[") is Some(start) else { fail("no time of day") }
  inspect(end - start, content="9")
  "\{text[:start]}[TIME\{text[end:]}"
}

///|
test "status messages" {
  let argv = ["a.typ", "--no-fullscreen"]
  inspect(
    status_text(Compiling, argv, false),
    content=(
      #|[TIME] compiling ...
      #|
    ),
  )
  inspect(
    status_text(Success(1234567L), argv, false),
    content=(
      #|[TIME] compiled successfully in 1.23 ms
      #|
      #|
    ),
  )
  inspect(
    status_text(PartialSuccess(2500000000L), argv, false),
    content=(
      #|[TIME] compiled with warnings in 2.5 s
      #|
      #|
    ),
  )
  inspect(
    status_text(Error, argv, false),
    content=(
      #|[TIME] compiled with errors
      #|
      #|
    ),
  )
  // Colors do not change a line of this mode.
  inspect(
    status_text(Error, argv, true),
    content=(
      #|[TIME] compiled with errors
      #|
      #|
    ),
  )
}

///|
test "status of the fullscreen mode" {
  let argv = ["dir/a.typ", "out/a.svg"]
  inspect(
    status_text(Compiling, argv, false),
    content=(
      #|watching dir/a.typ
      #|writing to out/a.svg
      #|
      #|[TIME] compiling ...
      #|
      #|
    ),
  )
  inspect(
    status_text(Success(90000000000L), ["-", "a.pdf"], false),
    content=(
      #|watching <stdin>
      #|writing to a.pdf
      #|
      #|[TIME] compiled successfully in 1 min 30 s
      #|
      #|
    ),
  )
  // On a terminal the screen is cleared first, and the headers have the
  // color of the status.
  inspect(
    status_text(Success(1000000L), argv, true).escape(),
    content=(
      #|"\u{1b}[2J\u{1b}[1;1H\u{1b}[0m\u{1b}[1m\u{1b}[38;5;10mwatching\u{1b}[0m dir/a.typ\n\u{1b}[0m\u{1b}[1m\u{1b}[38;5;10mwriting to\u{1b}[0m out/a.svg\n\n[TIME] compiled successfully in 1 ms\n\n"
    ),
  )
  inspect(
    status_text(PartialSuccess(1000000L), argv, true).escape(),
    content=(
      #|"\u{1b}[2J\u{1b}[1;1H\u{1b}[0m\u{1b}[1m\u{1b}[38;5;11mwatching\u{1b}[0m dir/a.typ\n\u{1b}[0m\u{1b}[1m\u{1b}[38;5;11mwriting to\u{1b}[0m out/a.svg\n\n[TIME] compiled with warnings in 1 ms\n\n"
    ),
  )
  inspect(
    status_text(Error, argv, true).escape(),
    content=(
      #|"\u{1b}[2J\u{1b}[1;1H\u{1b}[0m\u{1b}[1m\u{1b}[38;5;9mwatching\u{1b}[0m dir/a.typ\n\u{1b}[0m\u{1b}[1m\u{1b}[38;5;9mwriting to\u{1b}[0m out/a.svg\n\n[TIME] compiled with errors\n\n"
    ),
  )
}

///|
test "time of day" {
  inspect(time_of_day(0L), content="00:00:00")
  inspect(time_of_day(3661L), content="01:01:01")
  inspect(time_of_day(86399L), content="23:59:59")
  inspect(time_of_day(86400L), content="00:00:00")
  inspect(time_of_day(1759829696L), content="09:34:56")
  // West of Greenwich before 1970.
  inspect(time_of_day(-1L), content="23:59:59")
  inspect(time_of_day(-86400L - 3600L), content="23:00:00")
}

///|
/// A page with a frame of the given width.
fn test_page(width : Double) -> @layout.Page {
  {
    frame: @library.Frame::hard(
      @library.Axes::new(@library.Abs::pt(width), @library.Abs::pt(10.0)),
    ),
    bleed: @library.Sides::splat(@library.Abs::zero()),
    fill: Auto,
    numbering: None,
    supplement: @library.Content::empty(),
    number: 1UL,
  }
}

///|
test "export cache" {
  let cache = ExportCache::new()
  let a = test_page(100.0)
  let b = test_page(200.0)
  // The first compilation fills the cache.
  inspect(cache.is_cached(0, a), content="false")
  inspect(cache.is_cached(1, b), content="false")
  // The same pages again.
  inspect(cache.is_cached(0, test_page(100.0)), content="true")
  inspect(cache.is_cached(1, test_page(200.0)), content="true")
  // A page that changed, and the same page once more.
  inspect(cache.is_cached(1, test_page(300.0)), content="false")
  inspect(cache.is_cached(1, test_page(300.0)), content="true")
  inspect(cache.is_cached(0, a), content="true")
  // A page that was not there before.
  inspect(cache.is_cached(2, a), content="false")
  inspect(cache.is_cached(2, a), content="true")
  // The other fields of a page count too.
  inspect(cache.is_cached(0, { ..a, number: 2UL, }), content="false")
  inspect(
    cache.is_cached(0, { ..a, number: 2UL, fill: Custom(None), }),
    content="false",
  )
  inspect(
    cache.is_cached(0, { ..a, number: 2UL, fill: Custom(None), }),
    content="true",
  )
}
