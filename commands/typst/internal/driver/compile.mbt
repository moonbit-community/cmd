// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The `compile` command (upstream `typst-cli/src/compile.rs`).

///|
/// An application-level error with hints (upstream `HintedString` as the
/// error of a `HintedStrResult`).
priv suberror HintedFailure {
  HintedFailure(@library.HintedString)
}

///|
/// Bails with a message (upstream `bail!` in a `StrResult`).
fn bail(message : String) -> HintedFailure {
  HintedFailure(@library.HintedString::new(message))
}

///|
/// Execute a compilation command.
async fn compile(args : CompileArgs) -> Unit {
  let config = CompileConfig::new(args)
  let world = SystemWorld::new(Some(args.input), args.world, args.process) catch {
    err => raise bail("\{err}")
  }
  compile_once(world, config)
}

///|
/// A preprocessed `CompileCommand`.
priv struct CompileConfig {
  /// Static warnings to emit after compilation.
  warnings : Array[@library.HintedString]
  /// Whether we are watching.
  watching : Bool
  /// Whether to clear the terminal on recompilation (only while watching).
  fullscreen : Bool
  /// Path to input Typst file or stdin.
  input : Input
  /// Path to output file (PDF, PNG, SVG, or HTML).
  output : Output
  /// The format of the output file.
  output_format : OutputFormat
  /// Whether to make the serialized document pretty.
  pretty : Bool?
  /// Which pages to export.
  pages : @library.PageRanges?
  /// The document's creation date formatted as a UNIX timestamp, with UTC
  /// suffix.
  creation_timestamp : @kit.UtcDateTime?
  /// The format to emit diagnostics in.
  diagnostic_format : @kit.DiagnosticFormat
  /// Opens the output file with the default viewer or a specific program
  /// after compilation.
  open : String??
  /// A list of standards the PDF should conform to.
  pdf_standards : @library.PdfStandards?
  /// Whether to write PDF (accessibility) tags.
  tagged : Bool?
  /// A destination to write a list of dependencies to.
  deps : Output?
  /// The format to use for dependencies.
  deps_format : DepsFormat
  /// The PPI (pixels per inch) to use for PNG export.
  ppi : Double?
  /// The export cache for images, used for caching output files in `typst
  /// watch` sessions with images.
  export_cache : ExportCache
}

///|
/// Rust's `Path::extension`.
fn path_extension(path : String) -> String? {
  guard @platform.file_name(path) is Some(name) else { return None }
  guard name.rev_find(".") is Some(i) else { return None }
  if i == 0 {
    None
  } else {
    Some(name[i + 1:].to_owned())
  }
}

///|
/// Rust's `Path::with_extension`.
fn with_extension(path : String, ext : String) -> String {
  guard @platform.file_name(path) is Some(name) else { return path }
  let stem_len = match name.rev_find(".") {
    Some(i) if i > 0 => i
    _ => name.length()
  }
  // The path up to the end of the file stem.
  let trimmed = trim_trailing_slashes(path)
  let prefix = trimmed[:trimmed.length() - name.length() + stem_len].to_owned()
  if ext == "" {
    prefix
  } else {
    prefix + "." + ext
  }
}

///|
fn trim_trailing_slashes(path : String) -> String {
  let mut end = path.length()
  while end > 1 && path.code_unit_at(end - 1) == '/' {
    end -= 1
  }
  path[:end].to_owned()
}

///|
/// Preprocess a `CompileCommand`, producing a compilation config.
fn CompileConfig::new(args : CompileArgs) -> CompileConfig raise HintedFailure {
  CompileConfig::new_impl(args, None)
}

///|
/// Preprocess a `WatchCommand`, producing a compilation config.
// Only `watch` calls it (watch.rs:21), which not every target has
// (`watch_unsupported.mbt`).
#warnings("-unused_value")
fn CompileConfig::watching(
  command : WatchCommand,
) -> CompileConfig raise HintedFailure {
  CompileConfig::new_impl(command.args, Some(command))
}

