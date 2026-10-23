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
