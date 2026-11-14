///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Test complex expressions
test "parse complex filter" {
  json_inspect(@parser.parse(".[] | select(.age > 18) | .name"), content=[
    "Pipe",
    [
      "Pipe",
      ["Pipe", "Identity", ["Index", []]],
      [
        "Select",
        [
          "Operation",
          ["Key", "age"],
          "GreaterThan",
          ["Literal", ["Number", 18]],
        ],
      ],
    ],
    ["Key", "name"],
  ])
}
