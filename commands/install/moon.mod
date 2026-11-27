name = "cli/install"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/moonbit-community/cmd"

license = "Apache-2.0"

keywords = [ "command-line", "moonx", "wasm" ]

preferred_target = "wasm"

description = "Copy regular files and create directories with a requested POSIX mode."

import {
  "moonbitlang/x@0.5.9",
  "cli/core@0.11.10",
}
