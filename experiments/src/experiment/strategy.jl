module StrategyModule

using ..FeaturesModule
using ..NetworkModule
using ..EvaluateModule
using ..DoActionsModule
using ..OptimizerModule

@kwdef struct Strategy
    base_net::AbstractNetwork
    feats::Vector{AbstractFeature}
    actions::AbstractActions
    penalties::AbstractPenalties
    stop_conds::StopConds
    opt::AbstractOptimizer
    entry_ptr::NodePtr
    exit_ptr::NodePtr
    stop_loss::Float64
    take_profit::Float64
    max_hold_time::Int 
end
export Strategy

@kwdef struct NetworkSignal
    entry::Bool
    exit::Bool
end
export NetworkSignal

function net_signals!(strategy::Strategy, net::AbstractNetwork, feat_matrix::Matrix{Float64}, delay::Int)::Vector{NetworkSignal}

    n_rows = size(feat_matrix, 1)
    
    signals = Vector{NetworkSignal}(undef, n_rows)
    signals[1:delay] .= fill(NetworkSignal(
        entry = false,
        exit = false
    ), delay)

    reset_state!(net)

    for row ∈ delay + 1:n_rows

        eval!(net, feat_matrix, row)
        
        entry_value = node_value(net, strategy.entry_ptr)
        exit_value = node_value(net, strategy.exit_ptr)
        
        signals[row] = NetworkSignal(
            entry = entry_value,
            exit = exit_value
        )
    end

    return signals
end
export net_signals!

end