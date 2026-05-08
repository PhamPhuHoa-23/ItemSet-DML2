# LCMFreq — Khai thác Tập Phổ Biến (Lab 2)

Cài đặt và đánh giá thuật toán **LCMFreq** (Uno, Kiyomi & Arimura, FIMI 2004) cho bài toán Frequent Itemset Mining.  
Môn học: **CSC14004 — Khai thác Dữ liệu và Ứng dụng**, HK2 2025/2026, HCMUS.

Hai cài đặt được so sánh:

| Phiên bản | Cấu trúc TID-set | Phép giao |
|-----------|------------------|-----------|
| **Baseline** (`lcmfreq_base.jl`) | `Vector{Int}` — danh sách TID sắp xếp | Merge O(\|A\|+\|B\|) |
| **Optimised** (`lcmfreq.jl`) | `BitArray{1}` + `Dict` | AND bit (SIMD) + POPCNT |

Thực nghiệm trên **9 benchmark datasets** (FIMI Repository), so sánh với SPMF Java.

---

## Cấu trúc thư mục

```
ItemSet-DML2/
├── Project.toml               # Julia dependencies
├── src/
│   ├── algorithm/
│   │   ├── lcmfreq.jl         # Optimised (BitArray + Dict)
│   │   └── lcmfreq_base.jl    # Baseline (OccurrenceDeliver + Vector{Int})
│   ├── io/reader.jl            # Đọc file SPMF format
│   ├── structures.jl           # FrequentItem, LCMFreqResult
│   └── utils/utils.jl
├── tests/
│   ├── test_correctness.jl    # 24 test cases (toy + benchmark + edge cases)
│   └── test_benchmark.jl      # Benchmark correctness vs SPMF
├── notebooks/
│   └── demo.ipynb             # Interactive Julia demo (Jupyter)
├── scripts/
│   ├── setup.jl               # Cài đặt và kiểm tra môi trường
│   ├── run_experiments.jl     # Toàn bộ thực nghiệm (a–f)
│   ├── run_light.jl           # Quick run (subset datasets)
│   ├── plot_results.py        # Vẽ 14 biểu đồ kết quả
│   └── benchmark.jl           # BenchmarkTools micro-benchmarks
├── data/
│   ├── benchmark/             # 7 datasets nhỏ (<25 MB, xem bảng bên dưới)
│   ├── results/               # CSV + PNG kết quả thực nghiệm
│   └── toy/                   # CSDL nhỏ cho ví dụ tay
├── docs/
│   ├── Report.pdf             # Báo cáo hoàn chỉnh
│   └── LaTeX/report.tex       # Source LaTeX
└── materials/
    ├── Description.pdf        # Đề bài
    └── LCMFreq.pdf            # Bài báo gốc (Uno et al., 2004)
```

---

## Yêu cầu

- **Julia** ≥ 1.9 (khuyến nghị 1.12)
- **Python** ≥ 3.9 với `matplotlib`, `numpy`, `seaborn` (chỉ để vẽ biểu đồ)
- **Java** ≥ 8 + SPMF jar (để chạy thực nghiệm đầy đủ)

---

## Cài đặt môi trường

```bash
# Cài Julia dependencies (tạo Manifest.toml tự động)
julia --project=. scripts/setup.jl
```

---

## Chạy thuật toán

```julia
# CLI — optimised
julia --project=. src/algorithm/lcmfreq.jl data/benchmark/chess.dat 0.80

# CLI — baseline
julia --project=. src/algorithm/lcmfreq_base.jl data/benchmark/chess.dat 0.80

# REPL
julia --project=.
julia> include("src/algorithm/lcmfreq.jl")
julia> txs    = read_transactions("data/benchmark/mushroom.dat")
julia> result = lcmfreq(txs, 300)
julia> println(length(result.itemsets), " frequent itemsets")
```

Định dạng đầu ra (SPMF-compatible):
```
2 3 5 #SUP: 3
1 2 3 5 #SUP: 2
...
```

---

## Chạy tests

