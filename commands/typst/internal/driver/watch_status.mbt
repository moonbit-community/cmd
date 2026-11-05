// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The status of the `watch` command (upstream `typst-cli/src/watch.rs`, its
// `Status`). It is a file of its own because `compile_once` prints it on
// every target, while `watch` itself only exists where files can be
// watched (`watch.mbt`, `watch_unsupported.mbt`).

///|
/// The status in which the watcher can be.
priv enum Status {
  Compiling
  /// (The duration in nanoseconds.)
  Success(Int64)
  /// (The duration in nanoseconds.)
  PartialSuccess(Int64)
  Error
}

///|
/// Clear the terminal and render the status message.
async fn Status::print(self : Status, config : CompileConfig) -> Unit {
  let out = terminal_out()
  if config.fullscreen {
    self.print_fullscreen(out, config)
  } else {
    self.print_message(out)
    if !(self is Compiling) {
      out.write("\n")
    }
  }
  flush_terminal(out)
}

///|
fn Status::print_fullscreen(
  self : Status,
  out : @kit.ColorWriter,
  config : CompileConfig,
) -> Unit {
  let color = self.color()
  clear_screen(out)
  out.set_color(color)
  out.write("watching")
  out.reset()
  match config.input {
    Stdin => out.writeln(" <stdin>")
    Path(path) => out.writeln(" \{path}")
  }
  out.set_color(color)
  out.write("writing to")
  out.reset()
  out.writeln(" \{config.output.to_string()}")

  // (Upstream prints "serving at" here if it serves the output over HTTP.)
  out.write("\n")
  self.print_message(out)
  out.write("\n")
}

///|
fn Status::print_message(self : Status, out : @kit.ColorWriter) -> Unit {
  let timestamp = local_time(@platform.now_ms())
  out.writeln("[\{timestamp}] \{self.message()}")
}

///|
fn Status::message(self : Status) -> String {
  match self {
    Compiling => "compiling ..."
    Success(duration) =>
      "compiled successfully in \{@library.format_duration(duration)}"
    PartialSuccess(duration) =>
      "compiled with warnings in \{@library.format_duration(duration)}"
    Error => "compiled with errors"
  }
}

///|
fn Status::color(self : Status) -> @kit.ColorSpec {
  match self {
    Error => header_error_style()
    PartialSuccess(_) => header_warning_style()
    _ => header_note_style()
  }
}

///|
/// The local time of day as `%H:%M:%S`
/// (`chrono::offset::Local::now().format("%H:%M:%S")`), given the
/// milliseconds since the UNIX epoch.
fn local_time(now_ms : Int64) -> String {
  let secs = floor_div(now_ms, 1000L)
  time_of_day(secs + @platform.local_offset(secs).to_int64())
}

///|
/// The time of day of a number of seconds since some midnight, as
/// `%H:%M:%S`.
fn time_of_day(secs : Int64) -> String {
  let of_day = secs - floor_div(secs, 86400L) * 86400L
  let two = (n : Int64) => if n < 10L { "0\{n}" } else { n.to_string() }
  "\{two(of_day / 3600L)}:\{two(of_day % 3600L / 60L)}:\{two(of_day % 60L)}"
}

///|
/// Division rounding towards negative infinity.
fn floor_div(a : Int64, b : Int64) -> Int64 {
  let q = a / b
  if a % b != 0L && (a < 0L) != (b < 0L) {
    q - 1L
  } else {
    q
  }
}
