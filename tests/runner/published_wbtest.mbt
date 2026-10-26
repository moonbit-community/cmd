///|
test "published selection rejects mutable versions and incomplete inventories" {
  let selection : PublishedSelection = {
    base_manifest: "latest-cases.json",
    commands: [{ name: "cat", package_name: "cli/cat", version: "0.2.2", }],
    case_ids: ["cat-case"],
    extra_cases: [],
  }
  assert_eq(published_coordinates(selection)["cat"], "cli/cat@0.2.2")
  for
    invalid in [
      { ..selection, commands: [], },
      { ..selection, case_ids: [], },
      { ..selection, case_ids: ["cat-case", "cat-case"], },
      { ..selection, base_manifest: "../active-cases.json", },
      { ..selection, extra_cases: [{}], },
      { ..selection, commands: [selection.commands[0], selection.commands[0]], },
      {
        ..selection,
        commands: [
          { name: "timeout", package_name: "cli/timeout", version: "0.1.0", },
        ],
      },
      {
        ..selection,
        commands: [
          { name: "cat", package_name: "other/cat", version: "0.2.2", },
        ],
      },
    ] {
    try published_coordinates(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("invalid published selection accepted")
    }
  }
  for
    version in ["latest", "", "0.2", "0.2.2 --help", "0.2.2@latest", "../0.2.2"] {
    let invalid = {
      ..selection,
      commands: [{ ..selection.commands[0], version, }],
    }
    try published_coordinates(invalid) catch {
      _ => ()
    } noraise {
      _ => fail("mutable or malformed version accepted")
    }
  }
}
