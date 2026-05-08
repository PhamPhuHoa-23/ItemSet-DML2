# Setup

Hướng dẫn cài môi trường cho dự án LCMFreq (Julia + SPMF). Đã test trên Windows 10/11.

## Julia

Cài qua winget:

```powershell
winget install --id Julialang.Juliaup -e
```

Sau đó restart terminal, rồi:

```powershell
juliaup add release
juliaup default release
julia --version
```

Hoặc tải installer trực tiếp tại https://julialang.org/downloads nếu không dùng được winget.

## Cài packages

```powershell
julia --project=. scripts/setup.jl
```

Lần đầu mất khoảng 5-15 phút do Julia compile artifacts. Các lần sau nhanh hơn nhiều.

Nếu gặp lỗi escape khi dùng `julia -e "..."` trong PowerShell, viết code vào file `.jl` rồi chạy thay thế -- PowerShell xử lý dấu ngoặc kép khác bash.

## Java + SPMF

Java cần để chạy SPMF (công cụ kiểm tra correctness). Kiểm tra đã có chưa:

```powershell
java -version
```

Nếu chưa có, tải OpenJDK 21 tại https://adoptium.net (Windows x64 `.msi`).

Tải SPMF vào `tools/spmf/`:

```powershell
New-Item -ItemType Directory -Force -Path tools\spmf
Invoke-WebRequest -Uri "https://www.philippe-fournier-viger.com/spmf/spmf.jar" -OutFile "tools\spmf\spmf.jar" -UseBasicParsing
```

Test thử:

```powershell
java -jar tools\spmf\spmf.jar run LCMFreq data\toy\sample_9tx.dat out.txt 0.4
Get-Content out.txt
Remove-Item out.txt
```

## Datasets

Chess, Mushroom, Connect, Pumsb, Retail, T10I4D100K, T40I10D100K đã có trong repo. Hai file lớn cần tải thêm:

```powershell
cd data\benchmark
Invoke-WebRequest https://fimi.uantwerpen.be/data/accidents.dat -OutFile accidents.dat -UseBasicParsing
Invoke-WebRequest https://fimi.uantwerpen.be/data/kosarak.dat   -OutFile kosarak.dat   -UseBasicParsing
cd ..\..
```

Mỗi file khoảng 30-34 MB, mất vài phút.

## Chạy thử

```powershell
julia --project=. src/algorithm/lcmfreq.jl data/benchmark/chess.dat output.txt 0.80
```

Chạy tests:

```powershell
julia --project=. tests/test_correctness.jl
```

## Notebook

Cần IJulia cho Jupyter:

```powershell
julia -e "using Pkg; Pkg.add(\"IJulia\")"
jupyter notebook notebooks/demo.ipynb
```

## Lưu ý

- `--project=.` quan trọng, không có sẽ không load đúng packages.
- SPMF nhận minsup dạng tỉ lệ (0.0-1.0), không phải absolute count. `0.8` trên chess.dat (3,196 tx) tương đương `minsup_abs = 2557`.
- `Plots.jl` bị chặn trên một số máy tính trường/công ty do Application Control Policy. Dùng `UnicodePlots` thay thế (đã có trong Project.toml).
