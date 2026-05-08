# LCMFreq - Khai thác Tập Phổ Biến (Lab 2)

Cài đặt thuật toán **LCMFreq** (Uno et al., FIMI 2004) cho bài toán Frequent Itemset Mining.
Môn: CSC14004, HK2 2025/2026, HCMUS.

Hai phiên bản:

| | TID-set | Phép giao |
|--|---------|-----------|
| `lcmfreq_base.jl` | `Vector{Int}` | merge sort O(\|A\|+\|B\|) |
| `lcmfreq.jl` | `BitArray{1}` + `Dict` | AND bit (SIMD) + POPCNT |

## Cấu trúc

```
.
├── src/
│   ├── algorithm/lcmfreq.jl          # phiên bản BitArray
│   ├── algorithm/lcmfreq_base.jl     # phiên bản baseline
│   ├── io/reader.jl
│   └── utils/utils.jl
├── tests/
│   ├── test_correctness.jl
│   └── test_benchmark.jl
├── notebooks/demo.ipynb
├── scripts/
│   ├── setup.jl
│   ├── run_experiments.jl
│   ├── benchmark_baseline_vs_opt.jl
│   └── plot_results.py
├── data/
│   ├── benchmark/
│   ├── results/
│   └── toy/
├── docs/Report.pdf
└── Project.toml
```

## Setup

Yêu cầu: Julia >= 1.9, Python >= 3.9, Java >= 8.

```bash
julia --project=. scripts/setup.jl
```

## Chạy

```bash
julia --project=. src/algorithm/lcmfreq.jl data/benchmark/chess.dat output.txt 0.80
```

Hoặc từ REPL:

```julia
julia> include("src/algorithm/lcmfreq.jl")
julia> result = lcmfreq(read_transactions("data/benchmark/mushroom.dat"), 300)
```

Output format: `1 3 5 #SUP: 42`

## Tests

```bash
julia --project=. tests/test_correctness.jl
```

18/18 pass, kết quả khớp 100% SPMF trên tất cả datasets.

## Thực nghiệm

```bash
julia --project=. scripts/run_experiments.jl
```

Chạy khoảng 20-60 phút, ghi CSV vào `data/results/`. Vẽ biểu đồ:

```bash
python scripts/plot_results.py
```

## Datasets

| Dataset | #Trans | #Items | AvgLen | Loại |
|---------|--------|--------|--------|------|
| Chess | 3,196 | 75 | 37.0 | dense |
| Mushroom | 8,124 | 119 | 23.0 | dense |
| Connect | 67,557 | 129 | 43.0 | dense |
| Pumsb | 49,046 | 2,113 | 74.0 | dense |
| Retail | 88,162 | 16,470 | 10.3 | sparse |
| T10I4D100K | 100,000 | 870 | 10.1 | synthetic |
| T40I10D100K | 100,000 | 942 | 39.6 | synthetic |
| Accidents | 340,183 | 468 | 33.8 | dense, >25MB |
| Kosarak | 990,002 | 41,270 | 8.1 | sparse, >25MB |

accidents.dat và kosarak.dat không có trong repo (>25MB). Tải từ http://fimi.uantwerpen.be/data/

## Kết quả

Speedup của `lcmfreq.jl` so với SPMF Java:

| Dataset | median | max |
|---------|--------|-----|
| Chess | 135x | 241x |
| Mushroom | 58x | 101x |
| Connect | 6x | 34x |
| Pumsb | 343x | 343x |
| Accidents | 7x | 22x |
| Retail | 2x | 6x |
| T10I4D100K | 8x | 9x |
| T40I10D100K | 32x | 32x |

Báo cáo: [docs/Report.pdf](docs/Report.pdf)

## Tài liệu tham khảo

- Uno, Kiyomi, Arimura (2004). *LCM ver.2*. FIMI 2004. [PDF](materials/LCMFreq.pdf)
- Fournier-Viger et al. (2017). *SPMF*. https://www.philippe-fournier-viger.com/spmf/
- Agrawal, Srikant (1994). *Fast Algorithms for Mining Association Rules*. VLDB.
