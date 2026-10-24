///|
pub(all) struct ScopeBoundary {
  behavior_id : String
  support_record : String
  adr : String
  current_limit : String
  unlock_condition : String
  rejection_tests : Array[String]
  replacement_behaviors : Array[String]
} derive(ToJson, FromJson, Eq, Debug)

///|
pub(all) struct InputIdentities {
  base_policy : String
  candidate_policy : String
  base_graph : String
  candidate_graph : String
  base_registry : String
  candidate_registry : String
  base_associations : String
  candidate_associations : String
} derive(ToJson, FromJson, Eq, Debug)

///|
// Exact commits and observed results belong in execution receipts. The intent
// binds content without recursively hashing the commit that contains itself.
pub(all) struct ScopeIntent {
  schema : Int32
  transition : String
  policy_version : String
  target_ref : String
  base : String
  payload : String
  change_set : String
  changes : Array[GitChange]
  identities : InputIdentities
  automatic : Selection
  extras : Array[HumanExtra]
  selection : Selection
  boundaries : Array[ScopeBoundary]
  deferred : Array[String]
  uncovered : Array[String]
} derive(ToJson, FromJson, Eq, Debug)

///|
let scope_policy_version = "scope-v2.1"

///|
// The public JSON parser validates grammar but accepts duplicate object keys.
// Inspect key tokens after grammar validation so escaped aliases cannot hide
// a second requirement or identity behind a last-wins map entry.
pub fn strict_json(text : String) -> Json raise {
  let value = @json.parse(text)
  let chars = text.iter().collect()
  let stack : Array[Set[String]?] = []
  let mut index = 0
  while index < chars.length() {
    match chars[index] {
      '{' => stack.push(Some(Set([])))
      '[' => stack.push(None)
      '}' | ']' => ignore(stack.pop())
      '"' => {
        let literal = StringBuilder()
        literal.write_char('"')
        index += 1
        let mut escaped = false
        while index < chars.length() {
          let char = chars[index]
          literal.write_char(char)
          index += 1
          if !escaped && char == '"' {
            break
          }
          escaped = !escaped && char == '\\'
        }
        let mut next = index
        while next < chars.length() && chars[next] is (' ' | '\r' | '\n' | '\t') {
          next += 1
        }
        if next < chars.length() && chars[next] == ':' {
          guard @json.parse(literal.to_string()) is String(key) &&
            stack.last() is Some(Some(keys)) else {
            fail("invalid JSON object key context")
          }
          guard !keys.contains(key) else { fail("duplicate JSON key: " + key) }
          keys.add(key)
        }
        continue
      }
      _ => ()
    }
    index += 1
  }
  value
}

///|
pub fn parse_intent_text(text : String) -> ScopeIntent raise {
  parse_intent(strict_json(text))
}

///|
fn object_fields(
  value : Json,
  allowed : Array[String],
  context : String,
) -> Unit raise {
  guard value is Object(fields) else { fail(context + " must be an object") }
  for key in fields.keys() {
    guard allowed.contains(key) else {
      fail(context + " contains an unknown field or execution claim: " + key)
    }
  }
  for key in allowed {
    guard fields.contains(key) else { fail(context + " is missing " + key) }
  }
}

///|
fn array_field(value : Json, key : String) -> Array[Json] raise {
  guard value is Object(fields) && fields.get(key) is Some(Array(items)) else {
    fail("scope field must be an array: " + key)
  }
  items
}

///|
fn check_selection_shape(value : Json) -> Unit raise {
  object_fields(
    value,
    [
      "mode", "reasons", "changed_paths", "commands", "behaviors", "packages", "core_packages",
      "build_prerequisites", "case_ids", "published_coordinates", "affected_options",
      "affected_operands", "requirements",
    ],
    "selection",
  )
  for row in array_field(value, "requirements") {
    object_fields(
      row,
      [
        "behavior_id", "case_id", "command", "backends", "evidence", "observations",
        "platforms", "oracle_profile",
      ],
      "behavior requirement",
    )
  }
}

