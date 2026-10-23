///|
fn graph_object(
  value : Json,
  fields : Array[String],
) -> Map[String, Json] raise {
  guard value is Object(object) else { fail("graph: expected object") }
  guard object.length() == fields.length() else {
    fail("graph: unexpected object fields")
  }
  for field in fields {
    guard object.contains(field) else { fail("graph: missing field " + field) }
  }
  object
}

///|
fn graph_field(object : Map[String, Json], key : String) -> Json raise {
  guard object.get(key) is Some(value) else { fail("graph: missing " + key) }
  value
}

///|
fn graph_string(value : Json) -> String raise {
  guard value is String(text) else { fail("graph: expected string") }
  text
}

///|
fn graph_array(value : Json) -> Array[Json] raise {
  guard value is Array(values) else { fail("graph: expected array") }
  values
}

///|
fn graph_int(value : Json) -> Int32 raise {
  guard value is Number(number, ..) else { fail("graph: expected integer") }
  let result : Int32 = @json.from_json(value)
  guard result.to_double() == number else {
    fail("graph: nonintegral or overflowing index")
  }
  result
}

///|
fn graph_nonempty(value : Json) -> String raise {
  let text = graph_string(value)
  guard text != "" && !text.contains("\u0000") else {
    fail("graph: empty or NUL-containing identity")
  }
  text
}

///|
fn graph_slashes(path : String) -> String {
  path.split("\\").map(part => part.to_owned()).collect().join("/")
}

///|
// Git paths are deliberately stricter than host paths: one spelling must have
// the same owner on every supported host, and cannot escape an owned snapshot.
fn graph_relative(path : String, empty~ : Bool = false) -> String raise {
  if empty && path == "" {
    return ""
  }
  guard path != "" &&
    !path.contains("\\") &&
    !path.contains(":") &&
    !path.contains("\u0000") &&
    !path.has_prefix("/") else {
    fail("graph: unsafe relative path")
  }
  for part in path.split("/") {
    guard part != "" &&
      part != "." &&
      part != ".." &&
      part.to_owned().to_lower() != ".git" else {
      fail("graph: ambiguous relative path")
    }
  }
  path
}

///|
fn graph_local_owner(path : String, root : String) -> String raise {
  let root = graph_slashes(@path.Path(root).normalize().to_string())
  let path = graph_slashes(@path.Path(path).normalize().to_string())
  guard @path.Path(root).is_absolute() && @path.Path(path).is_absolute() else {
    fail("graph: local module paths must be absolute")
  }
  if root == path {
    return "."
  }
  let prefix = if root.has_suffix("/") { root } else { root + "/" }
  guard path.has_prefix(prefix) else {
    fail("graph: local module outside snapshot")
  }
  graph_relative(path[prefix.length():].to_owned())
}

///|
priv struct GraphModule {
  name : String
  version : String
  source : String
}

///|
fn graph_source(value : Json, root : String) -> (String, String) raise {
  guard value is Object(object) else { fail("graph: expected source") }
  let kind = graph_string(graph_field(object, "kind"))
  match kind {
    "registry" => {
      ignore(graph_object(value, ["kind"]))
      ("registry", "")
    }
    "local" => {
      ignore(graph_object(value, ["kind", "path"]))
      let owner = graph_local_owner(
        graph_string(graph_field(object, "path")),
        root,
      )
      ("local:" + owner, owner)
    }
    _ => fail("graph: unsupported module source " + kind)
  }
}

