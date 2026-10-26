///|
pub extend Adler32 with Hasher::{reset, checksum, size, update}

///|
pub extend CRC32 with Hasher::{reset, checksum, size, update}

///|
pub extend XXH32 with Hasher::{reset, checksum, size, update}

///|
pub extend XXH64 with Hasher::{checksum}
