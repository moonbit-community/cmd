///|
/// Synchronous consumers use the same machine with an exhausted input source.
pub fn eval(expr : Expr, input : Json) -> Iter[Json] raise {
  eval_with_env(expr, input, Env::new())
}

///|
fn eval_with_env(
  expr : Expr,
  input : Json,
  env : Env,
) -> Iter[Json] raise InterpreterError {
  let values : Array[Json] = []
  for current = evaluate(expr, input, env) {
    match current.step() {
      Done => break values.iter()
      Yield(value, next) => {
        values.push(value)
        continue next
      }
      Request(_, advance) => continue advance(Ok(None))
      Failed(error) => raise error
      Continue(_) => abort("step must resolve continuations")
    }
  }
}

///|
/// Constructing a filter never reads input or evaluates a user function.
pub fn evaluate(expr : Expr, input : Json, env : Env) -> Stream {
  Stream::delay(() => evaluate_step(expr, input, env))
}

///|
fn evaluate_step(
  expr : Expr,
  input : Json,
  env : Env,
) -> Stream raise InterpreterError {
  match expr {
    At(inner, _) => evaluate(inner, input, env)
    BuiltinCall(name, args, body) =>
      if env.has_function(name, args.length()) {
        call_stream(name, args, input, env, evaluate)
      } else {
        evaluate(body, input, env)
      }
    Constant(value) => Stream::one(value)
    Pipe(FunctionDef(name, params, body), right) =>
      evaluate(right, input, env.set_function(name, body, params))
    Pipe(left, right) =>
      evaluate(left, input, env).bind(value => evaluate(right, value, env))
    Comma(left, right) =>
      evaluate(left, input, env).append(() => evaluate(right, input, env))
    Optional(inner) => evaluate(inner, input, env).recover(_ => Stream::empty())
    ArrayConstruct(None) => Stream::one(Json::array([]))
    ArrayConstruct(Some(inner)) => evaluate(inner, input, env).gather()
    ObjectConstruct(pairs) => object_stream(pairs, 0, Map([]), input, env)
    Operation(left, And, right) =>
      evaluate(left, input, env).bind(a => {
        if is_truthy(a) {
          evaluate(right, input, env).map(b => Json::boolean(is_truthy(b)))
        } else {
          Stream::one(false)
        }
      })
    Operation(left, Or, right) =>
      evaluate(left, input, env).bind(a => {
        if is_truthy(a) {
          Stream::one(true)
        } else {
          evaluate(right, input, env).map(b => Json::boolean(is_truthy(b)))
        }
      })
    // jq evaluates the right operand first, retaining it across left outputs.
    Operation(left, op, right) =>
      evaluate(right, input, env).bind(b => {
        evaluate(left, input, env).map(a => eval_binary_op(op, a, b))
      })
    Map(inner) => {
      guard input is (Array(_) | Object(_)) else {
        raise TypeMismatch("array", json_type_name(input))
      }
      evaluate(Pipe(Index([]), inner), input, env).gather()
    }
    Select(condition) =>
      evaluate(condition, input, env).bind(value => {
        if is_truthy(value) {
          Stream::one(input)
        } else {
          Stream::empty()
        }
      })
    IfThenElse(condition, yes, no) =>
      evaluate(condition, input, env).bind(value => {
        evaluate(if is_truthy(value) { yes } else { no }, input, env)
      })
    TryCatch(body, handler) =>
      evaluate(body, input, env).recover(error => {
        match handler {
          Some(handler) => evaluate(handler, Json::string(error.message()), env)
          None => Stream::empty()
        }
      })
    Alternative(left, right) =>
      alternative_stream(
        evaluate(left, input, env),
        () => evaluate(right, input, env),
        false,
      )
    Variable(name) =>
      match env.get(name) {
        Some(value) => Stream::one(value)
        None =>
          Stream::failure(InvalidOperation("Undefined variable: $\{name}"))
      }
    As(source, name, body) =>
      evaluate(source, input, env).bind(value => {
        evaluate(body, input, env.set(name, value))
      })
    FunctionDef(_, _, _) => Stream::one(input)
    FunctionCall(name, args) => call_stream(name, args, input, env, evaluate)
    FirstGen(source) => evaluate(source, input, env).take(1)
    LastGen(source) => last_stream(evaluate(source, input, env), None)
    Limit(count, source) => evaluate(source, input, env).take(count)
    Repeat(source) =>
      evaluate(source, input, env).append(() => {
        evaluate(Repeat(source), input, env)
      })
    AnyGen(source, condition) =>
      predicate_stream(
        evaluate(source, input, env).bind(value => {
          evaluate(condition, value, env)
        }),
        false,
      )
    AllGen(source, condition) =>
      predicate_stream(
        evaluate(source, input, env).bind(value => {
          evaluate(condition, value, env)
        }),
        true,
      )
    Reduce(source, name, initial, update) =>
      evaluate(initial, input, env).bind(value => {
        fold_stream(
          evaluate(source, input, env),
          name,
          update,
          None,
          value,
          env,
          false,
        )
      })
    Foreach(source, name, initial, update, extract) =>
      evaluate(initial, input, env).bind(value => {
        fold_stream(
          evaluate(source, input, env),
          name,
          update,
          extract,
          value,
          env,
          true,
        )
      })
    While(condition, update) =>
      evaluate(condition, input, env).bind(value => {
        if is_truthy(value) {
          Stream::one(input).append(() => {
            evaluate(update, input, env).bind(next => evaluate(expr, next, env))
          })
        } else {
          Stream::empty()
        }
      })
    Until(condition, update) =>
      evaluate(condition, input, env).bind(value => {
        if is_truthy(value) {
          Stream::one(input)
        } else {
          evaluate(update, input, env).bind(next => evaluate(expr, next, env))
        }
      })
    StringInterpolation(parts) => interpolation_stream(parts, 0, "", input, env)
    Assign(path, value) =>
      evaluate(value, input, env).bind(value => {
        path_stream(path, input, env)
        .gather()
        .map(paths => assign_paths(input, paths, value))
      })
    Update(path, update) =>
      path_stream(path, input, env)
      .gather()
      .bind(paths => update_paths(paths, 0, input, [], update, env))
    AddAssign(path, value) => compound_stream(path, Add, value, input, env)
    SubAssign(path, value) => compound_stream(path, Subtract, value, input, env)
    MulAssign(path, value) => compound_stream(path, Multiply, value, input, env)
    DivAssign(path, value) => compound_stream(path, Divide, value, input, env)
    ModAssign(path, value) => compound_stream(path, Modulo, value, input, env)
    AltAssign(path, value) =>
      evaluate(Update(path, Alternative(Identity, value)), input, env)
    Path(path) => path_stream(path, input, env)
    MapValues(inner) => {
      guard input is (Array(_) | Object(_)) else {
        raise TypeMismatch("object/array", json_type_name(input))
      }
      evaluate(Update(Index([]), inner), input, env)
    }
    WithEntries(inner) =>
      evaluate(Pipe(Pipe(ToEntries, Map(inner)), FromEntries), input, env)
    RecurseWith(child, condition) =>
      Stream::one(input).append(() => {
        evaluate(child, input, env).bind(value => {
          evaluate(condition, value, env).bind(accepted => {
            if is_truthy(accepted) {
              evaluate(expr, value, env)
            } else {
              Stream::empty()
            }
          })
        })
      })
    Walk(inner) => walk_stream(inner, input, env)
    PathsWithFilter(condition) =>
      Stream::values(eval_paths(input).collect()).bind(path => {
        evaluate(condition, get_path_value(input, path), env).bind(accepted => {
          if is_truthy(accepted) {
            Stream::one(path)
          } else {
            Stream::empty()
          }
        })
      })
    SortBy(key) | GroupBy(key) | UniqueBy(key) | MinBy(key) | MaxBy(key) =>
      order_stream(expr, key, input, env)
    RangeFromTo(from, to) =>
      evaluate(from, input, env).bind(a => {
        evaluate(to, input, env).bind(b => range_stream(a, b, Json::number(1)))
      })
    RangeWithStep(from, to, step) =>
      evaluate(from, input, env).bind(a => {
        evaluate(to, input, env).bind(b => {
          evaluate(step, input, env).bind(c => range_stream(a, b, c))
        })
      })
    SetPath(path, value) =>
      evaluate(path, input, env).bind(path => {
        evaluate(value, input, env).map(value => {
          guard path is Array(segments) else { return input }
          set_at_path(input, segments, value)
        })
      })
    GetPath(path) =>
      evaluate(path, input, env).map(path => get_path_value(input, path))
    DelPaths(paths) =>
      evaluate(paths, input, env).map(paths => {
        guard paths is Array(paths) else { return input }
        let segments : Array[Array[Json]] = []
        for path in paths {
          if path is Array(items) {
            segments.push(items)
          }
        }
        delete_paths(input, segments.map(p => p))
      })
    Contains(child) =>
      evaluate(child, input, env).bind(value => {
        atom_stream(() => eval_contains(Constant(value), input, env))
      })
    Inside(child) =>
      evaluate(child, input, env).bind(value => {
        atom_stream(() => eval_inside(Constant(value), input, env))
      })
    In(child) =>
      evaluate(child, input, env).bind(value => {
        atom_stream(() => eval_in(Constant(value), input, env))
      })
    IndicesOf(child) =>
      evaluate(child, input, env).bind(value => {
        atom_stream(() => eval_indices_of(Constant(value), input, env))
      })
    IndexOf(child) =>
      evaluate(child, input, env).bind(value => {
        atom_stream(() => eval_index_of(Constant(value), input, env))
      })
    RIndex(child) =>
      evaluate(child, input, env).bind(value => {
        atom_stream(() => eval_rindex(Constant(value), input, env))
      })
    Pow(child) =>
      evaluate(child, input, env).bind(value => {
        atom_stream(() => eval_pow(Constant(value), input, env))
      })
    _ => atom_stream(() => eval_atom(expr, input))
  }
}

