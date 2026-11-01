///|
pub(all) enum CompatibilityTier {
  Core
  Extended
  Restricted
} derive(Eq, Debug)

///|
pub extend CompatibilityTier with Eq::{equal, not_equal}

///|
pub extend CompatibilityTier with @debug.Debug::{to_repr}

///|
pub(all) enum InputMode {
  NoInput
  OptionalStdin
  FileOrStdin
  StructuredInput
} derive(Eq, Debug)

///|
pub(all) enum OutputMode {
  ByteStream
  LineStream
  StructuredOutput
} derive(Eq, Debug)

///|
pub(all) enum Capability {
  FileRead
  FileWrite
  ProcessSpawn
  Network
  PermissionMutation
  SymbolicLink
  ProcessGroupCancellation
} derive(Eq, Debug)

///|
pub(all) struct CommandContract {
  name : String
  tier : CompatibilityTier
  input : InputMode
  output : OutputMode
  exit_codes : Array[Int32]
  capabilities : Array[Capability]
  options : Array[String]
}

///|
pub extend InputMode with Eq::{not_equal, equal}

///|
pub extend InputMode with @debug.Debug::{to_repr}

///|
pub extend OutputMode with Eq::{not_equal, equal}

///|
pub extend OutputMode with @debug.Debug::{to_repr}

///|
pub extend Capability with Eq::{not_equal, equal}

///|
pub extend Capability with @debug.Debug::{to_repr}
