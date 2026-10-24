///|
fn json_string(value : String) -> String {
  @json.to_json(value).stringify()
}

///|
fn kind_name(kind : @fs.FileKind) -> String {
  match kind {
    Directory => "directory"
    Regular => "file"
    SymLink => "link"
    Pipe => "fifo"
    Socket => "socket"
    BlockDevice => "block"
    CharDevice => "char"
    _ => "unknown"
  }
}

///|
priv enum JsonJob {
  Node(TreeNode, Int32, Bool)
  Text(String)
  End(Int32)
}

///|
async fn render_json(
  roots : Array[TreeNode],
  options : TreeOptions,
  counts : TreeCounts,
  output : TreeOutput,
) -> Unit {
  output.write("[\n")
  let pending : Array[JsonJob] = []
  for index = roots.length() - 1; index >= 0; index = index - 1 {
    pending.push(Text(if index + 1 < roots.length() { ",\n" } else { "\n" }))
    pending.push(Node(roots[index], 0, true))
  }
  while pending.pop() is Some(job) {
    match job {
      Text(text) => output.write(text)
      End(depth) => output.write("  ".repeat(depth + 1) + "]}")
      Node(node, depth, root) => {
        let indent = "  ".repeat(depth + 1)
        let out = StringBuilder()
        out.write_string(
          indent +
          "{\"type\":" +
          json_string(kind_name(node.kind)) +
          ",\"name\":" +
          json_string(node_label(node, options, root)),
        )
        if node.size is Some(size) {
          out.write_string(
            ",\"size\":" +
            (if options.size is (HumanSize | SiSize) {
              json_string(size_text(size, options.size).trim().to_owned())
            } else {
              size.to_string()
            }),
          )
        }
        if !node.children.is_empty() {
          out.write_string(",\"contents\":[\n")
          pending.push(End(depth))
          for index = node.children.length() - 1; index >= 0; index = index - 1 {
            pending.push(
              Text(
                if index + 1 < node.children.length() {
                  ",\n"
                } else {
                  "\n"
                },
              ),
            )
            pending.push(Node(node.children[index], depth + 1, false))
          }
        } else if node_note(node, options, root) is Some(note) {
          out.write_string(
            ",\"contents\":[{\"error\": " +
            json_string(note) +
            "}\n" +
            indent +
            "]}",
          )
        } else {
          out.write_char('}')
        }
        output.write(out.to_string())
      }
    }
  }
  let out = StringBuilder()
  if !options.no_report {
    out.write_string(",\n  {\"type\":\"report\"")
    if options.disk_usage {
      out.write_string(",\"size\":" + counts.size.to_string())
    }
    out.write_string(",\"directories\":" + counts.directories.to_string())
    if !options.directories_only {
      out.write_string(",\"files\":" + counts.files.to_string())
    }
    out.write_char('}')
  }
  out.write_string("\n]\n")
  output.write(out.to_string())
}

///|
fn html_escape(value : String) -> String {
  let out = StringBuilder()
  for c in value {
    out.write_string(
      match c {
        '&' => "&amp;"
        '<' => "&lt;"
        '>' => "&gt;"
        '"' => "&quot;"
        _ => c.to_string()
      },
    )
  }
  out.to_string()
}

///|
fn url_path(value : String) -> String {
  let out = StringBuilder()
  let hex = b"0123456789ABCDEF"
  for byte in @utf8.encode(value) {
    if byte
      is (b'A'..<=b'Z'
      | b'a'..<=b'z'
      | b'0'..<=b'9'
      | b'-'
      | b'.'
      | b'_'
      | b'~'
      | b'/') {
      out.write_char(byte.to_int().unsafe_to_char())
    } else {
      out.write_char('%')
      out.write_char(hex[byte.to_int() / 16].to_int().unsafe_to_char())
      out.write_char(hex[byte.to_int() % 16].to_int().unsafe_to_char())
    }
  }
  out.to_string()
}

