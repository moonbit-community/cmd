///|
fn sel_test_entry(id : String, command : String) -> @registry.RegistryEntry {
  {
    behavior_id: id,
    command,
    owner: "commands/" + command,
    surface: ["options"],
    status: "supported",
    implementation: "package-test",
    source: "commands/" + command + "/main_wbtest.mbt::" + id,
    case_id: "",
    aliases: [],
    coverage: [],
    required_backends: ["native", "wasm"],
    platforms: [],
    required_evidence: ["contract", "backend-pair"],
    observations: ["status", "stdout"],
    oracle_profile: "",
  }
}

///|
fn sel_test_registry(
  entries : Array[@registry.RegistryEntry],
) -> @registry.Registry {
  { schema: 2, entries, release_commands: [], }
}

///|
fn sel_test_node(owner : String) -> DependencyNode {
  {
    id: owner,
    owner,
    module_name: owner,
    version: "0.1.0",
    source: "local:" + owner,
    backends: ["native", "wasm"],
  }
}

///|
fn sel_test_graph(
  owners : Array[String],
  links~ : Array[(String, String)] = [],
) -> DependencyGraph {
  {
    nodes: owners.map(sel_test_node),
    edges: links.map(link => {
      from: link.0,
      to: link.1,
      import_alias: "dependency",
      kinds: ["source"],
      backends: ["native", "wasm"],
    }),
    uncertainties: [],
  }
}

///|
fn sel_test_file(path : String, content~ : String = "") -> TreeFile {
  {
    path,
    mode: "100644",
    blob: "1111111111111111111111111111111111111111",
    content: @utf8.encode(content),
  }
}

///|
fn sel_test_tree(
  files~ : Array[TreeFile] = [],
  associations~ : String = "{\"schema\":1,\"rules\":[]}",
  published~ : String = "{\"schema\":2,\"commands\":[]}",
) -> TreeSnapshot {
  {
    tree: "1111111111111111111111111111111111111111",
    files: [
      sel_test_file("tests/registry/associations.json", content=associations),
      sel_test_file(
        "tests/release_runner/current/published.json",
        content=published,
      ),
      ..files,
    ],
  }
}

///|
fn sel_test_change(path : String) -> GitChange {
  {
    status: "M",
    old_path: path,
    new_path: path,
    old_mode: "100644",
    new_mode: "100644",
    old_blob: "1111111111111111111111111111111111111111",
    new_blob: "2222222222222222222222222222222222222222",
  }
}

///|
test "scope command changes retain the complete collection without retesting prerequisites" {
  let first = {
    ..sel_test_entry("cat-one", "cat"),
    implementation: "json-case",
    source: "tests/cases/cat.json",
    case_id: "cat-first",
  }
  let second = { ..first, behavior_id: "cat-two", case_id: "cat-second", }
  let core = {
    ..sel_test_entry("core-stream", ""),
    owner: "core/stream",
    source: "core/stream/stream_wbtest.mbt::core-stream",
  }
  let registry = sel_test_registry([
    first,
    second,
    core,
    sel_test_entry("wc", "wc"),
  ])
  let graph = sel_test_graph(["commands/cat", "commands/wc", "core/stream"], links=[
    ("commands/cat", "core/stream"),
  ])
  let tree = sel_test_tree()
  let result = select_scope(
    tree,
    tree,
    [sel_test_change("commands/cat/main.mbt")],
    graph,
    graph,
    registry,
    registry,
  )
  assert_eq(result.mode, "scoped")
  assert_eq(result.commands, ["cat"])
  assert_eq(result.case_ids, ["cat-first", "cat-second"])
  assert_true(result.build_prerequisites.contains("core/stream"))
  assert_true(!result.behaviors.contains("core-stream"))
  assert_true(!result.behaviors.contains("wc"))
}