///|
fn hash_string(value : String, length : Int32) -> Bool {
  value.length() == length &&
  value.iter().all(char => char is ('0'..<='9') || char is ('a'..<='f'))
}

///|
pub fn parse_intent(value : Json) -> ScopeIntent raise {
  object_fields(
    value,
    [
      "schema", "transition", "policy_version", "target_ref", "base", "payload",
      "change_set", "changes", "identities", "automatic", "extras", "selection",
      "boundaries", "deferred", "uncovered",
    ],
    "scope intent",
  )
  guard value is { "schema": Number(2, ..), .. } else {
    fail("scope schema must be exactly 2")
  }
  guard value is Object(fields) else { fail("scope intent must be an object") }
  for key in ["automatic", "selection"] {
    check_selection_shape(fields[key])
  }
  object_fields(
    fields["identities"],
    [
      "base_policy", "candidate_policy", "base_graph", "candidate_graph", "base_registry",
      "candidate_registry", "base_associations", "candidate_associations",
    ],
    "scope identities",
  )
  for change in array_field(value, "changes") {
    object_fields(
      change,
      [
        "status", "old_path", "new_path", "old_mode", "new_mode", "old_blob", "new_blob",
      ],
      "Git change",
    )
  }
  for extra in array_field(value, "extras") {
    object_fields(
      extra,
      [
        "reason", "commands", "behaviors", "packages", "case_ids", "backends", "evidence",
        "observations",
      ],
      "human addition",
    )
  }
  for boundary in array_field(value, "boundaries") {
    object_fields(
      boundary,
      [
        "behavior_id", "support_record", "adr", "current_limit", "unlock_condition",
        "rejection_tests", "replacement_behaviors",
      ],
      "scope boundary",
    )
  }
  let intent : ScopeIntent = @json.from_json(value)
  guard intent.schema == 2 &&
    intent.transition == "shadow-full" &&
    intent.policy_version == scope_policy_version else {
    fail("scope requires schema 2 and the explicit shadow-full transition")
  }
  guard !intent.target_ref.trim().is_empty() &&
    !intent.target_ref.has_prefix("-") &&
    hash_string(intent.base, 40) &&
    hash_string(intent.payload, 64) &&
    hash_string(intent.change_set, 64) else {
    fail("scope base/ref/content identities are malformed")
  }
  for
    identity in [
      intent.identities.base_policy,
      intent.identities.candidate_policy,
      intent.identities.base_graph,
      intent.identities.candidate_graph,
      intent.identities.base_registry,
      intent.identities.candidate_registry,
      intent.identities.base_associations,
      intent.identities.candidate_associations,
    ] {
    guard hash_string(identity, 64) else {
      fail("scope input identity is malformed")
    }
  }
  for extra in intent.extras {
    guard !extra.reason.trim().is_empty() else {
      fail("every human addition requires a reviewable reason")
    }
  }
  for boundary in intent.boundaries {
    guard !boundary.behavior_id.is_empty() &&
      !boundary.current_limit.trim().is_empty() &&
      !boundary.unlock_condition.trim().is_empty() &&
      @testkit.safe_relative_path(boundary.support_record) &&
      @testkit.safe_relative_path(boundary.adr) &&
      boundary.support_record.has_prefix("docs/") &&
      boundary.adr.has_prefix("docs/adr/") &&
      (
        !boundary.rejection_tests.is_empty() ||
        !boundary.replacement_behaviors.is_empty()
      ) else {
      fail(
        "boundary requires support, ADR, unlock condition and rejection or replacement evidence",
      )
    }
  }
  for selection in [intent.automatic, intent.selection] {
    guard ["full", "scoped", "docs"].contains(selection.mode) else {
      fail("scope selection has an unknown classification")
    }
    if selection.mode == "full" &&
      (selection.reasons.is_empty() || selection.behaviors.is_empty()) {
      fail(
        "full selection requires nonempty obligations and an explained widening rule",
      )
    }
    if selection.mode == "docs" &&
      (
        !selection.commands.is_empty() ||
        !selection.behaviors.is_empty() ||
        !selection.packages.is_empty()
      ) {
      fail("an empty/docs classification cannot conceal selected behavior")
    }
    for
      ids in [
        selection.commands,
        selection.behaviors,
        selection.packages,
        selection.core_packages,
        selection.build_prerequisites,
        selection.case_ids,
        selection.published_coordinates,
        selection.changed_paths,
        selection.affected_options,
        selection.affected_operands,
      ] {
      guard ids == sorted_strings(ids.copy()) && ids.all(id => !id.is_empty()) else {
        fail("scope IDs must be nonempty, unique and canonical")
      }
    }
    let required = sorted_strings(
      selection.requirements.map(row => row.behavior_id),
    )
    guard required == selection.behaviors else {
      fail("scope requirements do not match the complete behavior selection")
    }
  }
  intent
}

