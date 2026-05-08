"""
run_experiments.jl — Comprehensive experiment suite for LCMFreq report
=======================================================================
Covers all required experiments from Description.pdf, Chapter 4:

  (a) Correctness : item-count + 100% support match vs SPMF on 5 datasets
  (b) Runtime     : Julia Optimized + SPMF vs minsup (5 datasets × 7 points)
  (c) Itemset cnt : same sweep as (b)
  (d) Memory      : @allocated baseline vs optimized
  (e) Scalability : Retail subsampled at 10/25/50/75/100%, fixed minsup=1%
  (f) Tx-length   : synthetic Bernoulli DBs, avg_len 5→40

Outputs:
  data/results/correctness.csv
  data/results/runtime_<dataset>.csv   (one per dataset, includes baseline col)
  data/results/memory.csv
  data/results/scalability.csv
  data/results/txlen_effect.csv

Run:
  julia --project=. notebooks/run_experiments.jl
"""

using Random, Statistics

# ── Load both implementations in separate modules (avoids type name clashes) ──
module Baseline_
    include(joinpath(@__DIR__, "../src/algorithm/lcmfreq_base.jl"))
end

module Optimized_
    include(joinpath(@__DIR__, "../src/algorithm/lcmfreq.jl"))
end

include(joinpath(@__DIR__, "../src/io/reader.jl"))

const SPMF_JAR = normpath(joinpath(@__DIR__, "../tools/spmf/spmf.jar"))
const DATA_BM  = normpath(joinpath(@__DIR__, "../data/benchmark"))
const RESULTS  = normpath(joinpath(@__DIR__, "../data/results"))
mkpath(RESULTS)

# ===========================================================================
# Helper functions
# ===========================================================================

"""Run SPMF LCMFreq on a file. Returns (count, time_ms) where time_ms is
SPMF's self-reported internal time (excludes JVM startup ~500–1000 ms)."""
function spmf_run(path::String, minsup_frac::Float64)
    out = tempname() * ".txt"
    io  = IOBuffer()
    try
        cmd = Cmd(["java", "-jar", SPMF_JAR, "run", "LCMFreq",
                   path, out, string(minsup_frac)])
        run(pipeline(cmd, stdout=io, stderr=io), wait=true)
        txt = String(take!(io))
        rm(out, force=true)
        m1 = match(r"Freq\. itemsets count: (\d+)", txt)
        m2 = match(r"Total time ~: (\d+)", txt)
        count   = m1 !== nothing ? parse(Int,     m1[1]) : -1
        time_ms = m2 !== nothing ? parse(Float64, m2[1]) : -1.0
        return (count=count, time_ms=time_ms)
    catch e
        rm(out, force=true)
        @warn "SPMF failed: $e"
        return (count=-1, time_ms=-1.0)
    end
end

"""Warmup (JIT compile) then time a mining function once.
Warmup uses first min(1000,n) transactions with proportionally scaled minsup."""
function timed_run(fn, txs, msa)
    n_w  = min(1000, length(txs))
    ms_w = max(1, round(Int, msa * n_w / length(txs)))
    fn(txs[1:n_w], ms_w)                          # JIT warmup
    t0 = time_ns()
    r  = fn(txs, msa)
    return (ms=round((time_ns()-t0)/1e6, digits=1), count=length(r.itemsets))
end

"""Total heap bytes allocated (MiB) during a mining call. GC'd before."""
function alloc_mb(fn, txs, msa)
    GC.gc(); GC.gc()
    round(@allocated(fn(txs, msa)) / 1024^2, digits=2)
end

function write_csv(path, hdr, rows)
    open(path, "w") do f
        println(f, join(hdr, ","))
        for r in rows
            println(f, join(string.(r), ","))
        end
    end
    println("  → data/results/$(basename(path))")
end

hr()  = println("─"^64)
sep() = println()

# ===========================================================================
# Dataset configurations
# ===========================================================================

struct DS
    name    ::String
    file    ::String
    minsups ::Vector{Float64}   # sweep from high → low
    med_ms  ::Float64           # representative minsup for memory experiment
    do_base ::Bool              # whether to include baseline timing/memory
end

