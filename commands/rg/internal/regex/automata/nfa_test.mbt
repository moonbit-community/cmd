///|
fn nfa(pattern : String, reverse~ : Bool = false) -> String {
  let hir = @syntax.parse(pattern, config={
    ..@syntax.ParseConfig::default(),
    utf8: false,
  }) catch {
    e => abort(e.to_string())
  }
  let config = {
    ..@automata.NFAConfig::default(),
    reverse,
    captures: !reverse,
  }
  @automata.compile_nfa(hir, config~).to_string() catch {
    _ => abort("build")
  }
}

///|
test "nfa basic" {
  inspect(
    nfa("a"),
    content=(
      #|>0: binary-union(2, 1)
      #| 1: \x00-\xff => 0
      #|^2: capture(group=0, slot=0) => 3
      #| 3: a => 4
      #| 4: capture(group=0, slot=1) => 5
      #| 5: MATCH
      #|
    ),
  )
  inspect(
    nfa("^ab|c*?", reverse=true),
    content=(
      #|>0: binary-union(7, 1)
      #| 1: \x00-\xff => 0
      #| 2: a => 4
      #| 3: b => 2
      #| 4: End => 8
      #| 5: binary-union(8, 6)
      #| 6: c => 5
      #|^7: binary-union(3, 5)
      #| 8: MATCH
      #|
    ),
  )
  let hir = @syntax.parse("\\w") catch { _ => abort("") }
  let n = @automata.compile_nfa(hir) catch { _ => abort("") }
  inspect(n.states().length(), content="321")
}

///|
test "utf8 sequences" {
  debug_inspect(
    @automata.utf8_sequences(0, 0x10FFFF),
    content=(
      #|[
      #|  [(0, 127)],
      #|  [(194, 223), (128, 191)],
      #|  [(224, 224), (160, 191), (128, 191)],
      #|  [(225, 236), (128, 191), (128, 191)],
      #|  [(237, 237), (128, 159), (128, 191)],
      #|  [(238, 239), (128, 191), (128, 191)],
      #|  [(240, 240), (144, 191), (128, 191), (128, 191)],
      #|  [(241, 243), (128, 191), (128, 191), (128, 191)],
      #|  [(244, 244), (128, 143), (128, 191), (128, 191)],
      #|]
    ),
  )
}
