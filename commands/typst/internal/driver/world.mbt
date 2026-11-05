// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// The world of the CLI (upstream `typst-cli/src/world.rs`).

///|
/// A world that provides access to the operating system.
priv struct SystemWorld {
  /// The working directory.
  workdir : String?
  /// Typst's standard library.
  library : @library.Library
  /// Metadata about discovered fonts and lazily loaded fonts.
  fonts : @kit.FontStore
  /// Maps file ids to source files and buffers.
  files : @kit.FileStore[SystemFiles]
  /// The current datetime if requested. This is stored here to ensure it is
  /// always the same within one compilation.
  /// Reset between compilations if not [`Time::Fixed`].
  now : @kit.Time
}

///|
/// An error that occurs during world construction.
priv suberror WorldCreationError {
  /// The input file does not appear to exist.
  InputNotFound(String)
  /// The input file path was malformed.
  InputMalformed(@syntax.VirtualizeError)
  /// The root directory does not appear to exist.
  RootNotFound(String)
  /// The requested creation timestamp was invalid.
  InvalidTimestamp
  /// Another type of I/O error.
  Io(@platform.IoError)
}

///|
impl Show for WorldCreationError with fn output(self, logger) {
  match self {
    InputMalformed(err) =>
      match err {
        Path(Escapes) =>
          logger.write_string("source file must be contained in project root")
        Path(Backslash) =>
          logger.write_string("source path must not contain a backslash")
        Invalid(s) =>
          logger.write_string(
            "source path contains invalid sequence `\{@library.repr_str(s)}`",
          )
        Utf8 => logger.write_string("source path must be valid UTF-8")
      }
    InputNotFound(path) =>
      logger.write_string("input file not found (searched at \{path})")
    RootNotFound(path) =>
      logger.write_string("root directory not found (searched at \{path})")
    InvalidTimestamp => logger.write_string("creation timestamp out of range")
    Io(err) => logger.write_string(err.to_string())
  }
}

///|
/// Creates a new system world.
async fn SystemWorld::new(
  input : Input?,
  world_args : WorldArgs,
  process_args : ProcessArgs,
) -> SystemWorld raise WorldCreationError {
  let library = {
    // Convert the input pairs to a dictionary.
    let inputs = @library.Dict::new()
    for pair in world_args.inputs {
      inputs.insert(pair.0, Str(pair.1))
    }
    let features = @library.Features(process_args.features)
    @typst.library_builder([
      @library.html_format(),
      @library.pdf_format(),
      @library.svg_format(),
      @library.png_format(),
      @library.bundle_format(),
    ])
    .with_inputs(inputs)
    .with_features(features)
    .build()
  }
  let now = match world_args.creation_timestamp {
    Some(time) =>
      @kit.Time::fixed_timestamp(time) catch {
        _ => raise InvalidTimestamp
      }
    None => @kit.Time::system()
  }
  let files = @kit.FileStore::new(SystemFiles::new(input, world_args))
  let fonts = discover_fonts(world_args.font) catch {
    err => raise Io(@platform.IoError(Other, err.to_string()))
  }
  { workdir: @platform.current_dir(), library, fonts, files, now, }
}

///|
/// The project root relative to which absolute paths are resolved.
fn SystemWorld::root(self : SystemWorld) -> String {
  self.files.loader().project.path()
}

///|
/// The current working directory.
fn SystemWorld::workdir(self : SystemWorld) -> String {
  self.workdir.unwrap_or(".")
}

///|
/// Return all paths the last compilation depended on.
fn SystemWorld::dependencies(self : SystemWorld) -> Array[String] {
  let loader = self.files.loader()
  let out = []
  for id in self.files.dependencies() {
    try loader.resolve(id) catch {
      _ => ()
    } noraise {
      path => out.push(path)
    }
  }
  out
}

///|
/// Reset the compilation state in preparation of a new compilation.
fn SystemWorld::reset(self : SystemWorld) -> Unit {
  self.files.reset()
  self.now.reset()
}