///|
fn graph_success(
  object : Map[String, Json],
  registry_coordinates : Array[String],
) -> Array[String] raise {
  guard graph_string(graph_field(object, "status")) == "success" &&
    graph_field(object, "error") is Null else {
    fail("graph: resolver did not report success")
  }
  let uncertainties : Array[String] = []
  for value in graph_array(graph_field(object, "logs")) {
    let item = graph_object(value, ["level", "message"])
    let level = graph_string(graph_field(item, "level"))
    let message = graph_string(graph_field(item, "message"))
    // Public registry/client.rs uses these informational status messages for
    // acquisition. Bind module progress to actual resolved coordinates; cache
    // state, URLs and temporary paths must not become graph semantics.
    let progress = registry_coordinates.any(coordinate => {
        message == "Using cached " + coordinate ||
        message == "Downloading " + coordinate
      }) ||
      [
        "Registry index cloned successfully", "Registry index updated successfully",
        "Registry index re-cloned successfully", "Registry update already completed by another process",
        "Symbols updated successfully",
      ].contains(message)
    if level == "info" && progress {
      continue
    }
    uncertainties.push(
      match level {
        "warning" => "public dependency graph contains warning diagnostics"
        "error" => "public dependency graph contains error diagnostics"
        _ => "public dependency graph contains unrecognized diagnostics"
      },
    )
  }
  graph_sorted_strings(uncertainties)
}

///|
fn graph_modules(
  value : Json,
  root : String,
) -> (Array[GraphModule], Int32, Array[String]) raise {
  let object = graph_object(value, [
    "version", "status", "error", "root", "modules", "edges", "logs",
  ])
  guard graph_int(graph_field(object, "version")) == 1 else {
    fail("graph: unsupported module graph version")
  }
  guard graph_string(graph_field(object, "status")) == "success" &&
    graph_field(object, "error") is Null else {
    fail("graph: resolver did not report success")
  }
  let values = graph_array(graph_field(object, "modules"))
  guard !values.is_empty() else { fail("graph: empty module graph") }
  let modules : Array[GraphModule] = []
  let identities : Map[String, Bool] = Map([])
  let local_owners : Map[String, Bool] = Map([])
  for value in values {
    let item = graph_object(value, [
      "name", "version", "source", "workspace_member",
    ])
    let (source, owner) = graph_source(graph_field(item, "source"), root)
    let resolved : GraphModule = {
      name: graph_nonempty(graph_field(item, "name")),
      version: graph_nonempty(graph_field(item, "version")),
      source,
    }
    let workspace_member : Bool = @json.from_json(
      graph_field(item, "workspace_member"),
    )
    guard (source == "registry" && !workspace_member) ||
      (source != "registry" && workspace_member) else {
      fail("graph: module source and workspace ownership disagree")
    }
    let identity = @testkit.canonical_json(
      Json([resolved.name, resolved.version, resolved.source]),
    )
    guard !identities.contains(identity) else {
      fail("graph: duplicate module identity")
    }
    identities[identity] = true
    if source != "registry" {
      guard !local_owners.contains(owner) else {
        fail("graph: duplicate module owner")
      }
      local_owners[owner] = true
    }
    modules.push(resolved)
  }
  let selected = graph_int(graph_field(object, "root"))
  guard selected >= 0 &&
    selected < modules.length() &&
    modules[selected].source != "registry" else {
    fail("graph: invalid selected module")
  }
  let module_edges : Map[String, Bool] = Map([])
  for value in graph_array(graph_field(object, "edges")) {
    let edge = graph_object(value, ["from", "to", "name", "kind"])
    let from = graph_int(graph_field(edge, "from"))
    let to = graph_int(graph_field(edge, "to"))
    guard from >= 0 &&
      from < modules.length() &&
      to >= 0 &&
      to < modules.length() &&
      from != to else {
      fail("graph: invalid module edge index")
    }
    let name = graph_nonempty(graph_field(edge, "name"))
    let kind = graph_string(graph_field(edge, "kind"))
    guard ["regular", "binary"].contains(kind) else {
      fail("graph: unknown module edge kind")
    }
    guard modules[to].name == name else {
      fail("graph: module edge name disagrees with target")
    }
    let key = @testkit.canonical_json(
      Json([from.to_string(), to.to_string(), name, kind]),
    )
    guard !module_edges.contains(key) else {
      fail("graph: duplicate module edge")
    }
    module_edges[key] = true
  }
  let coordinates = modules
    .filter(resolved => resolved.source == "registry")
    .map(resolved => resolved.name + "@" + resolved.version)
  (modules, selected, graph_success(object, coordinates))
}

