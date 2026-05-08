"""
    read_transactions(path::String) -> Vector{Vector{Int}}

Read a transaction database from a file in SPMF/FIMI format.
Each line is one transaction; items are space-separated positive integers.
Lines starting with '#', '%', '@' or empty lines are ignored.
Items within each transaction are returned sorted in ascending order.
"""
function read_transactions(path::String)::Vector{Vector{Int}}
    transactions = Vector{Vector{Int}}()
    open(path, "r") do f
        for line in eachline(f)
            line = strip(line)
            isempty(line) && continue
            first(line) in ('#', '%', '@') && continue
            items = sort!(parse.(Int, split(line)))
            push!(transactions, items)
        end
    end
    return transactions
end
