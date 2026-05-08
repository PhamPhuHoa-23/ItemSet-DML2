using Pkg
# Remove Plots if it was previously added (it needs FFMPEG which may be blocked)
try
    Pkg.rm("Plots")
catch
end
try
    Pkg.rm("GR")
catch
end
Pkg.add(["DataStructures", "BenchmarkTools", "UnicodePlots"])
Pkg.instantiate()
println("All packages installed successfully!")
println("Julia version: ", VERSION)
