# Publishing Command Modules

The repository is a MoonBit workspace with one shared core module and 48
independent executable modules:

```text
cli/core@0.1.0
cli/base64@0.1.0
cli/cat@0.1.0
...
cli/xxd@0.1.0
```

Each command directory has its own `moon.mod`, so `moon publish` must be run in
that directory. The root is only a workspace; the historical `mooxCLI/cmd`
module is a legacy compatibility release, not the source of new publications.
The `tests/` module and its `testkit` package are repository-only validation
code and must never be published.

## Account selection

Moon credentials are selected by `MOON_HOME`. Use a separate directory for the
Mooncakes account that owns the `cli` namespace:

```bash
export MOON_HOME="$HOME/.moon-accounts/cli"
moon login
moon whoami
```

`moon whoami` must print the exact Mooncakes username `cli`. The module owner
and the account name are coupled: if the account has a different username,
change the module prefix in the manifests to that exact username before
publishing. Switching back only changes the environment for the next command:

```bash
MOON_HOME="$HOME/.moon-accounts/cli" moon whoami
MOON_HOME="$HOME/.moon-accounts/ZSeanYves" moon whoami
```

The Mooncakes email account is independent of GitHub. Do not delete a GitHub
account as part of this switch; it is not used by these module credentials.

## Validation

From the repository root:

```bash
moon update
moon check --target all --deny-warn
moon test --target all
moon build --target native --release --deny-warn
moon run --target native tests/compat -- --bin-root _build/native/release/build
moon run --target native tests/policy -- --root .
```

Inspect one archive before publishing:

```bash
moon -C commands/base64 package --list
```

The archive should contain only the selected module's `moon.mod`, `moon.pkg`,
README, generated interface, and source files. It must not contain `core/`,
`tests/`, or sibling commands.

## Release order

Publish the shared implementation first, then publish commands that depend on
it. The command modules use the fixed dependency `cli/core@0.1.0`.

```bash
export MOON_HOME="$HOME/.moon-accounts/cli"
moon -C core publish
moon -C commands/base64 publish
moon -C commands/cat publish
```

Repeat the command publication for the remaining `commands/*` directories in
`moon.work`; do not publish the repository-only `tests` module.
After publication, a consumer can invoke a command directly:

```text
moonx cli/base64
moonx cli/jq -r '.name'
```

Before `cli/core` is published, `moon.work` makes `./core` available as a
local workspace dependency even though command manifests already say
`cli/core@0.1.0`. After publishing `cli/core`, remove only the `"./core"` line
from `moon.work` and run `moon update`; do not change command coordinates.
They will then resolve `cli/core` from Mooncakes.

When core changes, publish a new `cli/core` version first, update the affected
command manifests, and then publish new command versions.

## Legacy release

The last whole-tree release is `mooxCLI/cmd@0.1.3`. If a final release that
announces the migration is needed, make that release from the pre-split
revision, with a README notice that new users should move to `cli/<command>`.
Once the nested `moon.mod` files are present, publishing the root module would
produce a different archive without the command modules, so it must not be
treated as the final whole-tree release.
