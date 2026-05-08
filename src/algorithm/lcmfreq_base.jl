"""
LCMFreq Baseline Implementation
================================
Algorithm: LCMFreq (Linear time Closed itemset Miner - Frequent variant)
Paper: Uno, Kiyomi, Arimura (2004) "LCM ver.2: Efficient Mining Algorithms
       for Frequent/Closed/Maximal Itemsets", FIMI workshop, ICDM 2004.

Reference implementation: SPMF AlgoLCMFreq.java (Alan Souza / Philippe Fournier-Viger)

This baseline version uses:
  - Vector{Int} for transactions (list of items sorted ascending)
  - Vector{Int} for tidsets (list of transaction indices)
  - Linear scan for tidset intersection (O(|T(P)| * avg_tx_len))

The optimized version (lcmfreq.jl) replaces tidsets with BitArray.

Key algorithm concepts:
  1. Occurrence delivery: build buckets[item] = list of transactions containing item.
     This avoids scanning the full DB for every candidate item.
  2. Anytime database reduction: before each recursive call, rebuild buckets
     only for transactions in T(P∪{e}), pruning infrequent items early.
  3. DFS backtracking: enumerate frequent itemsets in depth-first order.
     Output P∪{e} immediately (support = |T(P∪{e})|), then recurse.
"""

include("../io/reader.jl")

# ---------------------------------------------------------------------------
# Types
# ---------------------------------------------------------------------------

"""A found frequent itemset together with its absolute support count."""
struct FreqItemset
    items::Vector{Int}
    support::Int
end

"""
    LCMFreqResult

Holds all frequent itemsets found by lcmfreq_base.
"""
struct LCMFreqResult
    itemsets::Vector{FreqItemset}
end

# ---------------------------------------------------------------------------
# Core algorithm
# ---------------------------------------------------------------------------

"""
    lcmfreq_base(transactions, minsup_abs) -> LCMFreqResult

Mine all frequent itemsets using the LCMFreq algorithm (baseline version).

# Arguments
- `transactions`: vector of transactions; each transaction is a sorted Vector{Int}
- `minsup_abs`: minimum support as an absolute count (number of transactions)
"""
function lcmfreq_base(transactions::Vector{Vector{Int}}, minsup_abs::Int)::LCMFreqResult
    result = FreqItemset[]

    isempty(transactions) && return LCMFreqResult(result)

    # --- Step 1: Occurrence delivery ---
    # Build initial buckets: buckets[item] = indices of transactions containing item
    max_item = maximum(maximum(tx) for tx in transactions if !isempty(tx))
    # buckets[item] stores transaction indices (1-based) containing that item
    buckets = [Int[] for _ in 1:(max_item + 1)]

    for (tid, tx) in enumerate(transactions)
        for item in tx
            push!(buckets[item], tid)
        end
    end

    # --- Step 2: Remove infrequent items from each transaction ---
    # (Anytime database reduction at root level)
    # Build cleaned transactions with only frequent items
    clean_transactions = Vector{Vector{Int}}(undef, length(transactions))
    for (tid, tx) in enumerate(transactions)
        clean_transactions[tid] = filter(item -> length(buckets[item]) >= minsup_abs, tx)
    end

    # --- Step 3: Collect all frequent items (sorted ascending) ---
    all_freq_items = sort([item for item in 1:max_item
                           if length(buckets[item]) >= minsup_abs])

    # --- Step 4: Start DFS from empty prefix ---
    # p_items: current prefix itemset (reused buffer, plen tracks actual length)
    p_items = zeros(Int, 500)

    _backtrack!(p_items, 0,
                collect(1:length(clean_transactions)),  # all transaction indices
                all_freq_items,
                clean_transactions,
                minsup_abs,
                result)

    return LCMFreqResult(result)
end