///|
fn graph_edge_key(edge : DependencyEdge) -> String {
  @testkit.canonical_json(Json([edge.from, edge.to, edge.import_alias]))
}

///|
fn graph_sorted_strings(values : Array[String]) -> Array[String] {
  values.sort_by((left, right) => left.lexical_compare(right))
  let result : Array[String] = []
  for value in values {
    if result.last() != Some(value) {
      result.push(value)
    }
  }
  result
}

///|
fn normalize_graph(graph : DependencyGraph) -> DependencyGraph {
  let nodes = graph.nodes.map(node => {
    ..node,
    backends: graph_sorted_strings(node.backends.copy()),
  })
  nodes.sort_by((left, right) => left.id.lexical_compare(right.id))
  let edges = graph.edges.map(edge => {
    ..edge,
    kinds: graph_sorted_strings(edge.kinds.copy()),
    backends: graph_sorted_strings(edge.backends.copy()),
  })
  edges.sort_by((left, right) => {
    graph_edge_key(left).lexical_compare(graph_edge_key(right))
  })
  {
    nodes,
    edges,
    uncertainties: graph_sorted_strings(graph.uncertainties.copy()),
  }
}

///|
/// Package v2 contains all declared import kinds and is a conservative union
/// for Native/Wasm. Package v3 is backend-specific and must be captured twice.
/// Both formats omit stdlib and self-package edges; isolated nodes are retained.
pub fn parse_package_graph(
  value : Json,
  module_graph : Json,
  root : String,
  backend : String,
) -> DependencyGraph raise {
  guard ["native", "wasm"].contains(backend) else {
    fail("graph: unsupported backend")
  }
  guard value is Object(raw) else { fail("graph: expected package graph") }
  let version = graph_int(graph_field(raw, "version"))
  let fields = ["version", "status", "error", "root", "nodes", "edges", "logs"]
  if version == 3 {
    fields.push("target")
  }
  guard version == 2 || version == 3 else {
    fail("graph: unsupported package graph version")
  }
  let object = graph_object(value, fields)
  let (modules, selected, module_uncertainties) = graph_modules(
    module_graph, root,
  )
  let uncertainties = graph_success(
    object,
    modules
    .filter(resolved => resolved.source == "registry")
    .map(resolved => resolved.name + "@" + resolved.version),
  )
  uncertainties.append(module_uncertainties)
  let backends = if version == 2 {
    ["native", "wasm"]
  } else {
    guard graph_string(graph_field(object, "target")) == backend else {
      fail("graph: package graph backend disagrees with request")
    }
    [backend]
  }
  let values = graph_array(graph_field(object, "nodes"))
  guard !values.is_empty() else { fail("graph: empty package graph") }
  let nodes : Array[DependencyNode] = []
  let identities : Map[String, Bool] = Map([])
  let module_indices : Array[Int32] = []
  for value in values {
    let item = graph_object(value, ["module", "version", "source", "rel"])
    let name = graph_nonempty(graph_field(item, "module"))
    let version = graph_nonempty(graph_field(item, "version"))
    let (source, module_owner) = graph_source(graph_field(item, "source"), root)
    let relative = graph_relative(
      graph_string(graph_field(item, "rel")),
      empty=true,
    )
    let matches : Array[Int32] = []
    for index, resolved in modules {
      if resolved.name == name &&
        resolved.version == version &&
        resolved.source == source {
        matches.push(index)
      }
    }
    guard matches.length() == 1 else {
      fail("graph: package has no unique resolved module")
    }
    let owner = if source == "registry" {
      ""
    } else if relative == "" {
      module_owner
    } else if module_owner == "." {
      relative
    } else {
      module_owner + "/" + relative
    }
    let id = if source == "registry" {
      "registry:" + @testkit.json_digest(Json([name, version, relative]))
    } else {
      "local:" + owner
    }
    guard !identities.contains(id) else {
      fail("graph: duplicate package identity or owner")
    }
    identities[id] = true
    nodes.push({
      id,
      owner,
      module_name: name,
      version,
      source,
      backends: backends.copy(),
    })
    module_indices.push(matches[0])
  }
  let roots : Map[Int32, Bool] = Map([])
  for value in graph_array(graph_field(object, "root")) {
    let index = graph_int(value)
    guard index >= 0 &&
      index < nodes.length() &&
      module_indices[index] == selected &&
      !roots.contains(index) else {
      fail("graph: invalid package root ownership")
    }
    roots[index] = true
  }
  guard !roots.is_empty() else {
    fail("graph: selected module has no package roots")
  }
  for index, module_index in module_indices {
    guard (module_index == selected) == roots.contains(index) else {
      fail("graph: selected module package omitted from roots")
    }
  }
  let edges : Array[DependencyEdge] = []
  let edge_ids : Map[String, Bool] = Map([])
  for value in graph_array(graph_field(object, "edges")) {
    let item = graph_object(value, ["from", "to", "alias", "kinds"])
    let from = graph_int(graph_field(item, "from"))
    let to = graph_int(graph_field(item, "to"))
    guard from >= 0 &&
      from < nodes.length() &&
      to >= 0 &&
      to < nodes.length() &&
      from != to else {
      fail("graph: invalid package edge index")
    }
    let kinds : Array[String] = []
    for value in graph_array(graph_field(item, "kinds")) {
      let kind = graph_string(value)
      guard [
          "source", "whitebox-test", "blackbox-test", "inline-test", "sub-package",
        ].contains(kind) &&
        !kinds.contains(kind) else {
        fail("graph: unknown or duplicate import kind")
      }
      kinds.push(kind)
    }
    guard !kinds.is_empty() else {
      fail("graph: import edge has no provenance")
    }
    let edge : DependencyEdge = {
      from: nodes[from].id,
      to: nodes[to].id,
      import_alias: graph_nonempty(graph_field(item, "alias")),
      kinds,
      backends: backends.copy(),
    }
    let key = graph_edge_key(edge)
    guard !edge_ids.contains(key) else { fail("graph: duplicate package edge") }
    edge_ids[key] = true
    edges.push(edge)
  }
  normalize_graph({ nodes, edges, uncertainties, })
}

