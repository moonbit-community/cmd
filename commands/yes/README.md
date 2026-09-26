# yes

Version **0.2.0** writes its operand text followed by a newline repeatedly
until stdout is closed or the task is cancelled.

```
yes [STRING]...
```

With no operands the line is `y`; multiple operands are joined by one space.
`--help` and `--version` print one line and exit. A broken pipe is treated as
normal producer termination, so `yes | head` does not report a command-level
failure. The command does not inspect terminal state or introduce an output
quota; callers should use a bounded consumer in tests.
