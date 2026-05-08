# LCMFreq baseline — Vector{Int} tidsets (Uno et al., FIMI 2004)
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

    max_item = maximum(maximum(tx) for tx in transactions if !isempty(tx))
    buckets  = [Int[] for _ in 1:(max_item + 1)]
    for (tid, tx) in enumerate(transactions)
        for item in tx
            push!(buckets[item], tid)
        end
    end

    clean_transactions = Vector{Vector{Int}}(undef, length(transactions))
    for (tid, tx) in enumerate(transactions)
        clean_transactions[tid] = filter(item -> length(buckets[item]) >= minsup_abs, tx)
    end

    all_freq_items = sort([item for item in 1:max_item
                           if length(buckets[item]) >= minsup_abs])

    p_items = zeros(Int, 500)
    _backtrack!(p_items, 0,
                collect(1:length(clean_transactions)),
                all_freq_items, clean_transactions, minsup_abs, result)

    return LCMFreqResult(result)
end

function _backtrack!(
    p::Vector{Int}, plen::Int, tids_P::Vector{Int},
    freq_items::Vector{Int}, transactions::Vector{Vector{Int}},
    minsup::Int, result::Vector{FreqItemset}
)
    # OccurrenceDeliver: one pass over tids_P fills all candidate buckets at once
    local_buckets = Dict{Int, Vector{Int}}(item => Int[] for item in freq_items)
    for tid in tids_P
        for item in transactions[tid]
            haskey(local_buckets, item) && push!(local_buckets[item], tid)
        end
    end

    for (j, e) in enumerate(freq_items)
        tids_Pe = local_buckets[e]
        support_Pe = length(tids_Pe)
        support_Pe < minsup && continue

        @inbounds p[plen + 1] = e
        push!(result, FreqItemset(sort(p[1:(plen + 1)]), support_Pe))

        items_after_e = freq_items[(j + 1):end]
        isempty(items_after_e) && continue

        counts = Dict{Int, Int}(item => 0 for item in items_after_e)
        for tid in tids_Pe
            for item in transactions[tid]
                haskey(counts, item) && (counts[item] += 1)
            end
        end
        new_freq_items = filter(item -> counts[item] >= minsup, items_after_e)
        isempty(new_freq_items) && continue

        _backtrack!(p, plen + 1, tids_Pe, new_freq_items, transactions, minsup, result)
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
