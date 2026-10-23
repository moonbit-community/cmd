///|
priv struct SelectionState {
  mut full : Bool
  reasons : Array[String]
  paths : Array[String]
  commands : Set[String]
  packages : Set[String]
  behaviors : Set[String]
  build : Set[String]
}

///|
fn sel_full(state : SelectionState, reason : String) -> Unit {
  state.full = true
  state.reasons.push(reason)
}

///|
fn sel_command(owner : String) -> String? {
  let parts = owner.split("/").collect()
  if parts is ["commands", command, ..] && command != "" {
    Some(command.to_owned())
  } else {
    None
  }
}

///|
fn sel_source(entry : @registry.RegistryEntry) -> String {
  entry.source.split("::").next().unwrap_or("").to_owned()
}

///|
fn sel_registered_package(entry : @registry.RegistryEntry) -> String {
  if entry.owner.has_suffix(".mbt") || entry.owner.has_suffix(".mbtx") {
    let parts = entry.owner.split("/").collect()
    parts[:parts.length() - 1].to_owned().join("/")
  } else {
    entry.owner
  }
}

///|
fn sel_owner(nodes : Array[DependencyNode], path : String) -> String? {
  let mut result = ""
  for node in nodes {
    if node.owner != "" &&
      (path == node.owner || path.has_prefix(node.owner + "/")) &&
      node.owner.length() > result.length() {
      result = node.owner
    }
  }
  if result == "" {
    None
  } else {
    Some(result)
  }
}

///|
fn sel_reach(
  nodes : Array[DependencyNode],
  edges : Array[DependencyEdge],
  packages : Array[String],
  reverse~ : Bool,
) -> Set[String] {
  let reached : Set[String] = Set([])
  for node in nodes {
    if packages.contains(node.owner) {
      reached.add(node.id)
    }
  }
  for ;; {
    let before = reached.length()
    for edge in edges {
      let (source, target) = if reverse {
        (edge.to, edge.from)
      } else {
        (edge.from, edge.to)
      }
      if reached.contains(source) {
        reached.add(target)
      }
    }
    if reached.length() == before {
      break
    }
  }
  reached
}

///|
/// Forward prerequisites do not select unchanged prerequisite behaviors.
pub fn selection_prerequisites(
  base_graph : DependencyGraph,
  candidate_graph : DependencyGraph,
  packages : Array[String],
) -> Array[String] {
  let nodes = base_graph.nodes + candidate_graph.nodes
  let reached = sel_reach(
    nodes,
    base_graph.edges + candidate_graph.edges,
    packages,
    reverse=false,
  )
  sorted_strings(
    nodes
    .filter(node => reached.contains(node.id))
    .map(node => if node.owner == "" { node.id } else { node.owner }),
  )
}

///|
fn sel_validate_graph(graph : DependencyGraph) -> Unit raise {
  let ids : Set[String] = Set([])
  for node in graph.nodes {
    guard node.id != "" && !ids.contains(node.id) else {
      fail("empty or duplicate dependency node")
    }
    ids.add(node.id)
  }
  for edge in graph.edges {
    guard ids.contains(edge.from) && ids.contains(edge.to) else {
      fail("dependency edge references an absent node")
    }
  }
}

///|
fn sel_global(path : String) -> Bool {
  path == "AGENTS.md" ||
  path == "moon.work" ||
  path == ".gitignore" ||
  path.has_prefix(".github/") ||
  path.has_prefix("tests/scope/") ||
  path.has_prefix("tests/coverage/") ||
  (path.has_prefix("tests/registry/") && path != "tests/registry/registry.json") ||
  path == "tests/moon.mod" ||
  path == "tests/moon.pkg" ||
  path.has_prefix("tests/testkit/") ||
  path.has_prefix("tests/runner/") ||
  (
    path.has_prefix("tests/release_runner/") &&
    path != "tests/release_runner/current/published.json" &&
    !path.has_prefix("tests/release_runner/current/")
  )
}

///|
fn sel_registry_rows(
  state : SelectionState,
  before : @registry.Registry,
  after : @registry.Registry,
) -> Unit {
  for (left, right) in [(before, after), (after, before)] {
    for entry in left.entries {
      let other = right.entries
        .iter()
        .find_first(row => row.behavior_id == entry.behavior_id)
      let changed = match other {
        None => true
        Some(row) =>
          @testkit.canonical_json(row.to_json()) !=
          @testkit.canonical_json(entry.to_json())
      }
      if changed {
        state.behaviors.add(entry.behavior_id)
        state.packages.add(sel_registered_package(entry))
        if entry.command != "" && entry.command != "all" {
          state.commands.add(entry.command)
        }
      }
    }
    for command in left.release_commands {
      let other = right.release_commands
        .iter()
        .find_first(row => row.name == command.name)
      if other is None ||
        (
          other is Some(row) &&
          @testkit.canonical_json(row.to_json()) !=
          @testkit.canonical_json(command.to_json())
        ) {
        state.commands.add(command.name)
      }
    }
  }
  state.reasons.push(
    "registry stable rows and both-side owners; global registry checks",
  )
  for entry in before.entries + after.entries {
    if entry.owner.has_prefix("tests/registry") {
      state.behaviors.add(entry.behavior_id)
    }
  }
}

