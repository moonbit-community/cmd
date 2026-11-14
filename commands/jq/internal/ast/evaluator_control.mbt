///|
fn request_stream(
  request : Request,
  required~ : Bool = false,
  repeat~ : Bool = false,
) -> Stream {
  {
    empty: false,
    advance: () => {
      Request(request, result => {
        match result {
          Err(error) => Stream::failure(error)
          Ok(None) =>
            if required {
              Stream::failure(InputError("break"))
            } else {
              Stream::empty()
            }
          Ok(Some(value)) =>
            if repeat {
              Stream::one(value).append(() => {
                request_stream(request, repeat=true)
              })
            } else {
              Stream::one(value)
            }
        }
      })
    },
  }
}

///|
fn call_stream(
  name : String,
  args : Array[Expr],
  input : Json,
  caller : Env,
  run : (Expr, Json, Env) -> Stream,
) -> Stream {
  if args.is_empty() && caller.filters.get(name) is Some((expr, scope)) {
    return run(expr, input, scope)
  }
  if caller.functions.get(function_key(name, args.length())) is Some(closure) {
    fn bind(position : Int32, scope : Env) -> Stream {
      if position == args.length() {
        return run(closure.body, input, scope)
      }
      let param = closure.params[position]
      if param.has_prefix("$") {
        let variable = param[1:].to_owned()
        evaluate(args[position], input, caller).bind(value => {
          bind(position + 1, scope.set(variable, value))
        })
      } else {
        bind(position + 1, scope.with_filter(param, args[position], caller))
      }
    }
    return bind(0, closure.scope.with_closure(closure.name, closure))
  }
  match (name, args) {
    ("input", []) => request_stream(Input, required=true)
    ("inputs", []) => request_stream(Input, repeat=true)
    ("input_filename", []) => request_stream(InputFilename)
    ("input_line_number", []) => request_stream(InputLineNumber)
    ("modulemeta", []) =>
      match input {
        String(name) => request_stream(ModuleMetadata(name))
        _ => Stream::failure(TypeMismatch("string", json_type_name(input)))
      }
    ("error", []) =>
      Stream::failure(
        EvalError(
          match input {
            String(s) => s
            _ => input.stringify()
          },
        ),
      )
    ("error", [message]) =>
      evaluate(message, input, caller).bind(value => {
        call_stream("error", [], value, caller, run)
      })
    _ => Stream::failure(EvalError("Undefined function: \{name}"))
  }
}

///|
fn alternative_stream(
  source : Stream,
  fallback : () -> Stream,
  found : Bool,
) -> Stream {
  {
    empty: false,
    advance: () => {
      match (source.advance)() {
        Done => if found { Done } else { Continue(fallback()) }
        Yield(value, next) =>
          if is_truthy(value) {
            Yield(value, alternative_stream(next, fallback, true))
          } else {
            Continue(alternative_stream(next, fallback, found))
          }
        Request(request, advance) =>
          Request(request, result => {
            alternative_stream(advance(result), fallback, found)
          })
        Failed(error) => Failed(error)
        Continue(next) => Continue(alternative_stream(next, fallback, found))
      }
    },
  }
}

///|
fn last_stream(source : Stream, last : Json?) -> Stream {
  {
    empty: false,
    advance: () => {
      match (source.advance)() {
        Done =>
          match last {
            Some(value) => Yield(value, Stream::empty())
            None => Done
          }
        Yield(value, next) => Continue(last_stream(next, Some(value)))
        Request(request, advance) =>
          Request(request, result => last_stream(advance(result), last))
        Failed(error) => Failed(error)
        Continue(next) => Continue(last_stream(next, last))
      }
    },
  }
}

///|
fn predicate_stream(source : Stream, all : Bool) -> Stream {
  {
    empty: false,
    advance: () => {
      match (source.advance)() {
        Done => Yield(Json::boolean(all), Stream::empty())
        Yield(value, next) =>
          if is_truthy(value) != all {
            Yield(Json::boolean(!all), Stream::empty())
          } else {
            Continue(predicate_stream(next, all))
          }
        Request(request, advance) =>
          Request(request, result => predicate_stream(advance(result), all))
        Failed(error) => Failed(error)
        Continue(next) => Continue(predicate_stream(next, all))
      }
    },
  }
}

