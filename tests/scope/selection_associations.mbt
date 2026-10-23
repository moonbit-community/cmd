///|
priv struct SelectionAssociation {
  id : String
  kind : String
  trigger_commands : Array[String]
  trigger_paths : Array[String]
  behavior_ids : Array[String]
  build_commands : Array[String]
  full : Bool
} derive(FromJson)

///|
fn sel_associations(
  snapshot : TreeSnapshot,
) -> (Array[SelectionAssociation], Array[String]) raise {
  guard snapshot_file(snapshot, "tests/registry/associations.json")
    is Some(file) else {
    return ([], ["non-import association policy is unavailable"])
  }
  let value = strict_json(@utf8.decode(file.content))
  object_fields(value, ["schema", "rules"], "non-import associations")
  guard value is { "schema": Number(schema, ..), .. } &&
    schema.floor() == schema else {
    fail("non-import association schema must be an integer")
  }
  if schema != 1.0 {
    return ([], ["unsupported non-import association schema"])
  }
  let rules : Array[SelectionAssociation] = []
  let reasons : Array[String] = []
  let ids : Set[String] = Set([])
  for item in array_field(value, "rules") {
    object_fields(
      item,
      [
        "id", "kind", "trigger_commands", "trigger_paths", "behavior_ids", "build_commands",
        "full",
      ],
      "non-import association rule",
    )
    let rule : SelectionAssociation = @json.from_json(item)
    guard !rule.id.trim().is_empty() && !ids.contains(rule.id) else {
      fail("empty or duplicate non-import association ID")
    }
    ids.add(rule.id)
    if !["scenario", "cohort", "policy", "fixture", "catalog", "release"].contains(
        rule.kind,
      ) {
      reasons.push("unsupported non-import association kind: " + rule.kind)
    }
    guard !rule.trigger_commands.is_empty() || !rule.trigger_paths.is_empty() else {
      fail("non-import association requires a trigger: " + rule.id)
    }
    for path in rule.trigger_paths {
      guard !path.is_empty() &&
        !path.has_prefix("/") &&
        !path.split("/").any(part => part == ".." || part == ".") else {
        fail("invalid non-import association path: " + rule.id)
      }
      let supported = !path.contains("*") ||
        (path.strip_suffix("/**") is Some(prefix) && !prefix.contains("*"))
      if !supported {
        reasons.push("unsupported non-import path pattern: " + path)
      }
    }
    rules.push(rule)
  }
  (rules, reasons)
}

///|
fn sel_association_path(pattern : String, path : String) -> Bool {
  if pattern.has_suffix("/**") {
    let prefix = pattern.strip_suffix("**").unwrap().to_owned()
    path.has_prefix(prefix)
  } else {
    pattern == path
  }
}

///|
fn sel_requires_association(entry : @registry.RegistryEntry) -> Bool {
  ["stateful-scenario", "compatibility-cohort", "policy-test"].contains(
    entry.implementation,
  )
}

///|
fn sel_association_triggered(
  rule : SelectionAssociation,
  commands : Array[String],
  paths : Array[String],
) -> Bool {
  rule.trigger_commands.any(command => {
    (command == "*" && !commands.is_empty()) || commands.contains(command)
  }) ||
  rule.trigger_paths.any(pattern => {
    paths.any(path => sel_association_path(pattern, path))
  })
}

///|
fn sel_reviewed_associations(
  base : TreeSnapshot,
  candidate : TreeSnapshot,
) -> (Array[SelectionAssociation], Array[String]) raise {
  let (old, old_uncertainty) = sel_associations(base)
  let (new, new_uncertainty) = sel_associations(candidate)
  (old + new, old_uncertainty + new_uncertainty)
}

///|
fn sel_association_commands(
  base_graph : DependencyGraph,
  candidate_graph : DependencyGraph,
  base_registry : @registry.Registry,
  candidate_registry : @registry.Registry,
) -> Set[String] {
  let known : Set[String] = Set([])
  for registry in [base_registry, candidate_registry] {
    for command in registry.release_commands {
      known.add(command.name)
    }
    for entry in registry.entries {
      if entry.command != "" && entry.command != "all" {
        known.add(entry.command)
      }
    }
  }
  for node in base_graph.nodes + candidate_graph.nodes {
    if sel_command(node.owner) is Some(command) {
      known.add(command)
    }
  }
  known
}

