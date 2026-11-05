// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The `fonts` command (upstream `typst-cli/src/fonts.rs`).

///|
/// Execute a font listing command.
async fn fonts(command : FontsCommand) -> Unit {
  let fonts = discover_fonts(command.font) catch {
    err => raise bail(err.to_string())
  }
  let out = StringBuilder()
  for entry in fonts.book().families() {
    let (family, indices) = entry
    out.write_string("\{family}\n")
    if command.variants {
      for k, index in indices {
        let info = fonts.book().info(index).unwrap()
        let path = match fonts.source(index) {
          Some(Path(path~, ..)) => Some(path)
          _ => None
        }
        let last = k == indices.length() - 1
        write_variant(out, info, path, last)
      }
      out.write_string("\n")
    }
  }
  print_out(out.to_string())
}

///|
/// Rust's `Debug` for a `FontStyle`.
fn style_debug(style : @library.FontStyle) -> String {
  match style {
    Normal => "Normal"
    Italic => "Italic"
    Oblique => "Oblique"
  }
}

///|
/// `Display for FontWeight`.
fn weight_display(weight : @library.FontWeight) -> String {
  weight.0.to_string()
}

///|
/// `Display for FontStretch`.
fn stretch_display(stretch : @library.FontStretch) -> String {
  let int_part = stretch.0 / 10
  let dec_part = stretch.0 % 10
  if dec_part == 0 {
    "\{int_part}%"
  } else {
    "\{int_part}.\{dec_part}%"
  }
}

///|
/// `Display for AxisValue`.
fn axis_value_display(value : @library.AxisValue) -> String {
  @library.rust_display_f64(
    @library.round_with_precision(value.get().to_double(), 2),
  )
}

///|
/// Displays information for one font file / variant.
fn write_variant(
  f : StringBuilder,
  info : @library.FontInfo,
  path : String?,
  last : Bool,
) -> Unit {
  let path = match path {
    Some(path) => path
    None => "(Embedded)"
  }
  let { style, weight, stretch, } = info.variant
  let marker = if last { "└" } else { "├" }
  let pad = if last { "     " } else { "  │  " }
  let axes = info.axes.mapi((i, axis) => (i, axis))
  axes.sort_by((a, b) => {
    let c = @library.StandardAxes::order(a.1.tag).compare(
      @library.StandardAxes::order(b.1.tag),
    )
    if c != 0 {
      c
    } else {
      a.0.compare(b.0)
    }
  })
  let axes = axes.map(a => a.1)
  if axes.is_empty() {
    f.write_string("  \{marker} \{path}\n")
    f.write_string(
      "\{pad} Style: \{style_debug(style)}, Weight: \{weight_display(weight)}, Stretch: \{stretch_display(stretch)}\n",
    )
  } else {
    f.write_string("  \{marker} \{path} (Variable)\n")
    let standard = @library.StandardAxes::parse(axes)
    if standard.ital is None && standard.slnt is None {
      f.write_string("\{pad} Style: \{style_debug(style)}\n")
    }
    if standard.wght is None {
      f.write_string("\{pad} Weight: \{weight_display(weight)}\n")
    }
    if standard.wdth is None {
      f.write_string("\{pad} Stretch: \{stretch_display(stretch)}\n")
    }
    for axis in axes {
      f.write_string("\{pad} \{write_axis(axis)}\n")
    }
  }
}

///|
/// Formats a variation axis.
fn write_axis(axis : @library.FontAxis) -> String {
  let identity = (v : @library.AxisValue) => axis_value_display(v)
  match axis.tag.0 {
    "ital" => write_axis_with(axis, "Italic", identity)
    "slnt" => write_axis_with(axis, "Slant", identity)
    "wght" =>
      write_axis_with(axis, "Weight", v => {
        weight_display(@library.FontWeight::from_wght(v))
      })
    "wdth" =>
      write_axis_with(axis, "Stretch", v => {
        stretch_display(@library.FontStretch::from_wdth(v))
      })
    "opsz" =>
      write_axis_with(axis, "Optical Size", v => "\{axis_value_display(v)}pt")
    _ => write_axis_with(axis, axis.tag.to_str_lossy(), identity)
  }
}

///|
/// Formats a variation axis with a specific name and value display
/// function.
fn write_axis_with(
  axis : @library.FontAxis,
  name : String,
  show : (@library.AxisValue) -> String,
) -> String {
  "\{name}: \{show(axis.min)}-\{show(axis.max)} (Default: \{show(axis.default)})"
}
