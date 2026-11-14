///|
/// Each extension creates a lexical scope; closures retain their defining scope.
pub struct Env {
  bindings : Map[String, Json]
  functions : Map[String, Closure]
  filters : Map[String, (Expr, Env)]
  source : String
}

///|
pub struct Closure {
  name : String
  body : Expr
  params : Array[String]
  scope : Env
  checking : Ref[Bool]
}

///|
pub fn Env::new() -> Env {
  {
    bindings: Map([]),
    functions: Map([]),
    filters: Map([]),
    source: "<top-level>",
  }
}

///|
fn function_key(name : String, arity : Int32) -> String {
  "\{name}/\{arity}"
}

///|
pub fn Env::get(self : Env, name : String) -> Json? {
  self.bindings.get(name)
}

///|
pub fn Env::set(self : Env, name : String, value : Json) -> Env {
  let bindings = self.bindings.copy()
  bindings[name] = value
  { ..self, bindings, }
}

///|
fn Env::with_closure(self : Env, name : String, closure : Closure) -> Env {
  let functions = self.functions.copy()
  functions[function_key(name, closure.params.length())] = closure
  let filters = if closure.params.is_empty() {
    let filters = self.filters.copy()
    filters.remove(name)
    filters
  } else {
    self.filters
  }
  { ..self, functions, filters, }
}

///|
pub fn Env::set_function(
  self : Env,
  name : String,
  body : Expr,
  params : Array[String],
) -> Env {
  self.with_closure(name, {
    name,
    body,
    params,
    scope: self,
    checking: Ref(false),
  })
}

///|
fn Env::with_filter(self : Env, name : String, expr : Expr, scope : Env) -> Env {
  let filters = self.filters.copy()
  filters[name] = (expr, scope)
  { ..self, filters, }
}

///|
pub fn Env::import_functions(
  self : Env,
  imported : Env,
  names : Array[(String, Int32)],
  prefix_opt : String?,
) -> Env {
  let functions = self.functions.copy()
  let filters = self.filters.copy()
  for (name, arity) in names {
    if imported.functions.get(function_key(name, arity)) is Some(closure) {
      let exported = match prefix_opt {
        Some(prefix) => prefix + "::" + name
        None => name
      }
      functions[function_key(exported, arity)] = closure
      if arity == 0 {
        filters.remove(exported)
      }
    }
  }
  { ..self, functions, filters, }
}

///|
pub fn Env::has_function(self : Env, name : String, arity : Int32) -> Bool {
  self.functions.contains(function_key(name, arity)) ||
  (arity == 0 && self.filters.contains(name))
}

///|
pub fn Env::with_source(self : Env, source : String) -> Env {
  { ..self, source, }
}
