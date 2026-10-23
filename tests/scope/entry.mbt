///|
async fn scope_git(root : String, args : Array[String]) -> String {
  scope_git_text(root, args)
}

///|
async fn require_ancestor(root : String, base : String, head : String) -> Unit {
  ignore(scope_git(root, ["merge-base", "--is-ancestor", base, head]))
}

///|
pub async fn recompute_intent(
  root : String,
  target_ref : String,
  base : String,
  candidate : String,
  extras : Array[HumanExtra],
  boundaries~ : Array[ScopeBoundary] = [],
  deferred~ : Array[String] = [],
  uncovered~ : Array[String] = [],
) -> ScopeIntent {
  let base_tree = read_tree(root, base)
  let candidate_tree = read_tree(root, candidate)
  let changes = read_changes(root, base, candidate_tree.tree)
  let base_graph = capture_graph(base_tree)
  let candidate_graph = capture_graph(candidate_tree)
  make_intent(
    target_ref,
    base,
    base_tree,
    candidate_tree,
    changes,
    base_graph,
    candidate_graph,
    extras,
    boundaries~,
    deferred~,
    uncovered~,
  )
}

///|
fn tree_intent(snapshot : TreeSnapshot) -> ScopeIntent raise {
  guard snapshot_file(snapshot, "tests/coverage/ci-change.json") is Some(file) else {
    fail("candidate has no scope intent")
  }
  parse_intent_text(@utf8.decode(file.content))
}

///|
async fn main_range_review(
  root : String,
  base : String,
  head : String,
  current : ScopeIntent,
) -> (Array[HumanExtra], Array[ScopeBoundary], Array[String], Array[String]) {
  let extras : Map[String, HumanExtra] = Map([])
  let boundaries : Map[String, ScopeBoundary] = Map([])
  let deferred = current.deferred.copy()
  let uncovered = current.uncovered.copy()
  let canonical_boundary_ids = boundary_definitions(read_tree(root, head)).map(row => {
    row.behavior_id
  })
  let commits = scope_git(root, [
    "rev-list",
    "--first-parent",
    "--reverse",
    base + ".." + head,
  ])
  for commit in commits.split("\n") {
    guard hash_string(commit.to_owned(), 40) else {
      fail("main range contains an invalid commit identity")
    }
    let value = strict_json(
      scope_git(root, [
        "show",
        commit.to_owned() + ":tests/coverage/ci-change.json",
      ]),
    )
    if value is { "schema": Number(2, ..), .. } {
      let reviewed = parse_intent(value)
      for extra in reviewed.extras {
        extras[@testkit.canonical_json(extra.to_json())] = extra
      }
      for boundary in reviewed.boundaries {
        if !boundary.replacement_behaviors.is_empty() ||
          !canonical_boundary_ids.contains(boundary.behavior_id) {
          boundaries[boundary.behavior_id] = boundary
        }
      }
    } else if value is { "schema": Number(1, ..), .. } {
      // A recorded pre-migration intent supplies no schema-v2 additions.
      ()
    } else {
      fail("main range contains an unknown scope schema")
    }
  }
  let extra_keys = sorted_strings(extras.keys().collect())
  let boundary_keys = sorted_strings(boundaries.keys().collect())
  (
    extra_keys.map(key => extras[key]),
    boundary_keys.map(key => boundaries[key]),
    sorted_strings(deferred),
    sorted_strings(uncovered),
  )
}

///|
// PR/local verification requires exact base alignment. A main push first
// validates the saved content, then recomputes its actual before..after range.
pub async fn verify_checkout_intent(
  root : String,
  base : String,
  head : String,
  event : String,
) -> ScopeIntent {
  guard ["local", "pull_request", "push"].contains(event) else {
    fail("scope verification requires an explicit supported change event")
  }
  let exact_head = resolve_commit(root, head)
  guard exact_head == resolve_commit(root, "HEAD") else {
    fail("scope verification must observe the exact checked-out head")
  }
  let intended_tree = staged_tree(root)
  let actual_tree = read_tree(root, exact_head)
  guard intended_tree == actual_tree.tree else {
    fail("scope verification requires a clean committed index")
  }
  let saved = tree_intent(actual_tree)
  let exact_base = resolve_commit(root, base)
  if event == "local" && resolve_commit(root, saved.target_ref) != exact_base {
    fail("scope target ref has advanced; fetch/synchronize and prepare again")
  }
  if event != "push" && saved.base != exact_base {
    fail("scope target base advanced; synchronize and prepare again")
  }
  require_ancestor(root, saved.base, exact_head)
  let recomputed = recompute_intent(
    root,
    saved.target_ref,
    saved.base,
    exact_head,
    saved.extras,
    boundaries=saved.boundaries,
    deferred=saved.deferred,
    uncovered=saved.uncovered,
  )
  let failures = freshness_errors(saved, recomputed)
  guard failures.is_empty() else { fail(failures.join("\n")) }
  if event == "push" && exact_base != saved.base {
    require_ancestor(root, exact_base, exact_head)
    let (extras, boundaries, deferred, uncovered) = main_range_review(
      root, exact_base, exact_head, saved,
    )
    return recompute_intent(
      root,
      saved.target_ref,
      exact_base,
      exact_head,
      extras,
      boundaries~,
      deferred~,
      uncovered~,
    )
  }
  recomputed
}

