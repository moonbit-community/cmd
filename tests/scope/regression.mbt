///|
// Execution-only requirements for a current-source full run. This does not
// parse, rewrite or fabricate a PR declaration, base diff or human additions.
pub fn full_regression_requirements(
  snapshot : TreeSnapshot,
  graph : DependencyGraph,
  source_sha : String,
) -> ScopeIntent raise {
  guard hash_string(source_sha, 40) else {
    fail("full regression requires an exact source SHA")
  }
  let registry = snapshot_registry(snapshot)
  let all = full_regression_selection(snapshot, registry)
  let selection = {
    ..all,
    build_prerequisites: sorted_strings(
      all.build_prerequisites +
      selection_prerequisites(
        graph,
        graph,
        all.packages + all.build_prerequisites,
      ),
    ),
  }
  let boundaries = selected_boundaries(
    snapshot,
    snapshot,
    selection,
    [],
    registry,
    registry,
  )
  let policy = policy_identity(snapshot)
  let registry_identity = content_identity(snapshot, [
    "tests/registry/registry.json",
  ])
  let associations = content_identity(snapshot, [
    "tests/registry/associations.json", "tests/registry/boundaries.json",
  ])
  {
    schema: 2,
    transition: "regression-only/full",
    policy_version: scope_policy_version,
    target_ref: "HEAD",
    base: source_sha,
    payload: payload_digest(snapshot),
    change_set: change_digest([]),
    changes: [],
    identities: {
      base_policy: policy,
      candidate_policy: policy,
      base_graph: graph_digest(graph),
      candidate_graph: graph_digest(graph),
      base_registry: registry_identity,
      candidate_registry: registry_identity,
      base_associations: associations,
      candidate_associations: associations,
    },
    automatic: selection,
    extras: [],
    selection,
    boundaries,
    deferred: [],
    uncovered: [],
  }
}
