# LCMFreq optimised — BitArray tidsets + Hypercube Decomposition (Uno et al., FIMI 2004)
# Tidset per item stored as BitArray{1}; intersection via SIMD AND, support via POPCNT.
# Hypercube Decomposition (Section 3.3): batches output of 2^|H(P)| itemsets with equal
# support instead of recursing into each individually.

include("../io/reader.jl")

struct FreqItemset
    items::Vector{Int}
    support::Int
end

struct LCMFreqResult
    itemsets::Vector{FreqItemset}
end

# All 2^n subsets of items (including empty set).
function _all_subsets(items::Vector{Int})::Vector{Vector{Int}}
    n = length(items)
    out = Vector{Vector{Int}}(undef, 2^n)
    for mask in 0:(2^n - 1)
        out[mask + 1] = [items[i] for i in 1:n if (mask >> (i-1)) & 1 == 1]
    end
    return out
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

    p_buf = zeros(Int, 500)
    _hypercube!(p_buf, 0, trues(n), all_freq_items, tidsets_full, minsup_abs, result, n, Int[])

    return LCMFreqResult(result)
end

# Hypercube Decomposition recursive kernel.
#
# p[1..plen] = current prefix P (shared scratch buffer).
# tidset_P   = T(P) as a BitArray.
# freq_items = candidate items to extend P (all > tail(P), all frequent w.r.t. tidset_P).
# S          = accumulated H sets from ancestor calls (items already "free" to add without
#              reducing support — see paper Section 3.3).
#
# At each call:
#   1. Compute H(P) = {e ∈ freq_items : frq(P∪{e}) = frq(P)}.
#   2. S' = S ∪ H(P).
#   3. Output P ∪ Q for every Q ⊆ S'   (2^|S'| itemsets, all with support = frq(P)).
#   4. Recurse only for items e ∉ S' with frq(P∪{e}) ≥ minsup.
function _hypercube!(
    p::Vector{Int}, plen::Int, tidset_P::BitArray{1},
    freq_items::Vector{Int}, tidsets_full::Dict{Int, BitArray{1}},
    minsup::Int, result::Vector{FreqItemset}, n::Int, S::Vector{Int}
)
    support_P = count(tidset_P)

    # Step 1 — H(P): items whose tidset equals T(P)
    H_P = filter(freq_items) do e
        count(tidset_P .& tidsets_full[e]) == support_P
    end

    # Step 2 — S' = S ∪ H(P)
    S_prime     = sort!(collect(union(S, H_P)))
    S_prime_set = Set(S_prime)

    # Step 3 — batch output: P ∪ Q for all Q ⊆ S'
    # (skip Q = ∅ when P itself is empty, i.e. don't emit the empty itemset)
    for Q in _all_subsets(S_prime)
        (plen == 0 && isempty(Q)) && continue
        push!(result, FreqItemset(sort!([p[1:plen]; Q]), support_P))
    end

    # Step 4 — recurse only for items outside S'
    tail_P = plen > 0 ? p[plen] : 0

    for (j, e) in enumerate(freq_items)
        e <= tail_P        && continue   # enforce e > tail(P)
        e in S_prime_set   && continue   # H(P) items handled by batch output

        tidset_Pe  = tidset_P .& tidsets_full[e]
        support_Pe = count(tidset_Pe)
        support_Pe < minsup && continue

        @inbounds p[plen + 1] = e

        items_after_e  = freq_items[(j + 1):end]
        new_freq_items = filter(items_after_e) do k
            count(tidset_Pe .& tidsets_full[k]) >= minsup
        end

        _hypercube!(p, plen + 1, tidset_Pe, new_freq_items,
                    tidsets_full, minsup, result, n, S_prime)
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
