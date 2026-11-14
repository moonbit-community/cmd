///|
// Adapted from MoonJQ 0.2.0 for local ownership and current syntax.
// See ../../THIRD_PARTY_NOTICES.md for source and license information.

///|
/// Parse primary expressions
fn Parser::parse_primary(self : Parser) -> @ast.Expr raise ParseError {
  match self.current() {
    Some(TNull) => {
      self.advance()
      Literal(Null)
    }
    Some(TTrue) => {
      self.advance()
      Literal(Bool(true))
    }
    Some(TFalse) => {
      self.advance()
      Literal(Bool(false))
    }
    Some(TNumber(n)) => {
      self.advance()
      Literal(Number(n))
    }
    Some(TString(s)) => {
      self.advance()
      Literal(String(s))
    }
    Some(TStringInterpolation(parts)) => {
      let offsets = self.interpolations.get(self.pos).unwrap_or([])
      let mut expression_index = 0
      self.advance()
      let parsed_parts : Array[(String, @ast.Expr?)] = []
      for pair in parts {
        let (text, expr_opt) = pair
        match expr_opt {
          Some(expr_str) => {
            let (expr_tokens, positions, nested) = lex_positions(expr_str) catch {
              _ => raise InvalidExpression("Failed to parse interpolation")
            }
            let expr_parser = Parser::new(expr_tokens)
            expr_parser.functions = self.functions.copy()
            if offsets.get(expression_index) is Some(offset) {
              expr_parser.positions = positions.map(position => {
                position + offset
              })
              for token, positions in nested {
                expr_parser.interpolations[token] = positions.map(position => {
                  position + offset
                })
              }
            }
            expression_index += 1
            let expr = expr_parser.parse_pipe()
            expr_parser.expect(TEof)
            parsed_parts.push((text, Some(expr)))
          }
          None => parsed_parts.push((text, None))
        }
      }
      StringInterpolation(parsed_parts)
    }
    Some(TDotDot) => {
      self.advance()
      Recurse
    }
    Some(TDot) => {
      self.advance()
      match self.current() {
        Some(TIdentifier(name)) => {
          self.advance()
          Key(name)
        }
        Some(TString(name)) => {
          // ."key"
          self.advance()
          Key(name)
        }
        Some(TLBracket) => {
          self.advance()
          self.parse_index_or_slice(Identity)
        }
        _ => Identity
      }
    }
    Some(TVariable(name)) => {
      let position = self.positions.get(self.pos)
      self.advance()
      match position {
        Some(position) => At(Variable(name), position)
        None => Variable(name)
      }
    }
    Some(TFormat(name)) => {
      self.advance()
      Format(name)
    }
    Some(TLParen) => {
      self.advance()
      let expr = self.parse_pipe()
      self.expect(TRParen)
      expr
    }
    Some(TLBracket) => {
      self.advance()
      if self.consume(TRBracket) {
        ArrayConstruct(None)
      } else {
        let expr = self.parse_pipe()
        self.expect(TRBracket)
        ArrayConstruct(Some(expr))
      }
    }
    Some(TLBrace) => {
      self.advance()
      self.parse_object()
    }
    Some(TIf) => self.parse_if()
    Some(TTry) => self.parse_try()
    Some(TReduce) => self.parse_reduce()
    Some(TForeach) => self.parse_foreach()
    Some(TIdentifier(name)) => {
      let position = self.positions.get(self.pos)
      self.advance()
      let expr = self.parse_builtin(name)
      match position {
        Some(position) => At(expr, position)
        None => expr
      }
    }
    Some(t) => raise UnexpectedToken(t.to_string(), "expression")
    None => raise UnexpectedEnd("expression")
  }
}
