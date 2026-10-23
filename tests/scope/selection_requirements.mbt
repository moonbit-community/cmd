///|
fn sel_requirement_key(row : BehaviorRequirement) -> String {
  @testkit.canonical_json(
    Json([
      Json(row.behavior_id),
      Json(row.case_id),
      Json(row.oracle_profile),
      Json(row.command),
      Json(sorted_strings(row.backends.copy())),
      Json(sorted_strings(row.platforms.copy())),
    ]),
  )
}

///|
fn sel_requirement_union(
  rows : Array[BehaviorRequirement],
) -> Array[BehaviorRequirement] {
  let merged : Map[String, BehaviorRequirement] = Map([])
  for row in rows {
    let key = sel_requirement_key(row)
    let next = match merged.get(key) {
      None =>
        {
          ..row,
          backends: sorted_strings(row.backends.copy()),
          evidence: sorted_strings(row.evidence.copy()),
          observations: sorted_strings(row.observations.copy()),
          platforms: sorted_strings(row.platforms.copy()),
        }
      Some(old) =>
        {
          ..row,
          backends: sorted_strings(row.backends.copy()),
          evidence: sorted_strings(old.evidence + row.evidence),
          observations: sorted_strings(old.observations + row.observations),
          // Applicability is part of the key: combining unrelated backend and
          // platform sets would invent executions that neither tree required.
          platforms: sorted_strings(row.platforms.copy()),
        }
    }
    merged[key] = next
  }
  let result = merged.values().collect()
  result.sort_by((left, right) => {
    sel_requirement_key(left).lexical_compare(sel_requirement_key(right))
  })
  result
}

///|
fn sel_requirements(
  entries : Array[@registry.RegistryEntry],
) -> Array[BehaviorRequirement] {
  sel_requirement_union(
    entries.map(entry => {
      behavior_id: entry.behavior_id,
      case_id: entry.case_id,
      command: entry.command,
      backends: entry.required_backends,
      evidence: entry.required_evidence,
      observations: entry.observations,
      platforms: entry.platforms,
      oracle_profile: entry.oracle_profile,
    }),
  )
}

///|
fn sel_extra_entry(
  registry : @registry.Registry,
  id : String,
) -> @registry.RegistryEntry? {
  registry.entries
  .iter()
  .find_first(entry => {
    entry.behavior_id == id ||
    entry.aliases.contains(id) ||
    (entry.case_id != "" && entry.case_id == id)
  })
}

///|
fn sel_extra_for_registry(
  extra : HumanExtra,
  registry : @registry.Registry,
) -> HumanExtra {
  {
    ..extra,
    behaviors: extra.behaviors.filter(id => {
      sel_extra_entry(registry, id) is Some(_)
    }),
    case_ids: extra.case_ids.filter(id => {
      sel_extra_entry(registry, id) is Some(entry) && entry.case_id != ""
    }),
    commands: extra.commands.filter(command => {
      command != "" &&
      command != "all" &&
      registry.entries.any(entry => entry.command == command)
    }),
    packages: extra.packages.filter(package_path => {
      package_path != "" &&
      registry.entries.any(entry => {
        entry.owner == package_path ||
        entry.owner.has_prefix(package_path + "/")
      })
    }),
  }
}

///|
/// Resolve reviewed additions against each immutable registry independently.
/// A deleted case or transferred alias remains an old-side obligation, and a
/// matching target on both sides receives each side's own added requirements.
pub fn add_human_extras_both(
  selection : Selection,
  extras : Array[HumanExtra],
  base_registry : @registry.Registry,
  candidate_registry : @registry.Registry,
) -> Selection raise {
  let mut result = add_human_extras(selection, [], base_registry)
  result = add_human_extras(result, [], candidate_registry)
  for extra in extras {
    guard !extra.commands.is_empty() ||
      !extra.behaviors.is_empty() ||
      !extra.packages.is_empty() ||
      !extra.case_ids.is_empty() else {
      fail("human addition requires an explicit target")
    }
    let old = sel_extra_for_registry(extra, base_registry)
    let new = sel_extra_for_registry(extra, candidate_registry)
    for
      (kind, targets, before, after) in [
        ("behavior", extra.behaviors, old.behaviors, new.behaviors),
        ("case", extra.case_ids, old.case_ids, new.case_ids),
        ("command", extra.commands, old.commands, new.commands),
        ("package", extra.packages, old.packages, new.packages),
      ] {
      for target in targets {
        guard before.contains(target) || after.contains(target) else {
          fail("unknown human-added " + kind + " on both snapshots: " + target)
        }
      }
    }
    for
      (registry, reviewed) in [(base_registry, old), (candidate_registry, new)] {
      if !reviewed.commands.is_empty() ||
        !reviewed.behaviors.is_empty() ||
        !reviewed.packages.is_empty() ||
        !reviewed.case_ids.is_empty() {
        result = add_human_extras(result, [reviewed], registry)
      }
    }
  }
  result
}

