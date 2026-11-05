// The font directories of a fontconfig configuration, for system font
// discovery on Linux (`fontdb`'s `load_fontconfig` with
// `fontconfig-parser` 0.5.7).
//
// Only the parts of the configuration that determine the font directories
// are interpreted: `<dir>`, `<include>` and `<reset-dirs>` (aliases only
// affect fontdb's generic families, which typst does not use). Unlike
// `fontconfig-parser`, malformed elements of other kinds (e.g. `<match>`)
// do not abort reading the rest of a file.

///|
/// The accumulated configuration: font directories and the configuration
/// files read so far (`fontconfig_parser::FontConfig`).
priv struct FontConfig {
  dirs : Array[String]
  config_files : @hashset.HashSet[String]
}

///|
/// Loads the system fonts listed in the fontconfig configuration
/// (`Database::load_fontconfig`). Returns `false` if the configuration has
/// no font directories.
async fn FontDb::load_fontconfig(self : FontDb) -> Bool {
  let fontconfig : FontConfig = {
    dirs: [],
    config_files: @hashset.HashSet([]),
  }
  let home = @platform.env_var("HOME")
  match @platform.env_var("FONTCONFIG_FILE") {
    Some(config_file) => fontconfig.merge_config(config_file) |> ignore
    None => {
      let xdg_config_home = match @platform.env_var("XDG_CONFIG_HOME") {
        Some(val) => Some(val)
        // according to https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
        // $XDG_CONFIG_HOME should default to $HOME/.config if not set
        None => home.map(home => @platform.join(home, ".config"))
      }
      let read_global = match xdg_config_home {
        Some(p) =>
          !fontconfig.merge_config(@platform.join(p, "fontconfig/fonts.conf"))
        None => true
      }
      if read_global {
        fontconfig.merge_config("/etc/fonts/local.conf") |> ignore
      }
      fontconfig.merge_config("/etc/fonts/fonts.conf") |> ignore
    }
  }
  if fontconfig.dirs.is_empty() {
    return false
  }
  let seen = @hashset.HashSet([])
  for dir in fontconfig.dirs {
    let path = if dir.has_prefix("~") {
      match home {
        Some(home) => @platform.join(home, strip_tilde(dir))
        None => continue
      }
    } else {
      dir
    }
    self.load_fonts_dir_impl(path, seen)
  }
  true
}

///|
/// The rest of a path after a leading `~` component (`Path::strip_prefix`).
fn strip_tilde(path : String) -> String {
  let rest = path[1:].to_owned()
  let mut i = 0
  while i < rest.length() && rest.code_unit_at(i) == '/' {
    i += 1
  }
  rest[i:].to_owned()
}

///|
/// Merges a configuration file. Returns whether it succeeded.
async fn FontConfig::merge_config(
  self : FontConfig,
  config_path : String,
) -> Bool {
  let canonical = @fs.realpath(config_path) catch { _ => return false }
  if self.config_files.contains(canonical) {
    return true
  }
  self.config_files.add(canonical)
  let data = @fs.read_file(config_path).binary() catch { _ => return false }
  let text = @utf8.decode(data) catch { _ => return false }
  let doc = @xml.Document::parse_with_options(text, {
    ..@xml.ParsingOptions::default(),
    allow_dtd: true,
  }) catch {
    _ => return false
  }
  let fontconfig = doc.root_element()
  if fontconfig.tag_name().name() != "fontconfig" {
    return false
  }
  for child in fontconfig.children() {
    match child.tag_name().name() {
      "dir" => {
        guard parse_prefix(child) is Some(prefix) else { return false }
        guard child.text() is Some(path) else { return false }
        self.dirs.push(
          calculate_path(
            path,
            prefix,
            config_path,
            "XDG_DATA_HOME",
            "~/.local/share",
            Cwd,
          ),
        )
      }
      "reset-dirs" => self.dirs.clear()
      "include" => {
        guard parse_prefix(child) is Some(prefix) else { return false }
        guard child.text() is Some(path) else { return false }
        let include_path = calculate_path(
          path,
          prefix,
          config_path,
          "XDG_CONFIG_HOME",
          "~/.config",
          Config,
        )
        self.include_config(include_path) |> ignore
      }
      _ => ()
    }
  }
  true
}

