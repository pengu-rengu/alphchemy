module StrategyModule

using ..FeaturesModule
using ..NetworkModule
using ..LogicNetModule
using ..DecisionNetModule
using ..ActionsModule
using ..OptimizerModule

@kwdef struct Strategy
    base_network::AbstractNetwork
    features::Vector{AbstractFeature}
    actions::AbstractActions
    penalties::AbstractPenalties
    stop_conditions::StopConditions
    optimizer::AbstractOpt
    entry_ptr::NodePointer
    exit_ptr::NodePointer
    stop_loss::Float64
    take_profit::Float64
    max_holding_time::Int 
end
export Strategy

@kwdef struct NetworkSignal
    entry::Bool
    exit::Bool
end
export NetworkSignal

function network_signals!(strategy::Strategy, net::AbstractNetwork, feat_matrix::Matrix{Float64}, delay::Int)::Vector{NetworkSignal}
    n_rows = size(feat_matrix, 1)

    signals = Vector{NetworkSignal}(undef, n_rows)
    signals[1:delay] .= fill(NetworkSignal(
        entry = false,
        exit = false
    ), delay)

    reset_state!(net)

    for row ∈ delay + 1:n_rows

        if isa(net, LogicNet)
            eval_logic_net!(net, feat_matrix, row - delay)

            entry_value = logic_node_value(net, strategy.entry_ptr)
            exit_value = logic_node_value(net, strategy.exit_ptr)
        elseif isa(net, DecisionNet)
            eval_decision_net!(net, feat_matrix, row)

            entry_value = decision_node_value(net, strategy.entry_ptr)
            exit_value = decision_node_value(net, strategy.exit_ptr)
        end
        
        signals[row] = NetworkSignal(
            entry = entry_value,
            exit = exit_value
        )
    end

    return signals
end
export network_signals!

end