///|
/// The shared implementation of [`CompileConfig::new`] and
/// [`CompileConfig::watching`].
fn CompileConfig::new_impl(
  args : CompileArgs,
  watch : WatchCommand?,
) -> CompileConfig raise HintedFailure {
  let warnings = []
  let input = args.input
  let output_format = match args.format {
    Some(specified) => specified
    None =>
      match args.output {
        Some(Path(output)) =>
          match path_extension(output).map(e => e.to_lower()) {
            Some("pdf") => Pdf
            Some("png") => Png
            Some("svg") => Svg
            Some("html") => Html
            _ =>
              raise bail(
                "could not infer output format for path \{output}.\nconsider providing the format manually with `--format/-f`",
              )
          }
        _ => Pdf
      }
  }
  let output = match args.output {
    Some(output) => output
    None => {
      guard input is Path(path) else {
        panic() // output must be specified when input is from stdin, as guarded by the CLI
      }
      Path(
        with_extension(
          path,
          match output_format {
            Pdf => "pdf"
            Png => "png"
            Svg => "svg"
            Html => "html"
            Bundle => ""
          },
        ),
      )
    }
  }
  let pages = args.pages.map(ranges => @library.PageRanges(ranges))
  if args.no_pdf_tags {
    warnings.push(
      @library.HintedString::new(
        "`--no-pdf-tags` is deprecated, use `--pdf-tagged=false` instead",
      ),
    )
  }
  let tagged = match args.pdf_tagged {
    Some(tagged) => {
      if tagged && pages is Some(_) {
        raise bail("cannot enable PDF tags when exporting a page range")
      }
      Some(tagged)
    }
    None => {
      if output_format == Pdf && pages is Some(_) && !args.no_pdf_tags {
        warnings.push(
          @library.HintedString::new(
            "using `--pages` implies `--pdf-tagged=false`",
          )
          .with_hint("the resulting PDF will be inaccessible")
          .with_hint("add `--pdf-tagged=false` to silence this warning"),
        )
      }
      if args.no_pdf_tags || pages is Some(_) {
        Some(false)
      } else {
        None
      }
    }
  }
  if tagged == Some(false) {
    let accessible : Array[(@library.PdfStandard, String)] = [
      (A_1a, "PDF/A-1a"),
      (A_2a, "PDF/A-2a"),
      (A_3a, "PDF/A-3a"),
      (UA_1, "PDF/UA-1"),
    ]
    for entry in accessible {
      let (standard, name) = entry
      if args.pdf_standard.contains(standard) {
        if args.no_pdf_tags {
          raise bail(
            "cannot disable PDF tags when exporting a \{name} document",
          )
        } else {
          let err = @library.HintedString::new(
            "cannot disable PDF tags when exporting a \{name} document",
          )
          if args.pages is Some(_) {
            err.hint("using --pages implies --pdf-tagged=false")
          }
          raise HintedFailure(err)
        }
      }
    }
  }
  let pdf_standards = if args.pdf_standard.is_empty() {
    None
  } else {
    Some(
      @library.PdfStandards::new(args.pdf_standard[:]) catch {
        @library.HintedError(err) => raise HintedFailure(err)
      },
    )
  }
  let fullscreen = match watch {
    Some(command) => !command.no_fullscreen
    None => true
  }
  let mut deps = args.deps
  let mut deps_format = args.deps_format
  if args.make_deps is Some(path) && deps is None {
    deps = Some(Path(path))
    deps_format = Make
    warnings.push(
      @library.HintedString::new(
        "--make-deps is deprecated, use --deps and --deps-format instead",
      ),
    )
  }
  match (output, deps, watch) {
    (Stdout, _, Some(_)) =>
      raise bail("cannot write document to stdout in watch mode")
    (_, Some(Stdout), Some(_)) =>
      raise bail("cannot write dependencies to stdout in watch mode")
    (Stdout, Some(Stdout), _) =>
      raise bail("cannot write both output and dependencies to stdout")
    _ => ()
  }
  // Not ported: upstream serves the HTML or the bundle over HTTP while
  // watching (compile.rs:217, its `http-server` feature; the server is
  // created before the checks above).
  if watch is Some(command) &&
    !command.server.no_serve &&
    output_format is (Html | Bundle) {
    raise bail(
      "the built-in HTTP server for HTML export is not supported by this build; pass `--no-serve`",
    )
  }
  let creation_timestamp = match args.world.creation_timestamp {
    Some(time) =>
      match @kit.UtcDateTime::from_timestamp(time) {
        Some(dt) => Some(dt)
        None => raise bail("creation timestamp is out of range")
      }
    None => None
  }
  // Not possible on all platforms of this port (wasm can only write text).
  if output is Stdout &&
    output_format is (Pdf | Png) &&
    !@platform.supports_binary_stdout() {
    raise bail(
      "cannot write binary output to stdout on this platform; specify an output file",
    )
  }
  // Not supported by this port (upstream writes a JSON trace).
  if args.timings is Some(_) {
    raise bail(
      "performance timings (`--timings`) are not supported by this build",
    )
  }
  {
    warnings,
    watching: watch is Some(_),
    input,
    output,
    output_format,
    pretty: args.pretty,
    pages,
    pdf_standards,
    tagged,
    creation_timestamp,
    ppi: args.ppi,
    diagnostic_format: args.process.diagnostic_format,
    open: args.open,
    export_cache: ExportCache::new(),
    deps,
    deps_format,
    fullscreen,
  }
}

