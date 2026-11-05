// Font loading and management (upstream `typst_kit::fonts`).
//
// This provides implementations to discover fonts [in directories](scan)
// and [from system](system) and can also serve standard [embedded] fonts.

///|
/// Holds loaded fonts.
///
/// Fonts can be added with [`push`](Self::push) and
/// [`extend_all`](Self::extend_all).
/// The three top-level font provider functions in this module can directly
/// be used with [`FontStore::extend_all`] (upstream `extend`).
///
/// Font are added in-order. The indices in the font book and those that
/// should be passed to [`source`](Self::source) and [`font`](Self::font)
/// match this order.
pub struct FontStore {
  priv book : @library.FontBook
  priv slots : Array[FontSlot]
}

///|
/// Creates a new empty font store.
pub fn FontStore::new() -> FontStore {
  { book: @library.FontBook::new(), slots: [], }
}

///|
/// Adds a new entry to the store.
pub fn FontStore::push(
  self : FontStore,
  entry : (FontSource, @library.FontInfo),
) -> Unit {
  self.book.push(entry.1)
  self.slots.push({ source: entry.0, font: Unloaded, })
}

///|
/// Adds multiple new entries to the store.
pub fn FontStore::extend_all(
  self : FontStore,
  entries : Array[(FontSource, @library.FontInfo)],
) -> Unit {
  for entry in entries {
    self.push(entry)
  }
}

///|
/// Provides metadata for the added fonts.
///
/// Can directly be used to implement `World::book`.
pub fn FontStore::book(self : FontStore) -> @library.FontBook {
  self.book
}

///|
/// Retrieves the font at the given index.
///
/// Loads the font if it's not already loaded.
///
/// Can directly be used to implement `World::font`.
pub fn FontStore::font(self : FontStore, index : Int32) -> @library.Font? {
  guard index >= 0 && index < self.slots.length() else { return None }
  self.slots[index].get()
}

///|
/// Retrieves the underlying font source for the font with this index.
pub fn FontStore::source(self : FontStore, index : Int32) -> FontSource? {
  guard index >= 0 && index < self.slots.length() else { return None }
  Some(self.slots[index].source)
}

///|
/// The number of fonts in the store.
pub fn FontStore::len(self : FontStore) -> Int32 {
  self.slots.length()
}

///|
/// The loading state of a font slot.
priv enum FontState {
  Unloaded
  Loading
  Ready(@library.Font?)
}

///|
/// Holds a font source and the lazily loaded font itself.
priv struct FontSlot {
  source : FontSource
  mut font : FontState
}

///|
/// Get the font for this slot. This loads the font into memory on first
/// access.
fn FontSlot::get(self : FontSlot) -> @library.Font? {
  match self.font {
    Ready(font) => font
    // A recursive load (which cannot happen) fails.
    Loading => None
    Unloaded => {
      self.font = Loading
      let font = self.source.load()
      self.font = Ready(font)
      font
    }
  }
}

///|
/// Serves a font on-demand (upstream `FontSource`: a loaded `Font` or a
/// `FontPath`).
pub(all) enum FontSource {
  /// A font that is already loaded (e.g. an embedded font).
  Loaded(@library.Font)
  /// Locates a font on the file system (upstream `FontPath`): the path at
  /// which the font or font collection resides and the index in the font
  /// collection, or zero if the path points to a single font rather than a
  /// collection.
  Path(path~ : String, index~ : UInt32)
}

///|
/// Try to load the font.
pub fn FontSource::load(self : FontSource) -> @library.Font? {
  match self {
    Loaded(font) => Some(font)
    Path(path~, index~) => {
      let data = @platform.read_file(path) catch { _ => return None }
      @library.Font::from_data(data, index)
    }
  }
}

///|
/// Yields the embedded fonts.
///
/// - For Text: _Libertinus Serif_, _New Computer Modern_
/// - For Math: _New Computer Modern Math_
/// - For Code: _Deja Vu Sans Mono_
pub fn embedded() -> Array[(FontSource, @library.FontInfo)] {
  let out = []
  for data in @assets_fonts.fonts() {
    for font in @library.Font::iter(data) {
      out.push((FontSource::Loaded(font), font.info()))
    }
  }
  out
}

///|
/// Discovers system fonts.
///
/// This searches in operating-system dependent standard font locations.
pub async fn system() -> Array[(FontSource, @library.FontInfo)] {
  with_db(db => {
    db.load_system_fonts()

    // Add Adobe Fonts on Windows and macOS.
    if @platform.os() != Linux {
      load_adobe_fonts(db)
    }
  })
}

