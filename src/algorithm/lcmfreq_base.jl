# LCMFreq baseline — Vector{Int} tidsets + Hypercube Decomposition (Uno et al., FIMI 2004)
# Uses OccurrenceDeliver (bucket-based single pass) to propagate tidsets.
# See lcmfreq.jl for the BitArray-optimised version.

include("../io/reader.jl")

struct FreqItemset
    items::Vector{Int}
    support::Int
end

struct LCMFreqResult
    itemsets::Vector{FreqItemset}
end

function lcmfreq_base(transactions::Vector{Vector{Int}}, minsup_abs::Int)::LCMFreqResult
    result = FreqItemset[]
    isempty(transactions) && return LCMFreqResult(result)

    # Item IDs are not guaranteed to start at 1 (e.g. Pumsb starts at 0), so
    # buckets is indexed by item + 1 to stay within Julia's 1-based arrays.
    max_item = maximum(maximum(tx) for tx in transactions if !isempty(tx))
    buckets  = [Int[] for _ in 1:(max_item + 1)]
    for (tid, tx) in enumerate(transactions)
        for item in tx
            push!(buckets[item + 1], tid)
        end
    end

    clean_transactions = Vector{Vector{Int}}(undef, length(transactions))
    for (tid, tx) in enumerate(transactions)
        clean_transactions[tid] = filter(item -> length(buckets[item + 1]) >= minsup_abs, tx)
    end

    all_freq_items = sort([item for item in 0:max_item
                           if length(buckets[item + 1]) >= minsup_abs])

    p_items = zeros(Int, 500)
    _hypercube_base!(p_items, 0,
                     collect(1:length(clean_transactions)),
                     all_freq_items, clean_transactions, minsup_abs, result, Int[])

    return LCMFreqResult(result)
end

function _all_subsets_base(items::Vector{Int})::Vector{Vector{Int}}
    n = length(items)
    out = Vector{Vector{Int}}(undef, 2^n)
    for mask in 0:(2^n - 1)
        out[mask + 1] = [items[i] for i in 1:n if (mask >> (i-1)) & 1 == 1]
    end
    return out
end

function _hypercube_base!(
    p::Vector{Int}, plen::Int, tids_P::Vector{Int},
    freq_items::Vector{Int}, transactions::Vector{Vector{Int}},
    minsup::Int, result::Vector{FreqItemset}, S::Vector{Int}
)
    support_P = length(tids_P)

    # OccurrenceDeliver: one pass over tids_P fills all candidate buckets at once
    local_buckets = Dict{Int, Vector{Int}}(item => Int[] for item in freq_items)
    for tid in tids_P
        for item in transactions[tid]
            haskey(local_buckets, item) && push!(local_buckets[item], tid)
        end
    end

    # H(P) = items whose tidset equals T(P) (adding them doesn't reduce support)
    H_P = filter(e -> length(local_buckets[e]) == support_P, freq_items)

    # S' = S ∪ H(P)
    S_prime     = sort!(collect(union(S, H_P)))
    S_prime_set = Set(S_prime)

    # Batch output: P ∪ Q for all Q ⊆ S'
    for Q in _all_subsets_base(S_prime)
        (plen == 0 && isempty(Q)) && continue
        push!(result, FreqItemset(sort!([p[1:plen]; Q]), support_P))
    end

    # Recurse only for items outside S'
    tail_P = plen > 0 ? p[plen] : 0

    for (j, e) in enumerate(freq_items)
        e <= tail_P      && continue
        e in S_prime_set && continue

        tids_Pe    = local_buckets[e]
        support_Pe = length(tids_Pe)
        support_Pe < minsup && continue

        @inbounds p[plen + 1] = e

        items_after_e = freq_items[(j + 1):end]
        counts = Dict{Int, Int}(item => 0 for item in items_after_e)
        for tid in tids_Pe
            for item in transactions[tid]
                haskey(counts, item) && (counts[item] += 1)
            end
        end
        new_freq_items = filter(item -> counts[item] >= minsup, items_after_e)

        _hypercube_base!(p, plen + 1, tids_Pe, new_freq_items,
                         transactions, minsup, result, S_prime)
    end
end

function _intersect_sorted(a::Vector{Int}, b::Vector{Int})::Vector{Int}
    result = Int[]
    i, j = 1, 1
    @inbounds while i <= length(a) && j <= length(b)
        if a[i] == b[j]
            push!(result, a[i]); i += 1; j += 1
        elseif a[i] < b[j]
            i += 1
        else
            j += 1
        end
    end
    return result
end

function write_output(result::LCMFreqResult, path::String)
    open(path, "w") do f
        for fi in result.itemsets
            println(f, join(fi.items, " "), " #SUP: ", fi.support)
        end
    end
end

function print_output(result::LCMFreqResult)
    for fi in result.itemsets
        println(join(fi.items, " "), " #SUP: ", fi.support)
    end
end

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
    output_path == "-" ? print_output(result) : write_output(result, output_path)
    println(stderr, "LCMFreq-Base: $(length(result.itemsets)) itemsets | minsup=$(minsup_abs)/$(n) | $(round(elapsed_ms, digits=1)) ms")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
