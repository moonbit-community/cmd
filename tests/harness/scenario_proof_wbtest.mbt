///|
fn scenario_test_definition() -> Json {
  {
    "case_id": "scene",
    "assertions": [
      {
        "id": "requests",
        "command": "curl",
        "relation": "equal",
        "expected": ["GET", "GET"],
        "observations": ["request-method", "request-count"],
      },
    ],
  }
}

///|
test "typed scene proof requires observed values and executing expectations" {
  let definition = scenario_test_definition()
  let proof = ScenarioProof::new("scene", definition)
  assert_false(proof.errors().is_empty())
  proof.observe_equal("requests", "curl", ["GET", "GET"], ["GET", "GET"])
  assert_eq(proof.errors(), [])
  assert_false(
    scenario_receipt_errors(
      definition,
      proof.receipt(),
      required=["requests"],
      command="wget",
    ).is_empty(),
  )
  let wrong = ScenarioProof::new("scene", definition)
  wrong.observe_equal("requests", "curl", ["GET"], ["GET"])
  assert_false(wrong.errors().is_empty())
  let wrong_expected = ScenarioProof::new("scene", definition)
  wrong_expected.observe_equal("requests", "curl", ["GET", "GET"], ["GET"])
  assert_false(wrong_expected.errors().is_empty())
  proof.observe_equal("requests", "curl", ["GET", "GET"], ["GET", "GET"])
  assert_false(proof.errors().is_empty())
}

///|
test "missing null observation and malformed mode controls cannot pass" {
  let exact : Json = {
    "id": "null",
    "command": "curl",
    "relation": "equal",
    "expected": Json::null(),
  }
  assert_false(
    scenario_assertion_errors(exact, {
      "id": "null",
      "command": "curl",
      "relation": "equal",
      "expected": Json::null(),
    }).is_empty(),
  )
  let pair : Json = {
    "id": "mode",
    "command": "cp",
    "relation": "equal-pair",
    "value_kind": "octal-mode",
    "observations": ["actual-mode", "control-mode"],
  }
  assert_eq(
    scenario_assertion_errors(pair, {
      "id": "mode",
      "command": "cp",
      "relation": "equal-pair",
      "value_kind": "octal-mode",
      "actual": ["640", "640"],
    }),
    [],
  )
  for values in [["600", "640"], ["", ""], ["999", "999"]] {
    assert_false(
      scenario_assertion_errors(pair, {
        "id": "mode",
        "command": "cp",
        "relation": "equal-pair",
        "value_kind": "octal-mode",
        "actual": Json(values),
      }).is_empty(),
    )
  }
}

///|
test "malformed or duplicate scenario descriptors fail closed" {
  let definition = scenario_test_definition()
  assert_eq(
    scenario_catalog_errors({ "schema": 1, "scenarios": [definition] }),
    [],
  )
  assert_false(
    scenario_catalog_errors({
      "schema": 1,
      "scenarios": [definition, definition],
    }).is_empty(),
  )
  assert_false(
    scenario_catalog_errors({ "schema": 1, "scenarios": [] }).is_empty(),
  )
  assert_false(
    scenario_catalog_errors({
      "schema": 1,
      "scenarios": [
        {
          "case_id": "scene",
          "assertions": [
            {
              "id": "x",
              "command": "curl",
              "relation": "equal",
              "observations": ["stdout"],
            },
          ],
        },
      ],
    }).is_empty(),
  )
  for
    bad in [
      ([Json::null()] : Array[Json]),
      [Json("")],
      [Json("stdout"), Json("stdout")],
    ] {
    assert_false(
      scenario_catalog_errors({
        "schema": 1,
        "scenarios": [
          {
            "case_id": "scene",
            "assertions": [
              {
                "id": "x",
                "command": "curl",
                "relation": "equal",
                "expected": "",
                "observations": Json(bad),
              },
            ],
          },
        ],
      }).is_empty(),
    )
  }
}

///|
test "observations are frozen at capture and retain declared scene identity" {
  let definition : Json = {
    "case_id": "scene",
    "assertions": [
      {
        "id": "value",
        "command": "curl",
        "relation": "equal",
        "expected": { "count": 2 },
        "observations": ["request-count"],
      },
    ],
  }
  let values : Map[String, Json] = Map([("count", Json(1))])
  let proof = ScenarioProof::new("scene", definition)
  proof.observe_equal("value", "curl", Json(values), { "count": 2 })
  values["count"] = Json(2)
  assert_false(proof.errors().is_empty())
  let wrong = ScenarioProof::new("wrong-scene", definition)
  wrong.observe_equal("value", "curl", { "count": 2 }, { "count": 2 })
  assert_false(wrong.errors().is_empty())
}
