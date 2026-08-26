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

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/moonbit-community/cmd"

license = "Apache-2.0"

keywords = [
  "command-line",
  "coreutils",
  "moonbit",
  "moonrun",
  "moonseek",
  "sandbox",
  "wasm",
]

preferred_target = "wasm"

description = "Common Unix command-line utilities implemented in MoonBit for policy-controlled execution in MoonSeek and Moonrun sandboxes."
