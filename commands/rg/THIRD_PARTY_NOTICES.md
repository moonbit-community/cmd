# Third-party notices

rg.mbt is a port of [ripgrep](https://github.com/BurntSushi/ripgrep)
(Copyright (c) 2015 Andrew Gallant, dual-licensed under MIT and the
Unlicense); this port is distributed under the MIT license (see `LICENSE`).
Its help text, man page, completions, messages and test data are derived from
ripgrep.

It also contains data derived from the following projects:

- **regex test corpus** (`regex/internal/testdata`), generated from the test
  suite of the Rust [regex](https://github.com/rust-lang/regex) crate.
  Copyright (c) 2014 The Rust Project Developers. Licensed under MIT or
  Apache-2.0.
- **Unicode tables** (`regex/unicode`), generated from the tables of the Rust
  [regex-syntax](https://github.com/rust-lang/regex) crate (produced by
  `ucd-generate`). Copyright (c) 2014 The Rust Project Developers, licensed
  under MIT or Apache-2.0. The underlying data is from the Unicode Character
  Database, Copyright (c) 1991-2024 Unicode, Inc., distributed under the
  [Unicode License v3](https://www.unicode.org/license.txt).
- **Encoding indexes** (`searcher/encoding_data.mbt`), generated from the
  index files of the [WHATWG Encoding Standard](https://encoding.spec.whatwg.org/).
  Copyright (c) WHATWG (Apple, Google, Mozilla, Microsoft). Licensed under
  the [Creative Commons Attribution 4.0 International License](https://creativecommons.org/licenses/by/4.0/).