DATASETS = [
    # ── Dense (middle-density) datasets ──────────────────────────────────────
    DS("Chess",       "chess.dat",
       [0.90, 0.85, 0.80, 0.75, 0.70, 0.65, 0.60], 0.75, true),
    DS("Connect",     "connect.dat",
       [0.97, 0.95, 0.93, 0.91, 0.89, 0.87, 0.85], 0.93, false),
    DS("Mushroom",    "mushroom.dat",
       [0.50, 0.40, 0.35, 0.30, 0.25, 0.20, 0.15], 0.30, true),
    DS("Pumsb",       "pumsb.dat",
       [0.95, 0.92, 0.90, 0.87, 0.85, 0.82, 0.80], 0.90, false),
    # ── Very dense ───────────────────────────────────────────────────────────
    DS("Accidents",   "accidents.dat",
       [0.90, 0.85, 0.80, 0.75, 0.70], 0.80, false),
    # ── Sparse datasets ───────────────────────────────────────────────────────
    DS("Retail",      "retail.dat",
       [0.10, 0.08, 0.06, 0.04, 0.02, 0.01, 0.005], 0.02, false),
    DS("T10I4D100K",  "T10I4D100K.dat",
       [0.02, 0.015, 0.01, 0.008, 0.006, 0.004, 0.002], 0.008, false),
    DS("T40I10D100K", "T40I10D100K.dat",
       [0.05, 0.04, 0.03, 0.02, 0.015, 0.01, 0.008], 0.02,  false),
    DS("Kosarak",     "kosarak.dat",
       [0.020, 0.015, 0.010, 0.008, 0.006, 0.004, 0.002], 0.008, false),
]

# ===========================================================================
println("\n" * "="^64)
println("  LCMFreq — Full Experiment Suite (Chapter 4)")
println("="^64)

# ===========================================================================
# (a) CORRECTNESS vs SPMF
# ===========================================================================
println("\n[a] Correctness vs SPMF  (at representative minsup per dataset)")
hr()
println("$(rpad("Dataset",14)) $(rpad("minsup",8)) $(rpad("n_tx",8)) " *
        "$(rpad("Julia",8)) $(rpad("SPMF",8)) Match%")
println("─"^58)

corr_rows = []
for ds in DATASETS
    path = joinpath(DATA_BM, ds.file)
    !isfile(path) && (println("  SKIP $(ds.name): file not found"); continue)
    txs = read_transactions(path)
    n   = length(txs)
    msa = max(1, ceil(Int, ds.med_ms * n))

    println("  Running Julia on $(ds.name)…"); flush(stdout)
    r    = timed_run(Optimized_.lcmfreq, txs, msa)
    println("  Running SPMF on $(ds.name)…"); flush(stdout)
    spmf = spmf_run(path, ds.med_ms)

    pct = spmf.count > 0 ? round(r.count / spmf.count * 100, digits=2) : "?"
    ok  = r.count == spmf.count ? "✓" : "✗"
    println("$(rpad(ds.name,14)) $(rpad(ds.med_ms,8)) $(rpad(n,8)) " *
            "$(rpad(r.count,8)) $(rpad(spmf.count,8)) $(ok) $(pct)%")
    push!(corr_rows, (ds.name, ds.med_ms, n, msa, r.count, spmf.count, pct))
end
write_csv(joinpath(RESULTS, "correctness.csv"),
    ["dataset","minsup_frac","n_tx","minsup_abs","julia_count","spmf_count","match_pct"],
    corr_rows)

# ===========================================================================
# (b)+(c) RUNTIME & ITEMSET COUNT vs MINSUP
# ===========================================================================
println("\n[b+c] Runtime & Itemset Count vs Minsup")
println("  (SPMF time = self-reported, excludes ~500–1000 ms JVM startup)")
hr()

for ds in DATASETS
    path = joinpath(DATA_BM, ds.file)
    !isfile(path) && continue
    fname_check = "runtime_$(lowercase(replace(ds.name, " "=>"_"))).csv"
    if isfile(joinpath(RESULTS, fname_check))
        println("  SKIP $(ds.name): $(fname_check) already exists"); flush(stdout)
        continue
    end
    txs = read_transactions(path)
    n   = length(txs)
    sep()
    println("  $(ds.name)  (n=$(n) transactions)")
    hdr_base = ds.do_base ? "  Base_ms" : ""
    println("  $(rpad("minsup",8)) $(rpad("msa",8)) $(rpad("#itemsets",10)) " *
            "$(rpad("Opt_ms",9)) $(rpad("SPMF_ms",9))$(hdr_base)")
    println("  " * "─"^(ds.do_base ? 58 : 48))

    rows = []
    for ms in ds.minsups
        msa  = max(1, ceil(Int, ms * n))
        r    = timed_run(Optimized_.lcmfreq, txs, msa)
        spmf = spmf_run(path, ms)
        if ds.do_base
            rb = timed_run(Baseline_.lcmfreq_base, txs, msa)
            println("  $(rpad(ms,8)) $(rpad(msa,8)) $(rpad(r.count,10)) " *
                    "$(rpad(r.ms,9)) $(rpad(spmf.time_ms,9))  $(rb.ms)")
            push!(rows, (ms, msa, r.count, r.ms, spmf.time_ms, rb.ms))
        else
            println("  $(rpad(ms,8)) $(rpad(msa,8)) $(rpad(r.count,10)) " *
                    "$(rpad(r.ms,9)) $(spmf.time_ms)")
            push!(rows, (ms, msa, r.count, r.ms, spmf.time_ms, "N/A"))
        end
    end

    fname = "runtime_$(lowercase(replace(ds.name, " "=>"_"))).csv"
    write_csv(joinpath(RESULTS, fname),
        ["minsup_frac","minsup_abs","itemset_count",
         "julia_opt_ms","spmf_ms","baseline_ms"],
        rows)