///|
fn atom_stream(action : () -> Iter[Json] raise InterpreterError) -> Stream {
  Stream::delay(() => Stream::values(action().collect()))
}

///|
fn eval_atom(expr : Expr, input : Json) -> Iter[Json] raise InterpreterError {
  match expr {
    Identity => Iter::singleton(input)
    Literal(value) => Iter::singleton(eval_literal(value))
    Key(key) => eval_key_access(key, input)
    Index(indices) => eval_index_access(indices, input)
    Slice(start, end) => eval_slice_access(start, end, input)
    Length => eval_length(input)
    Keys => eval_keys(input)
    Values => eval_values(input)
    Type => eval_type(input)
    Empty => eval_empty()
    Not => eval_not(input)
    Sort => eval_sort(input)
    Reverse => eval_reverse(input)
    Flatten(depth) => eval_flatten(depth, input)
    Unique => eval_unique(input)
    Add => eval_add(input)
    Floor => eval_floor(input)
    Sqrt => eval_sqrt(input)
    Min => eval_min(input)
    Max => eval_max(input)
    Recurse => recurse_all(input)
    Format(name) => eval_format(name, input)
    Round => eval_round(input)
    Ceil => eval_ceil(input)
    Abs => eval_abs(input)
    Split(sep) => eval_split(sep, input)
    Join(sep) => eval_join(sep, input)
    StartsWith(prefix) => eval_starts_with(prefix, input)
    EndsWith(suffix) => eval_ends_with(suffix, input)
    Has(key) => eval_has(key, input)
    ToEntries => eval_to_entries(input)
    FromEntries => eval_from_entries(input)
    Range(n) => eval_range(n)
    First => eval_first(input)
    Last => eval_last(input)
    Any => eval_any(input)
    All => eval_all(input)
    LTrimStr(prefix) => eval_ltrim_str(prefix, input)
    RTrimStr(suffix) => eval_rtrim_str(suffix, input)
    AsciiUpcase => eval_ascii_upcase(input)
    AsciiDowncase => eval_ascii_downcase(input)
    Nth(n) => eval_nth(n, input)
    Paths => eval_paths(input)
    LeafPaths => eval_leaf_paths(input)
    Log => eval_log(input)
    Exp => eval_exp(input)
    Sin => eval_sin(input)
    Cos => eval_cos(input)
    Tan => eval_tan(input)
    Asin => eval_asin(input)
    Acos => eval_acos(input)
    Atan => eval_atan(input)
    Test(pattern) => eval_test(pattern, input)
    Match(pattern) => eval_match(pattern, input)
    Capture(pattern) => eval_capture(pattern, input)
    Splits(pattern) => eval_splits(pattern, input)
    Sub(pattern, replacement) => eval_sub(pattern, replacement, input)
    GSub(pattern, replacement) => eval_gsub(pattern, replacement, input)
    Explode => eval_explode(input)
    Implode => eval_implode(input)
    ToJsonString => eval_to_json_string(input)
    FromJsonString => eval_from_json_string(input)
    Combinations => eval_combinations(input)
    Transpose => eval_transpose(input)
    Scan(pattern) => eval_scan(pattern, input)
    _ => raise InvalidOperation("Expected an atomic filter")
  }
}
