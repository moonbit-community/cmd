///|
fn graph_fixture_modules(root : String) -> Json {
  {
    "version": 1,
    "status": "success",
    "error": Json::null(),
    "root": 2,
    "modules": [
      {
        "name": "vendor/dependency",
        "version": "1.2.3",
        "source": { "kind": "registry" },
        "workspace_member": false,
      },
      {
        "name": "cli/core",
        "version": "0.7.0",
        "source": { "kind": "local", "path": Json(root + "/core") },
        "workspace_member": true,
      },
      {
        "name": "test/workspace",
        "version": "0.2.0",
        "source": { "kind": "local", "path": Json(root + "/tests") },
        "workspace_member": true,
      },
    ],
    "edges": [
      { "from": 2, "to": 1, "name": "cli/core", "kind": "regular" },
      { "from": 1, "to": 0, "name": "vendor/dependency", "kind": "regular" },
    ],
    "logs": [],
  }
}

///|
fn graph_fixture_packages(
  root : String,
  version : Int32,
  target~ : String = "native",
) -> Json {
  let value : Json = {
    "version": Json(version),
    "status": "success",
    "error": Json::null(),
    "root": [2, 3],
    "nodes": [
      {
        "module": "vendor/dependency",
        "version": "1.2.3",
        "source": { "kind": "registry" },
        "rel": "",
      },
      {
        "module": "cli/core",
        "version": "0.7.0",
        "source": { "kind": "local", "path": Json(root + "/core") },
        "rel": "stream",
      },
      {
        "module": "test/workspace",
        "version": "0.2.0",
        "source": { "kind": "local", "path": Json(root + "/tests") },
        "rel": "a",
      },
      {
        "module": "test/workspace",
        "version": "0.2.0",
        "source": { "kind": "local", "path": Json(root + "/tests") },
        "rel": "isolated",
      },
    ],
    "edges": [
      {
        "from": 2,
        "to": 1,
        "alias": "stream",
        "kinds": ["whitebox-test", "source"],
      },
      { "from": 1, "to": 0, "alias": "dep", "kinds": ["blackbox-test"] },
    ],
    "logs": [],
  }
  if version == 3 && value is Object(object) {
    object["target"] = Json(target)
  }
  value
}

///|
fn graph_fixture_set(value : Json, field : String, replacement : Json) -> Json {
  guard value is Object(object) else { abort("fixture must be object") }
  object[field] = replacement
  value
}

///|
fn graph_fixture_root(name~ : String = "snapshot") -> String {
  graph_slashes(@env.current_dir().unwrap()) + "/" + name
}

///|
fn graph_fixture_edge(
  from : Int32,
  to : Int32,
  import_alias : String,
  kinds : Array[String],
) -> Json {
  {
    "from": Json(from),
    "to": Json(to),
    "alias": Json(import_alias),
    "kinds": Json(kinds),
  }
}

///|
fn graph_expect_invalid(
  value : Json,
  modules : Json,
  root : String,
) -> Unit raise {
  try parse_package_graph(value, modules, root, "native") catch {
    _ => ()
  } noraise {
    _ => fail("invalid graph must not become a successful empty scope")
  }
}

///|
test "scope public package graph v2 retains isolated owners and all import kinds" {
  let root = graph_fixture_root()
  let graph = parse_package_graph(
    graph_fixture_packages(root, 2),
    graph_fixture_modules(root),
    root,
    "native",
  )
  assert_eq(graph.nodes.length(), 4)
  let node = graph.nodes.filter(node => node.id == "local:tests/isolated")[0]
  assert_eq(node.owner, "tests/isolated")
  assert_eq(node.source, "local:tests")
  assert_eq(node.backends, ["native", "wasm"])
  assert_true(
    graph.edges.all(edge => edge.from != node.id && edge.to != node.id),
  )
  let edge = graph.edges.filter(edge => edge.import_alias == "stream")[0]
  assert_eq(edge.from, "local:tests/a")
  assert_eq(edge.to, "local:core/stream")
  assert_eq(edge.kinds, ["source", "whitebox-test"])
  assert_eq(edge.backends, ["native", "wasm"])
  assert_true(graph.uncertainties.is_empty())
  let other_root = graph_fixture_root(name="different")
  let relocated = parse_package_graph(
    graph_fixture_packages(other_root, 2),
    graph_fixture_modules(other_root),
    other_root,
    "wasm",
  )
  assert_eq(graph, relocated)
  assert_eq(graph_digest(graph), graph_digest(relocated))
}

