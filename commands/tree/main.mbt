///|
priv suberror TreeError {
  TreeError(String)
}

///|
priv struct TreeOptions {
  all : Bool
  directories_only : Bool
  full_path : Bool
  level : Int32?
  no_report : Bool
  help : Bool
  version : Bool
  format : TreeFormat
  title : String
  includes : Array[TreePattern]
  excludes : Array[TreePattern]
  match_dirs : Bool
  ignore_case : Bool
  prune : Bool
  file_limit : Int32
  size : SizeStyle
  disk_usage : Bool
  colors : TreeColors?
  html_colors : Bool
}

///|
priv enum TreeFormat {
  Text
  Json
  Html(String)
} derive(Eq)

///|
priv enum SizeStyle {
  NoSize
  ExactSize
  HumanSize
  SiSize
} derive(Eq)

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
  mut size : Int64?
  note : String?
  limited : Bool
}

///|
priv struct TreeCounts {
  directories : Int32
  files : Int32
  size : Int64
}

///|
priv enum TreeJob {
  Visit(String, String, String, Int32, @fs.FileKind?, Array[TreeNode])
  Finish(TreeNode, String, Array[TreeNode])
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
fn parse_level(value : String) -> Int32 raise TreeError {
  let level = @string.parse_int(value) catch {
    _ => raise TreeError("invalid level: '\{value}'")
  }
  if level <= 0 {
    raise TreeError("Invalid level, must be greater than 0.")
  }
  level
}

///|
fn parse_file_limit(value : String) -> Int32 {
  let bytes = @utf8.encode(value)
  let mut index = 0
  while index < bytes.length() &&
        bytes[index] is (b' ' | b'\t' | b'\n' | b'\r' | 11 | 12) {
    index += 1
  }
  let negative = index < bytes.length() && bytes[index] == b'-'
  if index < bytes.length() && bytes[index] is (b'+' | b'-') {
    index += 1
  }
  let limit = if negative {
    9223372036854775808UL
  } else {
    9223372036854775807UL
  }
  let mut number = 0UL
  while index < bytes.length() && bytes[index] is (b'0'..<=b'9') {
    let digit = (bytes[index].to_int() - 48).to_uint64()
    number = if number > (limit - digit) / 10UL {
      limit
    } else {
      number * 10UL + digit
    }
    index += 1
  }
  if negative {
    -number.to_int()
  } else {
    number.to_int()
  }
}

///|
fn parse_arguments(args : Array[String]) -> TreeInvocation raise TreeError {
  let parsed = @cli.parse(args, [
    @cli.flag("all", short='a'),
    @cli.flag("dirs-only", short='d'),
    @cli.flag("full-path", short='f'),
    @cli.option("level", short='L'),
    @cli.flag("noreport"),
    @cli.flag("json", short='J'),
    @cli.option("html", short='H'),
    @cli.option("title", short='T'),
    @cli.option("pattern", short='P'),
    @cli.option("ignore", short='I'),
    @cli.flag("matchdirs"),
    @cli.flag("ignore-case"),
    @cli.flag("prune"),
    @cli.option("filelimit"),
    @cli.flag("size", short='s'),
    @cli.flag("human-readable", short='h'),
    @cli.flag("si"),
    @cli.flag("du"),
    @cli.flag("color", short='C'),
    @cli.flag("no-color", short='n'),
    @cli.flag("help"),
    @cli.flag("version"),
  ]) catch {
    @cli.CliError(message~, ..) => raise TreeError(message)
  }
  let level = match parsed.last_value("level") {
    Some(value) => Some(parse_level(value))
    None => None
  }
  for value in parsed.values("level") {
    ignore(parse_level(value))
  }
  let roots = if parsed.operands.is_empty() { ["."] } else { parsed.operands }
  let format = match parsed.last_occurrence(["json", "html"]) {
    Some("json") => Json
    Some("html") => Html(parsed.last_value("html").unwrap())
    _ => Text
  }
  let size = if parsed.contains("si") {
    SiSize
  } else if parsed.contains("human-readable") {
    HumanSize
  } else if parsed.contains("size") || parsed.contains("du") {
    ExactSize
  } else {
    NoSize
  }
  let file_limit = match parsed.last_value("filelimit") {
    Some(value) => parse_file_limit(value)
    None => 0
  }
  let ignore_case = parsed.contains("ignore-case")
  let force_color = parsed.contains("color")
  let colors = if format == Text { tree_colors(force_color) } else { None }
  {
    options: {
      all: parsed.contains("all"),
      directories_only: parsed.contains("dirs-only"),
      full_path: parsed.contains("full-path"),
      level,
      no_report: parsed.contains("noreport"),
      help: parsed.contains("help"),
      version: parsed.contains("version"),
      format,
      title: parsed.last_value("title").unwrap_or("Directory Tree"),
      includes: parsed
      .values("pattern")
      .map(value => compile_pattern(value, ignore_case)),
      excludes: parsed
      .values("ignore")
      .map(value => compile_pattern(value, ignore_case)),
      match_dirs: parsed.contains("matchdirs"),
      ignore_case,
      prune: parsed.contains("prune"),
      file_limit,
      size,
      disk_usage: parsed.contains("du"),
      colors,
      html_colors: force_color && format is Html(_),
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
  depth : Int32,
  options : TreeOptions,
  known_kind~ : @fs.FileKind? = None,
  relative~ : String = "",
) -> TreeNode raise TreeError {
  let roots : Array[TreeNode] = []
  let pending : Array[TreeJob] = [
    Visit(path, display_name, relative, depth, known_kind, roots),
  ]
  while pending.pop() is Some(job) {
    match job {
      Finish(node, relative, parent) => {
        let matched = options.match_dirs &&
          matches_any(options.includes, relative, true, options.ignore_case)
        if options.prune &&
          !relative.is_empty() &&
          node.children.is_empty() &&
          !matched {
          ignore(parent.pop())
        } else if options.disk_usage {
          let mut total = node.size.unwrap_or(0L)
          for child in node.children {
            total += child.size.unwrap_or(0L)
          }
          node.size = Some(total)
        }
      }
      Visit(path, name, relative, depth, known, parent) => {
        let kind = match known {
          Some(kind) => kind
          None =>
            @fs.kind(path, follow_symlink=false) catch {
              _ => raise TreeError("cannot access '\{path}'")
            }
        }
        if kind == SymLink {
          raise TreeError(
            "symbolic links are outside the supported profile: '\{path}'",
          )
        }
        if options.html_colors && kind == Regular {
          raise TreeError(
            "HTML executable color classification requires unavailable raw mode bits: '\{path}'",
          )
        }
        if options.colors is Some(colors) {
          require_color_kind(kind, colors)
        }
        let size = if options.size != NoSize {
          Some(
            @fs.file_size(path) catch {
              error =>
                raise TreeError(
                  "cannot read size of '\{path}': " + error.to_string(),
                )
            },
          )
        } else {
          None
        }
        let accepted : Array[(String, String, @fs.FileKind)] = []
        let can_descend = match options.level {
          Some(limit) => depth < limit
          None => true
        }
        if kind == Directory && can_descend {
          let entries = @fswalk.read_directory(path) catch {
            _ => raise TreeError("cannot read directory '\{path}'")
          }
          entries.sort_by((left, right) => {
            @utf8.encode(left).lexical_compare(@utf8.encode(right))
          })
          let matching_dir = options.match_dirs &&
            !relative.is_empty() &&
            matches_any(options.includes, relative, true, options.ignore_case)
          for entry in entries {
            if !options.all && entry.has_prefix(".") {
              continue
            }
            let entry_path = join_path(path, entry)
            let entry_kind = @fs.kind(entry_path, follow_symlink=false) catch {
              _ => raise TreeError("cannot access '\{entry_path}'")
            }
            let directory = entry_kind == Directory ||
              (
                entry_kind == SymLink &&
                options.directories_only &&
                (@fs.kind(entry_path, follow_symlink=true) catch {
                  _ => Unknown
                }) ==
                Directory
              )
            if options.directories_only && !directory {
              continue
            }
            if matches_any(
                options.excludes,
                entry,
                directory,
                options.ignore_case,
              ) {
              continue
            }
            if entry_kind != Directory &&
              !matching_dir &&
              !options.includes.is_empty() &&
              !matches_any(options.includes, entry, false, options.ignore_case) {
              continue
            }
            accepted.push((entry, entry_path, entry_kind))
          }
        }
        let limited = options.file_limit > 0 &&
          accepted.length() > options.file_limit
        let note = if limited {
          Some(
            "\{accepted.length()} entries exceeds filelimit, not opening dir",
          )
        } else if depth == 0 && kind != Directory {
          Some("error opening dir")
        } else {
          None
        }
        let node : TreeNode = {
          name,
          path,
          kind,
          children: [],
          size,
          note,
          limited,
        }
        parent.push(node)
        if kind == Directory &&
          (options.disk_usage || (options.prune && !relative.is_empty())) {
          pending.push(Finish(node, relative, parent))
        }
        if !limited {
          for index = accepted.length() - 1; index >= 0; index = index - 1 {
            let (name, path, kind) = accepted[index]
            let relative = if relative == "" {
              name
            } else {
              relative + "/" + name
            }
            pending.push(
              Visit(path, name, relative, depth + 1, Some(kind), node.children),
            )
          }
        }
      }
    }
  }
  roots[0]
}

///|
fn node_counts(
  node : TreeNode,
  root~ : Bool = false,
  prune~ : Bool = false,
  disk_usage~ : Bool = false,
) -> TreeCounts {
  let mut directories = if node.kind == Directory { 1 } else { 0 }
  let mut files = if node.kind == Directory { 0 } else { 1 }
  if root && node.kind == Directory && node.children.is_empty() {
    directories = if node.limited && !prune { 1 } else { 0 }
    if node.limited && prune {
      files = 1
    }
  }
  let mut size = node.size.unwrap_or(0L)
  let pending = node.children.copy()
  while pending.pop() is Some(child) {
    if child.kind == Directory {
      directories += 1
    } else {
      files += 1
    }
    if !disk_usage {
      size += child.size.unwrap_or(0L)
    }
    for grandchild in child.children {
      pending.push(grandchild)
    }
  }
  { directories, files, size, }
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
async fn render_node(
  node : TreeNode,
  options : TreeOptions,
  prefix : String,
  is_last : Bool,
  is_root : Bool,
  output : TreeOutput,
) -> Unit {
  let pending : Array[(TreeNode, String, Bool, Bool)] = [
    (node, prefix, is_last, is_root),
  ]
  while pending.pop() is Some((node, prefix, last, root)) {
    let line = StringBuilder()
    if !root {
      line.write_string(prefix + (if last { "`-- " } else { "|-- " }))
    }
    write_text_label(node, options, root, line)
    line.write_char('\n')
    output.write(line.to_string())
    let child_prefix = if root {
      ""
    } else {
      prefix + (if last { "    " } else { "|   " })
    }
    for index = node.children.length() - 1; index >= 0; index = index - 1 {
      pending.push(
        (
          node.children[index],
          child_prefix,
          index + 1 == node.children.length(),
          false,
        ),
      )
    }
  }
}

///|
fn write_report(
  counts : TreeCounts,
  output : StringBuilder,
  options : TreeOptions,
) -> Unit {
  let directory_word = if counts.directories == 1 {
    "directory"
  } else {
    "directories"
  }
  let file_word = if counts.files == 1 { "file" } else { "files" }
  if options.disk_usage {
    output.write_string(
      size_text(counts.size, options.size) +
      (if options.size == ExactSize { " bytes" } else { "" }) +
      " used in ",
    )
  }
  output.write_string("\{counts.directories} \{directory_word}")
  if !options.directories_only {
    output.write_string(", \{counts.files} \{file_word}")
  }
  output.write_char('\n')
}

///|
fn add_counts(left : TreeCounts, right : TreeCounts) -> TreeCounts {
  {
    directories: left.directories + right.directories,
    files: left.files + right.files,
    size: left.size + right.size,
  }
}

///|
fn usage() -> String {
  "Usage: tree [-adfJCnsh] [-L level] [-P pattern] [-I pattern] [-H base] [-T title] [directory ...]\n" +
  "      --help      display this help and exit\n" +
  "      --version   display version and exit\n" +
  "  -J emits JSON; -H BASE emits escaped HTML; -T TITLE selects its title.\n" +
  "  -P includes files; -I excludes names/subtrees; --ignore-case changes matching.\n" +
  "  --matchdirs includes matching directory contents; --prune removes empty branches.\n" +
  "  --filelimit N limits entries before traversal; --noreport omits totals.\n" +
  "  -s, -h, --si and --du use public size metadata; unsupported host metadata reports an error.\n" +
  "  -C forces explicit type/extension colors; -n disables unforced color.\n" +
  "  Mode-based colors and symlink targets require unavailable public metadata APIs.\n"
}

///|
async fn main {
  let metadata_args = @env.args()[1:]
  if metadata_args.length() == 1 && metadata_args[0] == "--version" {
    @stdio.stdout.write("tree 0.1.4\n")
    return
  }
  let invocation = parse_arguments(@env.args()[1:].to_owned()) catch {
    TreeError(message) => {
      @stdio.stderr.write("tree: \{message}\n")
      @sys.exit(1)
      return
    }
  }
  if invocation.options.help {
    @stdio.stdout.write(usage())
    return
  }
  if invocation.options.version {
    @stdio.stdout.write("tree \{command_version}\n")
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
  let output = TreeOutput::new(async fn(bytes) { @stdio.stdout.write(bytes) })
  let mut counts : TreeCounts = { directories: 0, files: 0, size: 0L, }
  for root in roots {
    counts = add_counts(
      counts,
      node_counts(
        root,
        root=true,
        prune=invocation.options.prune || invocation.options.disk_usage,
        disk_usage=invocation.options.disk_usage,
      ),
    )
  }
  match invocation.options.format {
    Text => {
      for root in roots {
        render_node(root, invocation.options, "", true, true, output)
      }
      if !invocation.options.no_report {
        let report = StringBuilder()
        report.write_char('\n')
        write_report(counts, report, invocation.options)
        output.write(report.to_string())
      }
    }
    Json => render_json(roots, invocation.options, counts, output)
    Html(base) => render_html(roots, invocation.options, base, counts, output)
  }
  output.flush()
}
