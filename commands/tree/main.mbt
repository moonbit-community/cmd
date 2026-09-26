///|
priv suberror TreeError {
  TreeError(String)
}

///|
priv struct TreeOptions {
  all : Bool
  directories_only : Bool
  full_path : Bool
  level : Int?
  no_report : Bool
  help : Bool
  version : Bool
}

///|
priv struct TreeInvocation {
  options : TreeOptions
  roots : Array[String]
}

///|
priv struct TreeNode {
  name : String
  path : String
  kind : @fs.FileKind
  children : Array[TreeNode]
}

///|
priv struct TreeCounts {
  directories : Int
  files : Int
}

///|
fn join_path(parent : String, child : String) -> String {
  if parent == "/" {
    "/" + child
  } else if parent == "." {
    "./" + child
  } else if parent == "" {
    child
  } else {
    parent + "/" + child
  }
}

///|
fn trim_trailing_slashes(path : String) -> String {
  if path == "" {
    return path
  }
  let chars : Array[Char] = path.iter().collect()
  let mut end = chars.length()
  while end > 1 && chars[end - 1] == '/' {
    end -= 1
  }
  let out = StringBuilder()
  for index in 0..<end {
    out.write_char(chars[index])
  }
  out.to_string()
}

///|
fn basename(path : String) -> String {
  let trimmed = trim_trailing_slashes(path)
  if trimmed == "/" {
    return "/"
  }
  let chars : Array[Char] = trimmed.iter().collect()
  let mut start = chars.length()
  while start > 0 && chars[start - 1] != '/' {
    start -= 1
  }
  let out = StringBuilder()
  for index in start..<chars.length() {
    out.write_char(chars[index])
  }
  out.to_string()
}

///|
fn parse_level(value : String) -> Int raise TreeError {
  let level = @string.parse_int(value) catch {
    _ => raise TreeError("invalid level: '\{value}'")
  }
  if level < 0 {
    raise TreeError("invalid level: '\{value}'")
  }
  level
}