///|
/// Compile a single time.
///
/// Returns whether it compiled without errors.
async fn compile_once(world : SystemWorld, config : CompileConfig) -> Unit {
  let start = @platform.monotonic_nanos()
  if config.watching {
    Status::Compiling.print(config)
  }
  let warned = compile_and_export(world, config)
  let warnings : Array[@library.SourceDiagnostic] = warned.warnings.copy()

  // Add static warnings (for deprecated CLI flags and such).
  for warning in config.warnings {
    warnings.push(warning.into_warning_at(@syntax.Span::detached()))
  }
  match warned.output {
    // Print success message and possibly warnings.
    Ok(_) => {
      // (Not negative: the clock of the wasm targets is the wall clock.)
      let elapsed = @platform.monotonic_nanos() - start
      let duration = if elapsed < 0L { 0L } else { elapsed }
      if config.watching {
        if warnings.is_empty() {
          Status::Success(duration).print(config)
        } else {
          Status::PartialSuccess(duration).print(config)
        }
      }
      print_diagnostics(world, [], warnings, config.diagnostic_format) catch {
        err => raise bail("failed to print diagnostics (\{err})")
      }
      open_output(config)
    }

    // Print failure message and diagnostics.
    Err(errors) => {
      set_failed()
      if config.watching {
        Status::Error.print(config)
      }
      print_diagnostics(world, errors, warnings, config.diagnostic_format) catch {
        err => raise bail("failed to print diagnostics (\{err})")
      }
    }
  }
  if config.deps is Some(dest) {
    let outputs = match warned.output {
      Ok(outputs) => Some(outputs)
      Err(_) => None
    }
    write_deps(world, dest, config.deps_format, outputs) catch {
      err => raise bail("failed to create dependency file (\{err})")
    }
  }
}

///|
/// `Warned::and_then`: chains a computation, collecting warnings.
async fn[T] and_then(
  warned : @library.Warned[Result[T, Array[@library.SourceDiagnostic]]],
  f : async (T) -> @library.Warned[
    Result[Array[Output], Array[@library.SourceDiagnostic]],
  ],
) -> @library.Warned[Result[Array[Output], Array[@library.SourceDiagnostic]]] {
  match warned.output {
    Ok(value) => {
      let next = f(value)
      { output: next.output, warnings: [..warned.warnings, ..next.warnings], }
    }
    Err(errors) => { output: Err(errors), warnings: warned.warnings, }
  }
}

///|
/// A plain result as a warned result.
fn plain(
  result : Result[Array[Output], Array[@library.SourceDiagnostic]],
) -> @library.Warned[Result[Array[Output], Array[@library.SourceDiagnostic]]] {
  { output: result, warnings: [], }
}

///|
/// An error at a detached span (`.at(Span::detached())`).
fn detached_error(message : String) -> Array[@library.SourceDiagnostic] {
  [@library.SourceDiagnostic::error(@syntax.DiagSpan::detached(), message)]
}