///|
pub async fn prepare_intent(root : String, target_ref : String) -> ScopeIntent {
  let base = resolve_commit(root, target_ref)
  require_ancestor(root, base, "HEAD")
  let tree = staged_tree(root)
  let snapshot = read_tree(root, tree)
  let base_snapshot = read_tree(root, base)
  let canonical_boundary_ids = boundary_definitions(snapshot).map(row => {
    row.behavior_id
  })
  for directory in [root + "/tests", root + "/tests/coverage"] {
    guard @fs.kind(directory, follow_symlink=false) == Directory else {
      fail("scope declaration parent must be an ordinary managed directory")
    }
  }
  if snapshot_file(snapshot, "tests/coverage/ci-change.json") is Some(file) {
    guard ["100644", "100755"].contains(file.mode) &&
      @fs.kind(root + "/tests/coverage/ci-change.json", follow_symlink=false) ==
      Regular else {
      fail("scope declaration must be an ordinary tracked file")
    }
  }
  let (extras, boundaries, deferred, uncovered) = match
    snapshot_file(snapshot, "tests/coverage/ci-change.json") {
    Some(file) => {
      let value = strict_json(@utf8.decode(file.content))
      match value {
        { "schema": Number(2, ..), .. } => {
          let previous = parse_intent(value)
          if snapshot_file(base_snapshot, "tests/coverage/ci-change.json")
            is Some(base_file) &&
            base_file.blob == file.blob {
            // A new branch inherits its base's declaration, not that previous
            // change's human additions. A prepared branch retains its review.
            ([], [], [], [])
          } else {
            (
              previous.extras,
              previous.boundaries.filter(row => {
                !row.replacement_behaviors.is_empty() ||
                !canonical_boundary_ids.contains(row.behavior_id)
              }),
              previous.deferred,
              previous.uncovered,
            )
          }
        }
        // Schema 1 is read only as the recorded predecessor during migration.
        // It supplies no automatic scope and cannot replace schema-v2 review.
        { "schema": Number(1, ..), .. } => ([], [], [], [])
        _ => fail("existing scope intent has an unknown schema")
      }
    }
    None => ([], [], [], [])
  }
  let intent = recompute_intent(
    root,
    target_ref,
    base,
    tree,
    extras,
    boundaries~,
    deferred~,
    uncovered~,
  )
  let path = root + "/tests/coverage/ci-change.json"
  let temporary = root +
    "/tests/coverage/.ci-change-" +
    intent.payload +
    "-" +
    @async.now().to_string()
  defer (@fs.remove(temporary) catch { _ => () })
  @fs.write_file(
    temporary,
    @testkit.canonical_json(intent.to_json()) + "\n",
    create_mode=CreateNew,
  )
  @fs.rename(temporary, path, replace=true)
  ignore(scope_git(root, ["add", "--", "tests/coverage/ci-change.json"]))
  let final_tree = read_tree(root, staged_tree(root))
  guard payload_digest(final_tree) == intent.payload else {
    fail("managed content changed while scope was being prepared")
  }
  intent
}

///|
pub fn intent_explanation(intent : ScopeIntent) -> String {
  "# Automatic scope review\n\n" +
  "Schema: 2; transition: shadow-full. All applicable full-suite execution remains required.\n\n" +
  "Target: `" +
  intent.target_ref +
  "` at `" +
  intent.base +
  "`.\n\n" +
  "Payload: `" +
  intent.payload +
  "`.\n\n" +
  "Automatic mode: " +
  intent.automatic.mode +
  ".\n\n" +
  "Reasons:\n\n" +
  intent.selection.reasons.map(reason => "- " + reason).join("\n") +
  "\n\nCommands: " +
  intent.selection.commands.join(", ") +
  "\n\nSelected behaviors: \{intent.selection.behaviors.length()}. " +
  "Build prerequisites: \{intent.selection.build_prerequisites.length()}.\n" +
  "\nHuman additions: \{intent.extras.length()}. " +
  "Requirements are recorded per behavior, platform, backend and oracle profile.\n"
}

///|
pub async fn run_cli(args : Array[String]) -> Unit {
  let root = scope_git(".", ["rev-parse", "--show-toplevel"])
  let intent = match args[:] {
    ["prepare", "--base-ref", target_ref] => prepare_intent(root, target_ref)
    ["verify", "--base", base, "--head", head] =>
      verify_checkout_intent(root, base, head, "local")
    _ =>
      fail(
        "Usage: --scope prepare --base-ref REF | verify --base SHA --head SHA",
      )
  }
  println(intent_explanation(intent))
}
