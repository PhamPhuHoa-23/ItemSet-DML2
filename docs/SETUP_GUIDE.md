# Hướng dẫn cài đặt môi trường – Frequent Itemset Mining (LCMFreq)

> Dự án: Đồ Án 2 – Khai thác tập phổ biến (CSC14004)
> Ngôn ngữ: **Julia ≥ 1.9**
> OS được test: Windows 10/11

---

## Bước 1 – Cài Julia qua Juliaup (trình quản lý phiên bản chính thức)

**Juliaup** là cách được khuyến nghị chính thức để cài và quản lý nhiều phiên bản Julia trên Windows.

### Option A – Dùng winget (nhanh nhất)

Mở **PowerShell** (không cần quyền Admin) và chạy:

```powershell
winget install --id Julialang.Juliaup -e --accept-source-agreements --accept-package-agreements
```

Sau khi cài xong, **khởi động lại terminal** để PATH được cập nhật.

### Option B – Tải installer thủ công

Truy cập <https://julialang.org/downloads/> → tải bản **Current stable release** cho Windows → chạy file `.exe`.

---

## Bước 2 – Cài Julia phiên bản mới nhất qua Juliaup

Sau khi juliaup đã được cài và terminal đã restart:

```powershell
# Cài Julia phiên bản stable mới nhất (>= 1.9)
juliaup add release

# Đặt làm phiên bản mặc định
juliaup default release
```

Kiểm tra:

```powershell
julia --version
# julia version 1.x.x
```

---

## Bước 3 – Clone / mở project

```powershell
cd đường/dẫn/tới/FrequentItemsetMining_Lab2
```

---

## Bước 4 – Kích hoạt môi trường Julia và cài dependencies

Project dùng `Project.toml` để quản lý packages.

> **Lưu ý PowerShell**: Không dùng `-e "..."` với nhiều dấu ngoặc kép lồng nhau trong PowerShell vì sẽ bị lỗi escape. Thay vào đó, tạo một file script `.jl` rồi chạy:

Tạo file `setup_env.jl` ở thư mục gốc project:

```julia
using Pkg
try Pkg.rm("Plots") catch end  # Xóa Plots nếu có (bị chặn bởi Application Control Policy)
try Pkg.rm("GR") catch end
Pkg.add(["DataStructures", "BenchmarkTools", "UnicodePlots"])
Pkg.instantiate()
println("All packages installed successfully!")
println("Julia version: ", VERSION)
```

Rồi chạy:

```powershell
julia --project=. setup_env.jl
```

Lần đầu sẽ mất **5–15 phút** vì Julia tải registry và compile artifacts (GR, Qt6, ...). Các lần sau sẽ rất nhanh.

Lệnh này sẽ:
- Kích hoạt môi trường local (`.`)
- Tải và cài đặt tất cả packages được khai báo trong `Project.toml`

---

## Bước 5 – Các packages sử dụng trong dự án

| Package | Mục đích |
|---|---|
| `DataStructures` | Cấu trúc dữ liệu nâng cao (Dict, Queue, ...) |
| `BenchmarkTools` | Đo thời gian chạy chính xác (`@benchmark`, `@btime`) |
| `Test` | Unit test tích hợp sẵn trong Julia stdlib |
| `Profile` | Profiling hiệu năng |
| `UnicodePlots` | Vẽ biểu đồ trực tiếp trong terminal (thay Plots.jl, không cần FFMPEG) |

Để thêm thủ công bất kỳ package nào:

```powershell
julia --project=. -e "using Pkg; Pkg.add(\"TênPackage\")"
```

---

## Bước 6 – Chạy thuật toán LCMFreq

```powershell
# Cú pháp cơ bản
julia --project=. src/algorithm/lcmfreq.jl <đường_dẫn_file_input> <minsup>

# Ví dụ
julia --project=. src/algorithm/lcmfreq.jl data/toy/example1.txt 2
```

**Định dạng file input (chuẩn SPMF):**
```
1 2 3 4
2 3 5
1 2 4 5
1 3 5
```
Mỗi dòng là một transaction, các item cách nhau bởi dấu cách.

---

## Bước 7 – Chạy unit tests

```powershell
julia --project=. test/runtests.jl
```

Hoặc từ trong Julia REPL:

```julia
using Pkg
Pkg.test()
```

---

## Bước 8 – Chạy demo notebook (Jupyter)

```powershell
# Cài IJulia nếu chưa có
julia --project=. -e "using Pkg; Pkg.add(\"IJulia\")"

# Mở Jupyter
jupyter notebook notebooks/demo.ipynb
```

---

## Lưu ý quan trọng khi setup

### Những gì bình thường (không phải lỗi)

| Thông báo | Ý nghĩa |
|---|---|
| `Tree Hash Mismatch ... System is Windows ... ignoring hash mismatch` | Windows không hỗ trợ symlink, Julia tự xử lý – **OK** |
| `Packages marked with ⌅ have new versions available` | Version bị giới hạn bởi compat – không ảnh hưởng chức năng |
| Precompiling mất 5–15 phút | Julia compile JIT lần đầu – chỉ xảy ra một lần |

