///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Evaluate binary operation
fn eval_binary_op(
  op : BinaryOp,
  left : Json,
  right : Json,
) -> Json raise InterpreterError {
  match op {
    Add => json_add(left, right)
    Subtract => json_subtract(left, right)
    Multiply => json_multiply(left, right)
    Divide => json_divide(left, right)
    Modulo => json_modulo(left, right)
    Equal => Json::boolean(compare_json(left, right) == 0)
    NotEqual => Json::boolean(compare_json(left, right) != 0)
    LessThan => Json::boolean(compare_json(left, right) < 0)
    LessEq => Json::boolean(compare_json(left, right) <= 0)
    GreaterThan => Json::boolean(compare_json(left, right) > 0)
    GreaterEq => Json::boolean(compare_json(left, right) >= 0)
    And => if is_truthy(left) { right } else { Json::boolean(false) }
    Or => if is_truthy(left) { left } else { right }
  }
}

///|
/// Arithmetic operations
fn json_add(left : Json, right : Json) -> Json raise InterpreterError {
  match (left, right) {
    // null is the identity for `+` in jq.
    (Null, other) | (other, Null) => other
    (Number(a, ..), Number(b, ..)) => Json::number(a + b)
    (String(a), String(b)) => Json::string(a + b)
    (Array(a), Array(b)) => Json::array(a + b)
    (Object(a), Object(b)) => Json::object(a.merge(b))
    _ =>
      raise InvalidOperation(
        "Cannot add \{json_type_name(left)} and \{json_type_name(right)}",
      )
  }
}

///|
fn json_subtract(left : Json, right : Json) -> Json raise InterpreterError {
  match (left, right) {
    (Number(a, ..), Number(b, ..)) => Json::number(a - b)
    (Array(a), Array(b)) => Json::array(array_without(a, b))
    _ =>
      raise InvalidOperation(
        "Cannot subtract \{json_type_name(right)} from \{json_type_name(left)}",
      )
  }
}

///|
fn json_multiply(left : Json, right : Json) -> Json raise InterpreterError {
  match (left, right) {
    (Number(a, ..), Number(b, ..)) => Json::number(a * b)
    (String(s), Number(n, ..)) | (Number(n, ..), String(s)) => {
      let count = n.to_int()
      Json::string(repeat_string(s, count))
    }
    _ =>
      raise InvalidOperation(
        "Cannot multiply \{json_type_name(left)} and \{json_type_name(right)}",
      )
  }
}

///|
fn repeat_string(s : String, count : Int32) -> String {
  if count <= 0 {
    ""
  } else {
    let builder = StringBuilder()
    for _ in 0..<count {
      builder.write_string(s)
    }
    builder.to_string()
  }
}

///|
fn array_contains_compare(haystack : ArrayView[Json], needle : Json) -> Bool {
  haystack.iter().any(fn(value) { compare_json(value, needle) == 0 })
}

///|
fn array_without(
  source : ArrayView[Json],
  remove : ArrayView[Json],
) -> Array[Json] {
  source
  .iter()
  .filter(fn(value) { !array_contains_compare(remove, value) })
  .collect()
}

///|
fn json_divide(left : Json, right : Json) -> Json raise InterpreterError {
  match (left, right) {
    (Number(a, ..), Number(b, ..)) => {
      if b == 0.0 {
        raise DivisionByZero
      }
      Json::number(a / b)
    }
    _ =>
      raise InvalidOperation(
        "Cannot divide \{json_type_name(left)} by \{json_type_name(right)}",
      )
  }
}

///|
fn json_modulo(left : Json, right : Json) -> Json raise InterpreterError {
  match (left, right) {
    (Number(a, ..), Number(b, ..)) => {
      if b == 0.0 {
        raise DivisionByZero
      }
      Json::number(a % b)
    }
    _ =>
      raise InvalidOperation(
        "Cannot modulo \{json_type_name(left)} by \{json_type_name(right)}",
      )
  }
}
