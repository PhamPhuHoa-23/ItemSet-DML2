"""
structures.jl — Core data structures for LCMFreq implementation
================================================================

This file documents and re-exports the key types used by both the baseline
and optimised implementations of LCMFreq. It serves as the single source of
truth for type definitions referenced across the project.

Types defined here:
  · FrequentItem     — a mined (itemset, support) pair
  · LCMFreqResult    — complete result set returned by both lcmfreq variants

The actual algorithm implementations live in:
  · src/algorithm/lcmfreq_base.jl   (baseline — OccurrenceDeliver + Vector{Int})
  · src/algorithm/lcmfreq.jl        (optimised — BitArray + Dict)

Internal TID-set representations (not exported, but documented here):

  Baseline (lcmfreq_base.jl):
    tidset :: Vector{Int}
      Sorted list of transaction IDs that contain a given itemset.
      Memory: O(n) integers per itemset, where n = |T(P)|.
      Intersection: merge two sorted lists in O(|A| + |B|) — linear scan.
      Built via OccurrenceDeliver (bucket-based single pass over DB).

  Optimised (lcmfreq.jl):
    tidset :: BitArray{1}  (length = total_transactions)
      Bit-vector where bit i is 1 iff transaction i contains the itemset.
      Memory: O(n/64) 64-bit words per itemset — 64× smaller than Vector{Int}.
      Intersection: bitwise AND in O(n/64) — hardware SIMD (64 bits/cycle).
      Support counting: count() using hardware POPCNT instruction.
      Stored in Dict{Int, BitArray{1}} — only frequent items allocated.

Complexity summary:
  Operation          Baseline           Optimised
  ─────────────────  ─────────────────  ──────────────────────
  TID-set intersect  O(|A| + |B|)       O(n/64)  ← SIMD
  Support count      O(1) (from size)   O(n/64)  ← POPCNT
  Memory per tidset  8·|T(P)| bytes     n/8 bytes
  Init (1 DB scan)   O(||D||)           O(||D||)
"""

# ---------------------------------------------------------------------------
# FrequentItem — one mined frequent itemset with its absolute support
# ---------------------------------------------------------------------------
"""
    FrequentItem

A frequent itemset together with its absolute support count.

Fields:
  · items   :: Vector{Int}  — sorted list of item IDs (1-indexed)
  · support :: Int          — number of transactions containing `items`

Example:
  fi = FrequentItem([1, 3, 5], 42)
  fi.items    # => [1, 3, 5]
  fi.support  # => 42
"""
struct FrequentItem
    items   :: Vector{Int}
    support :: Int
end

Base.show(io::IO, fi::FrequentItem) =
    print(io, "FrequentItem(items=$(fi.items), sup=$(fi.support))")

# ---------------------------------------------------------------------------
# LCMFreqResult — the full mining result returned by lcmfreq / lcmfreq_base
# ---------------------------------------------------------------------------
"""
    LCMFreqResult

Complete result of a LCMFreq mining run.

Fields:
  · itemsets    :: Vector{FrequentItem}  — all frequent itemsets found
  · n_tx        :: Int                   — number of transactions in input DB
  · minsup_abs  :: Int                   — absolute minimum support threshold
  · elapsed_ms  :: Float64               — wall-clock time (milliseconds)

Convenience accessors:
  · length(r)   — number of frequent itemsets
  · iterate(r)  — iterate over FrequentItem elements

Example:
  r = lcmfreq(transactions, 10)
  println(length(r.itemsets), " frequent itemsets found")
  for fi in r.itemsets
      println(join(fi.items, " "), "  #SUP: ", fi.support)
  end
"""
struct LCMFreqResult
    itemsets   :: Vector{FrequentItem}
    n_tx       :: Int
    minsup_abs :: Int
    elapsed_ms :: Float64
end

Base.length(r::LCMFreqResult) = length(r.itemsets)

Base.show(io::IO, r::LCMFreqResult) =
    print(io, "LCMFreqResult($(length(r.itemsets)) itemsets, " *
              "n_tx=$(r.n_tx), minsup=$(r.minsup_abs), " *
              "elapsed=$(round(r.elapsed_ms, digits=1))ms)")
