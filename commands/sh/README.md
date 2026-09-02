# sh

`cli/sh` is a MoonBit shell interpreter for native and Wasm targets.
It implements command parsing, quoting, variable and positional expansion,
conditionals, pipelines, redirections, and essential built-ins in MoonBit.

External commands are launched individually through the MoonBit async process
API. The active policy evaluates every child process request; the interpreter
never delegates a complete script to a host shell.

Native execution inherits the complete parent environment. Wasm execution
uses the explicit restricted environment and host process policy.

Unsupported shell language constructs fail closed with status 2 instead of
being forwarded to another interpreter.

When neither `-c` nor a script file is supplied, the shell silently reads its
script from stdin until EOF, as required by the POSIX compatibility path.