///|
/// Human additions target explicit behaviors/commands/packages/cases. Extra
/// requirements apply only to that extra's targets, not every automatic row.
pub fn add_human_extras(
  selection : Selection,
  extras : Array[HumanExtra],
  registry : @registry.Registry,
) -> Selection raise {
  let errors = @registry.validate(registry)
  guard errors.is_empty() else {
    fail("invalid extras registry: " + errors.join("; "))
  }
  let commands = selection.commands.copy()
  let behaviors = selection.behaviors.copy()
  let packages = selection.packages.copy()
  let cases = selection.case_ids.copy()
  let options = selection.affected_options.copy()
  let operands = selection.affected_operands.copy()
  let reasons = selection.reasons.copy()
  let requirements = selection.requirements.copy()
  for extra in extras {
    guard !extra.reason.trim().is_empty() else {
      fail("human addition requires a reason")
    }
    guard !extra.commands.is_empty() ||
      !extra.behaviors.is_empty() ||
      !extra.packages.is_empty() ||
      !extra.case_ids.is_empty() else {
      fail("human addition requires an explicit target")
    }
    for backend in extra.backends {
      guard ["native", "wasm"].contains(backend) else {
        fail("unknown extra backend")
      }
    }
    for evidence in extra.evidence {
      guard [
        "contract", "backend-pair", "upstream-differential", "published-differential",
        "boundary", "supplementary",
      ].contains(evidence) else {
        fail("unknown extra evidence class")
      }
    }
    for observation in extra.observations {
      guard [
        "status", "stdout", "stderr", "file-content", "file-type", "file-mode", "file-identity",
        "symlink-target", "atime", "mtime", "ctime",
      ].contains(observation) else {
        fail("unknown extra observation")
      }
    }
    let targets : Set[String] = Set([])
    for id in extra.behaviors + extra.case_ids {
      guard sel_extra_entry(registry, id) is Some(entry) else {
        fail("unknown human-added behavior/case: " + id)
      }
      if extra.case_ids.contains(id) && entry.case_id == "" {
        fail("human-added case is not a JSON case: " + id)
      }
      targets.add(entry.behavior_id)
    }
    for command in extra.commands {
      let rows = registry.entries.filter(entry => entry.command == command)
      guard !rows.is_empty() && command != "" && command != "all" else {
        fail("unknown human-added command: " + command)
      }
      commands.push(command)
      packages.push("commands/" + command)
      for row in rows {
        targets.add(row.behavior_id)
      }
    }
    for package_path in extra.packages {
      let rows = registry.entries.filter(entry => {
        entry.owner == package_path ||
        entry.owner.has_prefix(package_path + "/")
      })
      guard !rows.is_empty() && package_path != "" else {
        fail("unknown human-added package: " + package_path)
      }
      packages.push(package_path)
      for row in rows {
        targets.add(row.behavior_id)
      }
    }
    for row in registry.entries {
      if !targets.contains(row.behavior_id) {
        continue
      }
      behaviors.push(row.behavior_id)
      packages.push(sel_registered_package(row))
      if row.command != "" && row.command != "all" {
        commands.push(row.command)
      }
      if row.case_id != "" {
        cases.push(row.case_id)
      }
      if row.surface.contains("options") {
        options.append(row.coverage)
      }
      if row.surface.contains("operands") {
        operands.append(row.coverage)
      }
      let requirement : BehaviorRequirement = {
        behavior_id: row.behavior_id,
        case_id: row.case_id,
        command: row.command,
        backends: sorted_strings(row.required_backends + extra.backends),
        evidence: sorted_strings(row.required_evidence + extra.evidence),
        observations: sorted_strings(row.observations + extra.observations),
        platforms: row.platforms.copy(),
        oracle_profile: row.oracle_profile,
      }
      if requirement.evidence.contains("backend-pair") &&
        (
          !requirement.backends.contains("native") ||
          !requirement.backends.contains("wasm")
        ) {
        fail("extra backend-pair requires both executions")
      }
      if requirement.evidence.any(kind => {
          kind == "upstream-differential" || kind == "published-differential"
        }) &&
        requirement.oracle_profile == "" {
        fail("oracle evidence addition requires a registered immutable profile")
      }
      requirements.push(requirement)
    }
    reasons.push("human addition: " + extra.reason)
  }
  let packages = sorted_strings(packages)
  {
    ..selection,
    mode: if selection.mode == "full" {
      "full"
    } else if behaviors.is_empty() && packages.is_empty() {
      selection.mode
    } else {
      "scoped"
    },
    reasons: sorted_strings(reasons),
    commands: sorted_strings(commands),
    behaviors: sorted_strings(behaviors),
    packages: packages.copy(),
    core_packages: sorted_strings(
      selection.core_packages +
      packages.filter(path => path.has_prefix("core/")),
    ),
    build_prerequisites: sorted_strings(
      selection.build_prerequisites + packages,
    ),
    case_ids: sorted_strings(cases),
    affected_options: sorted_strings(options),
    affected_operands: sorted_strings(operands),
    requirements: sel_requirement_union(requirements),
  }
}
