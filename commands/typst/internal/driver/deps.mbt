// Adapted for cli/typst from moonbitlang/typst.mbt; see README.md and NOTICE.
// Modified for the private CLI/platform integration and Wasm package layout.

// Dependency files (upstream `typst-cli/src/deps.rs`).

///|
/// Writes dependencies in the given format.
async fn write_deps(
  world : SystemWorld,
  dest : Output,
  format : DepsFormat,
  outputs : Array[Output]?,
) -> Unit raise @platform.IoError {
  match format {
    Json => write_deps_json(world, dest, outputs)
    Zero => write_deps_zero(world, dest)
    Make =>
      if outputs is Some(outputs) {
        write_deps_make(world, dest, outputs)
      }
  }
}

///|
/// Writes dependencies in JSON format.
async fn write_deps_json(
  world : SystemWorld,
  dest : Output,
  outputs : Array[Output]?,
) -> Unit raise @platform.IoError {
  let inputs : Array[Json] = relative_dependencies(world).map(dep => {
    Json::string(dep)
  })
  let outputs : Json = match outputs {
    Some(outputs) => {
      let list : Array[Json] = []
      for output in outputs {
        match output {
          Path(path) => list.push(Json::string(path))
          // Skip stdout
          Stdout => ()
        }
      }
      Json::array(list)
    }
    None => Json::null()
  }
  let deps : Json = { "inputs": Json::array(inputs), "outputs": outputs }
  dest.write(@utf8.encode(json_compact(deps)))
}

///|
/// Serializes JSON like `serde_json::to_string` (keys in insertion order).
fn json_compact(json : Json) -> String {
  json.stringify()
}

///|
/// Writes dependencies in the Zero / Text0 format.
async fn write_deps_zero(
  world : SystemWorld,
  dest : Output,
) -> Unit raise @platform.IoError {
  let buf = StringBuilder()
  for dep in relative_dependencies(world) {
    buf.write_string(dep)
    buf.write_char('\u{0}')
  }
  dest.write(@utf8.encode(buf.to_string()))
}

///|
/// Writes dependencies in the Make format.
async fn write_deps_make(
  world : SystemWorld,
  dest : Output,
  outputs : Array[Output],
) -> Unit raise @platform.IoError {
  let buffer = StringBuilder()
  for i, output in outputs {
    let path = match output {
      Path(path) => path
      Stdout =>
        raise @platform.IoError(
          Other,
          "make dependencies contain the output path, but the output was stdout",
        )
    }
    if i != 0 {
      buffer.write_char(' ')
    }
    buffer.write_string(munge(path))
  }

  // Only create the deps file in case of valid output paths.
  buffer.write_char(':')
  for dep in relative_dependencies(world) {
    buffer.write_char(' ')
    buffer.write_string(munge(dep))
  }
  buffer.write_char('\n')
  dest.write(@utf8.encode(buffer.to_string()))
}

///|
/// Based on `munge` in libcpp/mkdeps.cc from the GCC source code. This
/// isn't perfect as some special characters can't be escaped.
fn munge(s : String) -> String {
  let res = StringBuilder()
  let mut slashes = 0
  for c in s {
    match c {
      '\\' => slashes += 1
      '$' => {
        res.write_char('$')
        slashes = 0
      }
      ':' => {
        res.write_char('\\')
        slashes = 0
      }
      ' ' | '\t' => {
        // `munge`'s source contains a comment here that says: "A space or
        // tab preceded by 2N+1 backslashes represents N backslashes
        // followed by space..."
        for _ in 0..<=slashes {
          res.write_char('\\')
        }
        slashes = 0
      }
      '#' => {
        res.write_char('\\')
        slashes = 0
      }
      _ => slashes = 0
    }
    res.write_char(c)
  }
  res.to_string()
}

///|
/// Extracts the current compilation's dependencies as paths relative to the
/// current directory.
fn relative_dependencies(world : SystemWorld) -> Array[String] {
  let root = world.root()
  let current_dir = world.workdir()
  let relative_root = diff_paths(root, current_dir).unwrap_or(root)
  world
  .dependencies()
  .map(dependency => {
    match strip_path_prefix(dependency, root) {
      Some(rest) => @platform.join(relative_root, rest)
      None => dependency
    }
  })
}

///|
/// Rust's `Path::strip_prefix` (component-wise).
fn strip_path_prefix(path : String, prefix : String) -> String? {
  let a = components(path)
  let b = components(prefix)
  guard a.strip_prefix(b[:]) is Some(rest) else { return None }
  Some(rest.to_owned().join(@platform.separator()))
}