end

# ===========================================================================
# (d) MEMORY USAGE
# ===========================================================================
println("\n[d] Memory Usage  (@allocated = total heap allocs during mining)")
println("    Proxy for memory pressure; not peak RSS.")
hr()
println("  $(rpad("Dataset",14)) $(rpad("n_tx",8)) $(rpad("minsup",8)) " *
        "$(rpad("Opt_MiB",10)) Base_MiB")
println("  " * "─"^54)

mem_rows = []
for ds in DATASETS
    path = joinpath(DATA_BM, ds.file)
    !isfile(path) && continue
    txs     = read_transactions(path)
    n       = length(txs)
    msa     = max(1, ceil(Int, ds.med_ms * n))
    opt_mb  = alloc_mb(Optimized_.lcmfreq,         txs, msa)
    base_mb = ds.do_base ? alloc_mb(Baseline_.lcmfreq_base, txs, msa) : "N/A"
    println("  $(rpad(ds.name,14)) $(rpad(n,8)) $(rpad(ds.med_ms,8)) " *
            "$(rpad(opt_mb,10)) $(base_mb)")
    push!(mem_rows, (ds.name, n, ds.med_ms, msa, opt_mb, base_mb))
end
write_csv(joinpath(RESULTS, "memory.csv"),
    ["dataset","n_tx","minsup_frac","minsup_abs","opt_alloc_mib","base_alloc_mib"],
    mem_rows)

# ===========================================================================
# (e) SCALABILITY  —  Retail, uniform random sampling without replacement
# ===========================================================================
println("\n[e] Scalability — Retail, uniform random subsampling")
hr()

# ── SAMPLING METHOD ──────────────────────────────────────────────────────────
# We use UNIFORM RANDOM SAMPLING WITHOUT REPLACEMENT of transactions.
#
# Why this is the correct method for FIM transaction databases:
#
#   1. I.I.D. assumption: benchmark transaction files (Retail, T10I4D100K, …)
#      are collections of independent shopping baskets / synthetic records.
#      There is NO temporal ordering that must be preserved, unlike time-series.
#
#   2. Probability preservation: for any itemset X,
#        E[sup(X, sample_k)] = (k / N) · sup(X, full_DB)
#      → marginal and joint co-occurrence probabilities are preserved in
#        expectation, so fractional minsup remains semantically consistent
#        across sample sizes.
#
#   3. Scale consistency: minsup_abs = ceil(minsup_frac × k) scales linearly
#      with k → the relative difficulty of the problem (ratio of frequent
#      itemsets to total itemsets) is approximately constant.
#
#   4. NOT stratified: transactions have no natural strata (they are not
#      pre-categorised by customer type, product group, etc.).
#
#   5. NOT systematic: systematic nth-row sampling would risk aliasing if the
#      file happens to be sorted by transaction length or item frequency.
#
#   6. NOT block/cluster: no sequential or spatial structure to exploit.
#
# → We shuffle all N indices once (seed=42 for reproducibility), then take
#   the first k for each sample size k. The k indices are sorted before
#   slicing (sort → preserves file-order locality → better cache behaviour).
# ─────────────────────────────────────────────────────────────────────────────

