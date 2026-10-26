///|
priv struct PathConfig {
  mut colors : ColorSpecs
  mut hyperlink : HyperlinkConfig
  mut separator : Byte?
  mut terminator : Byte
}

///|
/// A builder for a printer that emits file paths.
pub struct PathPrinterBuilder {
  priv config : PathConfig
}

///|
/// Return a new path printer builder with a default configuration.
pub fn PathPrinterBuilder::new() -> PathPrinterBuilder {
  {
    config: {
      colors: ColorSpecs::default(),
      hyperlink: HyperlinkConfig::default(),
      separator: None,
      terminator: b'\n',
    },
  }
}

///|
/// Create a new path printer with the current configuration that writes
/// paths to the given writer.
pub fn PathPrinterBuilder::build(
  self : PathPrinterBuilder,
  wtr : &@termcolor.WriteColor,
) -> PathPrinter {
  let interpolator = Interpolator::new(self.config.hyperlink)
  { config: { ..self.config, }, wtr, interpolator, }
}

///|
/// Set the user color specifications to use for coloring in this printer.
pub fn PathPrinterBuilder::color_specs(
  self : PathPrinterBuilder,
  specs : ColorSpecs,
) -> PathPrinterBuilder {
  self.config.colors = specs
  self
}

///|
/// Set the configuration to use for hyperlinks output by this printer.
pub fn PathPrinterBuilder::hyperlink(
  self : PathPrinterBuilder,
  config : HyperlinkConfig,
) -> PathPrinterBuilder {
  self.config.hyperlink = config
  self
}

///|
/// Set the path separator used when printing file paths.
pub fn PathPrinterBuilder::separator(
  self : PathPrinterBuilder,
  sep : Byte?,
) -> PathPrinterBuilder {
  self.config.separator = sep
  self
}

///|
/// Set the path terminator used (`\n` by default).
pub fn PathPrinterBuilder::terminator(
  self : PathPrinterBuilder,
  terminator : Byte,
) -> PathPrinterBuilder {
  self.config.terminator = terminator
  self
}

///|
/// A printer file paths, with optional color and hyperlink support.
pub struct PathPrinter {
  priv config : PathConfig
  priv wtr : &@termcolor.WriteColor
  priv interpolator : Interpolator
}

///|
/// Write the given path to the underlying writer.
pub async fn PathPrinter::write(self : PathPrinter, path : String) -> Unit {
  let ppath = PrinterPath::new(path).with_separator(self.config.separator)
  if !self.wtr.supports_color() {
    @termcolor.Write::write_bytes(self.wtr, ppath.bytes)
  } else {
    let status = self.start_hyperlink(ppath)
    self.wtr.set_color(self.config.colors.path())
    @termcolor.Write::write_bytes(self.wtr, ppath.bytes)
    self.wtr.reset()
    self.interpolator.finish(status, self.wtr)
  }
  @termcolor.Write::write_bytes(self.wtr, [self.config.terminator])
}

///|
async fn PathPrinter::start_hyperlink(
  self : PathPrinter,
  path : PrinterPath,
) -> Bool {
  guard path.as_hyperlink(self.config.hyperlink.env) is Some(hyperpath) else {
    return false
  }
  let values = Values::new(hyperpath)
  self.interpolator.begin(values, self.wtr)
}

///|
/// Returns the underlying writer.
pub fn PathPrinter::get_mut(self : PathPrinter) -> &@termcolor.WriteColor {
  self.wtr
}