///|
test "scope unions transitive old and new consumers when imports are removed" {
  let core = {
    ..sel_test_entry("stream", ""),
    owner: "core/stream",
    source: "core/stream/test_wbtest.mbt::stream",
  }
  let registry = sel_test_registry([
    core,
    sel_test_entry("cat", "cat"),
    sel_test_entry("wc", "wc"),
  ])
  let old = sel_test_graph(
    ["core/stream", "core/cli", "commands/cat", "commands/wc"],
    links=[("core/cli", "core/stream"), ("commands/cat", "core/cli")],
  )
  let new = { ..old, edges: [], }
  let tree = sel_test_tree()
  let result = select_scope(
    tree,
    tree,
    [sel_test_change("core/stream/scan.mbt")],
    old,
    new,
    registry,
    registry,
  )
  assert_eq(result.commands, ["cat"])
  assert_true(result.behaviors.contains("stream"))
  assert_true(result.core_packages.contains("core/cli"))
  assert_true(!result.behaviors.contains("wc"))
}

///|
test "scope deleted commands retain old owners requirements and exact coordinates" {
  let old_registry = sel_test_registry([sel_test_entry("retired", "cat")])
  let new_registry = sel_test_registry([])
  let old_graph = sel_test_graph(["commands/cat"])
  let old = sel_test_tree(
    published="{\"schema\":2,\"commands\":[{\"name\":\"cat\",\"package_name\":\"cli/cat\",\"version\":\"0.2.1\",\"published\":true}]}",
  )
  let new = sel_test_tree()
  let change = {
    ..sel_test_change("commands/cat/main.mbt"),
    status: "D",
    new_path: "",
    new_mode: "000000",
  }
  let result = select_scope(
    old,
    new,
    [change],
    old_graph,
    sel_test_graph([]),
    old_registry,
    new_registry,
  )
  assert_eq(result.commands, ["cat"])
  assert_true(result.behaviors.contains("retired"))
  assert_eq(result.published_coordinates, ["cli/cat@0.2.1"])
}

///|
test "scope durable non-import rules retain child scenarios and separate build artifacts" {
  let scenario = {
    ..sel_test_entry("scenario:child", "sh"),
    owner: "tests/integration",
    source: "tests/integration/scenarios.mbt::child",
    implementation: "stateful-scenario",
  }
  let registry = sel_test_registry([
    sel_test_entry("cat", "cat"),
    sel_test_entry("sh-ordinary", "sh"),
    {
      ..sel_test_entry("process-library", ""),
      owner: "core/process",
      source: "core/process/process_wbtest.mbt::process-library",
    },
    scenario,
  ])
  let graph = sel_test_graph(
    ["commands/cat", "commands/sh", "core/process", "tests/integration"],
    links=[("commands/sh", "core/process")],
  )
  let tree = sel_test_tree(
    associations="{\"schema\":1,\"rules\":[{\"id\":\"child\",\"kind\":\"scenario\",\"trigger_commands\":[\"cat\"],\"trigger_paths\":[],\"behavior_ids\":[\"scenario:child\"],\"build_commands\":[\"sh\"],\"full\":false}]}",
  )
  let result = select_scope(
    tree,
    tree,
    [sel_test_change("commands/cat/main.mbt")],
    graph,
    graph,
    registry,
    registry,
  )
  assert_eq(result.commands, ["cat"])
  assert_true(result.behaviors.contains("scenario:child"))
  assert_true(!result.behaviors.contains("sh-ordinary"))
  assert_true(result.build_prerequisites.contains("commands/sh"))
  assert_true(result.build_prerequisites.contains("core/process"))
  assert_true(!result.behaviors.contains("process-library"))
}

///|
test "scope shared harness is full while boundaries and supplementary applicability remain exact" {
  let host = {
    ..sel_test_entry("cohort:gnu-host", "cat"),
    owner: "tests/integration",
    source: "tests/integration/cohorts.mbt::host",
    implementation: "compatibility-cohort",
    required_backends: ["native"],
    platforms: ["linux"],
    required_evidence: ["supplementary"],
  }
  let boundary = {
    ..sel_test_entry("windows-boundary", "wc"),
    status: "boundary",
    required_backends: ["wasm"],
    platforms: ["windows"],
    required_evidence: ["boundary"],
  }
  let registry = sel_test_registry([host, boundary])
  let graph = sel_test_graph([
    "commands/cat", "commands/wc", "tests/integration",
  ])
  let tree = sel_test_tree()
  let result = select_scope(
    tree,
    tree,
    [sel_test_change("tests/testkit/process.mbt")],
    graph,
    graph,
    registry,
    registry,
  )
  assert_eq(result.mode, "full")
  assert_eq(result.commands, ["cat", "wc"])
  let requirement = result.requirements
    .iter()
    .find_first(row => row.behavior_id == "cohort:gnu-host")
    .unwrap()
  assert_eq(requirement.backends, ["native"])
  assert_eq(requirement.platforms, ["linux"])
  assert_eq(requirement.evidence, ["supplementary"])
  let refusal = result.requirements
    .iter()
    .find_first(row => row.behavior_id == "windows-boundary")
    .unwrap()
  assert_eq(refusal.backends, ["wasm"])
  assert_eq(refusal.platforms, ["windows"])
  assert_eq(refusal.evidence, ["boundary"])
}

