///|
/// The results of analyzing the AST of a regex (for smart case).
priv struct AstAnalysis {
  mut any_uppercase : Bool
  mut any_literal : Bool
}

///|
fn AstAnalysis::from_ast(ast : @syntax.Ast) -> AstAnalysis {
  let a = { any_uppercase: false, any_literal: false, }
  a.visit(ast)
  a
}

///|
fn AstAnalysis::done(self : AstAnalysis) -> Bool {
  self.any_uppercase && self.any_literal
}

///|
fn AstAnalysis::visit(self : AstAnalysis, ast : @syntax.Ast) -> Unit {
  if self.done() {
    return
  }
  match ast {
    Literal(x) => self.literal(x)
    ClassBracketed(x) => self.class_set(x.kind)
    Repetition(x) => self.visit(x.ast)
    Group(x) => self.visit(x.ast)
    Alternation(_, xs) | Concat(_, xs) =>
      for x in xs {
        self.visit(x)
      }
    _ => ()
  }
}

///|
fn AstAnalysis::class_set(self : AstAnalysis, set : @syntax.ClassSet) -> Unit {
  if self.done() {
    return
  }
  match set {
    Item(item) => self.class_set_item(item)
    BinaryOp(_, _, lhs, rhs) => {
      self.class_set(lhs)
      self.class_set(rhs)
    }
  }
}

///|
fn AstAnalysis::class_set_item(
  self : AstAnalysis,
  item : @syntax.ClassSetItem,
) -> Unit {
  if self.done() {
    return
  }
  match item {
    Literal(x) => self.literal(x)
    Range(_, s, e) => {
      self.literal(s)
      self.literal(e)
    }
    Bracketed(x) => self.class_set(x.kind)
    Union(_, items) =>
      for x in items {
        self.class_set_item(x)
      }
    _ => ()
  }
}

///|
fn AstAnalysis::literal(self : AstAnalysis, lit : @syntax.Literal) -> Unit {
  self.any_literal = true
  self.any_uppercase = self.any_uppercase ||
    @unicode.is_uppercase(lit.c.to_int())
}
