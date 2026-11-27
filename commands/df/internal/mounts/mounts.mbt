///|
priv struct Mount {
  id : String
  parent : String
  target : String
  source : String
  kind : String
}

///|
pub(all) enum Column {
  Source
  Type
  Target
}

///|
pub fn columns(text : String) -> Array[Column] raise {
  let fields = []
  let seen : Set[String] = Set([])
  for part in text.split(",") {
    let name = part.to_owned()
    guard !seen.contains(name) else {
      raise Failure("duplicate output column: " + name)
    }
    seen.insert(name)
    fields.push(
      match name {
        "source" => Source
        "fstype" => Type
        "target" => Target
        _ => raise Failure("unsupported output column: " + name)
      },
    )
  }
  fields
}

///|
fn unescape(text : StringView) -> String {
  text
  .replace_all(old="\\040", new=" ")
  .replace_all(old="\\011", new="\t")
  .replace_all(old="\\012", new="\n")
  .replace_all(old="\\134", new="\\")
  .to_owned()
}

///|
fn parse(text : String) -> Array[Mount] raise {
  let mounts = []
  for line in text.split("\n") {
    if line.is_empty() {
      continue
    }
    let parts = line.split(" ").collect()
    guard parts.length() >= 10 else {
      raise Failure("invalid mountinfo record")
    }
    let mut i = 6
    while i < parts.length() && parts[i] != "-" {
      i += 1
    }
    guard i + 3 < parts.length() else {
      raise Failure("incomplete mountinfo record")
    }
    mounts.push({
      id: parts[0].to_owned(),
      parent: parts[1].to_owned(),
      target: unescape(parts[4]),
      source: unescape(parts[i + 2]),
      kind: unescape(parts[i + 1]),
    })
  }
  mounts
}

///|
fn locate(mounts : ArrayView[Mount], path : String) -> Mount raise {
  let roots = mounts.filter(m => m.target == "/")
  guard roots is [root] else {
    raise Failure("ambiguous or missing root mount")
  }
  let mut current = root
  let visited : Set[String] = Set([])
  while !visited.contains(current.id) {
    visited.insert(current.id)
    let mut next : Mount? = None
    for mount in mounts {
      if mount.parent != current.id ||
        mount.id == current.id ||
        !(path == mount.target || path.has_prefix(mount.target + "/")) {
        continue
      }
      match next {
        Some(previous) if previous.target == mount.target =>
          raise Failure("ambiguous stacked mount")
        Some(previous) if previous.target.length() <= mount.target.length() =>
          ()
        _ => next = Some(mount)
      }
    }
    match next {
      Some(child) => current = child
      None => return current
    }
  }
  raise Failure("cyclic mountinfo record")
}

///|
pub async fn table(
  fields : ArrayView[Column],
  paths : ArrayView[String],
) -> String {
  guard @async.platform is Linux else {
    raise Failure("mount information requires Linux procfs")
  }
  let mounts = parse(@fs.read_text("/proc/self/mountinfo"))
  let header = fields.map(field => {
    match field {
      Source => "Filesystem"
      Type => "Type"
      Target => "Mounted on"
    }
  })
  let widths = header.map(label => label.length())
  let rows = [header]
  for path in paths {
    let mount = locate(mounts, @fs.realpath(path))
    let row = fields.map(field => {
      match field {
        Source => mount.source
        Type => mount.kind
        Target => mount.target
      }
    })
    for i, cell in row {
      guard cell.iter().all(ch => ch >= ' ' && ch <= '~') else {
        raise Failure("mount display requires printable ASCII")
      }
      widths[i] = widths[i].max(cell.length())
    }
    rows.push(row)
  }
  let output = StringBuilder()
  for row in rows {
    for i, cell in row {
      output.write_string(cell)
      if i + 1 < row.length() {
        output.write_string(" ".repeat(widths[i] + 1 - cell.length()))
      }
    }
    output.write_char('\n')
  }
  output.to_string()
}