///|
test "scope public graph rejects corrupt schema status indices identities and ownership" {
  let root = graph_fixture_root()
  let modules = graph_fixture_modules(root)
  for
    (field, replacement) in [
      ("version", Json(4)),
      ("version", Json(2.5)),
      ("status", Json("failure")),
      ("error", Json("resolver failed")),
      ("nodes", Json::array([])),
      ("root", Json::array([])),
      ("root", Json([2, 2, 3])),
      ("root", Json([1, 2, 3])),
      ("root", Json([2])),
      ("root", Json([2, 999])),
      ("unknown", Json(true)),
    ] {
    graph_expect_invalid(
      graph_fixture_set(graph_fixture_packages(root, 2), field, replacement),
      modules,
      root,
    )
  }
  for
    edge in [
      graph_fixture_edge(-1, 1, "bad", ["source"]),
      graph_fixture_edge(2, 99, "bad", ["source"]),
      graph_fixture_edge(2, 2, "bad", ["source"]),
      graph_fixture_edge(2, 1, "", ["source"]),
      graph_fixture_edge(2, 1, "bad", []),
      graph_fixture_edge(2, 1, "bad", ["source", "source"]),
      graph_fixture_edge(2, 1, "bad", ["future-condition"]),
    ] {
    graph_expect_invalid(
      graph_fixture_set(graph_fixture_packages(root, 2), "edges", Json([edge])),
      modules,
      root,
    )
  }
  let duplicate : Json = {
    "from": 2,
    "to": 1,
    "alias": "bad",
    "kinds": ["source"],
  }
  graph_expect_invalid(
    graph_fixture_set(
      graph_fixture_packages(root, 2),
      "edges",
      Json([duplicate, duplicate]),
    ),
    modules,
    root,
  )
  let elsewhere = graph_fixture_root(name="elsewhere")
  graph_expect_invalid(
    graph_fixture_packages(elsewhere, 2),
    graph_fixture_modules(elsewhere),
    root,
  )
  graph_expect_invalid(
    graph_fixture_packages(root, 2),
    graph_fixture_modules(graph_fixture_root(name="other")),
    root,
  )
  let packages = graph_fixture_packages(root, 2)
  guard packages is Object(object) && object.get("nodes") is Some(Array(nodes)) else {
    fail("fixture nodes")
  }
  nodes[0] = graph_fixture_set(nodes[0], "version", Json("9.9.9"))
  graph_expect_invalid(packages, modules, root)
  graph_expect_invalid(
    graph_fixture_packages(root, 3, target="wasm"),
    modules,
    root,
  )
}

///|
test "scope graph digest is stable under public node numbering and edge order" {
  let root = graph_fixture_root()
  let original = graph_fixture_packages(root, 2)
  let reordered = graph_fixture_packages(root, 2)
  guard reordered is Object(object) && object.get("nodes") is Some(Array(nodes)) else {
    fail("fixture nodes")
  }
  object["nodes"] = Json([nodes[3], nodes[2], nodes[1], nodes[0]])
  object["root"] = Json([1, 0])
  object["edges"] = Json::array([
    graph_fixture_edge(2, 3, "dep", ["blackbox-test"]),
    graph_fixture_edge(1, 2, "stream", ["source", "whitebox-test"]),
  ])
  let modules = graph_fixture_modules(root)
  let left = parse_package_graph(original, modules, root, "native")
  let right = parse_package_graph(reordered, modules, root, "wasm")
  assert_eq(graph_digest(left), graph_digest(right))
}

