# tree

Version **0.1.0** published behavior is documented here. The support record
includes exact published MoonX verification.

`tree` recursively displays directory entries with deterministic lexical
ordering and Unicode branch markers:

```text
.
├── bin
│   └── tool
└── README
```

Supported options are:

- `-a`, `--all`: include hidden entries;
- `-d`, `--dirs-only`: omit non-directory entries;
- `-f`, `--full-path`: print each child path instead of only its basename;
- `-L LEVEL`, `--level LEVEL`: stop traversal after `LEVEL` child levels;
- `--noreport`: omit the directory/file count line;
- `--help` and `--version`.

Multiple roots are accepted. Roots default to `.`. Entries are read with the
released public `async/fs` API and sorted before any output is produced. A
symbolic link is rejected with status 1 because the public API does not expose
the link target; tree does not follow links or guess their target. Unsupported
options and invalid levels exit with status 2. Missing paths and directory
read failures exit with status 1. The command does not invoke a host `tree`
program and does not change the caller's environment or authorization policy.

The current profile intentionally excludes GNU tree's link target display,
color, permissions, device metadata, and extended report formatting. Those
features require public metadata/readlink APIs and remain boundary items in the
project capability records.
