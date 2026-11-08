///|
pub(all) suberror ShellError {
  ShellError(String)
}

///|
#derive(Eq)
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
}

///|
#derive(Eq)
priv struct Word {
  parts : Array[WordPart]
  preserve_empty : Bool
}

///|
#derive(Eq)
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
  RedirectHereDoc(String, Bool)
  RedirectCopy(Int32)
  LParen
  RParen
  LBrace
  RBrace
  CaseEnd
}

///|
priv enum Redirect {
  InputFile(Word)
  OutputFile(Word, Bool, Bool)
  HereDocument(String, Bool)
  CopyDescriptor(Int32, Word)
}

///|
priv enum ExpandedRedirect {
  ReadPath(String)
  WritePath(String, Bool, Bool)
  HereBody(String, Bool)
  CopyTarget(Int32, String)
}

///|
priv struct Command {
  words : Array[Word]
  redirects : Array[Redirect]
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
  capture : CaptureBuffer?
  mut input : &@io.Reader?
  mut output : &@io.Writer?
  mut error : &@io.Writer?
  mut output_channel : Int32
  mut error_channel : Int32
  mut output_buffer_allocated : Bool
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
  BreakLoop(Int32)
  ContinueLoop(Int32)
}

///|
fn Context::take_loop_break(self : Context) -> Bool {
  match self.loop_control {
    Some(BreakLoop(levels)) => {
      self.loop_control = if levels > 1 {
        Some(BreakLoop(levels - 1))
      } else {
        None
      }
      true
    }
    Some(ContinueLoop(levels)) => {
      self.loop_control = if levels > 1 {
        Some(ContinueLoop(levels - 1))
      } else {
        None
      }
      levels > 1
    }
    None => false
  }
}

///|
priv struct Prepared {
  argv : Array[String]
  env : Map[String, String]
  assignments : Map[String, String]
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
