# `mooxCLI/cmd`

> **Deprecated: final legacy release**

This module is no longer maintained. Version `0.1.4` is the final release of
the legacy `mooxCLI/cmd` module and contains this migration notice only.

Future development, fixes, and releases are maintained by the `cli` account as
independent MoonBit command modules. Use the new module coordinates instead:

```text
cli/core
cli/base64
cli/cat
cli/grep
cli/jq
```

For a command named `<command>`, use `cli/<command>`. The shared runtime is
available as `cli/core`. The source repository and its test suite continue to
be maintained at:

<https://github.com/moonbit-community/cmd>

Do not depend on `mooxCLI/cmd` for new projects.
