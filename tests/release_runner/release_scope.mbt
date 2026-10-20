///|
/// The candidate retains the complete source inventory. Scope limits this
/// publication operation, never the registry or package-version validation.
fn release_scope_errors(manifest : ReleaseManifest) -> Array[String] {
  let failures : Array[String] = []
  if manifest.release_scope is Some(scope) {
    if manifest.candidate != Some(true) {
      failures.push("release_scope is only valid on an unpublished candidate")
    }
    if scope.is_empty() {
      failures.push("release_scope must select at least one command")
    }
    let previous : Ref[String?] = Ref(None)
    for name in scope {
      if !manifest.commands.any(row => row.name == name) {
        failures.push("release_scope contains unknown command: " + name)
      }
      if previous.val is Some(before) && before.lexical_compare(name) >= 0 {
        failures.push(
          "release_scope must contain unique names in lexical order",
        )
      }
      previous.val = Some(name)
    }
  }
  failures
}

///|
fn release_includes(manifest : ReleaseManifest, command : String) -> Bool {
  match manifest.release_scope {
    None => true
    Some(scope) => scope.contains(command)
  }
}

///|
fn release_network_scenario(fixture : ReleaseCase) -> Bool {
  fixture.command == "curl" &&
  fixture.related_commands.unwrap_or([]).contains("wget") &&
  (match (fixture.id, fixture.comparison) {
    ("network-auth-cookie", Some("scenario"))
    | ("network-transfer-boundaries", Some("scenario"))
    | ("network-auth-cookie-oracle", Some("oracle-scenario"))
    | ("network-transfer-boundaries-oracle", Some("oracle-scenario")) => true
    _ => false
  })
}

///|
fn release_commands(manifest : ReleaseManifest) -> Array[ReleaseCommand] {
  manifest.commands.filter(row => release_includes(manifest, row.name))
}

///|
fn release_cases(
  manifest : ReleaseManifest,
  base : BaseManifest,
) -> Array[ReleaseCase] {
  selected_cases(manifest, base).filter(fixture => {
    release_case_included(manifest, fixture)
  })
}

///|
fn release_case_included(
  manifest : ReleaseManifest,
  fixture : ReleaseCase,
) -> Bool {
  [fixture.command, ..fixture.related_commands.unwrap_or([])].any(command => {
    release_includes(manifest, command)
  })
}

///|
fn partial_publication(
  candidate : ReleaseManifest,
  previous : ReleaseManifest,
) -> ReleaseManifest raise Failure {
  guard candidate.release_scope is Some(_) &&
    release_scope_errors(candidate).is_empty() &&
    previous.candidate != Some(true) &&
    previous.release_scope is None &&
    previous.commands.all(row => row.published) else {
    fail(
      "partial publication requires a scoped candidate and full published predecessor",
    )
  }
  let commands = previous.commands.map(row => {
    if release_includes(candidate, row.name) {
      match find_command(candidate, row.name) {
        Some(replacement) => { ..replacement, published: true, }
        None => row
      }
    } else {
      row
    }
  })
  for row in release_commands(candidate) {
    if !previous.commands.any(old => old.name == row.name) {
      commands.push({ ..row, published: true, })
    }
  }
  commands.sort_by((left, right) => left.name.lexical_compare(right.name))
  { ..frozen_publication(candidate), commands, }
}

///|
/// Replace only the selected commands' frozen contracts. Reject identities
/// shared with retained contracts rather than letting aliases hide a rewrite.
fn partial_publication_cases(
  candidate : ReleaseManifest,
  previous : Array[ReleaseCase],
  selected : Array[ReleaseCase],
) -> Array[ReleaseCase] raise Failure {
  guard candidate.release_scope is Some(_) &&
    release_scope_errors(candidate).is_empty() &&
    selected.all(fixture => release_includes(candidate, fixture.command)) else {
    fail("partial publication cases must belong to the explicit release scope")
  }
  let merged = previous.filter(fixture => {
    !release_includes(candidate, fixture.command)
  })
  merged.append(selected)
  let identities : Set[String] = Set([])
  for fixture in merged {
    for id in [fixture.id, ..fixture.aliases.unwrap_or([])] {
      guard !identities.contains(id) else {
        fail("partial publication case identity collision: " + id)
      }
      identities.add(id)
    }
  }
  merged
}