///|
fn html_intro(title : String) -> String {
  "<!DOCTYPE html>\n<html>\n<head>\n <meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n <meta name=\"Author\" content=\"Made by 'tree'\">\n <meta name=\"GENERATOR\" content=\"cli/tree " +
  command_version +
  "\">\n <title>" +
  html_escape(title) +
  "</title>\n" +
  " <style>body{font-family:monospace,sans-serif;color:black}p{margin:0;white-space:pre-wrap}a{text-decoration:none}a:hover{text-decoration:underline;background:yellow}.VERSION{font:small sans-serif}.NORM{color:black}.FIFO{color:purple}.CHAR,.BLOCK{color:yellow}.DIR{color:blue}.LINK{color:aqua}.SOCK{color:fuchsia}.EXEC{color:green}</style>\n</head>\n<body>\n\t<h1>" +
  html_escape(title) +
  "</h1><p>\n"
}

///|
fn html_node_line(
  node : TreeNode,
  options : TreeOptions,
  base : String,
  root_path : String,
  prefix : String,
  last : Bool,
  root : Bool,
) -> String {
  let out = StringBuilder()
  out.write_char('\t')
  if !root {
    out.write_string(prefix + (if last { "`-- " } else { "|-- " }))
  }
  if node.size is Some(size) {
    out.write_string(
      ("[" + size_text(size, options.size)[1:].to_owned() + "]    ").replace_all(
        old=" ",
        new="&nbsp;",
      ),
    )
  }
  let offset = base.has_prefix("-")
  let host = if offset { base[1:].to_owned() } else { base }
  let path = if offset && node.path.has_prefix(root_path) {
    node.path[root_path.length():].to_owned()
  } else {
    node.path
  }
  let href = host +
    url_path(path) +
    (if node.kind == Directory { "/" } else { "" })
  out.write_string("<a")
  if options.html_colors {
    let class_name = match node.kind {
      Directory => "DIR"
      Pipe => "FIFO"
      Socket => "SOCK"
      BlockDevice => "BLOCK"
      CharDevice => "CHAR"
      _ => "NORM"
    }
    out.write_string(" class=\"" + class_name + "\"")
  }
  out.write_string(
    " href=\"" +
    html_escape(href) +
    "\">" +
    html_escape(node_label(node, options, root)) +
    "</a>",
  )
  if node_note(node, options, root) is Some(note) {
    out.write_string("  [" + html_escape(note) + "]")
  }
  out.write_string("<br>\n")
  out.to_string()
}

///|
async fn render_html(
  roots : Array[TreeNode],
  options : TreeOptions,
  base : String,
  counts : TreeCounts,
  output : TreeOutput,
) -> Unit {
  output.write(html_intro(options.title))
  let pending : Array[(TreeNode, String, Bool, Bool, String)] = []
  for index = roots.length() - 1; index >= 0; index = index - 1 {
    pending.push((roots[index], "", true, true, roots[index].path))
  }
  while pending.pop() is Some((node, prefix, last, root, root_path)) {
    output.write(
      html_node_line(node, options, base, root_path, prefix, last, root),
    )
    let child_prefix = if root {
      ""
    } else {
      prefix + (if last { "&nbsp;&nbsp;&nbsp; " } else { "|   " })
    }
    for index = node.children.length() - 1; index >= 0; index = index - 1 {
      pending.push(
        (
          node.children[index],
          child_prefix,
          index + 1 == node.children.length(),
          false,
          root_path,
        ),
      )
    }
  }
  let out = StringBuilder()
  if !options.no_report {
    out.write_string("<br><br><p>\n\n")
    write_report(counts, out, options)
    out.write_string("\n</p>\n")
  }
  out.write_string(
    "\t<hr>\n\t<p class=\"VERSION\">cli/tree " +
    command_version +
    "</p>\n</body>\n</html>\n",
  )
  output.write(out.to_string())
}
