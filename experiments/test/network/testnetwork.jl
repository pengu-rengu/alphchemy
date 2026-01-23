module TestNetworkModule

include("../../src/network/network.jl")
include("../testutils.jl")
include("networkutils.jl")

using Test
using Supposition
using .NetworkModule
using .TestUtilsModule
using .NetworkUtilsModule

@testset "idx_from_ptr" begin
    @check (ptr_idx = int_gen) -> begin
        ptr = NodePtr(
            anchor = :from_start,
            idx = ptr_idx
        )
        idx = idx_from_ptr(ptr, 10)
        return idx == ptr_idx
    end

    @check (ptr_idx = int_gen, len = int_gen) -> begin
        ptr = NodePtr(
            anchor = :from_end,
            idx = ptr_idx
        )
        idx = idx_from_ptr(ptr, len)
        expected_idx = len - ptr_idx + 1
        return idx == expected_idx
    end
end

@testset "idx_trail_value" begin
    e = example(logic_net_gen, 100)
    for net ∈ e
        println(length(net.nodes))
        println(net.default_value)
    end
    #ex = example(logic_nodes_gen, 1)
    #println(ex)
end

end