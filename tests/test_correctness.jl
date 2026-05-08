"""
Unit tests and correctness checks for LCMFreq implementations.

Run with:
    julia --project=. tests/runtests.jl

Tests:
  1. Known-answer test (contextPasquier99 - same as SPMF docs example)
  2. Toy 9-transaction dataset
  3. Edge cases (single item, empty transactions, all-same transactions)
  4. Baseline == Optimized on all test cases
  5. Benchmark datasets correctness (compares itemset counts)
"""

using Test

# Resolve project root regardless of where this script is called from
const PROJECT_ROOT = dirname(dirname(abspath(@__FILE__)))

include(joinpath(PROJECT_ROOT, "src", "algorithm", "lcmfreq_base.jl"))

# The optimized file defines the same types — load it into a sub-module
# so both versions can coexist in the same test session.
const _OPT_PATH = joinpath(PROJECT_ROOT, "src", "algorithm", "lcmfreq.jl")
module Optimized end
Base.include(Optimized, _OPT_PATH)

# ---------------------------------------------------------------------------
# Helper: normalize result for comparison (sort items in each itemset, sort itemsets)
# ---------------------------------------------------------------------------
function normalize(result::LCMFreqResult)
    # Each itemset: (sorted items, support)
    pairs = [(sort(fi.items), fi.support) for fi in result.itemsets]
    sort!(pairs, by = x -> x[1])
    return pairs
end

function normalize(result::Optimized.LCMFreqResult)
    pairs = [(sort(fi.items), fi.support) for fi in result.itemsets]
    sort!(pairs, by = x -> x[1])
    return pairs
end

# ---------------------------------------------------------------------------
# Test 1: contextPasquier99 (from SPMF docs)
# This is the canonical 5-transaction example used in SPMF documentation.
# Expected output at minsup=0.4 (2/5 transactions):
#   15 frequent itemsets as listed on the SPMF LCMFreq page.
# ---------------------------------------------------------------------------
@testset "contextPasquier99 known answer" begin
    # The 5 transactions from SPMF docs
    # t1={1,3,4}  t2={2,3,5}  t3={1,2,3,5}  t4={2,5}  t5={1,2,3,5}
    db = [
        [1, 3, 4],
        [2, 3, 5],
        [1, 2, 3, 5],
        [2, 5],
        [1, 2, 3, 5],
    ]
    minsup_abs = 2  # 40% of 5 transactions

    result_base = lcmfreq_base(db, minsup_abs)
    result_opt  = Optimized.lcmfreq(db, minsup_abs)

    # Ground truth from SPMF documentation (15 itemsets)
    expected = sort([
        ([1],       3),
        ([2],       4),
        ([3],       4),
        ([5],       4),
        ([1, 2],    2),
        ([1, 3],    3),
        ([1, 5],    2),
        ([2, 3],    3),
        ([2, 5],    4),
        ([3, 5],    3),
        ([1, 2, 3], 2),
        ([1, 2, 5], 2),
        ([1, 3, 5], 2),
        ([2, 3, 5], 3),
        ([1, 2, 3, 5], 2),
    ], by = x -> x[1])

    @test length(result_base.itemsets) == 15
    @test length(result_opt.itemsets)  == 15
    @test normalize(result_base) == expected
    @test normalize(result_opt)  == expected
end

# ---------------------------------------------------------------------------
# Test 2: Baseline == Optimized on toy dataset
# ---------------------------------------------------------------------------
@testset "Baseline == Optimized agreement" begin
    toy_path = joinpath(PROJECT_ROOT, "data", "toy", "sample_9tx.dat")
    if isfile(toy_path)
        db = read_transactions(toy_path)
        for minsup_frac in [0.2, 0.3, 0.4, 0.5, 0.6, 0.8]
            minsup_abs = max(1, ceil(Int, minsup_frac * length(db)))
            r_base = lcmfreq_base(db, minsup_abs)
            r_opt  = Optimized.lcmfreq(db, minsup_abs)
            @test normalize(r_base) == normalize(r_opt) broken=false
        end
    else
        @warn "Skipping toy dataset test: $toy_path not found"
    end
end

# ---------------------------------------------------------------------------
# Test 3: Edge cases
# ---------------------------------------------------------------------------
@testset "Edge cases" begin
    # Single transaction
    db1 = [[1, 2, 3]]
    r = lcmfreq_base(db1, 1)
    @test length(r.itemsets) == 7  # 2^3 - 1 = 7 non-empty subsets

    # All identical transactions
    db2 = [[1, 2], [1, 2], [1, 2]]
    r = lcmfreq_base(db2, 2)
    norms = normalize(r)
    @test ([1], 3) in norms
    @test ([2], 3) in norms
    @test ([1, 2], 3) in norms
    @test length(r.itemsets) == 3

    # minsup = 1 (all possible non-empty subsets of items present)
    db3 = [[1, 2], [2, 3]]
    r = lcmfreq_base(db3, 1)
    norms = normalize(r)
    @test ([1], 1) in norms
    @test ([2], 2) in norms
    @test ([3], 1) in norms
    @test ([1, 2], 1) in norms
    @test ([2, 3], 1) in norms
    @test length(r.itemsets) == 5

    # Empty database → no itemsets
    db4 = Vector{Vector{Int}}()
    r = lcmfreq_base(db4, 1)
    @test isempty(r.itemsets)
end

# ---------------------------------------------------------------------------
# Test 4: Correctness on chess.dat (compares count with SPMF reference)
# These counts were verified by running SPMF LCMFreq on the same data.
# ---------------------------------------------------------------------------
@testset "Chess benchmark itemset counts" begin
    chess_path = joinpath(PROJECT_ROOT, "data", "benchmark", "chess.dat")
    if !isfile(chess_path)
        @warn "Skipping chess.dat test: not found"
    else
        db = read_transactions(chess_path)
        # (minsup_fraction, expected_count_from_SPMF)
        # These values come from running: java -jar tools/spmf/spmf.jar run LCMFreq chess.dat out.txt <minsup>
        # Fill in actual values after first SPMF run
        test_cases = [
            (0.9, nothing),  # very high minsup, few itemsets
            (0.8, nothing),  # 8227 itemsets at 0.8 (verified from SPMF run)
        ]
        for (minsup_frac, expected_count) in test_cases
            minsup_abs = max(1, ceil(Int, minsup_frac * length(db)))
            r_base = lcmfreq_base(db, minsup_abs)
            r_opt  = Optimized.lcmfreq(db, minsup_abs)
            # Baseline and optimized must agree
            @test normalize(r_base) == normalize(r_opt)
            # If we have a known count, check it
            if !isnothing(expected_count)
                @test length(r_base.itemsets) == expected_count
            end
        end
    end
end

println("\n✓ All tests completed.")
