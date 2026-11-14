///|
/// Path tracking uses the same suspended stream and lexical closures as values.
fn path_stream(expr : Expr, input : Json, env : Env) -> Stream {
  path_entries_stream(expr, input, env).map(entry => {
    guard entry is Array([Array(path), _]) else {
      raise InvalidOperation(invalid_path_expression)
    }
    Json::array(path)
  })
}

///|
let invalid_path_expression : String = "Invalid path expression"

///|
fn path_entries_stream(expr : Expr, input : Json, env : Env) -> Stream {
  tracked_stream(expr, input, env, true)
}

///|
fn path_entry(path : Array[Json]?, value : Json) -> Json {
  Json::array([
    match path {
      Some(path) => Json::array(path)
      None => null
    },
    value,
  ])
}

///|
fn tracked_stream(
  expr : Expr,
  input : Json,
  env : Env,
  tracked : Bool,
) -> Stream {
  Stream::delay(() => {
    let here : Array[Json]? = if tracked { Some([]) } else { None }
    if !tracked && expr is (Recurse | Key(_) | Index(_) | First | Last) {
      raise InvalidOperation(invalid_path_expression)
    }
    match expr {
      At(inner, _) => tracked_stream(inner, input, env, tracked)
      BuiltinCall(name, args, body) =>
        if env.has_function(name, args.length()) {
          call_stream(name, args, input, env, (body, value, scope) => {
            tracked_stream(body, value, scope, tracked)
          })
        } else {
          tracked_stream(body, input, env, tracked)
        }
      Identity => Stream::one(path_entry(here, input))
      Key(key) =>
        Stream::one(
          path_entry(
            Some([Json::string(key)]),
            match input {
              Object(fields) => fields.get(key).unwrap_or(null)
              _ => null
            },
          ),
        )
      Index([]) =>
        match input {
          Array(items) =>
            Stream::values(
              items.mapi((i, v) => {
                path_entry(Some([Json::number(i.to_double())]), v)
              }),
            )
          Object(fields) =>
            Stream::values(
              fields
              .iter()
              .map(pair => path_entry(Some([Json::string(pair.0)]), pair.1))
              .collect(),
            )
          _ => Stream::empty()
        }
      Index(indices) => {
        let values = eval_index_access(indices, input).collect()
        Stream::values(
          indices.mapi((i, index) => {
            path_entry(Some([Json::number(index.to_double())]), values[i])
          }),
        )
      }
      First | Last => {
        guard input is (Array(_) | Null) else {
          raise TypeMismatch("array", json_type_name(input))
        }
        let index = if expr == First { 0 } else { -1 }
        let path = [Json::number(index.to_double())]
        Stream::one(
          path_entry(Some(path), get_at_path(input, path).unwrap_or(null)),
        )
      }
      Recurse =>
        Stream::values(
          recurse_path_values(input).map(pair => {
            path_entry(Some(pair.0), pair.1)
          }),
        )
      Empty => Stream::empty()
      Pipe(FunctionDef(name, params, body), right) =>
        tracked_stream(
          right,
          input,
          env.set_function(name, body, params),
          tracked,
        )
      Pipe(left, right) =>
        tracked_stream(left, input, env, tracked).bind(entry => {
          guard entry is Array([prefix, value]) else { return Stream::empty() }
          tracked_stream(right, value, env, prefix is Array(_)).map(inner => {
            guard inner is Array([suffix, value]) else {
              raise InvalidOperation(invalid_path_expression)
            }
            let path = match (prefix, suffix) {
              (Array(a), Array(b)) => Some(a + b)
              _ => None
            }
            path_entry(path, value)
          })
        })
      Comma(left, right) =>
        tracked_stream(left, input, env, tracked).append(() => {
          tracked_stream(right, input, env, tracked)
        })
      Optional(inner) =>
        tracked_stream(inner, input, env, tracked).recover(_ => Stream::empty())
      FirstGen(inner) => tracked_stream(inner, input, env, tracked).take(1)
      Select(condition) =>
        evaluate(condition, input, env).bind(value => {
          if is_truthy(value) {
            Stream::one(path_entry(here, input))
          } else {
            Stream::empty()
          }
        })
      IfThenElse(condition, yes, no) =>
        evaluate(condition, input, env).bind(value => {
          tracked_stream(
            if is_truthy(value) {
              yes
            } else {
              no
            },
            input,
            env,
            tracked,
          )
        })
      Alternative(left, right) =>
        path_alternative(
          tracked_stream(left, input, env, tracked),
          () => tracked_stream(right, input, env, tracked),
          false,
        )
      GetPath(path) =>
        evaluate(path, input, env).map(path => {
          guard path is Array(segments) else {
            raise InvalidOperation("Path must be specified as an array")
          }
          if !tracked && !segments.is_empty() {
            raise InvalidOperation(invalid_path_expression)
          }
          path_entry(
            if tracked {
              Some(segments)
            } else {
              None
            },
            get_at_path(input, segments).unwrap_or(null),
          )
        })
      As(source, name, body) =>
        evaluate(source, input, env).bind(value => {
          tracked_stream(body, input, env.set(name, value), tracked)
        })
      FunctionCall(name, args) if env.has_function(name, args.length()) =>
        call_stream(name, args, input, env, (body, value, scope) => {
          tracked_stream(body, value, scope, tracked)
        })
      _ => evaluate(expr, input, env).map(value => path_entry(None, value))
    }
  })
}