///|
pub fn snapshot_file(snapshot : TreeSnapshot, path : String) -> TreeFile? {
  snapshot.files.iter().find_first(file => file.path == path)
}

///|
fn snapshot_registry(snapshot : TreeSnapshot) -> @registry.Registry raise {
  guard snapshot_file(snapshot, "tests/registry/registry.json") is Some(file) else {
    fail("snapshot has no stable behavior registry")
  }
  let value = strict_json(@utf8.decode(file.content))
  object_fields(
    value,
    ["schema", "entries", "release_commands"],
    "behavior registry",
  )
  guard value is { "schema": Number(2, ..), .. } else {
    fail("registry schema must be exactly 2")
  }
  for entry in array_field(value, "entries") {
    object_fields(
      entry,
      [
        "behavior_id", "command", "owner", "surface", "status", "implementation",
        "source", "case_id", "aliases", "coverage", "required_backends", "platforms",
        "required_evidence", "observations", "oracle_profile",
      ],
      "registry entry",
    )
  }
  for metadata in array_field(value, "release_commands") {
    guard metadata is Object(fields) else {
      fail("release metadata must be an object")
    }
    for key in fields.keys() {
      guard [
        "name", "package_name", "compare_profile", "supported_options", "policy_sensitive",
        "releasable", "case_ids",
      ].contains(key) else {
        fail("unknown release metadata field: " + key)
      }
    }
  }
  let registry : @registry.Registry = @json.from_json(value)
  let errors = @registry.validate(registry)
  guard errors.is_empty() else {
    fail("invalid snapshot registry: " + errors.join("; "))
  }
  registry
}

///|
fn content_identity(snapshot : TreeSnapshot, paths : Array[String]) -> String {
  let entries : Array[Json] = []
  for file in snapshot.files {
    if paths.contains(file.path) {
      entries.push({ "path": file.path, "mode": file.mode, "blob": file.blob })
    }
  }
  entries.sort_by_key(entry => @testkit.canonical_json(entry))
  @testkit.json_digest(Json(entries))
}

///|
fn boundary_definitions(snapshot : TreeSnapshot) -> Array[ScopeBoundary] raise {
  guard snapshot_file(snapshot, "tests/registry/boundaries.json") is Some(file) else {
    return []
  }
  let value = strict_json(@utf8.decode(file.content))
  object_fields(value, ["schema", "entries"], "boundary requirement index")
  guard value is { "schema": Number(1, ..), .. } else {
    fail("boundary index requires schema 1")
  }
  let rows : Array[ScopeBoundary] = []
  let seen : Set[String] = Set([])
  for row in array_field(value, "entries") {
    object_fields(
      row,
      [
        "behavior_id", "support_record", "adr", "current_limit", "unlock_condition",
        "rejection_tests", "replacement_behaviors",
      ],
      "boundary requirement",
    )
    let boundary : ScopeBoundary = @json.from_json(row)
    guard boundary.replacement_behaviors.is_empty() else {
      fail(
        "current canonical rejection requirements cannot replace their own current execution",
      )
    }
    guard !seen.contains(boundary.behavior_id) else {
      fail("duplicate boundary requirement")
    }
    seen.add(boundary.behavior_id)
    rows.push(boundary)
  }
  rows
}

