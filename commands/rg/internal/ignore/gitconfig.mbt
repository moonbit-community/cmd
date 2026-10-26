// Discovery of git's global excludes file (`core.excludesFile`).

///|
/// Return the file path of the current environment's global gitignore file.
///
/// Note that the file path returned may not exist.
pub async fn gitconfig_excludes_path() -> String? {
  // When GIT_CONFIG_GLOBAL is set, it replaces both $HOME/.gitconfig and
  // $XDG_CONFIG_HOME/git/config (per git 2.32+). Otherwise, git supports
  // $HOME/.gitconfig and $XDG_CONFIG_HOME/git/config simultaneously, where
  // $HOME/.gitconfig takes precedent.
  if gitconfig_global_env_contents().bind(parse_excludes_file) is Some(p) {
    return Some(p)
  }
  if gitconfig_home_contents().bind(parse_excludes_file) is Some(p) {
    return Some(p)
  }
  if gitconfig_xdg_contents().bind(parse_excludes_file) is Some(p) {
    return Some(p)
  }
  // System-level config has the lowest priority for core.excludesFile.
  // GIT_CONFIG_SYSTEM overrides the default /etc/gitconfig path.
  if gitconfig_system_contents().bind(parse_excludes_file) is Some(p) {
    return Some(p)
  }
  excludes_file_default()
}

///|
async fn read_file_opt(path : String) -> Bytes? {
  (Ok(@sys.read_file(path)) catch { e => Err(e) }).to_option()
}

///|
fn non_empty_env(name : String) -> String? {
  match @sys.env_var(name) {
    Some(v) if v != "" => Some(v)
    _ => None
  }
}

///|
/// Returns the file contents of git's global config file from the path
/// specified by the `GIT_CONFIG_GLOBAL` environment variable.
async fn gitconfig_global_env_contents() -> Bytes? {
  guard non_empty_env("GIT_CONFIG_GLOBAL") is Some(path) else { return None }
  read_file_opt(path)
}

///|
/// Returns the file contents of git's system-level config file.
///
/// Checks `GIT_CONFIG_SYSTEM` first, then falls back to `/etc/gitconfig`.
async fn gitconfig_system_contents() -> Bytes? {
  let path = non_empty_env("GIT_CONFIG_SYSTEM").unwrap_or("/etc/gitconfig")
  read_file_opt(path)
}

///|
/// Returns the file contents of git's global config file, if one exists, in
/// the user's home directory.
async fn gitconfig_home_contents() -> Bytes? {
  guard home_dir() is Some(home) else { return None }
  read_file_opt(path_join(home, ".gitconfig"))
}

///|
/// Returns the file contents of git's global config file, if one exists, in
/// the user's XDG_CONFIG_HOME directory.
async fn gitconfig_xdg_contents() -> Bytes? {
  guard xdg_config_home() is Some(dir) else { return None }
  read_file_opt(path_join(dir, "git/config"))
}

///|
fn xdg_config_home() -> String? {
  match non_empty_env("XDG_CONFIG_HOME") {
    Some(dir) => Some(dir)
    None => home_dir().map(p => path_join(p, ".config"))
  }
}

///|
/// Returns the default file path for a global .gitignore file.
///
/// Specifically, this respects XDG_CONFIG_HOME.
fn excludes_file_default() -> String? {
  xdg_config_home().map(x => path_join(x, "git/ignore"))
}

///|
let excludes_file_regex : Ref[@regex.Regex?] = { val: None, }

///|
fn get_excludes_file_regex() -> @regex.Regex {
  match excludes_file_regex.val {
    Some(re) => re
    None => {
      let hir = @syntax.parse(
        "(?im-u)^\\s*excludesfile\\s*=\\s*\"?\\s*(\\S+?)\\s*\"?\\s*$",
        config={ ..@syntax.ParseConfig::default(), utf8: false, },
      ) catch {
        _ => abort("BUG: invalid excludesfile regex")
      }
      let re = @regex.Regex::from_hir(hir) catch {
        _ => abort("BUG: invalid excludesfile regex")
      }
      excludes_file_regex.val = Some(re)
      re
    }
  }
}

///|
/// Extract git's `core.excludesfile` config setting from the raw file
/// contents given.
fn parse_excludes_file(data : Bytes) -> String? {
  // N.B. This is the lazy approach, and isn't technically correct, but
  // probably works in more circumstances. I guess we would ideally have
  // a full INI parser. Yuck.
  let re = get_excludes_file_regex()
  let hay = data.to_fixedarray()
  let slots = FixedArray::make(re.captures_len() * 2, -1)
  if !re.captures_at(hay, 0, hay.length(), 0, hay.length(), slots) {
    return None
  }
  let (s, e) = (slots[2], slots[3])
  if s < 0 || e < 0 {
    return None
  }
  let candidate = @utf8.decode(data[s:e]) catch { _ => return None }
  Some(expand_tilde(candidate))
}

///|
/// Expands ~ in file paths to the value of $HOME.
fn expand_tilde(path : String) -> String {
  match home_dir() {
    None => path
    Some(home) => path.replace_all(old="~", new=home)
  }
}

///|
/// Returns the location of the user's home directory.
fn home_dir() -> String? {
  @sys.env_var("HOME")
}