///|
fn sel_association_floor(
  selection : Selection,
  base : TreeSnapshot,
  candidate : TreeSnapshot,
  base_graph : DependencyGraph,
  candidate_graph : DependencyGraph,
  base_registry : @registry.Registry,
  candidate_registry : @registry.Registry,
) -> Selection raise {
  let (rules, reasons) = sel_reviewed_associations(base, candidate)
  let known = sel_association_commands(
    base_graph, candidate_graph, base_registry, candidate_registry,
  )
  let entries = base_registry.entries + candidate_registry.entries
  for entry in entries {
    if sel_requires_association(entry) &&
      (
        !selection.commands.is_empty() ||
        selection.behaviors.contains(entry.behavior_id)
      ) &&
      !rules.any(rule => rule.behavior_ids.contains(entry.behavior_id)) {
      reasons.push("missing non-import association: " + entry.behavior_id)
    }
  }
  for rule in rules {
    for id in rule.behavior_ids {
      if !entries.any(entry => entry.behavior_id == id) {
        reasons.push("unknown non-import behavior: " + id)
      }
    }
    for command in rule.trigger_commands + rule.build_commands {
      if command != "*" && !known.contains(command) {
        reasons.push("unknown non-import command: " + command)
      }
    }
    if rule.full &&
      (
        sel_association_triggered(
          rule,
          selection.commands,
          selection.changed_paths,
        ) ||
        rule.behavior_ids.any(id => selection.behaviors.contains(id))
      ) {
      reasons.push("shared non-import layer: " + rule.id)
    }
  }
  if reasons.is_empty() {
    return selection
  }
  let mut result = {
    ..selection,
    mode: "full",
    reasons: sorted_strings(selection.reasons + reasons),
  }
  if selection.mode == "full" {
    return result
  }
  for
    (snapshot, registry) in [
      (base, base_registry),
      (candidate, candidate_registry),
    ] {
    let full = full_regression_selection(snapshot, registry)
    result = {
      ..result,
      commands: sorted_strings(result.commands + full.commands),
      behaviors: sorted_strings(result.behaviors + full.behaviors),
      packages: sorted_strings(result.packages + full.packages),
      core_packages: sorted_strings(result.core_packages + full.core_packages),
      build_prerequisites: sorted_strings(
        result.build_prerequisites + full.build_prerequisites,
      ),
      case_ids: sorted_strings(result.case_ids + full.case_ids),
      affected_options: sorted_strings(
        result.affected_options + full.affected_options,
      ),
      affected_operands: sorted_strings(
        result.affected_operands + full.affected_operands,
      ),
      requirements: sel_requirement_union(
        result.requirements + full.requirements,
      ),
    }
  }
  result
}

///|
/// A command addition includes linked integrations, with each registered row's
/// own requirements. Descriptive child commands do not select whole commands.
fn sel_extra_command_associations(
  selection : Selection,
  extras : Array[HumanExtra],
  base : TreeSnapshot,
  candidate : TreeSnapshot,
  base_registry : @registry.Registry,
  candidate_registry : @registry.Registry,
) -> Selection raise {
  let commands = sorted_strings(
    extras
    .map(extra => extra.commands)
    .fold(init=[], (all, items) => all + items),
  )
  if commands.is_empty() {
    return selection
  }
  let ids : Set[String] = Set([])
  let reasons = selection.reasons.copy()
  let entries = base_registry.entries + candidate_registry.entries
  let (rules, _) = sel_reviewed_associations(base, candidate)
  for rule in rules {
    if !sel_association_triggered(rule, commands, []) {
      continue
    }
    for id in rule.behavior_ids {
      ids.add(id)
    }
    reasons.push("reviewed command non-import association: " + rule.id)
  }
  let linked = entries.filter(entry => ids.contains(entry.behavior_id))
  let packages = sorted_strings(
    selection.packages + linked.map(sel_registered_package),
  )
  {
    ..selection,
    mode: if selection.mode == "docs" && !linked.is_empty() {
      "scoped"
    } else {
      selection.mode
    },
    reasons: sorted_strings(reasons),
    behaviors: sorted_strings(
      selection.behaviors + linked.map(entry => entry.behavior_id),
    ),
    packages: packages.copy(),
    core_packages: sorted_strings(
      selection.core_packages +
      packages.filter(path => path.has_prefix("core/")),
    ),
    build_prerequisites: sorted_strings(
      selection.build_prerequisites + packages,
    ),
    case_ids: sorted_strings(
      selection.case_ids +
      linked.filter(entry => entry.case_id != "").map(entry => entry.case_id),
    ),
    affected_options: sorted_strings(
      selection.affected_options +
      linked
      .filter(entry => entry.surface.contains("options"))
      .map(entry => entry.coverage)
      .fold(init=[], (all, items) => all + items),
    ),
    affected_operands: sorted_strings(
      selection.affected_operands +
      linked
      .filter(entry => entry.surface.contains("operands"))
      .map(entry => entry.coverage)
      .fold(init=[], (all, items) => all + items),
    ),
    requirements: sel_requirement_union(
      selection.requirements + sel_requirements(linked),
    ),
  }
}

