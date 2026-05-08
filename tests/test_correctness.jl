using Test

const PROJECT_ROOT = dirname(dirname(abspath(@__FILE__)))

include(joinpath(PROJECT_ROOT, "src", "algorithm", "lcmfreq_base.jl"))

module Optimized end
Base.include(Optimized, joinpath(PROJECT_ROOT, "src", "algorithm", "lcmfreq.jl"))

function normalize(result::LCMFreqResult)
    pairs = [(sort(fi.items), fi.support) for fi in result.itemsets]
    sort!(pairs, by = x -> x[1])
end

function normalize(result::Optimized.LCMFreqResult)
    pairs = [(sort(fi.items), fi.support) for fi in result.itemsets]
    sort!(pairs, by = x -> x[1])
end

@testset "contextPasquier99 known answer" begin
    db = [
        [1, 3, 4],
        [2, 3, 5],
        [1, 2, 3, 5],
        [2, 5],
        [1, 2, 3, 5],
    ]
    minsup_abs = 2

    result_base = lcmfreq_base(db, minsup_abs)
    result_opt  = Optimized.lcmfreq(db, minsup_abs)

    expected = sort([
        ([1], 3), ([2], 4), ([3], 4), ([5], 4),
        ([1, 2], 2), ([1, 3], 3), ([1, 5], 2), ([2, 3], 3),
        ([2, 5], 4), ([3, 5], 3),
        ([1, 2, 3], 2), ([1, 2, 5], 2), ([1, 3, 5], 2), ([2, 3, 5], 3),
        ([1, 2, 3, 5], 2),
    ], by = x -> x[1])

    @test length(result_base.itemsets) == 15
    @test length(result_opt.itemsets)  == 15
    @test normalize(result_base) == expected
    @test normalize(result_opt)  == expected
end

@testset "Baseline == Optimized agreement" begin
    toy_path = joinpath(PROJECT_ROOT, "data", "toy", "sample_9tx.dat")
    if isfile(toy_path)
        db = read_transactions(toy_path)
        for minsup_frac in [0.2, 0.3, 0.4, 0.5, 0.6, 0.8]
            minsup_abs = max(1, ceil(Int, minsup_frac * length(db)))
            @test normalize(lcmfreq_base(db, minsup_abs)) == normalize(Optimized.lcmfreq(db, minsup_abs))
        end
    else
        @warn "Skipping toy dataset test: $toy_path not found"
    end
end

@testset "Edge cases" begin
    r = lcmfreq_base([[1, 2, 3]], 1)
    @test length(r.itemsets) == 7   # 2^3 - 1

    r = lcmfreq_base([[1, 2], [1, 2], [1, 2]], 2)
    norms = normalize(r)
    @test ([1], 3) in norms && ([2], 3) in norms && ([1, 2], 3) in norms
    @test length(r.itemsets) == 3

    r = lcmfreq_base([[1, 2], [2, 3]], 1)
    norms = normalize(r)
    @test ([2], 2) in norms && ([1, 2], 1) in norms && ([2, 3], 1) in norms
    @test length(r.itemsets) == 5

    @test isempty(lcmfreq_base(Vector{Vector{Int}}(), 1).itemsets)
end

@testset "Chess benchmark itemset counts" begin
    chess_path = joinpath(PROJECT_ROOT, "data", "benchmark", "chess.dat")
    if !isfile(chess_path)
        @warn "Skipping chess.dat test: not found"
    else
        db = read_transactions(chess_path)
        for minsup_frac in [0.9, 0.8]
            msa = max(1, ceil(Int, minsup_frac * length(db)))
            @test normalize(lcmfreq_base(db, msa)) == normalize(Optimized.lcmfreq(db, msa))
        end
    end
end

println("\nAll tests completed.")
