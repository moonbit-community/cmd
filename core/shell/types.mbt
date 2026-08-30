///|
pub(all) suberror ShellError {
  ShellError(String)
}

///|
priv enum WordPart {
  Text(String)
  Variable(String, Bool)
  Positional(Int, Bool)
  LastStatus(Bool)
  ArgCount(Bool)
  AllArgs(Bool, Bool)
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
  pipeline : Pipeline
}

///|
priv struct Context {
  env : Map[String, String]
  positional : Array[String]
  name : String
  mut cwd : String
  mut last_status : Int
  mut exited : Bool
  mut exit_status : Int
}

///|
priv struct Prepared {
  argv : Array[String]
  env : Map[String, String]
  stdin : String?
  stdout : (String, Bool)?
  stderr : (String, Bool)?
}
