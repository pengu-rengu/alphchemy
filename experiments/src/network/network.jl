module NetworkModule

abstract type AbstractNetwork end
export AbstractNetwork

abstract type AbstractPenalties end
export AbstractPenalties

@kwdef struct NodePointer
    anchor::Symbol
    idx::Int
end
export NodePointer

function idx_from_pointer(pointer::NodePointer, len::Int)::Int
    anchor = pointer.anchor
    idx = pointer.idx

    if anchor == :from_start
        return idx
    elseif anchor == :from_end
        return len - idx + 1
    end
end
export idx_from_pointer

function reset_state!(network::AbstractNetwork)
    for node ∈ network.nodes
        node.value = network.default_value
    end
end
export reset_state!

end