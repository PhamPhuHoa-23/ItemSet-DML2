"""
utils.jl — Shared utility functions for LCMFreq
================================================

Provides helpers used by both the baseline and optimised implementations:
  · Database loading  (load_transactions)
  · Support checking  (count_support, is_frequent)
  · Result export     (write_itemsets, format_itemset)
  · Timing            (elapsed_ms)

Usage:
    include("src/utils/utils.jl")
    txs = load_transactions("data/benchmark/chess.dat")
    n_items = maximum(item for tx in txs for item in tx)
"""

# ---------------------------------------------------------------------------
# Database loading
# ---------------------------------------------------------------------------
"""
    load_transactions(path::AbstractString) -> Vector{Vector{Int}}

Load a transaction database from a whitespace-delimited file.
Each line is one transaction; items are positive integers.
Blank lines and lines starting with '#' are ignored.

# Example
    txs = load_transactions("data/benchmark/mushroom.dat")
    println(length(txs), " transactions, first = ", txs[1])
"""
function load_transactions(path::AbstractString)::Vector{Vector{Int}}
    txs = Vector{Vector{Int}}()
    open(path, "r") do fh
        for line in eachline(fh)
            stripped = strip(line)
            isempty(stripped) && continue
            startswith(stripped, '#') && continue
            push!(txs, parse.(Int, split(stripped)))
        end
    end
    return txs
end

# ---------------------------------------------------------------------------
# Support utilities
# ---------------------------------------------------------------------------
"""
    count_support(txs, itemset) -> Int

Count the number of transactions in `txs` that contain all items in `itemset`.
`itemset` may be any iterable of item IDs.

# Example
    count_support(txs, [1, 3])   # => 42
"""
function count_support(txs::Vector{Vector{Int}}, itemset)::Int
    target = Set(itemset)
    return count(tx -> target ⊆ Set(tx), txs)
end

"""
    is_frequent(txs, itemset, minsup_abs) -> Bool

Return true iff `itemset` appears in at least `minsup_abs` transactions.
"""
function is_frequent(txs::Vector{Vector{Int}}, itemset, minsup_abs::Int)::Bool
    return count_support(txs, itemset) >= minsup_abs
end

"""
    minsup_abs(n_tx, minsup_frac) -> Int

Convert a fractional minimum support threshold to an absolute count.

# Example
    minsup_abs(1000, 0.05)  # => 50
"""
function minsup_abs(n_tx::Int, minsup_frac::Float64)::Int
    return max(1, floor(Int, n_tx * minsup_frac))
end

# ---------------------------------------------------------------------------
# Item-set utilities
# ---------------------------------------------------------------------------
"""
    max_item(txs) -> Int

Return the largest item ID found in the transaction database.
"""
function max_item(txs::Vector{Vector{Int}})::Int
    return maximum(item for tx in txs for item in tx)
end

"""
    db_stats(txs) -> NamedTuple

Return basic statistics of a transaction database:
  · n_tx      — number of transactions
  · n_items   — number of distinct items
  · avg_len   — mean transaction length
  · max_item  — largest item ID

# Example
    stats = db_stats(txs)
    println("avg_len = ", stats.avg_len)
"""
function db_stats(txs::Vector{Vector{Int}})
    n_tx    = length(txs)
    all_items = Set{Int}()
    total_len = 0
    for tx in txs
        total_len += length(tx)
        union!(all_items, tx)
    end
    return (
        n_tx     = n_tx,
        n_items  = length(all_items),
        avg_len  = total_len / n_tx,
        max_item = isempty(all_items) ? 0 : maximum(all_items),
    )
end

# ---------------------------------------------------------------------------
# Result I/O
# ---------------------------------------------------------------------------
"""
    format_itemset(items, support) -> String

Format a frequent itemset as a string in SPMF output style:
    "1 3 5  #SUP: 42"
"""
function format_itemset(items::Vector{Int}, support::Int)::String
    return join(items, " ") * "  #SUP: $(support)"
end

"""
    write_itemsets(io, itemsets)

Write frequent itemsets to an IO object in SPMF format (one per line).
`itemsets` must be an iterable of objects with `.items` and `.support` fields.

# Example
    open("output.txt", "w") do f
        write_itemsets(f, result.itemsets)
    end
"""
function write_itemsets(io::IO, itemsets)
    for fi in itemsets
        println(io, format_itemset(fi.items, fi.support))
    end
end

# ---------------------------------------------------------------------------
# Timing
# ---------------------------------------------------------------------------
"""
    elapsed_ms(t0_ns) -> Float64

Return milliseconds elapsed since `t0_ns` (from `time_ns()`).

# Example
    t0 = time_ns()
    # ... do work ...
    println(elapsed_ms(t0), " ms")
"""
function elapsed_ms(t0_ns::UInt64)::Float64
    return (time_ns() - t0_ns) / 1_000_000.0
end