///|
test "scope graph v3 unions backend edges without dropping isolated packages" {
  let root = graph_fixture_root()
  let native = parse_package_graph(
    graph_fixture_packages(root, 3),
    graph_fixture_modules(root),
    root,
    "native",
  )
  let wasm_value = graph_fixture_set(
    graph_fixture_packages(root, 3, target="wasm"),
    "edges",
    Json::array([graph_fixture_edge(2, 0, "only_wasm", ["blackbox-test"])]),
  )
  let wasm = parse_package_graph(
    wasm_value,
    graph_fixture_modules(root),
    root,
    "wasm",
  )
  let graph = merge_backend_graphs(native, wasm)
  assert_eq(graph.nodes.length(), 4)
  assert_true(graph.nodes.all(node => node.backends == ["native", "wasm"]))
  assert_eq(graph.edges.length(), 3)
  assert_eq(
    graph.edges.filter(edge => edge.import_alias == "only_wasm")[0].backends,
    ["wasm"],
  )
  assert_eq(
    graph.edges.filter(edge => edge.import_alias == "stream")[0].backends,
    ["native"],
  )
}

///|
test "scope graph identity agrees across public v2 and v3 for shared import syntax" {
  let root = graph_fixture_root()
  let modules = graph_fixture_modules(root)
  let old = parse_package_graph(
    graph_fixture_packages(root, 2),
    modules,
    root,
    "native",
  )
  let current = merge_backend_graphs(
    parse_package_graph(
      graph_fixture_packages(root, 3),
      modules,
      root,
      "native",
    ),
    parse_package_graph(
      graph_fixture_packages(root, 3, target="wasm"),
      modules,
      root,
      "wasm",
    ),
  )
  assert_eq(graph_digest(old), graph_digest(current))
}

///|
test "scope graph acquisition progress has the same identity as a warm resolver" {
  let root = graph_fixture_root()
  let warm = parse_package_graph(
    graph_fixture_packages(root, 2),
    graph_fixture_modules(root),
    root,
    "native",
  )
  let module_logs : Array[Json] = [
    { "level": "info", "message": "Registry index cloned successfully" },
    { "level": "info", "message": "Registry index updated successfully" },
    { "level": "info", "message": "Registry index re-cloned successfully" },
    {
      "level": "info",
      "message": "Registry update already completed by another process",
    },
    { "level": "info", "message": "Symbols updated successfully" },
  ]
  let package_logs : Array[Json] = [
    { "level": "info", "message": "Using cached vendor/dependency@1.2.3" },
    { "level": "info", "message": "Downloading vendor/dependency@1.2.3" },
  ]
  let cold = parse_package_graph(
    graph_fixture_set(
      graph_fixture_packages(root, 2),
      "logs",
      Json(package_logs),
    ),
    graph_fixture_set(graph_fixture_modules(root), "logs", Json(module_logs)),
    root,
    "native",
  )
  assert_true(cold.uncertainties.is_empty())
  assert_eq(graph_digest(cold), graph_digest(warm))
}

///|
test "scope graph warnings unknown progress and malformed logs cannot narrow scope" {
  let root = graph_fixture_root()
  let modules = graph_fixture_modules(root)
  let messages : Array[Json] = [
    { "level": "warning", "message": "Using cached vendor/dependency@1.2.3" },
    { "level": "error", "message": "Using cached vendor/dependency@1.2.3" },
    { "level": "debug", "message": "Using cached vendor/dependency@1.2.3" },
    { "level": "info", "message": "Using cached unrecognized/package@9.9.9" },
    {
      "level": "info",
      "message": "Downloading https://example.invalid/archive",
    },
    { "level": "future", "message": "new semantic condition" },
  ]
  for message in messages {
    let graph = parse_package_graph(
      graph_fixture_set(
        graph_fixture_packages(root, 2),
        "logs",
        Json([message]),
      ),
      modules,
      root,
      "native",
    )
    assert_true(!graph.uncertainties.is_empty())
  }
  let diagnostics : Array[DependencyGraph] = []
  for
    diagnostic_message in [
      "/tmp/one at 10:00", "https://example.invalid/two at 12:00",
    ] {
    let logs : Array[Json] = [
      { "level": "warning", "message": Json(diagnostic_message) },
    ]
    diagnostics.push(
      parse_package_graph(
        graph_fixture_set(graph_fixture_packages(root, 2), "logs", Json(logs)),
        modules,
        root,
        "native",
      ),
    )
  }
  assert_eq(graph_digest(diagnostics[0]), graph_digest(diagnostics[1]))
  let malformed : Array[Json] = [
    { "level": "info", "message": 1 },
    {
      "level": "info",
      "message": "Using cached vendor/dependency@1.2.3",
      "unknown": true,
    },
    { "message": "missing severity" },
  ]
  for row in malformed {
    graph_expect_invalid(
      graph_fixture_set(graph_fixture_packages(root, 2), "logs", Json([row])),
      modules,
      root,
    )
  }
}

