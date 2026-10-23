///|
fn graph_parent(path : String) -> String {
  let parts = path.split("/").collect()
  if parts.length() <= 1 {
    "."
  } else {
    parts[:parts.length() - 1].map(part => part.to_owned()).join("/")
  }
}

///|
// The repository's README link has no graph semantics. Project only this exact
// same-directory link to regular UTF-8 target bytes, without host symlink APIs.
// Manifest, source, directory and unknown links remain unresolved boundaries.
fn graph_project_snapshot(snapshot : TreeSnapshot) -> TreeSnapshot raise {
  let files : Array[TreeFile] = []
  for file in snapshot.files {
    if file.mode == "120000" {
      guard (file.path == "README.md" || file.path.has_suffix("/README.md")) &&
        @utf8.decode(file.content) == "README.mbt.md" else {
        fail("graph: unsupported snapshot symlink")
      }
      let parent = graph_parent(file.path)
      let target = if parent == "." {
        "README.mbt.md"
      } else {
        parent + "/README.mbt.md"
      }
      let targets = snapshot.files.filter(other => other.path == target)
      guard targets.length() == 1 &&
        ["100644", "100755"].contains(targets[0].mode) else {
        fail("graph: README projection requires one regular snapshot target")
      }
      ignore(@utf8.decode(targets[0].content))
      files.push({ ..file, mode: "100644", content: targets[0].content, })
    } else {
      files.push(file)
    }
  }
  { ..snapshot, files, }
}

///|
fn graph_snapshot_paths(snapshot : TreeSnapshot) -> Map[String, Bool] raise {
  let paths : Map[String, Bool] = Map([])
  let portable : Map[String, String] = Map([])
  for file in snapshot.files {
    ignore(graph_relative(file.path))
    guard ["100644", "100755"].contains(file.mode) else {
      fail("graph: snapshot has a symlink, submodule, or unsupported file mode")
    }
    guard !paths.contains(file.path) else {
      fail("graph: duplicate snapshot path")
    }
    let mut portable_path = file.path
    while portable_path != "." {
      let key = portable_path.to_lower()
      guard portable.get(key) is None ||
        portable.get(key) == Some(portable_path) else {
        fail("graph: case-ambiguous snapshot path or directory")
      }
      portable[key] = portable_path
      portable_path = graph_parent(portable_path)
    }
    paths[file.path] = true
  }
  for path in paths.keys() {
    let mut parent = graph_parent(path)
    while parent != "." {
      guard !paths.contains(parent) else {
        fail("graph: file is also a directory")
      }
      parent = graph_parent(parent)
    }
  }
  paths
}

///|
// Public tree output does not describe virtual implementation selection or
// prebuild-generated imports. These declarations cannot narrow a scope safely.
// This is a conservative marker check, not a parser for the MoonBit DSL.
fn graph_manifest_uncertainties(snapshot : TreeSnapshot) -> Array[String] {
  let reasons : Array[String] = []
  for file in snapshot.files {
    if file.path == "moon.work" ||
      file.path.has_suffix("/moon.work") ||
      file.path == "moon.pkg" ||
      file.path.has_suffix("/moon.pkg") ||
      file.path == "moon.mod" ||
      file.path.has_suffix("/moon.mod") ||
      file.path.has_suffix("moon.pkg.json") ||
      file.path.has_suffix("moon.mod.json") {
      let text = @utf8.decode(file.content) catch {
        _ => {
          reasons.push("manifest is not valid UTF-8: " + file.path)
          continue
        }
      }
      for
        marker in [
          "#cfg", "virtual", "implement", "overrides", "pre-build", "pre_build",
          "prebuild", "native-stub", "native_stub", "import-all", "import_all",
        ] {
        if text.contains(marker) {
          reasons.push(
            "public graph omits manifest semantics (" +
            marker +
            "): " +
            file.path,
          )
        }
      }
    }
  }
  graph_sorted_strings(reasons)
}

///|
fn unresolved_snapshot_graph(
  snapshot : TreeSnapshot,
  reason : String,
) -> DependencyGraph {
  let owners : Array[String] = []
  for file in snapshot.files {
    if file.path == "moon.pkg" ||
      file.path.has_suffix("/moon.pkg") ||
      file.path == "moon.pkg.json" ||
      file.path.has_suffix("/moon.pkg.json") {
      try graph_relative(file.path) catch {
        _ => continue
      } noraise {
        _ => owners.push(graph_parent(file.path))
      }
    }
  }
  if owners.is_empty() {
    owners.push(".")
  }
  let nodes = graph_sorted_strings(owners).map(owner => {
    id: "unresolved:" + owner,
    owner,
    module_name: "",
    version: "",
    source: "snapshot-unresolved",
    backends: ["native", "wasm"],
  })
  normalize_graph({ nodes, edges: [], uncertainties: [reason], })
}

///|
fn graph_snapshot_ownership(
  graph : DependencyGraph,
  paths : Map[String, Bool],
) -> Unit raise {
  let owners : Map[String, Bool] = Map([])
  for node in graph.nodes {
    if node.source.has_prefix("local:") {
      let package_file = if node.owner == "." {
        "moon.pkg"
      } else {
        node.owner + "/moon.pkg"
      }
      guard paths.contains(package_file) ||
        paths.contains(package_file + ".json") else {
        fail("graph: resolved local package has no snapshot manifest")
      }
      let module_owner = node.source["local:".length():].to_owned()
      let module_file = if module_owner == "." {
        "moon.mod"
      } else {
        module_owner + "/moon.mod"
      }
      guard paths.contains(module_file) || paths.contains(module_file + ".json") else {
        fail("graph: resolved local module has no snapshot manifest")
      }
      let mut nearest = node.owner
      while true {
        let nearest_file = if nearest == "." {
          "moon.mod"
        } else {
          nearest + "/moon.mod"
        }
        if paths.contains(nearest_file) ||
          paths.contains(nearest_file + ".json") {
          guard nearest == module_owner else {
            fail("graph: package crosses a nested module owner")
          }
          break
        }
        guard nearest != "." else {
          fail("graph: package has no ancestor module")
        }
        nearest = graph_parent(nearest)
      }
      owners[node.owner] = true
    }
  }
  for path in paths.keys() {
    if path == "moon.pkg" ||
      path.has_suffix("/moon.pkg") ||
      path == "moon.pkg.json" ||
      path.has_suffix("/moon.pkg.json") {
      guard owners.contains(graph_parent(path)) else {
        fail("graph: snapshot package omitted by public resolver")
      }
    }
  }
}