///|
/// Compute a conservative minimum from immutable inputs. Unknown impact widens
/// to full; malformed registries, graphs and policy data cannot become scope.
pub fn select_scope(
  base : TreeSnapshot,
  candidate : TreeSnapshot,
  changes : Array[GitChange],
  base_graph : DependencyGraph,
  candidate_graph : DependencyGraph,
  base_registry : @registry.Registry,
  candidate_registry : @registry.Registry,
) -> Selection raise {
  for registry in [base_registry, candidate_registry] {
    let errors = @registry.validate(registry)
    guard errors.is_empty() else {
      fail("invalid selection registry: " + errors.join("; "))
    }
  }
  sel_validate_graph(base_graph)
  sel_validate_graph(candidate_graph)
  let nodes = base_graph.nodes + candidate_graph.nodes
  let edges = base_graph.edges + candidate_graph.edges
  let entries = base_registry.entries + candidate_registry.entries
  let known : Set[String] = Set([])
  for registry in [base_registry, candidate_registry] {
    for command in registry.release_commands {
      known.add(command.name)
    }
  }
  for node in nodes {
    if sel_command(node.owner) is Some(command) {
      known.add(command)
    }
  }
  let state : SelectionState = {
    full: false,
    reasons: [],
    paths: [],
    commands: Set([]),
    packages: Set([]),
    behaviors: Set([]),
    build: Set([]),
  }
  for reason in base_graph.uncertainties + candidate_graph.uncertainties {
    sel_full(state, reason)
  }
  let (old_rules, old_uncertainty) = sel_associations(base)
  let (new_rules, new_uncertainty) = sel_associations(candidate)
  for reason in old_uncertainty + new_uncertainty {
    sel_full(state, reason)
  }
  for change in changes {
    for path in sorted_strings([change.old_path, change.new_path]) {
      if path == "" || path == "tests/coverage/ci-change.json" {
        continue
      }
      state.paths.push(path)
      if sel_global(path) {
        sel_full(state, "shared harness or global selection policy: " + path)
        continue
      }
      let narrative = change.old_path == "" &&
        path.has_prefix("docs/reports/") &&
        path.has_suffix(".md") &&
        !path.has_suffix(".mbt.md") &&
        snapshot_file(base, path) is None &&
        change.status == "A" &&
        snapshot_file(candidate, path) is Some(report) &&
        report.mode == "100644"
      if narrative {
        state.reasons.push("new narrative report: " + path)
        continue
      }
      if path == "tests/registry/registry.json" {
        sel_registry_rows(state, base_registry, candidate_registry)
        continue
      }
      if path == "tests/release_runner/current/published.json" {
        ignore(sel_published(base))
        ignore(sel_published(candidate))
        let (old, old_global) = sel_published_rows(base)
        let (new, new_global) = sel_published_rows(candidate)
        if old_global != new_global {
          sel_full(state, "published manifest global structure changed")
        }
        for name in sorted_strings(old.keys().collect() + new.keys().collect()) {
          if old.get(name) != new.get(name) {
            state.commands.add(name)
          }
        }
        for entry in entries {
          if entry.owner.has_prefix("tests/registry") {
            state.behaviors.add(entry.behavior_id)
          }
        }
        state.reasons.push("published stable rows and both-side coordinates")
        continue
      }
      if path == "core/cli/catalog.mbt" {
        match sel_catalog_changes(base, candidate) {
          Some(commands) => {
            for command in commands {
              state.commands.add(command)
            }
            state.reasons.push(
              "strict catalog literal rows and global catalog invariant",
            )
            for entry in entries {
              if entry.behavior_id == "cohort:compat-catalog" {
                state.behaviors.add(entry.behavior_id)
              }
            }
            continue
          }
          None =>
            state.reasons.push(
              "catalog helpers or unknown expressions require core closure",
            )
        }
      }
      let mut owned = false
      if path.has_suffix("/moon.mod") {
        let module_source = "local:" +
          path.strip_suffix("/moon.mod").unwrap().to_owned()
        for node in nodes {
          if node.source == module_source && node.owner != "" {
            state.packages.add(node.owner)
            owned = true
          }
        }
      }
      for graph in [base_graph, candidate_graph] {
        if sel_owner(graph.nodes, path) is Some(owner) {
          state.packages.add(owner)
          if sel_command(owner) is Some(command) {
            state.commands.add(command)
          }
          owned = true
        }
      }
      for entry in entries {
        if sel_source(entry) == path {
          state.behaviors.add(entry.behavior_id)
          if known.contains(entry.command) {
            state.commands.add(entry.command)
          }
          owned = true
        }
      }
      if !owned {
        sel_full(state, "unknown source or ownership: " + path)
      }
    }
  }
  let reached = sel_reach(
    nodes,
    edges,
    state.packages.iter().collect(),
    reverse=true,
  )
  for node in nodes {
    if reached.contains(node.id) && node.owner != "" {
      state.packages.add(node.owner)
      if sel_command(node.owner) is Some(command) {
        state.commands.add(command)
      }
    }
  }
  for command in state.commands.iter() {
    if !known.contains(command) || !entries.any(row => row.command == command) {
      sel_full(
        state,
        "command has no complete registered behavior collection: " + command,
      )
    }
  }
  if !state.commands.is_empty() {
    for entry in entries {
      if ["stateful-scenario", "compatibility-cohort", "policy-test"].contains(
          entry.implementation,
        ) &&
        !(old_rules + new_rules).any(rule => {
          rule.behavior_ids.contains(entry.behavior_id)
        }) {
        sel_full(state, "missing non-import association: " + entry.behavior_id)
      }
    }
  }
  for rule in old_rules + new_rules {
    for id in rule.behavior_ids {
      if !entries.any(row => row.behavior_id == id) {
        sel_full(state, "unknown non-import behavior: " + id)
      }
    }
    for command in rule.trigger_commands + rule.build_commands {
      if command != "*" && !known.contains(command) {
        sel_full(state, "unknown non-import command: " + command)
      }
    }
    if rule.trigger_commands.any(command => {
        (command == "*" && !state.commands.is_empty()) ||
        state.commands.contains(command)
      }) ||
      rule.trigger_paths.any(pattern => {
        state.paths.any(path => sel_association_path(pattern, path))
      }) {
      state.reasons.push("non-import association: " + rule.id)
      if rule.full {
        sel_full(state, "shared non-import layer: " + rule.id)
      }
      for id in rule.behavior_ids {
        if entries.any(row => row.behavior_id == id) {
          state.behaviors.add(id)
        } else {
          sel_full(state, "unknown non-import behavior: " + id)
        }
      }
      for command in rule.build_commands {
        if command == "*" {
          for name in known.iter() {
            state.build.add("commands/" + name)
          }
        } else if known.contains(command) {
          state.build.add("commands/" + command)
        } else {
          sel_full(state, "unknown non-import build command: " + command)
        }
      }
    }
  }
  if state.full {
    for command in known.iter() {
      state.commands.add(command)
    }
    for node in nodes {
      if node.owner != "" {
        state.packages.add(node.owner)
      }
    }
    for entry in entries {
      state.behaviors.add(entry.behavior_id)
    }
  }
  for entry in entries {
    if state.commands.contains(entry.command) ||
      state.packages.contains(entry.owner) ||
      (
        sel_owner(base_graph.nodes, sel_source(entry)) is Some(owner) &&
        state.packages.contains(owner)
      ) ||
      (
        sel_owner(candidate_graph.nodes, sel_source(entry)) is Some(owner) &&
        state.packages.contains(owner)
      ) {
      state.behaviors.add(entry.behavior_id)
    }
    if state.behaviors.contains(entry.behavior_id) {
      for graph in [base_graph, candidate_graph] {
        if sel_owner(graph.nodes, sel_source(entry)) is Some(owner) {
          state.packages.add(owner)
        }
      }
    }
  }
  let packages = sorted_strings(state.packages.iter().collect())
  let build_roots = sorted_strings(packages + state.build.iter().collect())
  let commands = sorted_strings(state.commands.iter().collect())
  let behaviors = sorted_strings(state.behaviors.iter().collect())
  let selected = entries.filter(entry => {
    state.behaviors.contains(entry.behavior_id)
  })
  let options = selected
    .filter(entry => entry.surface.contains("options"))
    .map(entry => entry.coverage)
    .fold(init=[], (all, items) => all + items)
  let operands = selected
    .filter(entry => entry.surface.contains("operands"))
    .map(entry => entry.coverage)
    .fold(init=[], (all, items) => all + items)
  {
    mode: if state.full {
      "full"
    } else if state.paths.is_empty() ||
      (behaviors.is_empty() && state.packages.is_empty()) {
      "docs"
    } else {
      "scoped"
    },
    reasons: sorted_strings(state.reasons),
    changed_paths: sorted_strings(state.paths),
    commands,
    behaviors,
    packages: packages.copy(),
    core_packages: packages.filter(path => path.has_prefix("core/")),
    build_prerequisites: sorted_strings(
      build_roots +
      selection_prerequisites(base_graph, candidate_graph, build_roots),
    ),
    case_ids: sorted_strings(
      selected.filter(entry => entry.case_id != "").map(entry => entry.case_id),
    ),
    published_coordinates: selection_coordinates(base, candidate, commands),
    affected_options: sorted_strings(options),
    affected_operands: sorted_strings(operands),
    requirements: sel_requirements(selected),
  }
}