///|
/// Close artifacts only after reviewed and boundary targets are known. Rule
/// membership retains child builds without adding sibling behavior obligations.
fn sel_final_prerequisites(
  selection : Selection,
  base : TreeSnapshot,
  candidate : TreeSnapshot,
  base_graph : DependencyGraph,
  candidate_graph : DependencyGraph,
  base_registry : @registry.Registry,
  candidate_registry : @registry.Registry,
) -> Array[String] raise {
  let known = sel_association_commands(
    base_graph, candidate_graph, base_registry, candidate_registry,
  )
  let artifact_commands = sorted_strings(
    selection.commands +
    selection.requirements
    .map(row => row.command)
    .filter(command => command != "" && command != "all"),
  )
  let roots = selection.packages + selection.build_prerequisites
  for command in artifact_commands {
    guard known.contains(command) else {
      fail("selected artifact command has no known owner: " + command)
    }
    roots.push("commands/" + command)
  }
  let (rules, _) = sel_reviewed_associations(base, candidate)
  for rule in rules {
    if !sel_association_triggered(
        rule,
        selection.commands,
        selection.changed_paths,
      ) &&
      !rule.behavior_ids.any(id => selection.behaviors.contains(id)) {
      continue
    }
    for command in rule.build_commands {
      if command == "*" {
        for name in known.iter() {
          roots.push("commands/" + name)
        }
      } else if known.contains(command) {
        roots.push("commands/" + command)
      }
    }
  }
  let roots = sorted_strings(roots)
  sorted_strings(
    roots + selection_prerequisites(base_graph, candidate_graph, roots),
  )
}

///|
fn sel_published(snapshot : TreeSnapshot) -> Map[String, String] raise {
  guard snapshot_file(snapshot, "tests/release_runner/current/published.json")
    is Some(file) else {
    fail("snapshot has no current published manifest")
  }
  let value = strict_json(@utf8.decode(file.content))
  guard value is { "schema": Number(2, ..), "commands": Array(items), .. } else {
    fail("malformed current published manifest")
  }
  let result : Map[String, String] = Map([])
  for item in items {
    guard item
      is {
        "name": String(name),
        "version": String(version),
        "package_name": String(package_name),
        "published": published,
        ..
      } &&
      !name.is_empty() &&
      !version.is_empty() &&
      package_name == "cli/" + name &&
      (published is True || published is False) else {
      fail("malformed published command coordinate")
    }
    guard !result.contains(name) else {
      fail("duplicate published command: " + name)
    }
    result[name] = if published is True {
      package_name + "@" + version
    } else {
      ""
    }
  }
  result
}

///|
fn sel_published_rows(
  snapshot : TreeSnapshot,
) -> (Map[String, String], String) raise {
  guard snapshot_file(snapshot, "tests/release_runner/current/published.json")
    is Some(file) else {
    fail("snapshot has no current published manifest")
  }
  let value = strict_json(@utf8.decode(file.content))
  guard value is Object(fields) && fields.get("commands") is Some(Array(items)) else {
    fail("malformed published rows")
  }
  let rows : Map[String, String] = Map([])
  for item in items {
    guard item is { "name": String(name), .. } else {
      fail("published row has no stable name")
    }
    rows[name] = @testkit.canonical_json(item)
  }
  fields.remove("commands")
  (rows, @testkit.canonical_json(value))
}

///|
/// Exact relevant coordinates from both trees, including retired commands.
pub fn selection_coordinates(
  base : TreeSnapshot,
  candidate : TreeSnapshot,
  commands : Array[String],
) -> Array[String] raise {
  let result : Array[String] = []
  for inventory in [sel_published(base), sel_published(candidate)] {
    for command in commands {
      if inventory.get(command) is Some(coordinate) && coordinate != "" {
        result.push(coordinate)
      }
    }
  }
  sorted_strings(result)
}