///|
/// Scans for fonts in a directory.
///
/// The directory is searched recursively.
pub async fn scan(path : String) -> Array[(FontSource, @library.FontInfo)] {
  with_db(db => db.load_fonts_dir(path))
}

///|
/// Discovers fonts via the font database.
async fn with_db(
  f : async (FontDb) -> Unit,
) -> Array[(FontSource, @library.FontInfo)] {
  let db = FontDb::new()
  f(db)
  db.faces.map(face => {
    (FontSource::Path(path=face.path, index=face.index), face.info)
  })
}

///|
/// Loads Adobe fonts available on the system. Only supported on Windows and
/// macOS.
///
/// This is permissible as per Clause 3.1 (A) of the
/// [Adobe Fonts Service Product Specific Terms][terms].
///
/// [terms]: https://wwwimages2.adobe.com/content/dam/cc/en/legal/servicetou/Adobe-Fonts-Product-Specific-Terms-en_US-20241007.pdf
async fn load_adobe_fonts(db : FontDb) -> Unit {
  guard data_dir() is Some(data) else { return }
  let base = @platform.join(data, "Adobe")
  let prefix = if @platform.os() == MacOs { "." } else { "" }
  let subdirs = [
    "CoreSync/plugins/livetype/\{prefix}r",
    "\{prefix}User Owned Fonts",
  ]
  for subdir in subdirs {
    let dir = @platform.join(base, subdir)
    let entries = @fs.readdir(dir, sort=false) catch { _ => return }
    for name in entries {
      let path = @platform.join(dir, name)
      // Adobe fonts are stored as files (directories are skipped).
      if (font_stat_kind(path) catch { _ => Other }) == File {
        db.load_font_file(path)
      }
    }
  }
}

///|
/// Attempts to load system fonts (`Database::load_system_fonts`).
///
/// This scans some predefined, operating-system dependent directories.
async fn FontDb::load_system_fonts(self : FontDb) -> Unit {
  match @platform.os() {
    Windows => {
      let seen = @hashset.HashSet([])
      match @platform.env_var("SYSTEMROOT") {
        Some(system_root) =>
          self.load_fonts_dir_impl(@platform.join(system_root, "Fonts"), seen)
        None => self.load_fonts_dir_impl("C:\\Windows\\Fonts\\", seen)
      }
      if @platform.env_var("USERPROFILE") is Some(home) {
        self.load_fonts_dir_impl(
          @platform.join(home, "AppData\\Local\\Microsoft\\Windows\\Fonts"),
          seen,
        )
        self.load_fonts_dir_impl(
          @platform.join(home, "AppData\\Roaming\\Microsoft\\Windows\\Fonts"),
          seen,
        )
      }
    }
    MacOs => {
      let seen = @hashset.HashSet([])
      self.load_fonts_dir_impl("/Library/Fonts", seen)
      self.load_fonts_dir_impl("/System/Library/Fonts", seen)
      // Downloadable fonts, location varies on major macOS releases
      let assets = @fs.readdir("/System/Library/AssetsV2", sort=false) catch {
        _ => []
      }
      for name in assets {
        if name.has_prefix("com_apple_MobileAsset_Font") {
          self.load_fonts_dir_impl(
            @platform.join("/System/Library/AssetsV2", name),
            seen,
          )
        }
      }
      self.load_fonts_dir_impl("/Network/Library/Fonts", seen)
      if @platform.env_var("HOME") is Some(home) {
        self.load_fonts_dir_impl(@platform.join(home, "Library/Fonts"), seen)
      }
    }
    Linux => if !self.load_fontconfig() { self.load_no_fontconfig() }
  }
}

///|
/// Loads fonts from the known font directories of Linux
/// (`Database::load_no_fontconfig`).
async fn FontDb::load_no_fontconfig(self : FontDb) -> Unit {
  let seen = @hashset.HashSet([])
  self.load_fonts_dir_impl("/usr/share/fonts/", seen)
  self.load_fonts_dir_impl("/usr/local/share/fonts/", seen)
  if @platform.env_var("HOME") is Some(home) {
    self.load_fonts_dir_impl(@platform.join(home, ".fonts"), seen)
    self.load_fonts_dir_impl(@platform.join(home, ".local/share/fonts"), seen)
  }
}
