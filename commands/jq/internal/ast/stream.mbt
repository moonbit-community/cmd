///|
/// External effects suspend evaluation without replaying completed filters.
pub(all) enum Request {
  Input
  InputFilename
  InputLineNumber
  ModuleMetadata(String)
}

///|
pub(all) enum Step {
  Done
  Yield(Json, Stream)
  Request(Request, (Result[Json?, InterpreterError]) -> Stream)
  Failed(InterpreterError)
  Continue(Stream)
}

///|
pub struct Stream {
  advance : () -> Step
  empty : Bool
}

///|
pub fn Stream::step(self : Stream) -> Step {
  for current = self {
    match (current.advance)() {
      Continue(next) => continue next
      step => break step
    }
  }
}

///|
fn Stream::empty() -> Stream {
  { advance: () => Done, empty: true, }
}

///|
fn Stream::one(value : Json) -> Stream {
  { advance: () => Yield(value, Stream::empty()), empty: false, }
}

///|
fn Stream::failure(error : InterpreterError) -> Stream {
  { advance: () => Failed(error), empty: false, }
}

///|
fn Stream::delay(action : () -> Stream raise InterpreterError) -> Stream {
  {
    empty: false,
    advance: () => Continue(action()) catch { error => Failed(error) },
  }
}

///|
fn Stream::values(values : Array[Json], position~ : Int32 = 0) -> Stream {
  if position >= values.length() {
    return Stream::empty()
  }
  {
    empty: false,
    advance: () => {
      if position < values.length() {
        Yield(values[position], Stream::values(values, position=position + 1))
      } else {
        Done
      }
    },
  }
}

///|
fn Stream::append(self : Stream, tail : () -> Stream) -> Stream {
  if self.empty {
    return Stream::delay(() => tail())
  }
  {
    empty: false,
    advance: () => {
      match (self.advance)() {
        Done => Continue(tail())
        Yield(value, next) => Yield(value, next.append(tail))
        Request(request, advance) =>
          Request(request, result => advance(result).append(tail))
        Failed(error) => Failed(error)
        Continue(next) => Continue(next.append(tail))
      }
    },
  }
}

///|
fn Stream::bind(self : Stream, action : (Json) -> Stream) -> Stream {
  if self.empty {
    return self
  }
  {
    empty: false,
    advance: () => {
      match (self.advance)() {
        Done => Done
        Yield(value, next) =>
          Continue(
            if next.empty {
              action(value)
            } else {
              action(value).append(() => next.bind(action))
            },
          )
        Request(request, advance) =>
          Request(request, result => advance(result).bind(action))
        Failed(error) => Failed(error)
        Continue(next) => Continue(next.bind(action))
      }
    },
  }
}

///|
fn Stream::map(
  self : Stream,
  action : (Json) -> Json raise InterpreterError,
) -> Stream {
  self.bind(value => Stream::delay(() => Stream::one(action(value))))
}

///|
fn Stream::take(self : Stream, count : Int32) -> Stream {
  if count <= 0 || self.empty {
    return Stream::empty()
  }
  {
    empty: false,
    advance: () => {
      match (self.advance)() {
        Done => Done
        Yield(value, next) => Yield(value, next.take(count - 1))
        Request(request, advance) =>
          Request(request, result => advance(result).take(count))
        Failed(error) => Failed(error)
        Continue(next) => Continue(next.take(count))
      }
    },
  }
}

///|
fn Stream::gather(self : Stream) -> Stream {
  fn collect(current : Stream, values : Array[Json]) -> Stream {
    {
      empty: false,
      advance: () => {
        match (current.advance)() {
          Done => Yield(Json::array(values), Stream::empty())
          Yield(value, next) => {
            values.push(value)
            Continue(collect(next, values))
          }
          Request(request, advance) =>
            Request(request, result => collect(advance(result), values))
          Failed(error) => Failed(error)
          Continue(next) => Continue(collect(next, values))
        }
      },
    }
  }
  collect(self, [])
}

///|
fn Stream::recover(
  self : Stream,
  handler : (InterpreterError) -> Stream,
) -> Stream {
  if self.empty {
    return self
  }
  {
    empty: false,
    advance: () => {
      match (self.advance)() {
        Done => Done
        Yield(value, next) => Yield(value, next.recover(handler))
        Request(request, advance) =>
          Request(request, result => advance(result).recover(handler))
        Failed(error) => Continue(handler(error))
        Continue(next) => Continue(next.recover(handler))
      }
    },
  }
}
