# sh

`mooxCLI/cmd/sh` is a MoonBit shell interpreter for native and Wasm targets.
It implements command parsing, quoting, variable and positional expansion,
conditionals, pipelines, redirections, and essential built-ins in MoonBit.

External commands are launched individually through the MoonBit async process
API. A sandbox therefore evaluates every child process against its active
policy; the interpreter never delegates a complete script to a host shell.

Unsupported shell language constructs fail closed with status 2 instead of
being forwarded to another interpreter.
