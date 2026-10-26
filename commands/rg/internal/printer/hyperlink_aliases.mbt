///|
/// Aliases to well-known hyperlink schemes.
///
/// These need to be sorted by name.
let hyperlink_pattern_aliases : Array[HyperlinkAlias] = [
  make_alias(
    "cursor", "Cursor scheme (cursor://)", "cursor://file{path}:{line}:{column}",
  ),
  prioritized_alias(
    0, "default", "RFC 8089 scheme (file://) (platform-aware)", "file://{host}{path}",
  ),
  make_alias(
    "file", "RFC 8089 scheme (file://) with host", "file://{host}{path}",
  ),
  make_alias("grep+", "grep+ scheme (grep+://)", "grep+://{path}:{line}"),
  make_alias(
    "kitty", "kitty-style RFC 8089 scheme (file://) with line number", "file://{host}{path}#{line}",
  ),
  make_alias(
    "macvim", "MacVim scheme (mvim://)", "mvim://open?url=file://{path}&line={line}&column={column}",
  ),
  prioritized_alias(1, "none", "disable hyperlinks", ""),
  make_alias(
    "textmate", "TextMate scheme (txmt://)", "txmt://open?url=file://{path}&line={line}&column={column}",
  ),
  make_alias(
    "vscode", "VS Code scheme (vscode://)", "vscode://file{path}:{line}:{column}",
  ),
  make_alias(
    "vscode-insiders", "VS Code Insiders scheme (vscode-insiders://)", "vscode-insiders://file{path}:{line}:{column}",
  ),
  make_alias(
    "vscodium", "VSCodium scheme (vscodium://)", "vscodium://file{path}:{line}:{column}",
  ),
]

///|
fn make_alias(
  name : String,
  description : String,
  format : String,
) -> HyperlinkAlias {
  { name, description, format, display_priority: None, }
}

///|
fn prioritized_alias(
  priority : Int32,
  name : String,
  description : String,
  format : String,
) -> HyperlinkAlias {
  { name, description, format, display_priority: Some(priority), }
}
