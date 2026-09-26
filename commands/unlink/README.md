# unlink

Version **0.1.0** candidate behavior removes each named file-system entry. Regular files and
symbolic links are removed with the released `moonbitlang/async` API; a link is
never followed to inspect its target. Multiple operands are processed in order,
and a later failure does not undo earlier removals. Directories are rejected.

```
unlink FILE...
```

`--help` and `--version` are supported. Missing operands and an operand that
cannot be removed exit non-zero. Authorization is supplied by the caller; the
command does not add a policy or invoke a host `unlink` program. The command's
portable profile does not provide GNU-specific diagnostics or interactive
confirmation.
