///|
// Full execution and shadow obligations remain separate proof subjects. A
// replacement for an old row cannot replace a still-current full-suite row.
fn ci_full_shadow_impact(
  full : @scope.ScopeIntent,
  shadow : @scope.ScopeIntent?,
  registry : @registry.Registry,
) -> CiImpact {
  let current = ci_scope_impact(full, registry=Some(registry))
  guard shadow is Some(shadow) else { return current }
  let changed = ci_scope_impact(shadow, registry=Some(registry))
  let boundaries = current.boundaries.copy()
  for row in changed.boundaries {
    if !boundaries.any(existing => existing.behavior_id == row.behavior_id) {
      boundaries.push(row)
    }
  }
  {
    ..current,
    affected_commands: sorted_unique(
      current.affected_commands + changed.affected_commands,
    ),
    affected_behaviors: sorted_unique(
      current.affected_behaviors + changed.affected_behaviors,
    ),
    affected_options: sorted_unique(
      current.affected_options + changed.affected_options,
    ),
    affected_operands: sorted_unique(
      current.affected_operands + changed.affected_operands,
    ),
    case_ids: sorted_unique(current.case_ids + changed.case_ids),
    published_manifest_affected: current.published_manifest_affected ||
    changed.published_manifest_affected,
    boundaries,
    deferred: changed.deferred,
    uncovered: changed.uncovered,
  }
}