///|
/// Compile and then export the document.
async fn compile_and_export(
  world : SystemWorld,
  config : CompileConfig,
) -> @library.Warned[Result[Array[Output], Array[@library.SourceDiagnostic]]] {
  match config.output_format {
    Pdf | Png | Svg => {
      let compiled : @library.Warned[
        Result[@layout.PagedDocument, Array[@library.SourceDiagnostic]],
      ] = @typst.compile(world)
      and_then(compiled, document => export_paged(document, config))
    }
    Html => {
      let compiled : @library.Warned[
        Result[@html.HtmlDocument, Array[@library.SourceDiagnostic]],
      ] = @typst.compile(world)
      and_then(compiled, document => {
        plain(
          try export_html(document, config) catch {
            @library.SourceError(errors) => Err(errors)
          } noraise {
            _ => Ok([config.output])
          },
        )
      })
    }
    Bundle => {
      let compiled : @library.Warned[
        Result[@bundle.Bundle, Array[@library.SourceDiagnostic]],
      ] = @typst.compile(world)
      and_then(compiled, bundle => export_bundle(bundle, config))
    }
  }
}

///|
/// Export to HTML.
async fn export_html(
  document : @html.HtmlDocument,
  config : CompileConfig,
) -> Unit raise @library.SourceError {
  let options = html_options(config)
  let html = @html.html(document, options)
  config.output.write(@utf8.encode(html)) catch {
    err =>
      raise @library.SourceError(
        detached_error("failed to write HTML file (\{err})"),
      )
  }
}

///|
/// Export to a paged target format.
async fn export_paged(
  document : @layout.PagedDocument,
  config : CompileConfig,
) -> @library.Warned[Result[Array[Output], Array[@library.SourceDiagnostic]]] {
  match config.output_format {
    Pdf => {
      let exported = export_pdf(document, config)
      {
        output: exported.output.map(_ => [config.output]),
        warnings: exported.warnings,
      }
    }
    Png =>
      plain(
        export_image(document, config, Png) catch {
          @kit.StrError(msg) => Err(detached_error(msg))
        },
      )
    Svg =>
      plain(
        export_image(document, config, Svg) catch {
          @kit.StrError(msg) => Err(detached_error(msg))
        },
      )
    Html | Bundle => panic()
  }
}

///|
/// Export to a PDF.
async fn export_pdf(
  document : @layout.PagedDocument,
  config : CompileConfig,
) -> @library.Warned[Result[Unit, Array[@library.SourceDiagnostic]]] {
  let options = pdf_options(config)
  let result = @pdf.pdf(document, options)
  match result.output {
    Ok(buffer) => {
      let output : Result[Unit, Array[@library.SourceDiagnostic]] = try
        config.output.write(buffer)
      catch {
        err => Err(detached_error("failed to write PDF file (\{err})"))
      } noraise {
        _ => Ok(())
      }
      { output, warnings: result.warnings, }
    }
    Err(errors) => { output: Err(errors), warnings: result.warnings, }
  }
}

///|
/// Export to a bundle, a collection of files in a directory.
fn export_bundle(
  bundle : @bundle.Bundle,
  config : CompileConfig,
) -> @library.Warned[Result[Array[Output], Array[@library.SourceDiagnostic]]] {
  let pdf_opts = pdf_options(config)
  let png_opts = png_options(config)
  let options : @bundle.BundleOptions = {
    html: html_options(config),
    pdf: Some((doc, anchors, resolver) => {
      @pdf.pdf_in_bundle(doc, pdf_opts, anchors, resolver)
    }),
    png: Some(doc => bundle_png(doc, png_opts)),
    svg: svg_options(config),
  }
  let exported = @bundle.export_bundle(bundle, options)
  let output = match exported.output {
    Err(errors) => Err(errors)
    Ok(fs) =>
      match config.output {
        Stdout => Err(detached_error("cannot write bundle to standard output"))
        Path(root) =>
          write_virtual_fs(root, fs) catch {
            @kit.StrError(msg) => Err(detached_error(msg))
          }
      }
  }
  { output, warnings: exported.warnings, }
}

///|
/// Exports a PNG document of a bundle (`typst-bundle`'s `export_png`).
fn bundle_png(
  doc : @layout.PagedDocument,
  options : @render.RenderOptions,
) -> Bytes raise @library.SourceError {
  let options = options.resolve(@render.PngFormatOptions::get(doc.options()))
  let pixmap = @render.render(doc.pages()[0], options) catch {
    @render.RenderPanic(msg) => raise @library.SourceError(detached_error(msg))
  }
  pixmap.encode_png()
}

