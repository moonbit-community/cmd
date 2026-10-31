///|
pub(all) suberror ShellError {
  ShellError(String)
}

///|
priv enum WordPart {
  Text(String)
  QuotedText(String)
  Variable(String, Bool)
  CommandSubstitution(String, Bool)
  LengthVariable(String, Bool)
  Positional(Int32, Bool)
  LastStatus(Bool)
  ArgCount(Bool)
  AllArgs(Bool, Bool)
  Arithmetic(String, Bool)
  DefaultVariable(String, String, String, Bool)
} derive(Eq)

///|
priv struct Word {
  parts : Array[WordPart]
  preserve_empty : Bool
} derive(Eq)

///|
priv enum Token {
  WordToken(Word)
  Sequence
  AndIf
  OrIf
  Pipe
  RedirectIn
  RedirectOut
  RedirectAppend
  RedirectError
  RedirectErrorAppend
  RedirectHereDoc
  LParen
  RParen
  LBrace
  RBrace
  CaseEnd
} derive(Eq)

///|
priv struct Redirect {
  target : Word
  append : Bool
}

///|
priv struct Command {
  words : Array[Word]
  stdin : Word?
  stdin_data : String?
  stdout : Redirect?
  stderr : Redirect?
}

///|
priv struct Pipeline {
  commands : Array[Command]
}

///|
priv enum Connector {
  Always
  OnSuccess
  OnFailure
}

///|
priv struct Job {
  connector : Connector
  statement : Statement
}

///|
priv struct CaseArm {
  patterns : Array[Word]
  body : Array[Job]
}

///|
priv enum Statement {
  Pipeline(Pipeline)
  IfStatement(Array[Job], Array[Job], Array[Job])
  CaseStatement(Word, Array[CaseArm])
  ForStatement(String, Array[Word], Array[Job])
  LoopStatement(Array[Job], Array[Job], Bool)
  FunctionStatement(String, Array[Job])
  GroupStatement(Array[Job], Bool)
}

///|
priv struct Context {
  env : Map[String, String]
  exported : Set[String]
  mut positional : Array[String]
  name : String
  mut cwd : String
  mut last_status : Int32
  mut last_signal : Int32?
  mut exited : Bool
  mut exit_status : Int32
  capture : StringBuilder?
  mut input : &@io.Reader?
  mut output : &@io.Writer?
  mut error : &@io.Writer?
  functions : Map[String, Array[Job]]
  mut errexit : Bool
  mut nounset : Bool
  mut return_status : Int32?
  mut loop_control : LoopControl?
  mut loop_depth : Int32
  mut call_depth : Int32
  mut substitution_status : Int32?
  mut expansion_failed : Bool
}

///|
priv enum LoopControl {
  BreakLoop
  ContinueLoop
}

///|
fn Context::take_loop_break(self : Context) -> Bool {
  let should_break = self.loop_control is Some(BreakLoop)
  self.loop_control = None
  should_break
}

///|
priv struct Prepared {
  argv : Array[String]
  env : Map[String, String]
  assignments : Map[String, String]
  stdin : String?
  stdin_data : String?
  stdout : (String, Bool)?
  stderr : (String, Bool)?
}

///|
priv suberror ParseIssue {
  IncompleteSyntax(String)
  InvalidSyntax(String)
}

///|
fn ParseIssue::shell_error(self : ParseIssue) -> ShellError {
  match self {
    IncompleteSyntax(message) | InvalidSyntax(message) => ShellError(message)
  }
}
