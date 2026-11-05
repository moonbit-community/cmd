// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// Package loading (upstream `typst_kit::packages`).
//
// Downloading packages from Typst Universe is not supported by this port
// (there is no network access): packages are served from the package data
// and cache directories only.

///|
/// Serves packages from standard locations.
///
/// In order of priority, this tries to obtain a package from
///
/// - a package data directory (that is intended for system-wide storage of
///   user packages)
/// - a package cache directory (that is intended for caching of
///   automatically downloaded packages)
///
/// Upstream additionally downloads packages of the `preview` namespace from
/// Typst Universe into the cache directory; this port reports them as not
/// found instead.
pub struct SystemPackages {
  priv data : FsPackages?
  priv cache : FsPackages?
}

///|
/// The namespace from which Typst Universe serves packages.
pub let universe_namespace : String = "preview"

///|
/// Creates a new handle that serves packages from the standard
/// environment-defined directories.
pub fn SystemPackages::new() -> SystemPackages {
  SystemPackages::from_parts(
    FsPackages::system_data(),
    FsPackages::system_cache(),
  )
}

///|
/// Creates a new system package loader from custom configured parts.
pub fn SystemPackages::from_parts(
  data : FsPackages?,
  cache : FsPackages?,
) -> SystemPackages {
  { data, cache, }
}

///|
/// Returns a handle to the data package directory.
pub fn SystemPackages::data(self : SystemPackages) -> FsPackages? {
  self.data
}

///|
/// Returns a handle to the cache package directory.
pub fn SystemPackages::cache(self : SystemPackages) -> FsPackages? {
  self.cache
}

///|
/// Returns the file system root from which the given package's content can
/// be loaded.
pub fn SystemPackages::obtain(
  self : SystemPackages,
  spec : @syntax.PackageSpec,
) -> FsRoot raise @library.PackageError {
  if self.data is Some(packages) && packages.obtain(spec) is Some(root) {
    return root
  }
  if self.cache is Some(cache) && cache.obtain(spec) is Some(root) {
    return root
  }
  raise @library.PackageError::NotFound(spec)
}

///|
/// Tries to determine the latest version of a package.
pub fn SystemPackages::latest_version(
  self : SystemPackages,
  spec : @syntax.VersionlessPackageSpec,
) -> @syntax.PackageVersion raise StrError {
  if spec.namespace_ == universe_namespace {
    // Upstream downloads the package index of Typst Universe here.
    raise StrError(
      "failed to fetch package index (downloading packages is not supported by this build)",
    )
  } else {
    // For other namespaces, search locally. We only search in the data
    // directory and not the cache directory, because the latter is not
    // intended for storage of local packages.
    match self.data.bind(pkgs => pkgs.latest_version(spec)) {
      Some(version) => version
      None => raise StrError("please specify the desired version")
    }
  }
}

///|
/// Serves packages from a well-structured directory on the file system.
///
/// This directory should be structured as follows:
/// - Top-level directories denote namespaces
/// - Second-level directories denote packages
/// - Third-level directories denote package versions
#derive(Eq, Debug)
pub(all) struct FsPackages(String)

///|
#deprecated("call as `Eq::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FsPackages with Eq::{not_equal, equal}

///|
#deprecated("call as `Debug::m(x)`, or un-deprecate this `extend` to make it a method")
#doc(hidden)
pub extend FsPackages with @debug.Debug::{to_repr}

///|
/// Creates a new handle that serves packages from the given directory.
pub fn FsPackages::new(path : String) -> FsPackages {
  FsPackages(path)
}

///|
/// Tries to provide a handle to the environment-defined standard system
/// package data directory.
///
/// This is:
/// - `$XDG_DATA_HOME/typst/packages` or `~/.local/share/typst/packages` on
///   Linux
/// - `~/Library/Application Support/typst/packages` on macOS
/// - `%APPDATA%/typst/packages` on Windows
pub fn FsPackages::system_data() -> FsPackages? {
  data_dir().map(dir => FsPackages::new(@platform.join(dir, "typst/packages")))
}

///|
/// Tries to provide a handle to the environment-defined standard system
/// package cache directory.
///
/// This is:
/// - `$XDG_CACHE_HOME/typst/packages` or `~/.cache/typst/packages` on Linux
/// - `~/Library/Caches/typst/packages` on macOS
/// - `%LOCALAPPDATA%/typst/packages` on Windows
pub fn FsPackages::system_cache() -> FsPackages? {
  cache_dir().map(dir => FsPackages::new(@platform.join(dir, "typst/packages")))
}

///|
/// Returns the path from which this serves packages.
pub fn FsPackages::path(self : FsPackages) -> String {
  self.0
}

///|
/// Returns the file system root from which the given package's content can
/// be loaded.
pub fn FsPackages::obtain(
  self : FsPackages,
  spec : @syntax.PackageSpec,
) -> FsRoot? {
  let subdir = "\{spec.namespace_}/\{spec.name}/\{spec.version}"
  let dir = @platform.join(self.path(), subdir)
  if @platform.exists(dir) {
    Some(FsRoot::new(dir))
  } else {
    None
  }
}

///|
/// Tries to determine the latest version of a particular package in the
/// directory tree.
pub fn FsPackages::latest_version(
  self : FsPackages,
  spec : @syntax.VersionlessPackageSpec,
) -> @syntax.PackageVersion? {
  let subdir = "\{spec.namespace_}/\{spec.name}"
  let entries = @platform.read_dir(@platform.join(self.path(), subdir)) catch {
    _ => return None
  }
  let mut best : @syntax.PackageVersion? = None
  for entry in entries {
    if @syntax.PackageVersion::from_str(entry) is Ok(version) {
      best = match best {
        Some(b) if compare_versions(b, version) >= 0 => Some(b)
        _ => Some(version)
      }
    }
  }
  best
}

///|
fn compare_versions(
  a : @syntax.PackageVersion,
  b : @syntax.PackageVersion,
) -> Int32 {
  if a.major != b.major {
    a.major.compare(b.major)
  } else if a.minor != b.minor {
    a.minor.compare(b.minor)
  } else {
    a.patch.compare(b.patch)
  }
}

///|
/// The user's home directory (upstream `dirs::home_dir`).
pub fn home_dir() -> String? {
  match @platform.os() {
    Windows => @platform.env_var("USERPROFILE").filter(h => h != "")
    _ => @platform.env_var("HOME").filter(h => h != "")
  }
}

///|
/// An absolute path from an environment variable (`dirs-sys`'
/// `is_absolute_path`).
fn absolute_env(key : String) -> String? {
  @platform.env_var(key).filter(p => @platform.is_absolute(p))
}

///|
/// The user's data directory (upstream `dirs::data_dir`).
pub fn data_dir() -> String? {
  match @platform.os() {
    Linux =>
      match absolute_env("XDG_DATA_HOME") {
        Some(dir) => Some(dir)
        None => home_dir().map(h => @platform.join(h, ".local/share"))
      }
    MacOs =>
      home_dir().map(h => @platform.join(h, "Library/Application Support"))
    Windows => @platform.env_var("APPDATA").filter(p => p != "")
  }
}

///|
/// The user's cache directory (upstream `dirs::cache_dir`).
pub fn cache_dir() -> String? {
  match @platform.os() {
    Linux =>
      match absolute_env("XDG_CACHE_HOME") {
        Some(dir) => Some(dir)
        None => home_dir().map(h => @platform.join(h, ".cache"))
      }
    MacOs => home_dir().map(h => @platform.join(h, "Library/Caches"))
    Windows => @platform.env_var("LOCALAPPDATA").filter(p => p != "")
  }
}
