"""
plot_results.jl — Terminal charts for LCMFreq experiments (UnicodePlots.jl)
============================================================================
Mirrors the 13 individual charts from plot_results.py in terminal ASCII/Unicode.
For report-quality PNGs, use:  python notebooks/plot_results.py

Run:  julia --project=. notebooks/plot_results.jl
"""

using UnicodePlots
using DelimitedFiles

ROOT    = normpath(joinpath(@__DIR__, ".."))
RESULTS = joinpath(ROOT, "data", "results")

function read_csv(fname)
    path = joinpath(RESULTS, fname)
    lines = readlines(path)
    header = split(lines[1], ",")
    rows = []
    for line in lines[2:end]
        isempty(strip(line)) && continue
        vals = split(line, ",")
        push!(rows, Dict(zip(header, vals)))
    end
    return header, rows
end

hdr()  = println("─"^72)
title(s) = (println(); hdr(); println("  " * s); hdr())

datasets_rt = [
    ("Chess",      "runtime_chess.csv",      true),
    ("Mushroom",   "runtime_mushroom.csv",   true),
    ("Retail",     "runtime_retail.csv",     false),
    ("T10I4D100K", "runtime_t10i4d100k.csv", false),
    ("Accidents",  "runtime_accidents.csv",  false),
]

println("═"^72)
println("  LCMFreq — Terminal Charts  (mirror of plot_results.py)")
println("  13 individual charts — run python notebooks/plot_results.py for PNG")
println("═"^72)

# ── Charts 1–5: Individual runtime per dataset ────────────────────────────────
for (name, fname, has_base) in datasets_rt
    title("Runtime vs minsup — $name  (log scale)")
    _, rows = read_csv(fname)
    ms   = [parse(Float64, r["minsup_frac"]) * 100 for r in rows]
    opt  = [parse(Float64, r["julia_opt_ms"])       for r in rows]
    spmf = [parse(Float64, r["spmf_ms"])            for r in rows]

    p = lineplot(ms, opt,
        name   = "Julia Opt (BitArray)",
        xlabel = "minsup (%)",
        ylabel = "ms (log)",
        title  = "$name Runtime vs Minimum Support",
        yscale = :log10,
        canvas = BrailleCanvas,
        width  = 64, height = 14,
        color  = :blue)
    lineplot!(p, ms, spmf, name = "SPMF (Java)", color = :green)
    if has_base
        base = [parse(Float64, r["baseline_ms"]) for r in rows]
        lineplot!(p, ms, base, name = "Baseline (Vector)", color = :red)
    end
    println(p)
    speedups = round.(spmf ./ opt; digits=0)
    println("  Speedup vs SPMF: ", join(["$(Int(s))×" for s in speedups], "  "))
end

# ── Chart 6: #Itemsets — all datasets ────────────────────────────────────────
title("#Frequent Itemsets vs minsup — All Datasets (log scale)")
_, rows0 = read_csv(datasets_rt[1][2])
ms0 = [parse(Float64, r["minsup_frac"]) * 100 for r in rows0]
cnt0 = Float64[parse(Int, r["itemset_count"]) for r in rows0]
p_cnt = lineplot(ms0, cnt0,
    name   = datasets_rt[1][1],
    xlabel = "minsup (%)",
    ylabel = "#itemsets (log)",
    title  = "#Itemsets vs Minimum Support — All Datasets",
    yscale = :log10,
    canvas = BrailleCanvas,
    width  = 64, height = 14,
    color  = :magenta)
cols = [:red, :green, :blue, :yellow]
for (i, (name, fname, _)) in enumerate(datasets_rt[2:end])
    _, rows = read_csv(fname)
    ms  = [parse(Float64, r["minsup_frac"]) * 100 for r in rows]
    cnt = Float64[parse(Int, r["itemset_count"]) for r in rows]
    lineplot!(p_cnt, ms, cnt, name = name, color = cols[i])
end
println(p_cnt)

# ── Charts 7–8: Speedup summary ───────────────────────────────────────────────
title("Speedup — Julia Opt vs SPMF (median over minsup sweep)")
ds_labels   = String[]
su_spmf_med = Float64[]
su_base_med = Float64[]
su_spmf_min = Float64[]
su_spmf_max = Float64[]

for (name, fname, has_base) in datasets_rt
    _, rows = read_csv(fname)
    su = sort([parse(Float64, r["spmf_ms"]) / parse(Float64, r["julia_opt_ms"]) for r in rows])
    push!(ds_labels,   name)
    push!(su_spmf_med, su[div(length(su), 2) + 1])
    push!(su_spmf_min, su[1])
    push!(su_spmf_max, su[end])
    if has_base
        sub = sort([parse(Float64, r["baseline_ms"]) / parse(Float64, r["julia_opt_ms"]) for r in rows])
        push!(su_base_med, sub[div(length(sub), 2) + 1])
    else
        push!(su_base_med, 0.0)
    end