///|
impl @library.World for SystemWorld with fn library(self) {
  self.library
}

///|
impl @library.World for SystemWorld with fn book(self) {
  self.fonts.book()
}

///|
impl @library.World for SystemWorld with fn main(self) {
  self.files.loader().main
}

///|
impl @library.World for SystemWorld with fn source(self, id) {
  self.files.source(id)
}

///|
impl @library.World for SystemWorld with fn file(self, id) {
  self.files.file(id)
}

///|
impl @library.World for SystemWorld with fn font(self, index) {
  self.fonts.font(index)
}

///|
impl @library.World for SystemWorld with fn today(self, offset) {
  self.now.today(offset)
}

///|
impl @kit.DiagnosticWorld for SystemWorld with fn name(self, id) {
  let vpath = id.vpath()
  match id.root() {
    Project =>
      // Try to express the path relative to the working directory.
      try vpath.realize(self.root()) catch {
        _ => vpath.get_without_slash()
      } noraise {
        rooted =>
          match diff_paths(rooted, self.workdir()) {
            Some(path) => path
            None => vpath.get_without_slash()
          }
      }
    Package(spec) => "\{spec}\{vpath.get_with_slash()}"
  }
}

///|
/// Static `FileId` allocated for stdin. This is to ensure that stdin can
/// live in the project root without colliding with any real on-disk file.
let stdin_id : @syntax.FileId = @syntax.FileId::unique(
  @syntax.RootedPath::new(
    Project,
    @syntax.VirtualPath::new("<stdin>") catch {
      _ => panic()
    },
  ),
)

///|
/// Static `FileId` allocated for empty/no input at all. This is to ensure
/// that we can create a [`SystemWorld`] based on no main file or stdin at
/// all.
let empty_id : @syntax.FileId = @syntax.FileId::unique(
  @syntax.RootedPath::new(
    Project,
    @syntax.VirtualPath::new("<empty>") catch {
      _ => panic()
    },
  ),
)

///|
/// Provides project files from a configured directory and package files
/// from standard locations.
priv struct SystemFiles {
  main : @syntax.FileId
  stdin : Bytes
  project : @kit.FsRoot
  packages : @kit.SystemPackages
}

///|
/// Creates a new loader given the configuration.
async fn SystemFiles::new(
  input : Input?,
  world_args : WorldArgs,
) -> SystemFiles raise WorldCreationError {
  // Resolve the system-global input path.
  let input_path = match input {
    Some(Path(path)) =>
      Some(
        @platform.canonicalize(path) catch {
          err =>
            raise if err.kind() == NotFound {
              InputNotFound(path)
            } else {
              Io(err)
            }
        },
      )
    _ => None
  }

  // Resolve the system-global root directory.
  let root = {
    let path = match world_args.root {
      Some(root) => root
      None =>
        match input_path.bind(@platform.parent) {
          Some(parent) => parent
          None => "."
        }
    }
    @platform.canonicalize(path) catch {
      err =>
        raise if err.kind() == NotFound { RootNotFound(path) } else { Io(err) }
    }
  }
  let main = match input_path {
    Some(path) => {
      // Resolve the virtual path of the main file within the project root.
      let vpath = @syntax.VirtualPath::virtualize(root, path) catch {
        err => raise InputMalformed(err)
      }
      @syntax.RootedPath::new(Project, vpath).intern()
    }
    None =>
      if input is Some(Stdin) {
        // Return the special id of STDIN.
        stdin_id
      } else {
        // Return the special id of EMPTY/no input at all otherwise.
        empty_id
      }
  }
  {
    main,
    stdin: if input is Some(Stdin) {
      @platform.read_stdin() catch {
        err => raise Io(err)
      }
    } else {
      b""
    },
    project: @kit.FsRoot::new(root),
    packages: system_packages(world_args.package_args),
  }
}

