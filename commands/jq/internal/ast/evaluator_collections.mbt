///|
fn order_stream(
  operation : Expr,
  key : Expr,
  input : Json,
  env : Env,
) -> Stream {
  Stream::delay(() => {
    guard input is Array(items) else {
      raise TypeMismatch("array", json_type_name(input))
    }
    Stream::values(items)
    .bind(value => {
      evaluate(key, value, env).gather().map(keys => Json::array([keys, value]))
    })
    .gather()
    .map(pairs => {
      guard pairs is Array(pairs) else { return null }
      pairs.sort_by((a, b) => {
        match (a, b) {
          (Array([ka, _]), Array([kb, _])) => compare_json(ka, kb)
          _ => 0
        }
      })
      let values : Array[Json] = []
      let groups : Array[Json] = []
      let mut last : Json? = None
      let mut group : Array[Json] = []
      for pair in pairs {
        guard pair is Array([key, value]) else { continue }
        values.push(value)
        if last != Some(key) {
          if !group.is_empty() {
            groups.push(Json::array(group))
          }
          group = []
        }
        group.push(value)
        last = Some(key)
      }
      if !group.is_empty() {
        groups.push(Json::array(group))
      }
      match operation {
        MinBy(_) => values.get(0).unwrap_or(null)
        MaxBy(_) => values.last().unwrap_or(null)
        GroupBy(_) => Json::array(groups)
        UniqueBy(_) =>
          Json::array(
            groups.map(group => {
              match group {
                Array([head, ..]) => head
                _ => null
              }
            }),
          )
        _ => Json::array(values)
      }
    })
  })
}

///|
fn walk_stream(filter : Expr, input : Json, env : Env) -> Stream {
  match input {
    Array(items) =>
      Stream::values(items)
      .bind(value => walk_stream(filter, value, env))
      .gather()
      .bind(value => evaluate(filter, value, env))
    Object(fields) => {
      let pairs = fields.to_array()
      fn visit(index : Int32, result : Map[String, Json]) -> Stream {
        if index == pairs.length() {
          return evaluate(filter, Json::object(result), env)
        }
        let (key, value) = pairs[index]
        walk_stream(filter, value, env).bind(value => {
          let next = result.copy()
          next[key] = value
          visit(index + 1, next)
        })
      }
      visit(0, Map([]))
    }
    _ => evaluate(filter, input, env)
  }
}