///|
/// Writes a bundle's files to disk.
fn write_virtual_fs(
  root : String,
  fs : @bundle.VirtualFs,
) -> Result[Array[Output], Array[@library.SourceDiagnostic]] raise @kit.StrError {
  @platform.create_dir_all(root) catch {
    err => raise @kit.StrError("failed to create output directory (\{err})")
  }
  let outputs = []
  for path, data in fs {
    let realized = path.realize(root) catch {
      err => raise @kit.StrError("failed to realize path (\{err})")
    }
    if @platform.parent(realized) is Some(parent) {
      @platform.create_dir_all(parent) catch {
        err => raise @kit.StrError("failed to create directory (\{err})")
      }
    }
    @platform.write_file(realized, data.as_slice()) catch {
      err => raise @kit.StrError("failed to write file (\{err})")
    }
    outputs.push(Output::Path(realized))
  }
  Ok(outputs)
}

///|
/// Convert a UTC date and time to a `Datetime`.
fn convert_datetime(dt : @kit.UtcDateTime) -> @library.Datetime? {
  @library.Datetime::from_ymd_hms(
    dt.year,
    dt.month,
    dt.day,
    dt.hour,
    dt.minute,
    dt.second,
  )
}

///|
/// An image format to export in.
priv enum ImageExportFormat {
  Png
  Svg
}

///|
/// Export to one or multiple images.
async fn export_image(
  document : @layout.PagedDocument,
  config : CompileConfig,
  fmt : ImageExportFormat,
) -> Result[Array[Output], Array[@library.SourceDiagnostic]] raise @kit.StrError {
  match fmt {
    Png => {
      let options = png_options(config).resolve(
        @render.PngFormatOptions::get(document.options()),
      )
      export_image_pages(config, document, (page, output) => {
        let pixmap = @render.render(page, options) catch {
          @render.RenderPanic(msg) => raise @kit.StrError(msg)
        }
        let buf = pixmap.encode_png()
        output.write(buf) catch {
          err => raise @kit.StrError("failed to write PNG file (\{err})")
        }
      })
    }
    Svg => {
      let options = svg_options(config).resolve(
        @svg.SvgFormatOptions::get(document.options()),
      )
      export_image_pages(config, document, (page, output) => {
        let svg = @svg.svg(page, options)
        output.write(@utf8.encode(svg)) catch {
          err => raise @kit.StrError("failed to write SVG file (\{err})")
        }
      })
    }
  }
}

///|
/// Exports the document's pages as separate images, each exported with a
/// format-specific `export_image_page` function.
async fn export_image_pages(
  config : CompileConfig,
  document : @layout.PagedDocument,
  export_image_page : async (@layout.Page, Output) -> Unit raise @kit.StrError,
) -> Result[Array[Output], Array[@library.SourceDiagnostic]] raise @kit.StrError {
  // Determine whether we have indexable templates in output
  let can_handle_multiple = match config.output {
    Stdout => false
    Path(output) => has_indexable_template(output)
  }
  let pages = document.pages()
  let exported_pages = []
  for i, page in pages {
    if config.pages is Some(ranges) && !ranges.includes_page(i + 1) {
      continue
    }
    exported_pages.push((i, page))
  }
  if !can_handle_multiple && exported_pages.length() > 1 {
    let err = match config.output {
      Stdout => "to stdout"
      Path(_) => "without a page number template ({p}, {0p}) in the output path"
    }
    raise @kit.StrError("cannot export multiple images \{err}")
  }
  let outputs = []
  for entry in exported_pages {
    let (i, page) = entry
    // Use output with converted path.
    let output = match config.output {
      Path(path) => {
        let path = if can_handle_multiple {
          format_template(path, i + 1, pages.length())
        } else {
          path
        }

        // If we are not watching, don't use the cache.
        // If the frame is in the cache, skip it.
        // If the file does not exist, always create it.
        if config.watching &&
          config.export_cache.is_cached(i, page) &&
          @platform.exists(path) {
          outputs.push(Output::Path(path))
          continue
        }
        Output::Path(path)
      }
      Stdout => Stdout
    }
    export_image_page(page, output)
    outputs.push(output)
  }
  Ok(outputs)
}

///|
let indexable_templates : ReadOnlyArray[String] = ["{p}", "{0p}", "{n}"]

///|
fn has_indexable_template(output : String) -> Bool {
  indexable_templates.any(template => output.contains(template))
}