///|
fn sel_test_catalog(
  option : String,
  helper~ : String = "unchanged",
  expression~ : Bool = false,
) -> String {
  "fn contract_helper() { \"" +
  helper +
  "\" }\n///|\npub fn command_catalog() -> Array[CommandContract] {\n[contract(\"cat\", Core, FileOrStdin, ByteStream, [FileRead], " +
  (if expression { "dynamic_options()" } else { "[\"" + option + "\"]" }) +
  "),contract(\"wc\", Core, FileOrStdin, LineStream, [FileRead], [])]\n}\n///|\nfn suffix() { 1 }\n"
}

///|
test "scope catalog narrows only literal rows with unchanged surrounding helpers" {
  let registry = sel_test_registry([
    sel_test_entry("cat", "cat"),
    sel_test_entry("wc", "wc"),
  ])
  let graph = sel_test_graph(["core/cli", "commands/cat", "commands/wc"], links=[
    ("commands/cat", "core/cli"),
    ("commands/wc", "core/cli"),
  ])
  let old = sel_test_tree(files=[
    sel_test_file("core/cli/catalog.mbt", content=sel_test_catalog("old")),
  ])
  let new = sel_test_tree(files=[
    sel_test_file("core/cli/catalog.mbt", content=sel_test_catalog("new")),
  ])
  let result = select_scope(
    old,
    new,
    [sel_test_change("core/cli/catalog.mbt")],
    graph,
    graph,
    registry,
    registry,
  )
  assert_eq(result.commands, ["cat"])
  for
    candidate in [
      sel_test_tree(files=[
        sel_test_file(
          "core/cli/catalog.mbt",
          content=sel_test_catalog("new", helper="changed"),
        ),
      ]),
      sel_test_tree(files=[
        sel_test_file(
          "core/cli/catalog.mbt",
          content=sel_test_catalog("new", expression=true),
        ),
      ]),
    ] {
    let wider = select_scope(
      old,
      candidate,
      [sel_test_change("core/cli/catalog.mbt")],
      graph,
      graph,
      registry,
      registry,
    )
    assert_eq(wider.commands, ["cat", "wc"])
    assert_true(wider.core_packages.contains("core/cli"))
  }
  let renamed = sel_test_tree(files=[
    sel_test_file(
      "core/cli/catalog.mbt",
      content=sel_test_catalog("new").replace_all(
        old="contract(\"cat\"",
        new="contract(\"head\"",
      ),
    ),
  ])
  let new_graph = sel_test_graph(["core/cli", "commands/head", "commands/wc"], links=[
    ("commands/head", "core/cli"),
    ("commands/wc", "core/cli"),
  ])
  let renamed_registry = sel_test_registry([
    sel_test_entry("head", "head"),
    sel_test_entry("wc", "wc"),
  ])
  let moved = select_scope(
    old,
    renamed,
    [sel_test_change("core/cli/catalog.mbt")],
    graph,
    new_graph,
    registry,
    renamed_registry,
  )
  assert_eq(moved.commands, ["cat", "head"])
}

///|
test "scope registry stable ID transfer selects both owners and global registry checks" {
  let old = sel_test_entry("moved", "cat")
  let new = sel_test_entry("moved", "wc")
  let check = {
    ..sel_test_entry("registry-check", ""),
    owner: "tests/registry",
    source: "tests/registry/check_wbtest.mbt::check",
  }
  let before = sel_test_registry([old, check])
  let after = sel_test_registry([new, check])
  let graph = sel_test_graph(["commands/cat", "commands/wc", "tests/registry"])
  let tree = sel_test_tree()
  let result = select_scope(
    tree,
    tree,
    [sel_test_change("tests/registry/registry.json")],
    graph,
    graph,
    before,
    after,
  )
  assert_eq(result.commands, ["cat", "wc"])
  assert_true(result.behaviors.contains("registry-check"))
  assert_eq(
    result.requirements.filter(row => row.behavior_id == "moved").length(),
    2,
  )
}