///|
fn selected_boundaries(
  base_tree : TreeSnapshot,
  candidate_tree : TreeSnapshot,
  selection : Selection,
  supplied : Array[ScopeBoundary],
  base_registry : @registry.Registry,
  candidate_registry : @registry.Registry,
) -> Array[ScopeBoundary] raise {
  let known : Map[String, ScopeBoundary] = Map([])
  for
    row in boundary_definitions(base_tree) +
    boundary_definitions(candidate_tree) {
    known[row.behavior_id] = row
  }
  for row in supplied {
    if known.get(row.behavior_id) is Some(canonical) &&
      row.replacement_behaviors.is_empty() &&
      row != canonical {
      fail(
        "reviewed boundary conflicts with the current canonical support/unlock mapping: " +
        row.behavior_id,
      )
    }
    known[row.behavior_id] = row
  }
  let selected : Map[String, ScopeBoundary] = Map([])
  for entry in base_registry.entries + candidate_registry.entries {
    if entry.status == "boundary" &&
      selection.behaviors.contains(entry.behavior_id) {
      guard known.get(entry.behavior_id) is Some(row) else {
        fail(
          "selected rejection lacks an ADR/support/unlock mapping: " +
          entry.behavior_id,
        )
      }
      selected[row.behavior_id] = row
    }
  }
  let supplied_ids : Set[String] = Set([])
  for row in supplied {
    guard !supplied_ids.contains(row.behavior_id) &&
      selection.behaviors.contains(row.behavior_id) else {
      fail(
        "duplicate or unrelated reviewed boundary mapping: " + row.behavior_id,
      )
    }
    supplied_ids.add(row.behavior_id)
    selected[row.behavior_id] = row
  }
  let ids = sorted_strings(selected.keys().collect())
  let rows = ids.map(id => selected[id])
  for row in rows {
    for path in [row.support_record, row.adr] {
      guard @testkit.safe_relative_path(path) &&
        snapshot_file(candidate_tree, path) is Some(file) &&
        ["100644", "100755"].contains(file.mode) &&
        !file.content.is_empty() else {
        fail(
          "boundary support/ADR must be a nonempty tracked regular file: " +
          path,
        )
      }
    }
    for id in row.rejection_tests + row.replacement_behaviors {
      guard candidate_registry.entries.any(entry => entry.behavior_id == id) else {
        fail(
          "boundary/replacement target must be a current canonical registered behavior: " +
          id,
        )
      }
    }
  }
  rows
}

///|
pub fn policy_identity(snapshot : TreeSnapshot) -> String {
  let paths = snapshot.files
    .filter(file => {
      file.path.has_prefix("tests/scope/") ||
      (
        file.path.has_prefix("tests/coverage/") &&
        file.path != "tests/coverage/ci-change.json"
      ) ||
      file.path.has_prefix(".github/workflows/") ||
      file.path == "AGENTS.md" ||
      file.path == "moon.work" ||
      file.path == "tests/moon.mod"
    })
    .map(file => file.path)
  content_identity(snapshot, paths)
}

///|
fn sel_boundary_targets(
  selection : Selection,
  boundaries : Array[ScopeBoundary],
  registry : @registry.Registry,
) -> Selection raise {
  add_human_extras(
    selection,
    boundaries.map(row => {
      reason: "registered rejection/replacement obligations for " +
      row.behavior_id,
      commands: [],
      behaviors: sorted_strings(row.rejection_tests + row.replacement_behaviors),
      packages: [],
      case_ids: [],
      backends: [],
      evidence: [],
      observations: [],
    }),
    registry,
  )
}