```bash
# 24 test cases — toy datasets, benchmark, edge cases
julia --project=. tests/test_correctness.jl
```

Kết quả mong đợi: **24/24 Pass**, khớp 100% với SPMF trên tất cả input.

---

## Chạy thực nghiệm

```bash
# Toàn bộ (20–60 phút tuỳ phần cứng)
julia --project=. scripts/run_experiments.jl

# Quick run — subset datasets, 5 minsup levels
julia --project=. scripts/run_light.jl
```

Kết quả ghi vào `data/results/`:

| File | Nội dung |
|------|----------|
| `correctness.csv` | Số lượng frequent itemsets (Julia vs SPMF) |
| `runtime_<dataset>.csv` | Thời gian chạy (ms) theo minsup |
| `memory.csv` | Peak RAM (MiB) theo dataset |
| `scalability.csv` | Runtime vs kích thước CSDL (Retail) |
| `txlen_effect.csv` | Runtime & #itemsets vs avg transaction length |

```bash
# Vẽ biểu đồ sau khi có CSV
$env:PYTHONIOENCODING="utf-8"
python scripts/plot_results.py
```

---

## Tập dữ liệu benchmark

| Dataset | #Trans. | #Items | AvgLen | Đặc điểm | Trong repo |
|---------|---------|--------|--------|-----------|------------|
| Chess | 3,196 | 75 | 37.0 | Dense | ✓ |
| Mushroom | 8,124 | 119 | 23.0 | Dense | ✓ |
| Connect | 67,557 | 129 | 43.0 | Dense | ✓ |
| Pumsb | 49,046 | 2,113 | 74.0 | Dense | ✓ |
| Retail | 88,162 | 16,470 | 10.3 | Sparse | ✓ |
| T10I4D100K | 100,000 | 870 | 10.1 | Synthetic | ✓ |
| T40I10D100K | 100,000 | 942 | 39.6 | Synthetic | ✓ |
| Accidents | 340,183 | 468 | 33.8 | Dense, lớn | Google Drive¹ |
| Kosarak | 990,002 | 41,270 | 8.1 | Very sparse | Google Drive¹ |

> ¹ **accidents.dat** và **kosarak.dat** vượt 25 MB — tải tại:  
> http://fimi.uantwerpen.be/data/ · đặt vào `data/benchmark/`

---

## Kết quả chính

**Correctness:** Kết quả khớp **100%** với SPMF trên cả 9 datasets.

**Speedup Julia Opt vs SPMF Java:**

| Dataset | Trung vị | Min | Max |
|---------|----------|-----|-----|
| Chess | 135× | 22× | 241× |
| Mushroom | 58× | 23× | 101× |
| Connect | 6× | 1× | 34× |
| Pumsb | **343×** | 12× | **343×** |
| Accidents | 7× | 2× | 22× |
| Retail | 2× | 1× | 6× |
| T10I4D100K | 8× | 4× | 9× |
| T40I10D100K | 32× | 21× | 32× |

**Bộ nhớ:** BitArray tiết kiệm ~64× so với `Vector{Int}`; `Dict`-based allocation giải quyết OOM trên Retail/Kosarak (max item ID = 41,270).

---

## Báo cáo

Báo cáo đầy đủ: [`docs/Report.pdf`](docs/Report.pdf)  
Source LaTeX: [`docs/LaTeX/report.tex`](docs/LaTeX/report.tex)

---

## Tài liệu tham khảo

1. T. Uno, M. Kiyomi, H. Arimura (2004). *LCM ver.2: Efficient Mining Algorithms for Frequent/Closed/Maximal Itemsets.* FIMI 2004. [`materials/LCMFreq.pdf`](materials/LCMFreq.pdf)
2. P. Fournier-Viger et al. (2017). *A Survey of Sequential Pattern Mining.* SPMF: https://www.philippe-fournier-viger.com/spmf/
3. R. Agrawal, R. Srikant (1994). *Fast Algorithms for Mining Association Rules.* VLDB 1994.
