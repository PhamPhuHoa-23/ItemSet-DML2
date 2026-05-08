"""
run_remaining.jl — Chạy runtime sweep cho Pumsb, T40I10D100K, Kosarak
Không chạy baseline. Chỉ Julia Opt + SPMF.
"""

using Random, Statistics

module Optimized_
    include(joinpath(@__DIR__, "../src/algorithm/lcmfreq.jl"))
end

include(joinpath(@__DIR__, "../src/io/reader.jl"))

const SPMF_JAR = normpath(joinpath(@__DIR__, "../tools/spmf/spmf.jar"))
const DATA_BM  = normpath(joinpath(@__DIR__, "../data/benchmark"))
const RESULTS  = normpath(joinpath(@__DIR__, "../data/results"))
mkpath(RESULTS)

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

function timed_run(fn, txs, msa)
    n_w  = min(1000, length(txs))
    ms_w = max(1, round(Int, msa * n_w / length(txs)))
    fn(txs[1:n_w], ms_w)
    t0 = time_ns()
    r  = fn(txs, msa)
    return (ms=round((time_ns()-t0)/1e6, digits=1), count=length(r.itemsets))
end

function write_csv(path, hdr, rows)
    open(path, "w") do f
        println(f, join(hdr, ","))
        for r in rows
            println(f, join(string.(r), ","))
        end
    end
    println("  → $(basename(path))")
end

struct DS
    name    ::String
    file    ::String
    minsups ::Vector{Float64}
end

# Chỉ 3 dataset còn thiếu, minsup range hẹp hơn để nhanh hơn
DATASETS = [
    DS("Pumsb",       "pumsb.dat",
       [0.95, 0.90, 0.85, 0.80]),
    DS("T40I10D100K", "T40I10D100K.dat",
       [0.05, 0.03, 0.02, 0.01]),
    DS("Kosarak",     "kosarak.dat",
       [0.020, 0.010, 0.005, 0.002]),
]

println("\n=== Runtime sweep: Pumsb / T40I10D100K / Kosarak ===\n")

for ds in DATASETS
    fname_out = "runtime_$(lowercase(replace(ds.name, " "=>"_"))).csv"
    out_path  = joinpath(RESULTS, fname_out)
    if isfile(out_path)
        println("SKIP $(ds.name): already exists"); continue
    end

    path = joinpath(DATA_BM, ds.file)
    if !isfile(path)
        println("SKIP $(ds.name): data file not found"); continue
    end

    txs = read_transactions(path)
    n   = length(txs)
    println("--- $(ds.name)  (n=$(n)) ---")
    println("  minsup   msa        #items     Julia_ms   SPMF_ms")

    rows = []
    for ms in ds.minsups
        msa  = max(1, ceil(Int, ms * n))
        r    = timed_run(Optimized_.lcmfreq, txs, msa)
        spmf = spmf_run(path, ms)
        println("  $(rpad(ms,8)) $(rpad(msa,10)) $(rpad(r.count,10)) $(rpad(r.ms,10)) $(spmf.time_ms)")
        flush(stdout)
        push!(rows, (ms, msa, r.count, r.ms, spmf.time_ms, "N/A"))
    end

    write_csv(out_path,
        ["minsup_frac","minsup_abs","itemset_count","julia_opt_ms","spmf_ms","baseline_ms"],
        rows)
end

println("\nDone!")
