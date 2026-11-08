///|
// The standalone utility gives one through four arguments explicit priority
// before its recursive expression grammar. Operator-looking strings therefore
// remain operands in cases such as `test -e` and `test -e = -e`.
async fn Parser::evaluate_count(self : Parser, count : Int32) -> Bool {
  match count {
    1 => self.take() != ""
    2 => {
      let first = self.take()
      if first == "!" {
        self.take() == ""
      } else if is_unary(first) {
        eval_unary(first, self.take())
      } else {
        raise TestError("unary operator expected: '\{first}'")
      }
    }
    3 => {
      guard self.args.get(self.pos + 1) is Some(middle) else {
        raise TestError("missing argument")
      }
      if is_binary(middle) {
        let left = self.take()
        ignore(self.take())
        eval_binary(left, middle, self.take())
      } else if self.peek() == Some("!") {
        ignore(self.take())
        !self.evaluate_count(2)
      } else if self.peek() == Some("(") &&
        self.args.get(self.pos + 2) == Some(")") {
        ignore(self.take())
        let result = self.take() != ""
        ignore(self.take())
        result
      } else if middle == "-a" || middle == "-o" {
        self.parse_or()
      } else {
        raise TestError("binary operator expected: '\{middle}'")
      }
    }
    4 if self.peek() == Some("!") => {
      ignore(self.take())
      !self.evaluate_count(3)
    }
    4 if self.peek() == Some("(") && self.args.get(self.pos + 3) == Some(")") => {
      ignore(self.take())
      let result = self.evaluate_count(2)
      ignore(self.take())
      result
    }
    _ => self.parse_or()
  }
}
