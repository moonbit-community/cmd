# touch

Create missing files without changing existing contents. `-c`/`--no-create`
suppresses creation. The current portable Moonrun filesystem API does not
expose timestamp mutation, so existing-file timestamps are left unchanged.