///|
/// Resolves the file system path for the given `id`.
fn SystemFiles::resolve(
  self : SystemFiles,
  id : @syntax.FileId,
) -> String raise @library.FileError {
  self.root(id).resolve(id.vpath())
}

///|
/// Resolves the root in which the given file ID resides.
fn SystemFiles::root(
  self : SystemFiles,
  id : @syntax.FileId,
) -> @kit.FsRoot raise @library.FileError {
  match id.root() {
    Project => self.project
    Package(spec) =>
      self.packages.obtain(spec) catch {
        err => raise @library.FileError::Package(err)
      }
  }
}

///|
impl @kit.FileLoader for SystemFiles with fn load(self, id) {
  if id == empty_id {
    b""
  } else if id == stdin_id {
    self.stdin
  } else {
    self.root(id).load(id.vpath())
  }
}

///|
/// Returns a new package storage for the given args
/// (`typst-cli/src/packages.rs`).
fn system_packages(args : PackageArgs) -> @kit.SystemPackages {
  @kit.SystemPackages::from_parts(
    match args.package_path {
      Some(path) => Some(@kit.FsPackages::new(path))
      None => @kit.FsPackages::system_data()
    },
    match args.package_cache_path {
      Some(path) => Some(@kit.FsPackages::new(path))
      None => @kit.FsPackages::system_cache()
    },
  )
}

///|
/// Discovers the fonts as specified by the CLI flags
/// (`typst-cli/src/fonts.rs`).
async fn discover_fonts(args : FontArgs) -> @kit.FontStore {
  let fonts = @kit.FontStore::new()
  if !args.ignore_system_fonts {
    fonts.extend_all(@kit.system())
  }
  if !args.ignore_embedded_fonts {
    fonts.extend_all(@kit.embedded())
  }
  for path in args.font_paths {
    if path is Some(path) {
      fonts.extend_all(@kit.scan(path))
    }
  }
  fonts
}

///|
/// Constructs a relative path from `base` to `path` (`pathdiff::diff_paths`).
fn diff_paths(path : String, base : String) -> String? {
  if @platform.is_absolute(path) != @platform.is_absolute(base) {
    return if @platform.is_absolute(path) { Some(path) } else { None }
  }
  let ita = components(path)
  let itb = components(base)
  // Paths on distinct Windows volumes cannot be made relative.
  if @platform.os() == Windows &&
    ita.get(0) is Some(volume) &&
    volume.has_suffix(":") &&
    ita.get(0) != itb.get(0) {
    return None
  }
  let comps : Array[String] = []
  let mut a = 0
  let mut b = 0
  while true {
    let ca = if a < ita.length() { Some(ita[a]) } else { None }
    let cb = if b < itb.length() { Some(itb[b]) } else { None }
    a += 1
    b += 1
    match (ca, cb) {
      (None, None) => break
      (Some(x), None) => {
        comps.push(x)
        for i in a..<ita.length() {
          comps.push(ita[i])
        }
        break
      }
      (None, _) => comps.push("..")
      (Some(x), Some(y)) if comps.is_empty() && x == y => ()
      (Some(x), Some(".")) => comps.push(x)
      (Some(_), Some("..")) => return None
      (Some(x), Some(_)) => {
        comps.push("..")
        for _ in b..<itb.length() {
          comps.push("..")
        }
        comps.push(x)
        for i in a..<ita.length() {
          comps.push(ita[i])
        }
        break
      }
    }
  }
  Some(comps.join(@platform.separator()))
}

///|
/// The components of a path (Rust's `Path::components`, simplified: the
/// root is a component, empty and inner `.` components are skipped).
fn components(path : String) -> Array[String] {
  let path = if @platform.os() == Windows {
    path.replace_all(old="\\", new="/")
  } else {
    path
  }
  let out = []
  if path.has_prefix("/") {
    out.push("/")
  }
  for i, part in path.split("/").to_array() {
    let part = part.to_owned()
    if part == "" || (part == "." && i > 0) {
      continue
    }
    out.push(part)
  }
  out
}
