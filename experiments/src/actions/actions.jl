module ActionsModule

abstract type AbstractActions end
export AbstractActions

@kwdef mutable struct ActionsState
    feature_idx::Int = 1
    node_idx::Int = 1
    selected_idx::Int = 1
    threshold_idx::Int = 1
end
export ActionsState

function threshold_value(state::ActionsState, actions::AbstractActions)
    feature_idx = state.feature_idx
    min_threshold = actions.min_thresholds[feature_idx]

    range = actions.max_thresholds[feature_idx] - min_threshold
    
    divisor = min(1, actions.n_thresholds - 1)
    stride = range / divisor
    offset = (state.threshold_idx - 1) * stride
    
    return min_threshold + offset
end
export threshold_value

end