///|
/// Includes a configuration file or all files of a configuration directory
/// (in reverse path order, like the `BinaryHeap` upstream iterates).
async fn FontConfig::include_config(
  self : FontConfig,
  include_path : String,
) -> Bool {
  let kind = font_stat_kind(include_path) catch { _ => return false }
  if kind == File {
    return self.merge_config(include_path)
  } else if kind == Dir {
    let entries = @fs.readdir(include_path, sort=false) catch {
      _ => return false
    }
    let config_paths = []
    for name in entries {
      let path = @platform.join(include_path, name)
      let ty = font_stat_kind(path, follow_symlink=false) catch {
        _ => continue
      }
      if ty == File || ty == Symlink {
        config_paths.push(path)
      }
    }
    // Upstream collects the paths into a `BinaryHeap` and iterates it,
    // which yields the heap's internal order.
    heapify(config_paths, @library.compare_str)
    for config_path in config_paths {
      self.merge_config(config_path) |> ignore
    }
  }
  true
}

///|
/// How a relative path is resolved (`fontconfig_parser::PrefixBehavior`).
priv enum PrefixBehavior {
  Config
  Cwd
  Xdg
  Relative
}

///|
/// The `prefix` attribute (`DirPrefix`): `None` if it is invalid.
fn parse_prefix(node : @xml.Node) -> PrefixBehavior?? {
  match node.attribute("prefix") {
    None => Some(None)
    Some("default") => Some(None)
    Some("cwd") => Some(Some(Cwd))
    Some("xdg") => Some(Some(Xdg))
    Some("relative") => Some(Some(Relative))
    Some(_) => None
  }
}

///|
/// Expands a leading `~` to the home directory.
fn expand_tilde(path : String) -> String {
  if path == "~" || path.has_prefix("~/") {
    let home = @platform.env_var("HOME").unwrap_or("/")
    @platform.join(home, strip_tilde(path))
  } else {
    path
  }
}

///|
/// Calculates the actual path of a `<dir>` or `<include>`.
fn calculate_path(
  path : String,
  prefix : PrefixBehavior?,
  config_file_path : String,
  xdg_env : String,
  xdg_fallback : String,
  default_behavior : PrefixBehavior,
) -> String {
  let expanded_path = expand_tilde(path)
  if @platform.is_absolute(expanded_path) {
    return expanded_path
  }
  match prefix.unwrap_or(default_behavior) {
    Config => @platform.join("/etc/fonts", expanded_path)
    Cwd => @platform.join(".", expanded_path)
    Relative =>
      match @platform.parent(config_file_path) {
        Some(parent) => @platform.join(parent, expanded_path)
        None => @platform.join(".", expanded_path)
      }
    Xdg => {
      let xdg_path = @platform.env_var(xdg_env).unwrap_or(xdg_fallback)
      @platform.join(expand_tilde(xdg_path), expanded_path)
    }
  }
}

///|
/// Arranges a vector into a max-heap in place like Rust's
/// `BinaryHeap::from(vec)` (`rebuild`), so that iterating it yields the
/// same order as iterating the `BinaryHeap`.
fn[T] heapify(data : Array[T], cmp : (T, T) -> Int32) -> Unit {
  let len = data.length()
  let mut n = len / 2
  while n > 0 {
    n -= 1
    sift_down_range(data, n, len, cmp)
  }
}

///|
/// Rust's `BinaryHeap::sift_down_range`.
fn[T] sift_down_range(
  data : Array[T],
  pos : Int32,
  end : Int32,
  cmp : (T, T) -> Int32,
) -> Unit {
  let elem = data[pos]
  let mut hole = pos
  let mut child = 2 * hole + 1
  // Loop invariant: child == 2 * hole + 1.
  while child <= end - 2 {
    // compare with the greater of the two children
    if cmp(data[child], data[child + 1]) <= 0 {
      child += 1
    }
    // if we are already in order, stop.
    if cmp(elem, data[child]) >= 0 {
      data[hole] = elem
      return
    }
    data[hole] = data[child]
    hole = child
    child = 2 * hole + 1
  }
  if child == end - 1 && cmp(elem, data[child]) < 0 {
    data[hole] = data[child]
    hole = child
  }
  data[hole] = elem
}
