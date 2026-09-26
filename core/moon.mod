name = "cli/core"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/moonbit-community/cmd"

license = "Apache-2.0"

keywords = [ "command-line", "moonx", "wasm" ]

preferred_target = "wasm"

description = "Shared runtime core for cli command modules."

import {
  "moonbitlang/async@0.22.4",
  "moonbitlang/x@0.5.5",
}
