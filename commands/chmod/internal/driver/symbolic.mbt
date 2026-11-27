///|
priv enum PermissionSource {
  Literal(Int32, conditional_execute~ : Bool)
  Copy(Int32)
}

///|
priv struct ModeChange {
  classes : Int32
  operator : Char
  permissions : PermissionSource
}

///|
fn symbolic_actions(text : String) -> Array[ModeChange] raise ChmodError {
  let actions : Array[ModeChange] = []
  for clause in text.split(",") {
    let chars = clause.iter().to_array()
    let mut classes = 0
    let mut i = 0
    while i < chars.length() {
      match chars[i] {
        'u' => classes = classes | 0o4700
        'g' => classes = classes | 0o2070
        'o' => classes = classes | 0o1007
        'a' => classes = 0o7777
        _ => break
      }
      i += 1
    }
    guard classes != 0 && i < chars.length() else {
      raise ChmodError(
        "symbolic clauses require explicit classes and an operator",
      )
    }
    while i < chars.length() {
      let operator = chars[i]
      guard operator is ('=' | '+' | '-') else {
        raise ChmodError("invalid symbolic operator: '\{operator}'")
      }
      i += 1
      let permissions = if i < chars.length() && chars[i] is ('u' | 'g' | 'o') {
        let shift = match chars[i] {
          'u' => 6
          'g' => 3
          _ => 0
        }
        i += 1
        PermissionSource::Copy(shift)
      } else {
        let mut bits = 0
        let mut conditional_execute = false
        while i < chars.length() {
          match chars[i] {
            '=' | '+' | '-' => break
            'r' => bits = bits | 0o444
            'w' => bits = bits | 0o222
            'x' => bits = bits | 0o111
            's' => bits = bits | 0o6000
            't' => bits = bits | 0o1000
            'X' => conditional_execute = true
            c => raise ChmodError("invalid symbolic permission: '\{c}'")
          }
          i += 1
        }
        Literal(bits, conditional_execute~)
      }
      actions.push({ classes, operator, permissions, })
    }
  }
  actions
}

///|
fn apply_symbolic(actions : Array[ModeChange], initial : Int32) -> Int32 {
  let mut mode = initial
  for action in actions {
    let bits = match action.permissions {
      Copy(shift) => ((mode >> shift) & 7) * 0o111
      Literal(bits, conditional_execute~) =>
        if conditional_execute && (mode & 0o111) != 0 {
          bits | 0o111
        } else {
          bits
        }
    }
    let selected = action.classes & bits
    mode = match action.operator {
      '+' => mode | selected
      '-' => mode & selected.lnot()
      _ => (mode & action.classes.lnot()) | selected
    }
  }
  mode
}

///|
fn parse_symbolic_mode(text : String) -> Int32 raise ChmodError {
  let actions = symbolic_actions(text)
  let result = apply_symbolic(actions, 0)
  let unknown = "result depends on existing permission bits"
  guard apply_symbolic(actions, 0o7777) == result else {
    raise ChmodError(unknown)
  }
  // Assignment, union and subtracting literals are monotone on permission
  // bit sets. Subtracting a copied class or X can reverse that ordering.
  if actions.any(action => {
      action.operator == '-' &&
      (
        action.permissions is Copy(_) ||
        action.permissions is Literal(_, conditional_execute=true)
      )
    }) {
    for initial in 1..<0o7777 {
      guard apply_symbolic(actions, initial) == result else {
        raise ChmodError(unknown)
      }
    }
  }
  result
}