### Không dùng `Plots.jl` trên máy có Application Control Policy (trường/công ty)

Trên Windows máy tính học đường hoặc doanh nghiệp có policy bảo mật, `Plots.jl` sẽ bị chặn vì nó dùng `FFMPEG_jll.dll`. Lỗi trông như:

```
Error opening package file FFMPEG_jll\*.dll: An Application Control policy has blocked this file.
```

**Giải pháp**: Dùng `UnicodePlots` thay thế – nhẹ hơn, không cần FFMPEG, vẽ đồ thị trực tiếp trong terminal.

### Tuyệt đối không dùng `julia -e "..."` với dấu ngoặc kép lồng nhau trong PowerShell

PowerShell xử lý escape khác với bash. Thay vào đó, luôn viết code vào file `.jl` và chạy `julia --project=. tênfile.jl`.

---

## Lưu ý hiệu năng (Julia-specific)

- Không dùng **global variable không typed** trong hot loop
- Dùng `@inbounds` khi truy cập mảng đã biết chắc index hợp lệ
- Dùng `BitArray` thay `Vector{Bool}` cho tidset (tiết kiệm ~8x bộ nhớ)
- Dùng `@btime` (BenchmarkTools) thay `@time` để đo chính xác (loại bỏ JIT warmup)
- Tránh dùng abstract type trong inner loop

---

## Troubleshooting

| Lỗi | Giải pháp |
|---|---|
| `julia: command not found` sau cài juliaup | Restart terminal / PowerShell |
| `ERROR: package X not found` | Chạy `Pkg.instantiate()` hoặc `Pkg.add("X")` |
| Kết quả không khớp SPMF | Kiểm tra minsup tuyệt đối vs tương đối (SPMF dùng absolute count) |
| Chạy test thất bại | Đảm bảo chạy đúng `julia --project=. test/runtests.jl` |

---

*Tài liệu này được cập nhật liên tục theo tiến độ dự án.*

---

## Bước 9 – Cài Java (yêu cầu cho SPMF)

SPMF là công cụ Java để kiểm tra tính đúng đắn (correctness) của cài đặt.

Kiểm tra Java đã có chưa:

```powershell
java -version
# java version "21.x.x" ...
```

Nếu chưa có, tải **OpenJDK 21** tại <https://adoptium.net/temurin/releases/?version=21> (Windows x64 `.msi`), cài như thông thường và restart terminal.

---

## Bước 10 – Tải SPMF (công cụ tham chiếu)

SPMF là thư viện Java với hàng trăm thuật toán khai thác dữ liệu, dùng để **kiểm tra kết quả** của cài đặt Julia.

Tải file jar về thư mục `tools\spmf\`:

```powershell
# Tạo thư mục
New-Item -ItemType Directory -Force -Path tools\spmf

# Tải spmf.jar (~16 MB)
Invoke-WebRequest -Uri "https://www.philippe-fournier-viger.com/spmf/spmf.jar" `
    -OutFile "tools\spmf\spmf.jar" -UseBasicParsing

# Kiểm tra
Get-Item tools\spmf\spmf.jar | Select-Object Name, @{N='Size(MB)';E={[math]::Round($_.Length/1MB,1)}}
```

Kết quả mong đợi: file khoảng **16 MB**.

### Kiểm tra SPMF hoạt động

```powershell
java -jar tools\spmf\spmf.jar run LCMFreq data\toy\sample_9tx.dat output_test.txt 0.4
Get-Content output_test.txt
Remove-Item output_test.txt
```

Kết quả mong đợi: xuất ra các dòng dạng `1 2 #SUP: N`, tổng 6 itemsets với minsup=0.4 (4/9 giao dịch).

---

## Bước 11 – Tải benchmark datasets

```powershell
New-Item -ItemType Directory -Force -Path data\benchmark
cd data\benchmark

$datasets = @{
    "chess.dat"        = "https://fimi.uantwerpen.be/data/chess.dat"
    "mushroom.dat"     = "https://fimi.uantwerpen.be/data/mushroom.dat"
    "T10I4D100K.dat"   = "https://fimi.uantwerpen.be/data/T10I4D100K.dat"
    "retail.dat"       = "https://fimi.uantwerpen.be/data/retail.dat"
    "connect.dat"      = "https://fimi.uantwerpen.be/data/connect.dat"
    "T40I10D100K.dat"  = "https://fimi.uantwerpen.be/data/T40I10D100K.dat"
    "pumsb.dat"        = "https://fimi.uantwerpen.be/data/pumsb.dat"
    "kosarak.dat"      = "https://fimi.uantwerpen.be/data/kosarak.dat"
    "accidents.dat"    = "https://fimi.uantwerpen.be/data/accidents.dat"
}
foreach ($d in $datasets.GetEnumerator()) {
    Write-Host "Downloading $($d.Key)..."
    Invoke-WebRequest -Uri $d.Value -OutFile $d.Key -UseBasicParsing
    Write-Host "  OK: $([math]::Round((Get-Item $d.Key).Length/1MB,1)) MB"
}

cd ../..
```

