"""
scripts/setup.jl — Install dependencies and verify the environment
===================================================================
Run once before first use:

    julia --project=. scripts/setup.jl
"""

using Pkg

println("=== LCMFreq environment setup ===\n")
println("Julia $(VERSION)")

# Install / resolve declared dependencies from Project.toml
println("\n[1/2] Installing packages...")
Pkg.instantiate()
println("      Done.")

# Verify all packages load correctly
println("\n[2/2] Verifying imports...")
using DataStructures
using BenchmarkTools
using UnicodePlots

println("      DataStructures  v", pkgversion(DataStructures))
println("      BenchmarkTools  v", pkgversion(BenchmarkTools))
println("      UnicodePlots    v", pkgversion(UnicodePlots))

# Quick smoke test
q = Queue{Int}()
enqueue!(q, 42)
@assert dequeue!(q) == 42

println("\nAll checks passed -- ready to run experiments.")
println("Next: julia --project=. scripts/run_light.jl")
