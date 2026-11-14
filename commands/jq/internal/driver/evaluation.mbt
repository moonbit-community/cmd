///|
fn json_space(byte : Byte) -> Bool {
  byte is (b' ' | b'\t' | b'\r' | b'\n')
}

///|
async fn StreamInput::next_json(self : StreamInput) -> Json? {
  let mut value : Json = null
  let mut found = false
  while self.next_event(
          open_container=Some((path, object) => {
            // A repeated key starts a new value, even when its next leaves share a path.
            value = assemble(
              value,
              path,
              if object {
                Json::object(Map([]))
              } else {
                Json::array([])
              },
            )
          }),
        )
        is Some(event) {
    if event is Array([Array(path), leaf]) {
      value = assemble(value, path, leaf)
      found = true
    }
    if found && self.frames.is_empty() && self.ready.is_empty() {
      return Some(value)
    }
  }
  None
}

///|
priv struct Evaluation {
  query : @ast.Expr
  scope : @ast.Env
  cursor : InputCursor
  modules : Modules
  options : CliOptions
  colors : Array[String]?
  mut last : Json?
}

///|
async fn Evaluation::emit(self : Evaluation, input : Json) -> Unit {
  let options = self.options
  consume(
    @ast.evaluate(self.query, input, self.scope),
    request => {
      match request {
        ModuleMetadata(name) =>
          Ok(
            Some(
              self.modules.metadata(name, message => {
                @stdio.stderr.write(message)
              }),
            ),
          ) catch {
            ModuleError(message) => Err(@ast.EvalError(message))
            error => raise error
          }
        _ => self.cursor.request(request)
      }
    },
    value => {
      self.last = write_results(
        Iter::singleton(value),
        options.raw_output || options.join_output,
        options.compact_output,
        options.join_output,
        options.sort_keys,
        options.indent,
        options.tab,
        self.colors,
      )
    },
  )
}

///|
async fn consume(
  stream : @ast.Stream,
  request : async (@ast.Request) -> Result[Json?, @ast.InterpreterError],
  emit : async (Json) -> Unit,
) -> Unit {
  for current = stream {
    match current.step() {
      Done => break
      Yield(value, next) => {
        emit(value)
        continue next
      }
      Request(effect, advance) => continue advance(request(effect))
      Failed(error) => raise error
      Continue(_) => abort("step must resolve continuations")
    }
  }
}
