# LCMFreq optimised — BitArray tidsets (Uno et al., FIMI 2004)
# Tidset per item stored as BitArray{1}; intersection via SIMD AND, support via POPCNT.
# Dict-based allocation avoids OOM on sparse datasets with large item IDs.

include("../io/reader.jl")

struct FreqItemset
    items::Vector{Int}
    support::Int
end

struct LCMFreqResult
    itemsets::Vector{FreqItemset}
end

function lcmfreq(transactions::Vector{Vector{Int}}, minsup_abs::Int)::LCMFreqResult
    result = FreqItemset[]
    n = length(transactions)
    isempty(transactions) && return LCMFreqResult(result)

    item_counts = Dict{Int, Int}()
    for tx in transactions
        for item in tx
            item_counts[item] = get(item_counts, item, 0) + 1
        end
    end

    all_freq_items = sort([item for (item, cnt) in item_counts if cnt >= minsup_abs])
    freq_set = Set(all_freq_items)

    tidsets_full = Dict{Int, BitArray{1}}()
    for item in all_freq_items
        tidsets_full[item] = falses(n)
    end
    for (tid, tx) in enumerate(transactions)
        for item in tx
            if haskey(tidsets_full, item)
                @inbounds tidsets_full[item][tid] = true
            end
        end
    end

    clean_transactions = [filter(x -> x in freq_set, tx) for tx in transactions]

    p_buf = zeros(Int, 500)
    _backtrack_bit!(p_buf, 0, trues(n), all_freq_items,
                    clean_transactions, tidsets_full, minsup_abs, result, n)

    return LCMFreqResult(result)
end

function _backtrack_bit!(
    p::Vector{Int}, plen::Int, tidset_P::BitArray{1},
    freq_items::Vector{Int}, transactions::Vector{Vector{Int}},
    tidsets_full::Dict{Int, BitArray{1}}, minsup::Int,
    result::Vector{FreqItemset}, n::Int
)
    for (j, e) in enumerate(freq_items)
        tidset_Pe = tidset_P .& tidsets_full[e]
        support_Pe = count(tidset_Pe)
        support_Pe < minsup && continue

        p[plen + 1] = e
        push!(result, FreqItemset(sort(p[1:(plen + 1)]), support_Pe))

        items_after_e = freq_items[(j + 1):end]
        isempty(items_after_e) && continue

        new_freq_items = filter(items_after_e) do k
            count(tidset_Pe .& tidsets_full[k]) >= minsup
        end
        isempty(new_freq_items) && continue

        _backtrack_bit!(p, plen + 1, tidset_Pe, new_freq_items,
                        transactions, tidsets_full, minsup, result, n)
    end
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
        println(stderr, "Usage: julia --project=. src/algorithm/lcmfreq.jl <input> <output> <minsup>")
        exit(1)
    end
    input_path  = ARGS[1]
    output_path = ARGS[2]
    minsup_rel  = parse(Float64, ARGS[3])
    transactions = read_transactions(input_path)
    n = length(transactions)
    minsup_abs = max(1, ceil(Int, minsup_rel * n))
    t0 = time_ns()
    result = lcmfreq(transactions, minsup_abs)
    elapsed_ms = (time_ns() - t0) / 1e6
    output_path == "-" ? print_output(result) : write_output(result, output_path)
    println(stderr, "LCMFreq-Opt: $(length(result.itemsets)) itemsets | minsup=$(minsup_abs)/$(n) | $(round(elapsed_ms, digits=1)) ms")
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
