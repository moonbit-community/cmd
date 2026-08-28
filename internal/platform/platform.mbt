///|
pub(all) enum Platform {
  Windows
  Posix
} derive(Eq, Debug)

///|
pub fn current() -> Platform {
  if @path.sep == '\\' {
    Windows
  } else {
    Posix
  }
}

///|
pub fn is_windows() -> Bool {
  current() == Windows
}

///|
pub fn permission_mutation_supported() -> Bool {
  !is_windows()
}

///|
pub fn symbolic_links_supported() -> Bool {
  !is_windows()
}

///|
pub fn native_separator() -> Char {
  @path.sep
}

///|
pub fn accepts_separator(char : Char) -> Bool {
  char == '/' || (is_windows() && char == '\\')
}

///|
pub fn normalize_input_separators(path : String) -> String {
  if !is_windows() {
    return path
  }
  path.replace_all(old="/", new="\\")
}
