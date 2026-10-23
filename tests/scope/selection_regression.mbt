///|
/// Derive current full-suite obligations without inventing a change range or
/// consulting an earlier PR intent. The execution coordinator adds resolved
/// external prerequisites from the current dependency graph.
pub fn full_regression_selection(
  snapshot : TreeSnapshot,
  registry : @registry.Registry,
) -> Selection raise {
  let errors = @registry.validate(registry)
  guard errors.is_empty() else {
    fail("invalid full-regression registry: " + errors.join("; "))
  }
  let packages : Array[String] = []
  let commands : Array[String] = []
  let paths : Set[String] = Set([])
  for file in snapshot.files {
    guard @testkit.safe_relative_path(file.path) && !paths.contains(file.path) else {
      fail("full regression requires unique safe snapshot paths")
    }
    paths.add(file.path)
    if file.path == "moon.pkg" ||
      file.path == "moon.pkg.json" ||
      file.path.has_suffix("/moon.pkg") ||
      file.path.has_suffix("/moon.pkg.json") {
      guard ["100644", "100755"].contains(file.mode) else {
        fail("full regression package manifest must be a tracked regular file")
      }
      let parts = file.path.split("/").collect()
      let owner = if parts.length() == 1 {
        "."
      } else {
        parts[:parts.length() - 1].to_owned().join("/")
      }
      packages.push(owner)
      if sel_command(owner) is Some(command) {
        commands.push(command)
      }
    }
  }
  for entry in registry.entries {
    packages.push(sel_registered_package(entry))
    if entry.command != "" && entry.command != "all" {
      commands.push(entry.command)
    }
  }
  for command in registry.release_commands {
    commands.push(command.name)
  }
  let commands = sorted_strings(commands)
  let packages = sorted_strings(packages)
  let requirements = sel_requirements(registry.entries)
  guard !registry.entries.is_empty() &&
    !commands.is_empty() &&
    !packages.is_empty() &&
    !requirements.is_empty() else {
    fail(
      "full regression requires a nonempty command, package and behavior inventory",
    )
  }
  let options = registry.entries
    .filter(entry => entry.surface.contains("options"))
    .map(entry => entry.coverage)
    .fold(init=[], (all, items) => all + items)
  let operands = registry.entries
    .filter(entry => entry.surface.contains("operands"))
    .map(entry => entry.coverage)
    .fold(init=[], (all, items) => all + items)
  {
    mode: "full",
    reasons: ["regression-only/full: complete current registry and packages"],
    changed_paths: [],
    commands,
    behaviors: sorted_strings(registry.entries.map(entry => entry.behavior_id)),
    packages: packages.copy(),
    core_packages: packages.filter(path => {
      path == "core" || path.has_prefix("core/")
    }),
    build_prerequisites: packages.copy(),
    case_ids: sorted_strings(
      registry.entries
      .filter(entry => entry.case_id != "")
      .map(entry => entry.case_id),
    ),
    published_coordinates: selection_coordinates(snapshot, snapshot, commands),
    affected_options: sorted_strings(options),
    affected_operands: sorted_strings(operands),
    requirements,
  }
}