///|
pub fn make_intent(
  target_ref : String,
  base : String,
  base_tree : TreeSnapshot,
  candidate_tree : TreeSnapshot,
  changes : Array[GitChange],
  base_graph : DependencyGraph,
  candidate_graph : DependencyGraph,
  extras : Array[HumanExtra],
  boundaries~ : Array[ScopeBoundary] = [],
  deferred~ : Array[String] = [],
  uncovered~ : Array[String] = [],
) -> ScopeIntent raise {
  let candidate_registry = snapshot_registry(candidate_tree)
  let base_registry = snapshot_registry(base_tree)
  let automatic = select_scope(
    base_tree, candidate_tree, changes, base_graph, candidate_graph, base_registry,
    candidate_registry,
  )
  let linked = sel_extra_command_associations(
    add_human_extras_both(automatic, extras, base_registry, candidate_registry),
    extras,
    base_tree,
    candidate_tree,
    base_registry,
    candidate_registry,
  )
  let with_extras = sel_association_floor(
    linked, base_tree, candidate_tree, base_graph, candidate_graph, base_registry,
    candidate_registry,
  )
  let mut boundaries = selected_boundaries(
    base_tree, candidate_tree, with_extras, boundaries, base_registry, candidate_registry,
  )
  let mapped = sel_boundary_targets(with_extras, boundaries, candidate_registry)
  let widened = sel_association_floor(
    mapped, base_tree, candidate_tree, base_graph, candidate_graph, base_registry,
    candidate_registry,
  )
  let mapped = if widened.mode == "full" && mapped.mode != "full" {
    boundaries = selected_boundaries(
      base_tree, candidate_tree, widened, boundaries, base_registry, candidate_registry,
    )
    sel_boundary_targets(widened, boundaries, candidate_registry)
  } else {
    widened
  }
  let selection = {
    ..mapped,
    published_coordinates: selection_coordinates(
      base_tree,
      candidate_tree,
      sorted_strings(
        mapped.commands +
        mapped.requirements
        .filter(row => {
          row.evidence.contains("published-differential") &&
          row.command != "" &&
          row.command != "all"
        })
        .map(row => row.command),
      ),
    ),
    build_prerequisites: sel_final_prerequisites(
      mapped, base_tree, candidate_tree, base_graph, candidate_graph, base_registry,
      candidate_registry,
    ),
  }
  let intent : ScopeIntent = {
    schema: 2,
    transition: "shadow-full",
    policy_version: scope_policy_version,
    target_ref,
    base,
    payload: payload_digest(candidate_tree),
    change_set: change_digest(changes),
    changes: payload_changes(changes),
    identities: {
      base_policy: policy_identity(base_tree),
      candidate_policy: policy_identity(candidate_tree),
      base_graph: graph_digest(base_graph),
      candidate_graph: graph_digest(candidate_graph),
      base_registry: content_identity(base_tree, [
        "tests/registry/registry.json",
      ]),
      candidate_registry: content_identity(candidate_tree, [
        "tests/registry/registry.json",
      ]),
      base_associations: content_identity(base_tree, [
        "tests/registry/associations.json", "tests/registry/boundaries.json",
      ]),
      candidate_associations: content_identity(candidate_tree, [
        "tests/registry/associations.json", "tests/registry/boundaries.json",
      ]),
    },
    automatic,
    extras,
    selection,
    boundaries,
    deferred: sorted_strings(deferred.copy()),
    uncovered: sorted_strings(uncovered.copy()),
  }
  parse_intent(intent.to_json())
}

///|
pub fn freshness_errors(
  saved : ScopeIntent,
  recomputed : ScopeIntent,
) -> Array[String] {
  let failures : Array[String] = []
  if saved.base != recomputed.base || saved.target_ref != recomputed.target_ref {
    failures.push("scope target base advanced or differs from the actual range")
  }
  if saved.payload != recomputed.payload {
    failures.push("scope payload is stale")
  }
  if saved.change_set != recomputed.change_set ||
    saved.changes != recomputed.changes {
    failures.push("scope old/new paths, modes, blobs or change types are stale")
  }
  if saved.identities != recomputed.identities {
    failures.push(
      "scope policy, dependency, registry or association identity is stale",
    )
  }
  if saved.automatic != recomputed.automatic {
    failures.push("automatic scope differs from both-side closure")
  }
  if saved.selection != recomputed.selection {
    failures.push("final scope lost automatic consumers or reviewed additions")
  }
  if saved.extras != recomputed.extras ||
    saved.boundaries != recomputed.boundaries ||
    saved.deferred != recomputed.deferred ||
    saved.uncovered != recomputed.uncovered {
    failures.push("reviewed additions or boundaries differ")
  }
  failures
}