"""
    _backtrack!(p, plen, tids_P, freq_items, transactions, minsup, result)

Recursive DFS backtracking (core of LCMFreq).

- `p`          : itemset buffer (shared, reused to avoid allocation)
- `plen`       : current prefix length
- `tids_P`     : sorted transaction indices of T(P) — transactions containing P
- `freq_items` : items e > tail(P) frequent in T(P) (sorted ascending)
- `transactions`: cleaned transaction array (items already filtered at root level)
- `minsup`     : minimum support (absolute count)
- `result`     : output accumulator

Note: buckets are NOT shared mutable state here.
Instead, occurrence delivery is done locally in each call (re-built fresh),
matching SPMF's anyTimeDatabaseReductionFreq which resets only items after e.
"""
function _backtrack!(
    p::Vector{Int},
    plen::Int,
    tids_P::Vector{Int},
    freq_items::Vector{Int},
    transactions::Vector{Vector{Int}},
    minsup::Int,
    result::Vector{FreqItemset}
)
    # Build local buckets for freq_items, restricted to tids_P
    # This is occurrence delivery: bucket[item] = tids in T(P) that contain item
    local_buckets = Dict{Int, Vector{Int}}()
    for item in freq_items
        local_buckets[item] = Int[]
    end
    for tid in tids_P
        for item in transactions[tid]
            if haskey(local_buckets, item)
                push!(local_buckets[item], tid)
            end
        end
    end

    for (j, e) in enumerate(freq_items)
        tids_Pe = local_buckets[e]   # T(P ∪ {e}) — already built above
        support_Pe = length(tids_Pe)
        support_Pe < minsup && continue

        # --- Output P ∪ {e} ---
        p[plen + 1] = e
        items_out = sort(p[1:(plen + 1)])
        push!(result, FreqItemset(items_out, support_Pe))

        # --- Recurse: items after e position j ---
        items_after_e = freq_items[(j + 1):end]
        isempty(items_after_e) && continue

        # Filter to only those items still frequent in tids_Pe
        # (check their intersection count by scanning tids_Pe)
        # This is the anytime database reduction step.
        # We pass tids_Pe and items_after_e; the next call will rebuild buckets.
        # First, count how many tids_Pe contain each item_after_e
        counts = Dict{Int, Int}(item => 0 for item in items_after_e)
        for tid in tids_Pe
            for item in transactions[tid]
                if haskey(counts, item)
                    counts[item] += 1
                end
            end
        end
        new_freq_items = filter(item -> counts[item] >= minsup, items_after_e)
        isempty(new_freq_items) && continue

        _backtrack!(p, plen + 1, tids_Pe, new_freq_items, transactions, minsup, result)
    end
end

# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

"""
Merge-intersect two sorted integer vectors. Returns sorted intersection.
O(|a| + |b|) — same as SPMF's intersectTransactions logic.
"""
function _intersect_sorted(a::Vector{Int}, b::Vector{Int})::Vector{Int}
    result = Int[]
    i, j = 1, 1
    @inbounds while i <= length(a) && j <= length(b)
        if a[i] == b[j]
            push!(result, a[i])
            i += 1; j += 1
        elseif a[i] < b[j]
            i += 1
        else
            j += 1
        end
    end
    return result
end

"""Binary search: is `x` in sorted vector `v`?"""
function _in_sorted(v::Vector{Int}, x::Int)::Bool
    lo, hi = 1, length(v)
    @inbounds while lo <= hi
        mid = (lo + hi) >>> 1
        v[mid] == x && return true
        v[mid] < x  ? (lo = mid + 1) : (hi = mid - 1)
    end
    return false
end

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

"""Write results to a file in SPMF format: `item1 item2 ... #SUP: count`"""
function write_output(result::LCMFreqResult, path::String)
    open(path, "w") do f
        for fi in result.itemsets
            println(f, join(fi.items, " "), " #SUP: ", fi.support)
        end
    end
end

"""Print results to stdout in SPMF format."""
function print_output(result::LCMFreqResult)
    for fi in result.itemsets
        println(join(fi.items, " "), " #SUP: ", fi.support)
    end
end

# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

"""
Usage: julia --project=. src/algorithm/lcmfreq_base.jl <input_file> <output_file> <minsup>

- <input_file>  : path to SPMF/FIMI format transaction database
- <output_file> : path for output (use '-' to print to stdout)
- <minsup>      : minimum support as fraction 0.0–1.0 (e.g. 0.4 = 40%)
"""
function main()
    if length(ARGS) < 3
        println(stderr, "Usage: julia --project=. src/algorithm/lcmfreq_base.jl <input> <output> <minsup>")
        exit(1)
    end

    input_path  = ARGS[1]
    output_path = ARGS[2]
    minsup_rel  = parse(Float64, ARGS[3])

    transactions = read_transactions(input_path)
    n = length(transactions)
    minsup_abs = max(1, ceil(Int, minsup_rel * n))

    t0 = time_ns()
    result = lcmfreq_base(transactions, minsup_abs)
    elapsed_ms = (time_ns() - t0) / 1e6

    if output_path == "-"
        print_output(result)
    else
        write_output(result, output_path)
    end

    println(stderr, "LCMFreq-Base: $(length(result.itemsets)) itemsets | " *
                    "minsup=$(minsup_abs)/$(n) | $(round(elapsed_ms, digits=1)) ms")
end

# Run when called directly (not when included as a module)
if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