end

labels_with_range = ["$n  [$(Int(round(su_spmf_min[i])))–$(Int(round(su_spmf_max[i])))×]"
                     for (i, n) in enumerate(ds_labels)]
p_bar = barplot(labels_with_range, su_spmf_med,
    title  = "Median Speedup vs SPMF (Java)  [range shown in label]",
    xlabel = "Speedup (×)",
    color  = :green,
    width  = 60)
println(p_bar)

base_mask = su_base_med .> 0
if any(base_mask)
    println()
    p_base = barplot(ds_labels[base_mask], su_base_med[base_mask],
        title  = "Median Speedup vs Baseline (Vector)  — Chess & Mushroom only",
        xlabel = "Speedup (×)",
        color  = :red,
        width  = 60)
    println(p_base)
end

# ── Chart 9: Memory ───────────────────────────────────────────────────────────
title("Memory — Total Heap Allocations (MiB)")
_, mem_rows = read_csv("memory.csv")
mem_ds  = [r["dataset"]                          for r in mem_rows]
opt_mib = [parse(Float64, r["opt_alloc_mib"])    for r in mem_rows]
base_mib = [let v = tryparse(Float64, r["base_alloc_mib"]); v === nothing ? 0.0 : v end
            for r in mem_rows]

p_mem = barplot(mem_ds, opt_mib,
    title  = "Julia Optimised — Heap Allocated (MiB)",
    xlabel = "MiB",
    color  = :blue,
    width  = 60)
println(p_mem)

if any(base_mib .> 0)
    mask = base_mib .> 0
    p_memb = barplot(mem_ds[mask], base_mib[mask],
        title  = "Julia Baseline — Heap Allocated (MiB)  [Chess & Mushroom]",
        xlabel = "MiB",
        color  = :red,
        width  = 60)
    println(p_memb)
end

# ── Charts 10–11: Scalability ─────────────────────────────────────────────────
title("Scalability — Retail, minsup=1%, uniform random subsampling")
_, sc_rows = read_csv("scalability.csv")
pcts    = [parse(Int,     r["pct"])           for r in sc_rows]
n_txs   = [parse(Int,     r["n_tx"])           for r in sc_rows]
opt_ms  = [parse(Float64, r["julia_opt_ms"])   for r in sc_rows]
spmf_ms = [parse(Float64, r["spmf_ms"])        for r in sc_rows]
lin_ref = [opt_ms[1] * n / n_txs[1]            for n in n_txs]

p_sc = lineplot(n_txs, opt_ms,
    name   = "Julia Opt",
    xlabel = "n_tx",
    ylabel = "ms",
    title  = "Runtime vs DB Size (n_tx)",
    canvas = BrailleCanvas,
    width  = 64, height = 12,
    color  = :blue)
lineplot!(p_sc, n_txs, spmf_ms, name = "SPMF",           color = :green)
lineplot!(p_sc, n_txs, lin_ref, name = "Linear ref",      color = :yellow)
println(p_sc)

p_pct = lineplot(pcts, opt_ms,
    name   = "Julia Opt",
    xlabel = "% sampled",
    ylabel = "ms",
    title  = "Runtime vs Sample %  (dotted = perfect linear)",
    canvas = BrailleCanvas,
    width  = 64, height = 12,
    color  = :blue)
lineplot!(p_pct, pcts, spmf_ms, name = "SPMF",        color = :green)
lineplot!(p_pct, pcts, lin_ref, name = "Linear ref",  color = :yellow)
println(p_pct)

# ── Charts 12–13: Transaction length effect ───────────────────────────────────
title("Transaction Length Effect — Bernoulli synthetic, N=5000, minsup=30%")
_, tl_rows = read_csv("txlen_effect.csv")
avg_lens = [parse(Int,     r["avg_len"])        for r in tl_rows]
counts   = [parse(Int,     r["itemset_count"])  for r in tl_rows]
times    = [parse(Float64, r["julia_opt_ms"])   for r in tl_rows]

p_bar2 = barplot(string.(avg_lens), counts,
    title  = "#Itemsets vs Avg Transaction Length  (phase transition ≈ 30)",
    xlabel = "#itemsets",
    color  = :blue,
    width  = 64)
println(p_bar2)

p_tl = lineplot(avg_lens, times,
    name   = "Julia Opt",
    xlabel = "avg_len",
    ylabel = "ms",
    title  = "Runtime vs Avg Transaction Length  (phase transition ≈ 30)",
    canvas = BrailleCanvas,
    width  = 64, height = 12,
    color  = :red)
println(p_tl)

println()
println("═"^72)
println("  13 charts complete.  For PNG report figures:")
println("    python notebooks/plot_results.py")
println("═"^72)
