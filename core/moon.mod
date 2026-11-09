name = "cli/core"

version = "0.9.5"

readme = "README.md"

repository = "https://github.com/moonbit-community/cmd"

license = "Apache-2.0"

keywords = [ "command-line", "moonx", "wasm" ]

preferred_target = "wasm"

description = "Shared runtime core for cli command modules."

import {
  "moonbitlang/async@0.22.7",
  "moonbitlang/x@0.5.5",
  "cc06b/mooncry@0.95.0",
  "moonbit-community/normalization@0.5.2",
  "moonbit-community/punycode@0.5.2",
}