///|
fn graph_diagnostic(text : String, root : String) -> String {
  graph_slashes(text)
  .split(graph_slashes(root))
  .map(part => part.to_owned())
  .collect()
  .join("<snapshot>")
}

///|
async fn graph_command(
  cwd : String,
  arguments : Array[String],
  execute : async (String, Array[String]) -> (Int32, String, String),
) -> Json {
  let (status, stdout, stderr) = execute(cwd, arguments)
  guard status == 0 else {
    fail(
      "graph: public moon tree failed (" + status.to_string() + "): " + stderr,
    )
  }
  strict_json(stdout)
}

///|
async fn capture_materialized_graph(
  snapshot : TreeSnapshot,
  root : String,
  execute : async (String, Array[String]) -> (Int32, String, String),
) -> DependencyGraph {
  let snapshot = graph_project_snapshot(snapshot)
  let paths = graph_snapshot_paths(snapshot)
  let modules : Array[String] = []
  for file in snapshot.files {
    if file.path == "moon.pkg.json" ||
      file.path.has_suffix("/moon.pkg.json") ||
      file.path == "moon.mod.json" ||
      file.path.has_suffix("/moon.mod.json") {
      ignore(strict_json(@utf8.decode(file.content)))
    }
    let destination = root + "/" + file.path
    let parent = graph_parent(file.path)
    if parent != "." {
      @fs.mkdir(root + "/" + parent, recursive=true, allow_exist=true)
    }
    @fs.write_file(
      destination,
      file.content,
      create_mode=CreateNew,
      permission=if file.mode == "100755" { 0o700 } else { 0o600 },
    )
    if file.path == "moon.mod" ||
      file.path.has_suffix("/moon.mod") ||
      file.path == "moon.mod.json" ||
      file.path.has_suffix("/moon.mod.json") {
      modules.push(parent)
    }
  }
  guard !modules.is_empty() else {
    fail("graph: snapshot has no module manifest")
  }
  modules.sort()
  let selected = if modules.contains("tests") { "tests" } else { modules[0] }
  let cwd = if selected == "." { root } else { root + "/" + selected }
  let module_graph = graph_command(cwd, ["tree", "--json"], execute)
  let initial = graph_command(cwd, ["tree", "--json", "--package"], execute)
  guard initial is Object(object) else {
    fail("graph: expected package graph envelope")
  }
  let version = graph_int(graph_field(object, "version"))
  let graph = if version == 2 {
    // CI's pinned Moon supports v2 and rejects --target; its import graph is
    // already a conservative backend union, so no toolchain upgrade is needed.
    parse_package_graph(initial, module_graph, root, "native")
  } else if version == 3 {
    let target = graph_string(graph_field(object, "target"))
    let native = if target == "native" {
      initial
    } else {
      graph_command(
        cwd,
        ["tree", "--json", "--package", "--target", "native"],
        execute,
      )
    }
    let wasm = if target == "wasm" {
      initial
    } else {
      graph_command(
        cwd,
        ["tree", "--json", "--package", "--target", "wasm"],
        execute,
      )
    }
    // Validate even an unused preferred-backend response before accepting it.
    guard ["native", "wasm"].contains(target) else {
      fail("graph: preferred package backend is outside Native/Wasm")
    }
    merge_backend_graphs(
      parse_package_graph(native, module_graph, root, "native"),
      parse_package_graph(wasm, module_graph, root, "wasm"),
    )
  } else {
    fail("graph: unsupported public package graph version")
  }
  graph_snapshot_ownership(graph, paths)
  normalize_graph({
    ..graph,
    uncertainties: graph.uncertainties + graph_manifest_uncertainties(snapshot),
  })
}

///|
async fn capture_graph_using(
  snapshot : TreeSnapshot,
  execute : async (String, Array[String]) -> (Int32, String, String),
) -> DependencyGraph {
  // tmpdir atomically creates a fresh private directory. No user checkout is
  // modified, and cleanup is nocancel even when resolver execution is cancelled.
  let temporary = @fs.tmpdir(prefix="mooncmd-scope-graph-")
  defer @fs.rmdir(temporary, recursive=true)
  let root = @fs.realpath(temporary)
  capture_materialized_graph(snapshot, root, execute) catch {
    error => {
      if @async.is_being_cancelled() {
        raise error
      }
      unresolved_snapshot_graph(
        snapshot,
        "dependency graph unresolved: " +
        graph_diagnostic(error.to_string(), root),
      )
    }
  }
}

///|
/// Resolve the exact Git snapshot through Moon's public graph interface. Graph
/// uncertainty is explicit and never represented by an empty successful scope.
pub async fn capture_graph(snapshot : TreeSnapshot) -> DependencyGraph {
  capture_graph_using(snapshot, (cwd, arguments) => {
    let output = @shell.Cmd("moon", arguments, cwd~).output(
      timeout_ms=120000,
      max_output_bytes=16777216,
    )
    (output.exit_code(), output.stdout(), output.stderr())
  })
}