///|
fn fold_stream(
  source : Stream,
  name : String,
  update : Expr,
  extract : Expr?,
  accumulator : Json,
  env : Env,
  each : Bool,
) -> Stream {
  {
    empty: false,
    advance: () => {
      match (source.advance)() {
        Done => if each { Done } else { Yield(accumulator, Stream::empty()) }
        Yield(item, next) => {
          let scope = env.set(name, item)
          Continue(
            fold_update(
              evaluate(update, accumulator, scope),
              next,
              name,
              update,
              extract,
              null,
              scope,
              env,
              each,
            ),
          )
        }
        Request(request, advance) =>
          Request(request, result => {
            fold_stream(
              advance(result),
              name,
              update,
              extract,
              accumulator,
              env,
              each,
            )
          })
        Failed(error) => Failed(error)
        Continue(next) =>
          Continue(
            fold_stream(next, name, update, extract, accumulator, env, each),
          )
      }
    },
  }
}

///|
/// The last update result becomes the next accumulator, including null when
/// the update is empty. Extract outputs never replace the accumulator.
fn fold_update(
  current : Stream,
  source : Stream,
  name : String,
  update : Expr,
  extract : Expr?,
  last : Json,
  scope : Env,
  env : Env,
  each : Bool,
) -> Stream {
  {
    empty: false,
    advance: () => {
      match (current.advance)() {
        Done =>
          Continue(fold_stream(source, name, update, extract, last, env, each))
        Yield(value, next) => {
          let rest = () => {
            fold_update(
              next, source, name, update, extract, value, scope, env, each,
            )
          }
          Continue(
            if each {
              evaluate(extract.unwrap_or(Identity), value, scope).append(rest)
            } else {
              rest()
            },
          )
        }
        Request(request, advance) =>
          Request(request, result => {
            fold_update(
              advance(result),
              source,
              name,
              update,
              extract,
              last,
              scope,
              env,
              each,
            )
          })
        Failed(error) => Failed(error)
        Continue(next) =>
          Continue(
            fold_update(
              next, source, name, update, extract, last, scope, env, each,
            ),
          )
      }
    },
  }
}

///|
fn object_stream(
  pairs : Array[(Expr, Expr?)],
  index : Int32,
  fields : Map[String, Json],
  input : Json,
  env : Env,
) -> Stream {
  if index == pairs.length() {
    return Stream::one(Json::object(fields))
  }
  let (key, value) = pairs[index]
  evaluate(key, input, env).bind(key => {
    Stream::delay(() => {
      guard key is String(name) else {
        raise TypeMismatch("string", json_type_name(key))
      }
      evaluate(value.unwrap_or(Key(name)), input, env).bind(value => {
        let next = fields.copy()
        next[name] = value
        object_stream(pairs, index + 1, next, input, env)
      })
    })
  })
}

///|
fn interpolation_stream(
  parts : Array[(String, Expr?)],
  index : Int32,
  text : String,
  input : Json,
  env : Env,
) -> Stream {
  if index == parts.length() {
    return Stream::one(Json::string(text))
  }
  let (prefix, expression) = parts[index]
  match expression {
    None => interpolation_stream(parts, index + 1, text + prefix, input, env)
    Some(expr) =>
      evaluate(expr, input, env).bind(value => {
        let fragment = match value {
          String(value) => value
          _ => value.stringify()
        }
        interpolation_stream(
          parts,
          index + 1,
          text + prefix + fragment,
          input,
          env,
        )
      })
  }
}

///|
fn range_stream(start : Json, end : Json, stride : Json) -> Stream {
  Stream::delay(() => {
    guard (start, end, stride)
      is (Number(a, ..), Number(b, ..), Number(step, ..)) else {
      raise TypeMismatch("numbers", "non-numbers")
    }
    if (step > 0 && a < b) || (step < 0 && a > b) {
      Stream::one(start).append(() => {
        range_stream(Json::number(a + step), end, stride)
      })
    } else {
      Stream::empty()
    }
  })
}