///|
fn merge_backend_graphs(
  left : DependencyGraph,
  right : DependencyGraph,
) -> DependencyGraph raise {
  let nodes : Map[String, DependencyNode] = Map([])
  let edges : Map[String, DependencyEdge] = Map([])
  for graph in [left, right] {
    for node in graph.nodes {
      match nodes.get(node.id) {
        None => nodes[node.id] = node
        Some(previous) => {
          guard { ..previous, backends: [], } == { ..node, backends: [], } else {
            fail("graph: backend package identities disagree")
          }
          nodes[node.id] = {
            ..previous,
            backends: previous.backends + node.backends,
          }
        }
      }
    }
    for edge in graph.edges {
      let key = graph_edge_key(edge)
      match edges.get(key) {
        None => edges[key] = edge
        Some(previous) =>
          edges[key] = {
            ..previous,
            kinds: previous.kinds + edge.kinds,
            backends: previous.backends + edge.backends,
          }
      }
    }
  }
  normalize_graph({
    nodes: nodes.values().collect(),
    edges: edges.values().collect(),
    uncertainties: left.uncertainties + right.uncertainties,
  })
}

///|
pub fn graph_digest(graph : DependencyGraph) -> String {
  @testkit.json_digest(Json(normalize_graph(graph)))
}
