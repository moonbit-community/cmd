///|
/// Bind the executed definitions to the registry's own source corpus. A known
/// ID alone cannot authorize changed arguments, weaker assertions or fixtures.
/// This is for current executions; historical replay uses its frozen corpus.
pub async fn validate_selected_cases(
  registry : Registry,
  cases : ArrayView[@testkit.Case],
  root~ : String = "",
) -> Array[String] {
  let root = if root == "" || root.has_suffix("/") { root } else { root + "/" }
  let failures : Array[String] = []
  let sources : Map[String, Array[@testkit.Case]] = Map([])
  let seen : Map[String, Bool] = Map([])
  for selected in cases {
    if seen.contains(selected.id) {
      failures.push("registry: duplicate selected case '" + selected.id + "'")
    }
    seen[selected.id] = true
    let bindings = registry.entries.filter(entry => {
      entry.is_case() &&
      (entry.case_id == selected.id || entry.aliases.contains(selected.id))
    })
    if bindings.length() != 1 {
      failures.push(
        if bindings.is_empty() {
          "registry: unregistered selected case '" + selected.id + "'"
        } else {
          "registry: ambiguous selected case '" + selected.id + "'"
        },
      )
      continue
    }
    let binding = bindings[0]
    if !@testkit.safe_relative_path(binding.source) {
      failures.push(
        "registry: unsafe selected case source '" + binding.source + "'",
      )
      continue
    }
    let source = match sources.get(binding.source) {
      Some(source) => source
      None => {
        let source = @testkit.load_cases(root + binding.source) catch {
          error => {
            failures.push(
              "registry: selected case source unavailable '" +
              binding.source +
              "': " +
              error.to_string(),
            )
            []
          }
        }
        sources[binding.source] = source
        source
      }
    }
    let canonical = source.filter(fixture => fixture.id == binding.case_id)
    if canonical.length() != 1 {
      failures.push(
        "registry: selected case source binding missing or ambiguous '" +
        selected.id +
        "'",
      )
      continue
    }
    if binding.command != canonical[0].command ||
      @testkit.canonical_json(ToJson::to_json(selected)) !=
      @testkit.canonical_json(ToJson::to_json(canonical[0])) {
      failures.push(
        "registry: selected case body differs from registered source '" +
        selected.id +
        "'",
      )
    }
  }
  failures
}