///|
fn parse_arguments(args : Array[String]) -> TreeInvocation raise TreeError {
  let parsed = @cli.parse(args, [
    @cli.flag("all", short='a'),
    @cli.flag("dirs-only", short='d'),
    @cli.flag("full-path", short='f'),
    @cli.option("level", short='L'),
    @cli.flag("noreport"),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(message~, ..) => raise TreeError(message)
  }
  let level = match parsed.last_value("level") {
    Some(value) => Some(parse_level(value))
    None => None
  }
  let roots = if parsed.operands.is_empty() { ["."] } else { parsed.operands }
  {
    options: {
      all: parsed.contains("all"),
      directories_only: parsed.contains("dirs-only"),
      full_path: parsed.contains("full-path"),
      level,
      no_report: parsed.contains("noreport"),
      help: parsed.contains("help"),
      version: parsed.contains("version"),
    },
    roots,
  }
}

///|
fn display_root(path : String, full_path : Bool) -> String {
  let trimmed = trim_trailing_slashes(path)
  if full_path {
    trimmed
  } else {
    trimmed
  }
}

///|
async fn collect_node(
  path : String,
  display_name : String,
  depth : Int,
  options : TreeOptions,
) -> TreeNode raise TreeError {
  let kind = @fs.kind(path, follow_symlink=false) catch {
    _ => raise TreeError("cannot access '\{path}'")
  }
  if kind == SymLink {
    raise TreeError(
      "symbolic links are outside the supported profile: '\{path}'",
    )
  }
  let children : Array[TreeNode] = []
  let can_descend = match options.level {
    Some(limit) => depth < limit
    None => true
  }
  if kind == Directory && can_descend {
    let entries = @fs.readdir(
      path,
      include_hidden=options.all,
      include_special=true,
      sort=true,
    ) catch {
      _ => raise TreeError("cannot read directory '\{path}'")
    }
    for entry in entries {
      let entry_path = join_path(path, entry)
      let entry_kind = @fs.kind(entry_path, follow_symlink=false) catch {
        _ => raise TreeError("cannot access '\{entry_path}'")
      }
      if entry_kind == SymLink {
        raise TreeError(
          "symbolic links are outside the supported profile: '\{entry_path}'",
        )
      }
      if options.directories_only && entry_kind != Directory {
        continue
      }
      children.push(collect_node(entry_path, entry, depth + 1, options))
    }
  }
  { name: display_name, path, kind, children, }
}

///|
fn node_counts(node : TreeNode) -> TreeCounts {
  let mut directories = if node.kind == Directory { 1 } else { 0 }
  let mut files = if node.kind == Directory { 0 } else { 1 }
  for child in node.children {
    let child_counts = node_counts(child)
    directories += child_counts.directories
    files += child_counts.files
  }
  { directories, files, }
}

///|
fn node_label(node : TreeNode, options : TreeOptions, is_root : Bool) -> String {
  if is_root {
    display_root(node.path, options.full_path)
  } else if options.full_path {
    node.path
  } else {
    node.name
  }
}

///|
fn render_node(
  node : TreeNode,
  options : TreeOptions,
  prefix : String,
  is_last : Bool,
  is_root : Bool,
  output : StringBuilder,
) -> Unit {
  if is_root {
    output.write_string(node_label(node, options, true))
    output.write_char('\n')
  } else {
    output.write_string(prefix)
    output.write_string(if is_last { "└── " } else { "├── " })
    output.write_string(node_label(node, options, false))
    output.write_char('\n')
  }
  let child_prefix = if is_root {
    ""
  } else if is_last {
    prefix + "    "
  } else {
    prefix + "│   "
  }
  for index, child in node.children {
    render_node(
      child,
      options,
      child_prefix,
      index == node.children.length() - 1,
      false,
      output,
    )
  }
}

///|
fn write_report(counts : TreeCounts, output : StringBuilder) -> Unit {
  let directory_word = if counts.directories == 1 {
    "directory"
  } else {
    "directories"
  }
  let file_word = if counts.files == 1 { "file" } else { "files" }
  output.write_string(
    "\{counts.directories} \{directory_word}, \{counts.files} \{file_word}\n",
  )
}

///|
fn add_counts(left : TreeCounts, right : TreeCounts) -> TreeCounts {
  {
    directories: left.directories + right.directories,
    files: left.files + right.files,
  }
}

///|
fn usage() -> String {
  "Usage: tree [-adf] [-L level] [--noreport] [--] [directory ...]\n"
}

///|
async fn main {
  let invocation = parse_arguments(@env.args()[1:].to_owned()) catch {
    TreeError(message) => {
      @stdio.stderr.write("tree: \{message}\n")
      @sys.exit(2)
      return
    }
  }
  if invocation.options.help {
    @stdio.stdout.write(usage())
    return
  }
  if invocation.options.version {
    @stdio.stdout.write("tree (moonbit cmd) \{command_version}\n")
    return
  }
  let roots : Array[TreeNode] = []
  let mut failed = false
  for root in invocation.roots {
    let path = trim_trailing_slashes(root)
    let display_name = basename(path)
    let node = collect_node(path, display_name, 0, invocation.options) catch {
      TreeError(message) => {
        @stdio.stderr.write("tree: \{message}\n")
        failed = true
        continue
      }
    }
    roots.push(node)
  }
  if failed {
    @sys.exit(1)
    return
  }
  let output = StringBuilder()
  let mut counts : TreeCounts = { directories: 0, files: 0, }
  for index, root in roots {
    if index > 0 {
      output.write_char('\n')
    }
    render_node(root, invocation.options, "", true, true, output)
    counts = add_counts(counts, node_counts(root))
  }
  if !invocation.options.no_report {
    write_report(counts, output)
  }
  @stdio.stdout.write(output.to_string())
}