///|
fn path_alternative(
  source : Stream,
  fallback : () -> Stream,
  found : Bool,
) -> Stream {
  {
    empty: false,
    advance: () => {
      match (source.advance)() {
        Done => if found { Done } else { Continue(fallback()) }
        Yield(entry, next) =>
          if entry is Array([_, value]) && is_truthy(value) {
            Yield(entry, path_alternative(next, fallback, true))
          } else {
            Continue(path_alternative(next, fallback, found))
          }
        Request(request, advance) =>
          Request(request, result => {
            path_alternative(advance(result), fallback, found)
          })
        Failed(error) => Failed(error)
        Continue(next) => Continue(path_alternative(next, fallback, found))
      }
    },
  }
}

///|
fn get_path_value(input : Json, path : Json) -> Json {
  match path {
    Array(segments) => get_at_path(input, segments).unwrap_or(null)
    _ => null
  }
}

///|
fn assign_paths(
  input : Json,
  paths : Json,
  value : Json,
) -> Json raise InterpreterError {
  guard paths is Array(paths) else { return input }
  for path in paths; current = input {
    guard path is Array(segments) else { continue current }
    continue set_at_path(current, segments, value)
  } nobreak {
    current
  }
}

///|
fn update_paths(
  paths : Json,
  index : Int32,
  input : Json,
  removed : Array[Array[Json]],
  update : Expr,
  env : Env,
) -> Stream {
  Stream::delay(() => {
    guard paths is Array(items) else { return Stream::one(input) }
    if index == items.length() {
      return Stream::one(delete_paths(input, removed.map(p => p)))
    }
    guard items[index] is Array(path) else {
      raise InvalidOperation(invalid_path_expression)
    }
    evaluate(update, get_at_path(input, path).unwrap_or(null), env)
    .take(1)
    .gather()
    .bind(values => {
      Stream::delay(() => {
        match values {
          Array([value]) =>
            update_paths(
              paths,
              index + 1,
              set_at_path(input, path, value),
              removed,
              update,
              env,
            )
          _ =>
            update_paths(paths, index + 1, input, removed + [path], update, env)
        }
      })
    })
  })
}

///|
fn compound_stream(
  path : Expr,
  op : BinaryOp,
  value : Expr,
  input : Json,
  env : Env,
) -> Stream {
  evaluate(value, input, env).bind(value => {
    evaluate(Update(path, Operation(Identity, op, Constant(value))), input, env)
  })
}

///|
fn recurse_path_values(input : Json) -> Array[(Array[Json], Json)] {
  let out : Array[(Array[Json], Json)] = []
  fn visit(prefix : Array[Json], value : Json) -> Unit {
    out.push((prefix, value))
    match value {
      Array(items) =>
        for i, value in items {
          visit(prefix + [Json::number(i.to_double())], value)
        }
      Object(fields) =>
        for key, value in fields {
          visit(prefix + [Json::string(key)], value)
        }
      _ => ()
    }
  }
  visit([], input)
  out
}