///|
fn format_template(
  output : String,
  this_page : Int32,
  total_pages : Int32,
) -> String {
  // Find the base 10 width of number `i`
  let width = (i : Int32) => {
    let mut digits = 1
    let mut n = i
    while n >= 10 {
      n /= 10
      digits += 1
    }
    digits
  }
  let mut out = output
  for template in ["{p}", "{0p}", "{n}", "{t}"] {
    let replacement = match template {
      "{p}" => this_page.to_string()
      "{0p}" | "{n}" => {
        let s = this_page.to_string()
        let w = width(total_pages)
        if s.length() < w {
          "0".repeat(w - s.length()) + s
        } else {
          s
        }
      }
      _ => total_pages.to_string()
    }
    out = out.replace_all(old=template, new=replacement)
  }
  out
}

///|
/// Creates options for HTML export.
fn html_options(config : CompileConfig) -> @html.HtmlOptions {
  { format: { pretty: config.pretty, }, }
}

///|
/// Creates options for PDF export.
fn pdf_options(config : CompileConfig) -> @pdf.PdfOptions {
  // If the timestamp is provided through the CLI, use UTC suffix, else, use
  // the current local time and timezone.
  let timestamp = match config.creation_timestamp {
    Some(timestamp) => convert_datetime(timestamp).map(@pdf.Timestamp::new_utc)
    None => {
      let secs = @platform.now_ms() / 1000L
      let offset = @platform.local_offset(secs)
      guard @kit.UtcDateTime::from_timestamp(secs + offset.to_int64())
        is Some(local_dt) else {
        return pdf_options_with(config, None)
      }
      convert_datetime(local_dt).bind(datetime => {
        @pdf.Timestamp::new_local(datetime, offset / 60)
      })
    }
  }
  pdf_options_with(config, timestamp)
}

///|
fn pdf_options_with(
  config : CompileConfig,
  timestamp : @pdf.Timestamp?,
) -> @pdf.PdfOptions {
  {
    ident: Auto,
    creator: Auto,
    timestamp,
    format: {
      pages: config.pages.map(p => Some(p)),
      standard: config.pdf_standards,
      tagged: config.tagged.map(t => @library.Smart::Custom(t)),
      pretty: config.pretty,
    },
  }
}

///|
/// Creates options for SVG export.
fn svg_options(config : CompileConfig) -> @svg.SvgOptions {
  { render_bleed: false, format: { pretty: config.pretty, }, }
}

///|
/// Creates options for PNG export.
fn png_options(config : CompileConfig) -> @render.RenderOptions {
  { render_bleed: false, format: { ppi: config.ppi, }, }
}

///|
/// Caches exported files so that we can avoid re-exporting them if they
/// haven't changed.
///
/// This is done by having a list of size `files.len()` that contains the
/// hashes of the last rendered frame in each file. If a new frame is
/// inserted, this will invalidate the rest of the cache, this is deliberate
/// as to decrease the complexity and memory usage of such a cache.
priv struct ExportCache {
  /// The hashes of last compilation's frames.
  cache : Array[@library.U128]
}

///|
/// Creates a new export cache.
fn ExportCache::new() -> ExportCache {
  { cache: Array(capacity=32), }
}

///|
/// Returns true if the entry is cached and appends the new hash to the
/// cache (for the next compilation).
fn ExportCache::is_cached(
  self : ExportCache,
  i : Int32,
  page : @layout.Page,
) -> Bool {
  let hash = @library.hash128(page)
  if i >= self.cache.length() {
    self.cache.push(hash)
    return false
  }
  let cached = self.cache[i]
  self.cache[i] = hash
  cached == hash
}

///|
/// Opens the output if desired.
fn open_output(config : CompileConfig) -> Unit raise HintedFailure {
  guard config.open is Some(_) else { return }
  // Can't open stdout.
  guard config.output is Path(_) else { return }
  raise bail("opening the output (`--open`) is not supported by this build")
}

///|
/// Print diagnostic messages to the terminal.
async fn print_diagnostics(
  world : &@kit.DiagnosticWorld,
  errors : Array[@library.SourceDiagnostic],
  warnings : Array[@library.SourceDiagnostic],
  format : @kit.DiagnosticFormat,
) -> Unit {
  let out = terminal_out()
  @kit.emit_diagnostics(out, world, [..errors, ..warnings], format)
  flush_terminal(out)
}