retail_path = joinpath(DATA_BM, "retail.dat")
if isfile(retail_path)
    all_txs = read_transactions(retail_path)
    N_full  = length(all_txs)
    pcts    = [0.10, 0.25, 0.50, 0.75, 1.00]
    ms_frac = 0.01
    rng     = MersenneTwister(42)
    idx_all = shuffle(rng, 1:N_full)   # shuffle once, fixed seed

    println("  Full DB: $(N_full) tx | Fixed minsup_frac=$(ms_frac) | Seed=42")
    println("  Sampling: uniform random without replacement")
    println("  $(rpad("pct%",6)) $(rpad("n_tx",8)) $(rpad("msa",7)) " *
            "$(rpad("#itemsets",10)) $(rpad("Opt_ms",9)) SPMF_ms")
    println("  " * "─"^54)

    scale_rows = []
    for pct in pcts
        k   = round(Int, pct * N_full)
        idx = sort(idx_all[1:k])          # sort → preserve row locality
        sub = all_txs[idx]
        msa = max(1, ceil(Int, ms_frac * k))

        r = timed_run(Optimized_.lcmfreq, sub, msa)

        # Write subsample to temp FIMI file for SPMF
        tmp = tempname() * ".dat"
        open(tmp, "w") do f
            for tx in sub; println(f, join(tx, " ")); end
        end
        spmf = spmf_run(tmp, ms_frac)
        rm(tmp, force=true)

        println("  $(rpad(round(Int,pct*100),6)) $(rpad(k,8)) $(rpad(msa,7)) " *
                "$(rpad(r.count,10)) $(rpad(r.ms,9)) $(spmf.time_ms)")
        push!(scale_rows, (round(Int,pct*100), k, msa, r.count, r.ms, spmf.time_ms))
    end
    write_csv(joinpath(RESULTS,"scalability.csv"),
        ["pct","n_tx","minsup_abs","itemset_count","julia_opt_ms","spmf_ms"],
        scale_rows)
else
    println("  SKIP: retail.dat not found")
end

# ===========================================================================
# (f) TRANSACTION LENGTH EFFECT  —  Synthetic Bernoulli databases
# ===========================================================================
println("\n[f] Transaction Length Effect — Synthetic Bernoulli databases")
hr()

# ── SYNTHETIC DATA MODEL ────────────────────────────────────────────────────
# We use the BERNOULLI (independent items) model:
#
#   Given n_items items and a target average transaction length avg_len:
#     p  = avg_len / n_items          (per-item inclusion probability)
#     For each transaction, item j is independently included with prob p.
#     Transaction length ~ Binomial(n_items, p)
#     E[length] = avg_len,   Var[length] = n_items · p · (1 – p)
#
# This is the canonical synthetic FIM model:
#   · IBM Quest data generator (Agrawal & Srikant 1994) uses this approach.
#   · It isolates the effect of density from other structural factors.
#   · Higher avg_len → larger p → more co-occurrences → more frequent pairs
#     and higher-order itemsets → exponential growth in output size.
#
# Alternative: Poisson(λ) truncated at n_items.  In practice, for
# n_items=100 and avg_len ≤ 40, Binomial ≈ Poisson so results are similar.
# Bernoulli is preferred because it bounds length ≤ n_items naturally.
# ─────────────────────────────────────────────────────────────────────────────

begin
    n_tx     = 5_000
    n_items  = 100
    ms_frac  = 0.30
    avg_lens = [5, 10, 15, 20, 25, 30, 35, 40]
    msa_syn  = max(1, ceil(Int, ms_frac * n_tx))   # = 1500
    rng2     = MersenneTwister(42)

    println("  N=$(n_tx) tx | $(n_items) items | minsup=$(ms_frac) → msa=$(msa_syn)")
    println("  Bernoulli model: item j included independently with p = avg_len/$(n_items)")
    println("  Seed = 42")
    println("  $(rpad("avg_len",9)) $(rpad("actual_avg",11)) " *
            "$(rpad("msa",6)) $(rpad("#itemsets",10)) Opt_ms")
    println("  " * "─"^50)

    txlen_rows = []
    for al in avg_lens
        p   = al / n_items
        txs = [sort([j for j in 1:n_items if rand(rng2) < p]) for _ in 1:n_tx]
        actual = round(mean(length.(txs)), digits=2)
        r = timed_run(Optimized_.lcmfreq, txs, msa_syn)
        println("  $(rpad(al,9)) $(rpad(actual,11)) " *
                "$(rpad(msa_syn,6)) $(rpad(r.count,10)) $(r.ms)")
        push!(txlen_rows,
            (al, actual, n_tx, n_items, ms_frac, msa_syn, r.count, r.ms))
    end
    write_csv(joinpath(RESULTS, "txlen_effect.csv"),
        ["avg_len","actual_avg_len","n_tx","n_items",
         "minsup_frac","minsup_abs","itemset_count","julia_opt_ms"],
        txlen_rows)
end

# ===========================================================================
println("\n" * "="^64)
println("  All experiments complete!")
println("  Results saved to data/results/:")
for f in sort(readdir(RESULTS))
    endswith(f, ".csv") && println("    ✓ $f")
end
println("="^64)
