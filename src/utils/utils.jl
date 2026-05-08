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

function count_support(txs::Vector{Vector{Int}}, itemset)::Int
    target = Set(itemset)
    return count(tx -> target ⊆ Set(tx), txs)
end

is_frequent(txs, itemset, minsup_abs::Int) = count_support(txs, itemset) >= minsup_abs

to_minsup_abs(n_tx::Int, frac::Float64) = max(1, floor(Int, n_tx * frac))

function db_stats(txs::Vector{Vector{Int}})
    all_items = Set{Int}()
    total_len = 0
    for tx in txs
        total_len += length(tx)
        union!(all_items, tx)
    end
    return (
        n_tx     = length(txs),
        n_items  = length(all_items),
        avg_len  = total_len / length(txs),
        max_item = isempty(all_items) ? 0 : maximum(all_items),
    )
end

format_itemset(items::Vector{Int}, support::Int) = join(items, " ") * "  #SUP: $(support)"

function write_itemsets(io::IO, itemsets)
    for fi in itemsets
        println(io, format_itemset(fi.items, fi.support))
    end
end

elapsed_ms(t0_ns::UInt64) = (time_ns() - t0_ns) / 1_000_000.0
