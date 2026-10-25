name = "cli/sha1sum"

version = "0.1.2"

readme = "README.md"

repository = "https://github.com/moonbit-community/cmd"

license = "Apache-2.0"

keywords = [ "command-line", "moonx", "wasm" ]

preferred_target = "wasm"

description = "sha1sum command for MoonX."

import {
  "cli/core@0.8.0",
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.5",
}
