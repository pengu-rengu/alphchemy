module NetworkUtilitiesModule

using ..NetworkModule

function first_value(network::AbstractNetwork)::Any
    return network.nodes[1].value
end
export first_value

function second_value(network::AbstractNetwork)::Any
    return network.nodes[2].value
end
export second_value

function set_first_node!(network::AbstractNetwork, node::Any)
    network.nodes[1] = node 
end
export set_first_node!

end
