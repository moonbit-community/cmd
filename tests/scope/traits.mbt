///|
pub extend GitChange with ToJson::{to_json}

///|
pub extend GitChange with @json.FromJson::{from_json}

///|
pub extend GitChange with Eq::{not_equal, equal}

///|
pub extend GitChange with @debug.Debug::{to_repr}

///|
pub extend DependencyNode with ToJson::{to_json}

///|
pub extend DependencyNode with @json.FromJson::{from_json}

///|
pub extend DependencyNode with Eq::{not_equal, equal}

///|
pub extend DependencyNode with @debug.Debug::{to_repr}

///|
pub extend DependencyEdge with ToJson::{to_json}

///|
pub extend DependencyEdge with @json.FromJson::{from_json}

///|
pub extend DependencyEdge with Eq::{not_equal, equal}

///|
pub extend DependencyEdge with @debug.Debug::{to_repr}

///|
pub extend DependencyGraph with ToJson::{to_json}

///|
pub extend DependencyGraph with @json.FromJson::{from_json}

///|
pub extend DependencyGraph with Eq::{not_equal, equal}

///|
pub extend DependencyGraph with @debug.Debug::{to_repr}

///|
pub extend BehaviorRequirement with ToJson::{to_json}

///|
pub extend BehaviorRequirement with @json.FromJson::{from_json}

///|
pub extend BehaviorRequirement with Eq::{not_equal, equal}

///|
pub extend BehaviorRequirement with @debug.Debug::{to_repr}

///|
pub extend Selection with ToJson::{to_json}

///|
pub extend Selection with @json.FromJson::{from_json}

///|
pub extend Selection with Eq::{not_equal, equal}

///|
pub extend Selection with @debug.Debug::{to_repr}

///|
pub extend HumanExtra with ToJson::{to_json}

///|
pub extend HumanExtra with @json.FromJson::{from_json}

///|
pub extend HumanExtra with Eq::{not_equal, equal}

///|
pub extend HumanExtra with @debug.Debug::{to_repr}

///|
pub extend ScopeBoundary with ToJson::{to_json}

///|
pub extend ScopeBoundary with @json.FromJson::{from_json}

///|
pub extend ScopeBoundary with Eq::{not_equal, equal}

///|
pub extend ScopeBoundary with @debug.Debug::{to_repr}

///|
pub extend InputIdentities with ToJson::{to_json}

///|
pub extend InputIdentities with @json.FromJson::{from_json}

///|
pub extend InputIdentities with Eq::{not_equal, equal}

///|
pub extend InputIdentities with @debug.Debug::{to_repr}

///|
pub extend ScopeIntent with ToJson::{to_json}

///|
pub extend ScopeIntent with @json.FromJson::{from_json}

///|
pub extend ScopeIntent with Eq::{not_equal, equal}

///|
pub extend ScopeIntent with @debug.Debug::{to_repr}