///|
fn graph_fixture_snapshot() -> TreeSnapshot {
  let paths = [
    "moon.work", "core/moon.mod", "core/stream/moon.pkg", "tests/moon.mod", "tests/a/moon.pkg",
    "tests/isolated/moon.pkg", "tests/a/input.mbt",
  ]
  {
    tree: "fixture-tree",
    files: paths.map(path => {
      path,
      mode: "100644",
      blob: "fixture-blob",
      content: if path.has_suffix("input.mbt") {
        b"snapshot bytes\x00\xff"
      } else {
        b""
      },
    }),
  }
}

///|
async test "scope graph capture materializes immutable bytes uses v2 without target and cleans ownership" {
  let calls : Array[Array[String]] = []
  let owned = Ref("")
  let graph = capture_graph_using(graph_fixture_snapshot(), (cwd, arguments) => {
    let root = graph_slashes(@path.Path(cwd).dirname().to_string())
    owned.val = root
    assert_true(cwd.has_suffix("/tests") || cwd.has_suffix("\\tests"))
    assert_eq(
      @fs.read_file(root + "/tests/a/input.mbt").binary(),
      b"snapshot bytes\x00\xff",
    )
    calls.push(arguments.copy())
    let value = if arguments.contains("--package") {
      graph_fixture_packages(root, 2)
    } else {
      graph_fixture_modules(root)
    }
    (0, value.stringify(), "")
  })
  assert_eq(calls, [["tree", "--json"], ["tree", "--json", "--package"]])
  assert_eq(graph.nodes.length(), 4)
  assert_true(graph.uncertainties.is_empty())
  assert_false(@fs.exists(owned.val))
}

///|
async test "scope graph capture requests missing v3 backend and does not narrow failed resolution" {
  let snapshot = graph_fixture_snapshot()
  let calls : Array[Array[String]] = []
  let graph = capture_graph_using(snapshot, (cwd, arguments) => {
    let root = graph_slashes(@path.Path(cwd).dirname().to_string())
    calls.push(arguments.copy())
    let value = if !arguments.contains("--package") {
      graph_fixture_modules(root)
    } else {
      graph_fixture_packages(
        root,
        3,
        target=if arguments.contains("wasm") { "wasm" } else { "native" },
      )
    }
    (0, value.stringify(), "")
  })
  assert_eq(calls.length(), 3)
  assert_eq(calls[2], ["tree", "--json", "--package", "--target", "wasm"])
  assert_true(graph.nodes.all(node => node.backends == ["native", "wasm"]))
  let failed = capture_graph_using(snapshot, (_, _) => {
    (7, "", "resolver unavailable")
  })
  assert_eq(failed.nodes.length(), 3)
  assert_true(failed.nodes.all(node => node.source == "snapshot-unresolved"))
  assert_true(failed.edges.is_empty())
  assert_true(failed.uncertainties[0].contains("resolver unavailable"))
  let malformed = capture_graph_using(snapshot, (_, _) => {
    (0, "{\"version\":1,\"version\":1}", "")
  })
  assert_true(!malformed.uncertainties.is_empty())
  assert_true(!malformed.nodes.is_empty())
}

///|
async test "scope graph capture rejects unsafe snapshot paths and unsupported file modes before resolver" {
  for
    (path, mode) in [
      ("../escape/moon.pkg", "100644"),
      ("/absolute/moon.pkg", "100644"),
      ("tests\\moon.pkg", "100644"),
      (".git/config", "100644"),
      ("tests/link", "120000"),
      ("tests/module", "160000"),
    ] {
    let called = Ref(false)
    let graph = capture_graph_using(
      {
        tree: "tree",
        files: [{ path, mode, blob: "blob", content: b"escape", }],
      },
      (_, _) => {
        called.val = true
        fail("unsafe snapshot must not run resolver")
      },
    )
    assert_false(called.val)
    assert_true(!graph.nodes.is_empty())
    assert_true(!graph.uncertainties.is_empty())
  }
}