Tổng khoảng **112 MB**. Các file lớn nhất (kosarak ~31MB, accidents ~34MB) sẽ mất vài phút.

### Bảng tóm tắt datasets

| Dataset | Kích thước | #Transactions | #Items | Mật độ | Đặc điểm |
|---|---|---|---|---|---|
| chess.dat | 334 KB | 3,196 | 75 | 49% | Dense, chạy nhanh, test đầu tiên |
| mushroom.dat | 557 KB | 8,416 | 119 | 19% | Dense |
| T10I4D100K.dat | 3.8 MB | 100,000 | 870 | 1.2% | Synthetic, sparse |
| retail.dat | 4.0 MB | 88,162 | 16,470 | 0.06% | Real, rất sparse |
| connect.dat | 8.8 MB | 67,557 | 129 | 33% | Dense |
| T40I10D100K.dat | 14.8 MB | 100,000 | 942 | 4.3% | Synthetic, medium |
| pumsb.dat | 15.9 MB | 49,046 | 2,113 | 3.5% | Dense, transactions dài |
| kosarak.dat | 30.6 MB | 990,002 | 41,270 | 0.02% | Rất lớn, sparse |
| accidents.dat | 33.9 MB | 340,183 | 468 | 7.2% | Rất lớn, dense |

Assignment yêu cầu **tối thiểu 4**: chess, mushroom, retail, accidents, T10I4D100K.

---

## Bước 12 – Workflow kiểm tra tính đúng đắn (Correctness Check)

Sau khi cài đặt LCMFreq trong Julia, phải kiểm tra kết quả khớp 100% với SPMF.

### 1. Chạy SPMF (reference)

```powershell
java -jar tools\spmf\spmf.jar run LCMFreq data\benchmark\chess.dat spmf_chess_80.txt 0.8
```

### 2. Chạy Julia

```powershell
julia --project=. src\algorithm\lcmfreq.jl data\benchmark\chess.dat julia_chess_80.txt 0.8
```

### 3. Chuẩn hóa và so sánh

SPMF xuất định dạng: `1 3 7 #SUP: 2734`  
Julia nên xuất cùng định dạng.

Script PowerShell để so sánh tự động:

```powershell
# Chuẩn hóa: sort từng dòng theo item, rồi sort các dòng
function Normalize-Itemset($file) {
    Get-Content $file | ForEach-Object {
        if ($_ -match '(.*?)#SUP:\s*(\d+)') {
            $items = ($Matches[1].Trim() -split '\s+' | Sort-Object { [int]$_ }) -join ' '
            "$items #SUP: $($Matches[2])"
        }
    } | Sort-Object
}

$spmf = Normalize-Itemset "spmf_chess_80.txt"
$julia = Normalize-Itemset "julia_chess_80.txt"

if (Compare-Object $spmf $julia) {
    Write-Host "FAIL: Outputs differ!" -ForegroundColor Red
    Compare-Object $spmf $julia | Select-Object -First 10
} else {
    Write-Host "PASS: $($spmf.Count) itemsets match 100%!" -ForegroundColor Green
}
```

### Minsup: tuyệt đối vs tương đối

> **Quan trọng**: SPMF LCMFreq nhận minsup dưới dạng **số thập phân (0.0–1.0)** (tỉ lệ phần trăm).  
> Ví dụ: `0.8` = 80% transactions. Với chess.dat (3,196 tx), đây là `0.8 × 3196 = 2556` transactions.

---

## Tóm tắt kiến trúc tối ưu hóa (Optimization Plan)

Theo yêu cầu Description.pdf (Chương 3 – Cài đặt), cần implement **2 bản**:

### Bản 1 – Baseline (`src/algorithm/lcmfreq_base.jl`)
- Tidset dùng `Set{Int}` hoặc `Vector{Int}`
- Giao tidset bằng `intersect()`
- Mục đích: dễ hiểu, đúng với paper

### Bản 2 – Optimized (`src/algorithm/lcmfreq.jl`)
- Tidset dùng `BitArray` (N bits cho N transactions)
- Giao tidset bằng bitwise AND: `tidset_P .& tidset_i`
- Thêm `@inbounds` trên inner loops
- Tránh global variable không typed
- **Mục đích**: đo và báo cáo mức cải thiện so bản 1

```julia
# Baseline: Set{Int}
tidset_Pi = intersect(tidset_P, tidset_i)   # ~O(min(|A|,|B|))

# Optimized: BitArray
tidset_Pi = tidset_P .& tidset_i            # bitwise AND, SIMD-friendly
support = count(tidset_Pi)                  # popcount
```

Đo lường bằng `@benchmark` (BenchmarkTools) và báo cáo trong Chương 4.
