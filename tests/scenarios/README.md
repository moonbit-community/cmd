# Stateful command scenarios

`dispatch.mbt` routes selectable stateful case IDs; `cohorts.mbt` defines
multi-command and permission selections. Both are bound by `cases/index.json`.
The driver owns selection and reporting orchestration, while this package
owns concrete assertions, shared fixture lifetimes and child coordination.

On macOS, scenario files live under `work.noindex` so background indexing does
not read fixtures and change their access times. Timestamp assertions remain
exact; the runner neither resets observed timestamps nor disables atime updates.
Other platforms retain the `work` directory name.

Shell sessions, make handshakes, filesystem fidelity and process lifetimes
have separate files. Permission admission, runtime, mutation, process,
network and permission-mode checks are separated by responsibility. HTTP,
HTTPS and proxy cohorts retain their concrete request assertions.

`network/` owns injectable transfer/request scenarios and their observation
regressions. `filesystem/` owns open-stdin move observations, mktemp option
relations and tee output-failure modes. Command-specific assertions belong
here, with private regression tests beside their implementation.

Workspace and published launch adapters execute these same assertions.
Reviewed finite descriptors live in `coverage/review/scenarios.json`.
A passing scenario label is insufficient: actual receipts must contain the
matching expected values, command identity and complete observation dimensions.
