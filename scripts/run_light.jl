"""
run_light.jl — Chỉ Julia timing cho T40I10D100K và Kosarak (nhanh, không nóng máy)
"""

module Optimized_
    include(joinpath(@__DIR__, "../src/algorithm/lcmfreq.jl"))
end
include(joinpath(@__DIR__, "../src/io/reader.jl"))

const SPMF_JAR = normpath(joinpath(@__DIR__, "../tools/spmf/spmf.jar"))
const DATA_BM  = normpath(joinpath(@__DIR__, "../data/benchmark"))
const RESULTS  = normpath(joinpath(@__DIR__, "../data/results"))

function spmf_run(path, ms)
    out = tempname() * ".txt"; io = IOBuffer()
    try
        run(pipeline(Cmd(["java","-jar",SPMF_JAR,"run","LCMFreq",path,out,string(ms)]),
            stdout=io, stderr=io), wait=true)
        txt = String(take!(io)); rm(out,force=true)
        m1 = match(r"Freq\. itemsets count: (\d+)", txt)
        m2 = match(r"Total time ~: (\d+)", txt)
        return (count=m1!==nothing ? parse(Int,m1[1]) : -1,
                time_ms=m2!==nothing ? parse(Float64,m2[1]) : -1.0)
    catch; rm(out,force=true); return (count=-1, time_ms=-1.0) end
end

function timed_run(fn, txs, msa)
    n_w = min(1000,length(txs)); ms_w = max(1,round(Int,msa*n_w/length(txs)))
    fn(txs[1:n_w], ms_w)
    t0 = time_ns(); r = fn(txs, msa)
    (ms=round((time_ns()-t0)/1e6,digits=1), count=length(r.itemsets))
end

function write_csv(path, hdr, rows)
    open(path,"w") do f
        println(f, join(hdr,",")); for r in rows; println(f, join(string.(r),",")); end
    end
    println("  → $(basename(path))")
end

println("\n=== Light runtime sweep ===\n")

# ── T40I10D100K: chỉ minsup cao (SPMF nhanh), minsup thấp chỉ Julia ─────────
let ds_name="T40I10D100K", ds_file="T40I10D100K.dat",
    out_path=joinpath(RESULTS,"runtime_t40i10d100k.csv")
    isfile(out_path) && (println("SKIP T40: already exists"); @goto skip_t40)
    path = joinpath(DATA_BM, ds_file)
    !isfile(path) && (println("SKIP T40: file not found"); @goto skip_t40)
    txs = read_transactions(path); n = length(txs)
    println("--- T40I10D100K  (n=$n) ---")
    rows = []
    # minsup cao: chạy cả SPMF (nhanh vì ít itemsets)
    for ms in [0.05, 0.03]
        msa = max(1,ceil(Int,ms*n))
        r   = timed_run(Optimized_.lcmfreq, txs, msa)
        sp  = spmf_run(path, ms)
        println("  ms=$ms  items=$(r.count)  Julia=$(r.ms)ms  SPMF=$(sp.time_ms)ms")
        push!(rows, (ms, msa, r.count, r.ms, sp.time_ms, "N/A"))
        flush(stdout)
    end
    # minsup thấp: chỉ Julia
    for ms in [0.02, 0.01, 0.005]
        msa = max(1,ceil(Int,ms*n))
        r   = timed_run(Optimized_.lcmfreq, txs, msa)
        println("  ms=$ms  items=$(r.count)  Julia=$(r.ms)ms  SPMF=N/A")
        push!(rows, (ms, msa, r.count, r.ms, -1.0, "N/A"))
        flush(stdout)
    end
    write_csv(out_path,
        ["minsup_frac","minsup_abs","itemset_count","julia_opt_ms","spmf_ms","baseline_ms"],
        rows)
    @label skip_t40
end

# ── Kosarak: tương tự ────────────────────────────────────────────────────────
let ds_name="Kosarak", ds_file="kosarak.dat",
    out_path=joinpath(RESULTS,"runtime_kosarak.csv")
    isfile(out_path) && (println("SKIP Kosarak: already exists"); @goto skip_kos)
    path = joinpath(DATA_BM, ds_file)
    !isfile(path) && (println("SKIP Kosarak: file not found"); @goto skip_kos)
    txs = read_transactions(path); n = length(txs)
    println("\n--- Kosarak  (n=$n) ---")
    rows = []
    for ms in [0.020, 0.010]
        msa = max(1,ceil(Int,ms*n))
        r   = timed_run(Optimized_.lcmfreq, txs, msa)
        sp  = spmf_run(path, ms)
        println("  ms=$ms  items=$(r.count)  Julia=$(r.ms)ms  SPMF=$(sp.time_ms)ms")
        push!(rows, (ms, msa, r.count, r.ms, sp.time_ms, "N/A"))
        flush(stdout)
    end
    for ms in [0.008, 0.005, 0.002]
        msa = max(1,ceil(Int,ms*n))
        r   = timed_run(Optimized_.lcmfreq, txs, msa)
        println("  ms=$ms  items=$(r.count)  Julia=$(r.ms)ms  SPMF=N/A")
        push!(rows, (ms, msa, r.count, r.ms, -1.0, "N/A"))
        flush(stdout)
    end
    write_csv(out_path,
        ["minsup_frac","minsup_abs","itemset_count","julia_opt_ms","spmf_ms","baseline_ms"],
        rows)
    @label skip_kos
end

println("\nDone!")
