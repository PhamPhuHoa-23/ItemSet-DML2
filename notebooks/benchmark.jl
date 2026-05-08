"""
Benchmark: LCMFreq Baseline vs Optimized
=========================================
Run: julia --project=. notebooks/benchmark.jl

Compares runtime of:
  - Baseline : Vector{Int} tidsets (sorted list intersection)
  - Optimized: BitArray tidsets    (bitwise AND + popcount)

Uses BenchmarkTools @btime for reliable timing (multiple runs, min reported).
"""

using BenchmarkTools

# Load both implementations into separate modules
module Base_
    include("../src/algorithm/lcmfreq_base.jl")
end

module Opt_
    include("../src/algorithm/lcmfreq.jl")
end

include("../src/io/reader.jl")

println("=" ^ 60)
println("LCMFreq Benchmark: Baseline (Vector) vs Optimized (BitArray)")
println("=" ^ 60)

datasets = [
    ("Chess",    "data/benchmark/chess.dat",    0.80),
    ("Mushroom", "data/benchmark/mushroom.dat", 0.30),
]

for (name, path, minsup_frac) in datasets
    !isfile(path) && (println("Skip $name (not found)"); continue)

    txs = read_transactions(path)
    n = length(txs)
    minsup_abs = max(1, ceil(Int, minsup_frac * n))

    println("\nDataset : $name ($n transactions, minsup=$minsup_abs)")

    # Warm-up
    r_base = Base_.lcmfreq_base(txs, minsup_abs)
    r_opt  = Opt_.lcmfreq(txs, minsup_abs)

    @assert length(r_base.itemsets) == length(r_opt.itemsets) "Count mismatch on $name!"

    println("Itemsets: $(length(r_base.itemsets))")

    t_base = @belapsed Base_.lcmfreq_base($txs, $minsup_abs) seconds=5
    t_opt  = @belapsed Opt_.lcmfreq($txs, $minsup_abs) seconds=5

    println("  Baseline : $(round(t_base*1000, digits=1)) ms")
    println("  Optimized: $(round(t_opt*1000,  digits=1)) ms")
    println("  Speedup  : $(round(t_base/t_opt, digits=1))x")
end

println("\n" * "=" ^ 60)
println("Benchmark complete.")