///|
test "scope old new requirements never create a backend platform cross product" {
  let old = {
    ..sel_test_entry("same", "cat"),
    required_backends: ["native"],
    platforms: ["windows"],
    required_evidence: ["contract"],
    oracle_profile: "profile-one",
  }
  let new = { ..old, required_backends: ["wasm"], platforms: ["linux"], }
  let tree = sel_test_tree()
  let graph = sel_test_graph(["commands/cat"])
  let result = select_scope(
    tree,
    tree,
    [sel_test_change("commands/cat/main.mbt")],
    graph,
    graph,
    sel_test_registry([old]),
    sel_test_registry([new]),
  )
  assert_eq(result.requirements.length(), 2)
  assert_true(
    result.requirements.any(row => {
      row.backends == ["native"] && row.platforms == ["windows"]
    }),
  )
  assert_true(
    result.requirements.any(row => {
      row.backends == ["wasm"] && row.platforms == ["linux"]
    }),
  )
  let changed_profile = sel_requirements([
    old,
    { ..old, oracle_profile: "profile-two", },
  ])
  assert_eq(changed_profile.length(), 2)
  let changed_case = sel_requirements([
    { ..old, case_id: "old-case", },
    { ..old, case_id: "new-case", },
  ])
  assert_eq(changed_case.length(), 2)
  assert_true(changed_case.any(row => row.case_id == "old-case"))
  assert_true(changed_case.any(row => row.case_id == "new-case"))
}

