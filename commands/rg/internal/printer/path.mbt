///|
priv struct PathConfig {
  colors : ColorSpecs
  hyperlink : HyperlinkConfig
  separator : Byte?
  terminator : Byte
}

///|
/// Configure once before writing any paths.
pub fn PathPrinter::new(
  wtr : &@termcolor.WriteColor,
  colors~ : ColorSpecs = ColorSpecs::default(),
  hyperlink~ : HyperlinkConfig = HyperlinkConfig::default(),
  separator~ : Byte? = None,
  terminator~ : Byte = b'\n',
) -> PathPrinter {
  {
    config: { colors, hyperlink, separator, terminator, },
    wtr,
    interpolator: Interpolator::new(hyperlink),
  }
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
