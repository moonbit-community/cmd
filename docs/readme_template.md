# Command README template

Use the English example below as the structure and length reference for
`commands/<command>/README.md`. Replace the command, examples, options and notes
with the behavior of the command being documented.

- Start with a one-sentence description, followed by practical examples,
  common options and necessary notes.
- Use unversioned `moonx cli/<command>` examples. Keep version information in
  `moon.mod` and expose it through `--version`.
- Explain input, output and defaults where they help users run the command.
  Include limits that affect usage, such as unsupported input, partial output
  or memory requirements. Omit the Notes section when there is nothing to add.
- Keep simple commands short. Add a few focused usage scenarios for complex
  commands, and link detailed compatibility information to the shared guide.
- Keep release history, test results and internal architecture in their owning
  documents. Keep generated option sections consistent with `options.json` and
  `tools/metadata` when applying this layout.

The relative link in the example is resolved from the command directory.

````markdown
# base32

Encode and decode files or standard input as Base32 through MoonX.

## Usage

```sh
# Encode a file
moonx cli/base32 input.txt

# Decode a file
moonx cli/base32 --decode encoded.txt > decoded.txt

# Read from standard input
printf 'hello' | moonx cli/base32
```

With no file, or with `-` as the filename, read from standard input.
Write results to standard output.

## Common options

| Option | Description |
| --- | --- |
| `-d, --decode` | Decode input. |
| `-i, --ignore-garbage` | Ignore non-alphabet characters when decoding. |
| `-w N, --wrap N` | Wrap output at N characters, default 76. Use 0 to disable wrapping and the trailing newline. |
| `--help` | Show help. |
| `--version` | Show the version. |

## Notes

- Decoding rejects lowercase characters by default.
- Invalid input may produce partial output before an error is reported.
- Decoding reads the entire input into memory.

See the [compatibility guide](../../docs/compatibility.md) for more details.
````