///|
async test "scope graph capture retains unknown semantics and cleans resolver exceptions" {
  let snapshot = graph_fixture_snapshot()
  let annotated = {
    ..snapshot,
    files: snapshot.files.map(file => {
      if file.path == "tests/a/moon.pkg" {
        { ..file, content: b"#cfg(backend=\"native\")\nimport {}\n", }
      } else {
        file
      }
    }),
  }
  let graph = capture_graph_using(annotated, (cwd, arguments) => {
    let root = graph_slashes(@path.Path(cwd).dirname().to_string())
    let value = if arguments.contains("--package") {
      graph_fixture_packages(root, 2)
    } else {
      graph_fixture_modules(root)
    }
    (0, value.stringify(), "")
  })
  assert_eq(graph.nodes.length(), 4)
  assert_true(graph.uncertainties.any(reason => reason.contains("#cfg")))
  let owned = Ref("")
  let failed = capture_graph_using(snapshot, (cwd, _) => {
    owned.val = graph_slashes(@path.Path(cwd).dirname().to_string())
    fail("injected resolver exception")
  })
  assert_true(!failed.nodes.is_empty())
  assert_true(failed.uncertainties[0].contains("injected resolver exception"))
  assert_false(@fs.exists(owned.val))
}

///|
async test "scope graph capture rejects case-colliding directories and omitted local packages" {
  let original = graph_fixture_snapshot()
  let collision : TreeFile = {
    path: "TESTS/other.mbt",
    mode: "100644",
    blob: "blob",
    content: b"",
  }
  let called = Ref(false)
  let rejected = capture_graph_using(
    { ..original, files: original.files + [collision], },
    (_, _) => {
      called.val = true
      fail("case-colliding directories must be rejected before resolver")
    },
  )
  assert_false(called.val)
  assert_true(!rejected.uncertainties.is_empty())
  let omitted : TreeFile = {
    path: "tests/omitted/moon.pkg",
    mode: "100644",
    blob: "blob",
    content: b"",
  }
  let graph = capture_graph_using(
    { ..original, files: original.files + [omitted], },
    (cwd, arguments) => {
      let root = graph_slashes(@path.Path(cwd).dirname().to_string())
      let value = if arguments.contains("--package") {
        graph_fixture_packages(root, 2)
      } else {
        graph_fixture_modules(root)
      }
      (0, value.stringify(), "")
    },
  )
  assert_true(graph.nodes.any(node => node.owner == "tests/omitted"))
  assert_true(graph.nodes.all(node => node.source == "snapshot-unresolved"))
  assert_true(graph.uncertainties[0].contains("snapshot package omitted"))
}

///|
async test "scope graph capture projects the known README link without host symlink privileges" {
  let original = graph_fixture_snapshot()
  let readme : TreeFile = {
    path: "README.md",
    mode: "120000",
    blob: "link",
    content: b"README.mbt.md",
  }
  let target : TreeFile = {
    path: "README.mbt.md",
    mode: "100644",
    blob: "text",
    content: b"readme bytes\n",
  }
  let graph = capture_graph_using(
    { ..original, files: original.files + [readme, target], },
    (cwd, arguments) => {
      let root = graph_slashes(@path.Path(cwd).dirname().to_string())
      assert_eq(@fs.kind(root + "/README.md", follow_symlink=false), Regular)
      assert_eq(@fs.read_file(root + "/README.md").binary(), target.content)
      let value = if arguments.contains("--package") {
        graph_fixture_packages(root, 2)
      } else {
        graph_fixture_modules(root)
      }
      (0, value.stringify(), "")
    },
  )
  assert_true(graph.uncertainties.is_empty())
  let unsafe_link = { ..readme, content: b"../outside", }
  let called = Ref(false)
  let rejected = capture_graph_using(
    { ..original, files: original.files + [unsafe_link, target], },
    (_, _) => {
      called.val = true
      fail("unsafe README must not invoke resolver")
    },
  )
  assert_false(called.val)
  assert_true(!rejected.uncertainties.is_empty())
}
