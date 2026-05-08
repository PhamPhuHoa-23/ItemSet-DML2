# LCMFreq — Frequent Itemset Mining Lab (Lab 2)

Implementation and experimental evaluation of the **LCMFreq** algorithm
(Uno et al., 2004) for mining all frequent itemsets from transaction databases.

Two implementations are provided and compared:

| Variant | TID-set structure | Intersection |
|---------|-------------------|--------------|
| **Baseline** (`lcmfreq_base.jl`) | `Vector{Int}` — sorted TID list | Merge O(\|A\|+\|B\|) |
| **Optimised** (`lcmfreq.jl`) | `BitArray{1}` — bit-vector + `Dict` | Bitwise AND + POPCNT |

Experiments run on **9 benchmark datasets** from the FIMI repository and are
compared against the SPMF Java reference implementation.

---

## Project Structure

```
FrequentItemsetMining_Lab2/
├── src/
│   ├── structures.jl              # Core type definitions (FrequentItem, LCMFreqResult)
│   ├── algorithm/
│   │   ├── lcmfreq_base.jl        # Baseline implementation (OccurrenceDeliver + Vector{Int})
│   │   └── lcmfreq.jl             # Optimised implementation (BitArray + Dict)
│   ├── utils/
│   │   └── utils.jl               # Shared helpers (I/O, support counting, timing)
│   └── io/
├── tests/
│   ├── test_correctness.jl        # Unit & correctness tests (24 tests)
│   └── test_benchmark.jl          # Benchmark correctness vs SPMF (all 9 datasets)
├── notebooks/
│   ├── run_experiments.jl         # Full experiment suite (a–f)
│   ├── plot_results.py            # Generate all result figures
│   └── demo.ipynb                 # Interactive demo notebook
├── docs/
│   ├── Report.pdf                 # Final report
│   └── LaTeX/
│       └── report.tex             # Report source
├── data/
│   ├── benchmark/                 # 9 FIMI datasets (.dat files)
│   ├── results/                   # Experiment CSVs
│   │   └── figures/               # Generated PNG charts
│   └── toy/                       # Small toy datasets for unit tests
├── tools/
│   └── spmf/spmf.jar              # SPMF reference (v0.96r18)
└── Project.toml
```

---

## Environment Setup

**Requirements:** Julia ≥ 1.9, Python ≥ 3.9 (with matplotlib), Java ≥ 8

```powershell
# 1. Clone / open project in VS Code
cd FrequentItemsetMining_Lab2

# 2. Install Julia dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"

# 3. Install Python dependencies
pip install matplotlib numpy
```

---

## Running the Algorithm

```julia
# Interactive (Julia REPL)
julia --project=.
julia> include("src/algorithm/lcmfreq.jl")
julia> txs = read_transactions("data/benchmark/mushroom.dat")
julia> result = lcmfreq(txs, 300)          # minsup = 300 transactions
julia> println(length(result.itemsets), " frequent itemsets found")

# From the command line (optimised)
julia --project=. src/algorithm/lcmfreq.jl data/benchmark/chess.dat 0.80

# From the command line (baseline)
julia --project=. src/algorithm/lcmfreq_base.jl data/benchmark/chess.dat 0.80
```

---

## Running Tests

### Unit & Correctness Tests (24 tests)

```powershell
julia --project=. tests/test_correctness.jl
```

Expected output:
```
Test Summary:                         | Pass  Total  Time
contextPasquier99 known answer        |    4      4   0.5s
Baseline == Optimized agreement       |    6      6   1.2s
Edge cases                            |    9      9   0.3s
Chess benchmark itemset counts        |    5      5  18.4s
  ✓ All tests completed.
```

### Benchmark Correctness Tests (all 9 datasets vs SPMF)

> Run experiments first to generate `data/results/correctness.csv`

```powershell
julia --project=. tests/test_benchmark.jl
```

---

## Running Experiments

The full experiment suite (experiments a–f from the assignment):

```powershell
julia --project=. notebooks/run_experiments.jl
```

This runs (~20–60 minutes depending on hardware):
- **(a)** Correctness: compare Julia Opt vs SPMF vs Baseline counts
- **(b)** Runtime vs minsup sweep for all 9 datasets
- **(c)** Memory usage (heap allocation) for all datasets
- **(d)** Scalability: runtime vs DB size (Retail, minsup=1%)
- **(e)** Transaction length effect (Bernoulli synthetic DB)
- **(f)** Association rule mining (MBA example)

Results are written to `data/results/`:

| File | Contents |
|------|----------|
| `correctness.csv` | itemset counts (Julia Opt, SPMF, Baseline) per dataset/minsup |
| `runtime_<dataset>.csv` | runtime (ms) × minsup for each dataset |
| `memory.csv` | heap allocations (MiB) per dataset |
| `scalability.csv` | runtime vs DB size (Retail) |
| `txlen_effect.csv` | runtime & #itemsets vs avg transaction length |

---

## Generating Plots

```powershell
$env:PYTHONIOENCODING="utf-8"
python notebooks/plot_results.py
```

Saves ~17 PNG figures to `data/results/figures/`.

---

## Benchmark Datasets

Downloaded from the [FIMI Repository](http://fimi.uantwerpen.be/data/):

| Dataset | #Transactions | #Items | Avg Length | Type |
|---------|--------------|--------|------------|------|
| Chess | 3,196 | 75 | 37.0 | Dense |
| Connect | 67,557 | 129 | 43.0 | Dense |
| Mushroom | 8,124 | 119 | 23.0 | Dense |
| Pumsb | 49,046 | 2,113 | 74.0 | Dense |
| Accidents | 340,183 | 468 | 33.8 | Dense/Middle |
| Retail | 88,162 | 16,469 | 10.3 | Sparse |
| T10I4D100K | 100,000 | 870 | 10.1 | Sparse (synthetic) |
| T40I10D100K | 100,000 | 942 | 39.6 | Sparse (synthetic) |
| Kosarak | 990,002 | 41,270 | 8.1 | Very sparse |

> Data files are not included in the repository (total ~112 MB).
> Download from http://fimi.uantwerpen.be/data/ and place in `data/benchmark/`.

---

## Key Results Summary

- **Julia Optimised** is **3–12× faster than SPMF** (Java) on dense datasets,
  and **comparable or faster** on sparse datasets.
- **BitArray AND intersection** is ~8× faster than `Vector{Int}` merge for large
  dense tidsets; POPCNT makes support counting essentially free.
- **Baseline** runs out of memory on Kosarak (41,270 distinct items → 5 GB
  for a full-length BitArray indexed by item ID); the optimised `Dict` approach
  allocates only for frequent items.
- LCMFreq exhibits near-linear scalability with DB size (Retail, minsup=1%).
- Transaction length has a super-linear effect on #itemsets near the
  dense/sparse phase transition (~avg_len 28–32 for N=5000, 100 items, minsup=30%).

---

## Report

The full lab report is at [docs/Report.pdf](docs/Report.pdf).

---

## References

1. Uno, T., Kiyomi, M., Arimura, H. (2004). *LCMFreq: A faster algorithm for mining
   frequent closed sets*. FIMI'04. [PDF](https://fimi.uantwerpen.be/src/lcm2.pdf)
2. Fournier-Viger, P. et al. (2016). *The SPMF Open-Source Data Mining Library
   Version 2*. ECML/PKDD. https://www.philippe-fournier-viger.com/spmf/
