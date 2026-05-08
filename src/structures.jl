# Shared types for LCMFreq results (used by tests and notebooks).
# Note: the algorithm files define their own FreqItemset/LCMFreqResult;
# these exported types include elapsed_ms for external use.

struct FrequentItem
    items   :: Vector{Int}
    support :: Int
end

struct LCMFreqResult
    itemsets   :: Vector{FrequentItem}
    n_tx       :: Int
    minsup_abs :: Int
    elapsed_ms :: Float64
end

Base.length(r::LCMFreqResult) = length(r.itemsets)
