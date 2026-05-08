using DataStructures
using BenchmarkTools
using UnicodePlots

println("Julia version: ", VERSION)
println("DataStructures: OK - Queue{Int} = ", Queue{Int})
println("BenchmarkTools: OK - version ", pkgversion(BenchmarkTools))
println("UnicodePlots:   OK - version ", pkgversion(UnicodePlots))

# Quick smoke test
q = Queue{Int}()
enqueue!(q, 42)
@assert dequeue!(q) == 42

println("\nAll checks passed!")
