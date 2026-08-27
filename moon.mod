// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "mooxCLI/cmd"

version = "0.1.3"

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/cmd"

license = "Apache-2.0"

keywords = [ "command-line", "coreutils", "moonbit", "wasm" ]

preferred_target = "wasm"

description = "Common Unix command-line utilities implemented in MoonBit for policy-controlled execution."

import {
  "bobzhang/moonjq@0.1.1",
  "moonbitlang/async@0.21.0",
  "moonbitlang/x@0.5.1",
}

options(
  exclude: [ "AGENTS.md", "docs/" ],
)
