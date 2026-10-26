# Internal public-API system adapter

The fixed rg.mbt system boundary was replaced with released public
`moonbitlang/async@0.22.5` and `moonbitlang/x@0.5.5` APIs. Both Native development
observations and the Wasm product run through this adapter. No C stub, custom
WASI import or dependency-internal package is used.

File/stdio reads and writes, directory advancement, metadata times and
user-selected child processes are asynchronous. File identity is `None` when
unavailable. `Capability::Unavailable(reason)` preserves unknown stdin/terminal
state; it does not report a fabricated false query. Creation time and readlink
text remain explicit gaps. Canonical realpath supports followed-file size and
directory loop checks. OS diagnostics retain their public runtime text.

`Process` transfers stdout through an async memory reader with backpressure,
drains stderr concurrently for the inherited diagnostic API, and waits for the
direct child after EOF or cancellation. This API makes no process-tree claim.
Original system-test names remain in their source files, rewritten for the
released API behavior and portable pure MoonBit child fixtures.

The former WASI preopen rules, fake inode/time/detection defaults and native-only
subprocess restrictions are not current support claims. See the repository's
[rg support record](../../../../docs/compatibility.md#rg-candidate).