///|
test "scope human extras union only their targeted requirements and preserve automatic rows" {
  let native = {
    ..sel_test_entry("native-only", "cat"),
    required_backends: ["native"],
    platforms: ["linux"],
    required_evidence: ["contract"],
  }
  let wasm = {
    ..sel_test_entry("wasm-boundary", "wc"),
    status: "boundary",
    required_backends: ["wasm"],
    platforms: ["windows"],
    required_evidence: ["boundary"],
  }
  let registry = sel_test_registry([native, wasm])
  let graph = sel_test_graph(["commands/cat", "commands/wc"])
  let tree = sel_test_tree()
  let automatic = select_scope(
    tree,
    tree,
    [sel_test_change("AGENTS.md")],
    graph,
    graph,
    registry,
    registry,
  )
  let extra : HumanExtra = {
    reason: "independent native rejection observation",
    commands: [],
    behaviors: ["wasm-boundary"],
    packages: [],
    case_ids: [],
    backends: ["native"],
    evidence: [],
    observations: ["stderr"],
  }
  let result = add_human_extras(automatic, [extra], registry)
  assert_eq(result.mode, "full")
  assert_eq(result.behaviors, automatic.behaviors)
  assert_true(
    result.requirements.any(row => {
      row.behavior_id == "native-only" &&
      row.backends == ["native"] &&
      row.platforms == ["linux"]
    }),
  )
  assert_true(
    result.requirements.any(row => {
      row.behavior_id == "wasm-boundary" &&
      row.backends == ["native", "wasm"] &&
      row.platforms == ["windows"]
    }),
  )
  assert_eq(
    automatic.requirements.filter(row => row.behavior_id == "wasm-boundary")[0].backends,
    ["wasm"],
  )
  let rejected = try {
    ignore(add_human_extras(automatic, [{ ..extra, reason: "", }], registry))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "scope only newly added narrative reports get docs mode" {
  let registry = sel_test_registry([sel_test_entry("cat", "cat")])
  let graph = sel_test_graph(["commands/cat"])
  let path = "docs/reports/new/narrative.md"
  let old = sel_test_tree()
  let new = sel_test_tree(files=[sel_test_file(path, content="new report")])
  let result = select_scope(
    old,
    new,
    [{ ..sel_test_change(path), status: "A", old_path: "", }],
    graph,
    graph,
    registry,
    registry,
  )
  assert_eq(result.mode, "docs")
  let index = "docs/reports/README.md"
  let index_before = sel_test_tree(files=[
    sel_test_file(index, content="previous report index"),
  ])
  let index_after = sel_test_tree(files=[
    sel_test_file(index, content="updated report index"),
  ])
  let index_result = select_scope(
    index_before,
    index_after,
    [sel_test_change(index)],
    graph,
    graph,
    registry,
    registry,
  )
  assert_eq(index_result.mode, "docs")
  assert_eq(index_result.changed_paths, [index])
  assert_true(index_result.commands.is_empty())
  assert_true(index_result.behaviors.is_empty())
  assert_true(index_result.packages.is_empty())
  assert_true(index_result.build_prerequisites.is_empty())
  assert_true(index_result.requirements.is_empty())
  let historical = "docs/reports/previous/README.md"
  let historical_before = sel_test_tree(files=[
    sel_test_file(historical, content="frozen report"),
  ])
  let historical_after = sel_test_tree(files=[
    sel_test_file(historical, content="modified frozen report"),
  ])
  for
    (before, after, change) in [
      (historical_before, historical_after, sel_test_change(historical)),
      (
        historical_before,
        index_after,
        { ..sel_test_change(index), status: "R100", old_path: historical, },
      ),
      (
        index_before,
        new,
        { ..sel_test_change(index), status: "R100", new_path: path, },
      ),
      (
        index_before,
        old,
        {
          ..sel_test_change(index),
          status: "D",
          new_path: "",
          new_mode: "000000",
        },
      ),
    ] {
    assert_eq(
      select_scope(before, after, [change], graph, graph, registry, registry).mode,
      "full",
    )
  }
  for mode in ["120000", "100755"] {
    let nonregular = sel_test_tree(files=[{ ..sel_test_file(index), mode, }])
    for
      (before, after, change) in [
        (nonregular, index_after, { ..sel_test_change(index), old_mode: mode, }),
        (
          index_before,
          nonregular,
          { ..sel_test_change(index), new_mode: mode, },
        ),
        (nonregular, index_after, sel_test_change(index)),
        (index_before, nonregular, sel_test_change(index)),
        (
          index_before,
          index_after,
          { ..sel_test_change(index), old_mode: mode, },
        ),
        (
          index_before,
          index_after,
          { ..sel_test_change(index), new_mode: mode, },
        ),
      ] {
      assert_eq(
        select_scope(before, after, [change], graph, graph, registry, registry).mode,
        "full",
      )
    }
  }
  for
    protected_path in [
      "docs/compatibility.md", "docs/adr/0001-evidence.md", "README.mbt.md", "unknown/new.mbt",
    ] {
    assert_eq(
      select_scope(
        old,
        new,
        [sel_test_change(protected_path)],
        graph,
        graph,
        registry,
        registry,
      ).mode,
      "full",
    )
  }
  assert_eq(
    select_scope(
      old,
      new,
      [sel_test_change("commands/cat/README.md")],
      graph,
      graph,
      registry,
      registry,
    ).commands,
    ["cat"],
  )
}

///|
test "scope unknown graph or association schemas widen while corrupt policies reject" {
  let registry = sel_test_registry([sel_test_entry("cat", "cat")])
  let graph = sel_test_graph(["commands/cat"])
  let tree = sel_test_tree()
  let uncertain = { ..graph, uncertainties: ["unrecognized manifest syntax"], }
  assert_eq(
    select_scope(tree, tree, [], graph, uncertain, registry, registry).mode,
    "full",
  )
  let unsupported = sel_test_tree(associations="{\"schema\":9,\"rules\":[]}")
  assert_eq(
    select_scope(tree, unsupported, [], graph, graph, registry, registry).mode,
    "full",
  )
  let unsupported_glob = sel_test_tree(
    associations="{\"schema\":1,\"rules\":[{\"id\":\"unknown-glob\",\"kind\":\"fixture\",\"trigger_commands\":[],\"trigger_paths\":[\"tests/*/**\"],\"behavior_ids\":[],\"build_commands\":[],\"full\":false}]}",
  )
  assert_eq(
    select_scope(tree, unsupported_glob, [], graph, graph, registry, registry).mode,
    "full",
  )
  let corrupt = sel_test_tree(
    associations="{\"schema\":1,\"schema\":1,\"rules\":[]}",
  )
  let rejected = try {
    ignore(select_scope(tree, corrupt, [], graph, graph, registry, registry))
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  for
    fractional in [
      sel_test_tree(associations="{\"schema\":1.5,\"rules\":[]}"),
      sel_test_tree(published="{\"schema\":2.5,\"commands\":[]}"),
    ] {
    assert_true(
      try {
        ignore(
          select_scope(tree, fractional, [], graph, graph, registry, registry),
        )
        false
      } catch {
        _ => true
      },
    )
  }
  let malformed = sel_test_registry([
    sel_test_entry("duplicate", "cat"),
    sel_test_entry("duplicate", "cat"),
  ])
  assert_true(
    try {
      ignore(select_scope(tree, tree, [], graph, graph, malformed, registry))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "scope nested package moves retain consumers of both previous and new owners" {
  let registry = sel_test_registry([
    sel_test_entry("cat", "cat"),
    sel_test_entry("wc", "wc"),
  ])
  let old = sel_test_graph(["core/stream", "commands/cat"], links=[
    ("commands/cat", "core/stream"),
  ])
  let new = sel_test_graph(["core/stream/nested", "commands/wc"], links=[
    ("commands/wc", "core/stream/nested"),
  ])
  let tree = sel_test_tree()
  let result = select_scope(
    tree,
    tree,
    [sel_test_change("core/stream/nested/scan.mbt")],
    old,
    new,
    registry,
    registry,
  )
  assert_eq(result.commands, ["cat", "wc"])
  assert_true(result.core_packages.contains("core/stream"))
  assert_true(result.core_packages.contains("core/stream/nested"))
}

///|
test "scope published row metadata changes select owners even when coordinates are unchanged" {
  let registry = sel_test_registry([
    sel_test_entry("cat", "cat"),
    sel_test_entry("wc", "wc"),
  ])
  let graph = sel_test_graph(["commands/cat", "commands/wc"])
  let old = sel_test_tree(
    published="{\"schema\":2,\"commands\":[{\"name\":\"cat\",\"version\":\"0.2.1\",\"package_name\":\"cli/cat\",\"published\":true,\"supported_options\":[\"old\"]}]}",
  )
  let new = sel_test_tree(
    published="{\"schema\":2,\"commands\":[{\"name\":\"cat\",\"version\":\"0.2.1\",\"package_name\":\"cli/cat\",\"published\":true,\"supported_options\":[\"new\"]}]}",
  )
  let result = select_scope(
    old,
    new,
    [sel_test_change("tests/release_runner/current/published.json")],
    graph,
    graph,
    registry,
    registry,
  )
  assert_eq(result.commands, ["cat"])
  assert_eq(result.published_coordinates, ["cli/cat@0.2.1"])
}

///|
test "scope regression full derives every current obligation without a synthetic change range" {
  let boundary = {
    ..sel_test_entry("custom-stable-boundary", "cat"),
    implementation: "json-case",
    source: "tests/cases/cat.json",
    case_id: "actual-rejection",
    status: "boundary",
    required_backends: ["wasm"],
    platforms: ["windows"],
    required_evidence: ["boundary"],
  }
  let supplementary = {
    ..sel_test_entry("host-diagnostic", ""),
    owner: "tests/runner",
    source: "tests/runner/host_wbtest.mbt::host-diagnostic",
    required_backends: ["native"],
    platforms: ["linux"],
    required_evidence: ["supplementary"],
  }
  let registry = sel_test_registry([boundary, supplementary])
  let snapshot = sel_test_tree(
    files=[
      sel_test_file("commands/cat/moon.pkg"),
      sel_test_file("commands/timeout/moon.pkg"),
      sel_test_file("core/stream/moon.pkg"),
      sel_test_file("tests/isolated/moon.pkg"),
    ],
    published="{\"schema\":2,\"commands\":[{\"name\":\"cat\",\"version\":\"0.2.1\",\"package_name\":\"cli/cat\",\"published\":true},{\"name\":\"timeout\",\"version\":\"0.1.0\",\"package_name\":\"cli/timeout\",\"published\":false}]}",
  )
  let selection = full_regression_selection(snapshot, registry)
  assert_eq(selection.mode, "full")
  assert_eq(selection.changed_paths, [])
  assert_eq(selection.commands, ["cat", "timeout"])
  assert_eq(selection.behaviors, ["custom-stable-boundary", "host-diagnostic"])
  assert_eq(selection.case_ids, ["actual-rejection"])
  assert_eq(selection.published_coordinates, ["cli/cat@0.2.1"])
  assert_true(selection.packages.contains("tests/isolated"))
  assert_true(selection.build_prerequisites.contains("core/stream"))
  assert_eq(selection.core_packages, ["core/stream"])
  assert_true(
    selection.requirements.any(row => {
      row.behavior_id == boundary.behavior_id &&
      row.case_id == "actual-rejection" &&
      row.backends == ["wasm"] &&
      row.platforms == ["windows"] &&
      row.evidence == ["boundary"]
    }),
  )
  assert_true(
    selection.requirements.any(row => {
      row.behavior_id == supplementary.behavior_id &&
      row.backends == ["native"] &&
      row.platforms == ["linux"] &&
      row.evidence == ["supplementary"] &&
      row.oracle_profile == ""
    }),
  )
  assert_true(
    try {
      ignore(
        full_regression_selection(
          { ..snapshot, files: snapshot.files + [snapshot.files[0]], },
          registry,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
  for empty in [sel_test_registry([]), sel_test_registry([supplementary])] {
    assert_true(
      try {
        ignore(full_regression_selection(sel_test_tree(), empty))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "scope both-side human extras retain removed cases and strengthen matching aliases" {
  let old = {
    ..sel_test_entry("stable-transfer", "cat"),
    implementation: "json-case",
    source: "tests/cases/cat.json",
    case_id: "removed-case",
    aliases: ["reviewed-alias"],
    required_backends: ["native"],
    platforms: ["linux"],
    required_evidence: ["contract"],
  }
  let new = {
    ..old,
    command: "wc",
    owner: "commands/wc",
    source: "tests/cases/wc.json",
    case_id: "current-case",
    required_backends: ["wasm"],
    platforms: ["windows"],
  }
  let before = sel_test_registry([old])
  let after = sel_test_registry([new])
  let tree = sel_test_tree()
  let selection = select_scope(
    tree,
    tree,
    [sel_test_change("AGENTS.md")],
    sel_test_graph(["commands/cat"]),
    sel_test_graph(["commands/wc"]),
    before,
    after,
  )
  let removed : HumanExtra = {
    reason: "retain reviewed old-side rejection observation",
    commands: [],
    behaviors: [],
    packages: [],
    case_ids: ["removed-case"],
    backends: ["wasm"],
    evidence: [],
    observations: ["stderr"],
  }
  let alias_extra = {
    ..removed,
    reason: "independent alias-bound observation on both owners",
    behaviors: ["reviewed-alias"],
    case_ids: [],
    backends: ["native"],
    observations: ["file-content"],
  }
  let result = add_human_extras_both(
    selection,
    [removed, alias_extra],
    before,
    after,
  )
  assert_eq(result.behaviors, selection.behaviors)
  assert_eq(result.commands, ["cat", "wc"])
  assert_eq(result.case_ids, ["current-case", "removed-case"])
  assert_true(
    result.requirements.any(row => {
      row.case_id == "removed-case" &&
      row.command == "cat" &&
      row.backends == ["native", "wasm"] &&
      row.platforms == ["linux"] &&
      row.observations.contains("stderr")
    }),
  )
  assert_true(
    result.requirements.any(row => {
      row.case_id == "current-case" &&
      row.command == "wc" &&
      row.backends == ["native", "wasm"] &&
      row.platforms == ["windows"] &&
      row.observations.contains("file-content")
    }),
  )
  for original in selection.requirements {
    assert_true(
      result.requirements.any(row => {
        row.behavior_id == original.behavior_id &&
        row.case_id == original.case_id &&
        row.command == original.command &&
        row.backends == original.backends &&
        row.platforms == original.platforms &&
        original.evidence.all(kind => row.evidence.contains(kind)) &&
        original.observations.all(kind => row.observations.contains(kind))
      }),
    )
  }
  assert_true(
    try {
      ignore(
        add_human_extras_both(
          selection,
          [{ ..removed, case_ids: ["unknown-on-both-sides"], }],
          before,
          after,
        ),
      )
      false
    } catch {
      _ => true
    },
  )
}
