"""
plot_results.py — Beautiful individual charts for LCMFreq experiments
=====================================================================
Generates separate PNG files into data/results/figures/
  - 5 runtime charts (one per dataset)
  - 1 itemset-count overlay chart
  - 1 speedup radar chart
  - 1 speedup grouped-bar chart
  - 1 memory chart
  - 2 scalability charts
  - 2 transaction-length charts
  Total: 13 PNGs

Run:  python notebooks/plot_results.py
"""

import csv, os, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
from matplotlib.patches import FancyBboxPatch

# ── Paths ─────────────────────────────────────────────────────────────────
ROOT    = os.path.join(os.path.dirname(__file__), "..")
RESULTS = os.path.join(ROOT, "data", "results")
FIGS    = os.path.join(RESULTS, "figures")
os.makedirs(FIGS, exist_ok=True)

# ── Global style ───────────────────────────────────────────────────────────
plt.style.use("seaborn-v0_8-whitegrid")
plt.rcParams.update({
    "figure.dpi":         150,
    "savefig.dpi":        150,
    "font.family":        "sans-serif",
    "font.size":          12,
    "axes.titlesize":     14,
    "axes.titleweight":   "bold",
    "axes.titlepad":      14,
    "axes.labelsize":     12,
    "axes.spines.top":    False,
    "axes.spines.right":  False,
    "lines.linewidth":    2.5,
    "lines.markersize":   8,
    "legend.fontsize":    10,
    "legend.framealpha":  0.9,
    "legend.edgecolor":   "#cccccc",
})

# ── Colour palette ─────────────────────────────────────────────────────────
COL_OPT  = "#1E88E5"   # blue
COL_BASE = "#E53935"   # red
COL_SPMF = "#43A047"   # green
COL_LIN  = "#9E9E9E"   # grey (reference lines)

# Dataset colours for multi-series overlay plots
DS_COLORS = {
    "Chess":       "#7B1FA2",
    "Connect":     "#AD1457",
    "Mushroom":    "#E53935",
    "Pumsb":       "#FF6F00",
    "Accidents":   "#FB8C00",
    "Retail":      "#43A047",
    "T10I4D100K":  "#1E88E5",
    "T40I10D100K": "#039BE5",
    "Kosarak":     "#00897B",
}

# ── Helpers ────────────────────────────────────────────────────────────────
def read_csv(fname):
    path = os.path.join(RESULTS, fname)
    with open(path, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        return list(reader)

def savefig(fig, name):
    p = os.path.join(FIGS, name)
    fig.savefig(p, bbox_inches="tight")
    plt.close(fig)
    print(f"  → {name}")

def annotate_speedup(ax, xs, y_top, y_bot, sample_idx=None, color="#555555"):
    """Annotate selected points with speedup ratio."""
    idxs = sample_idx or range(0, len(xs), max(1, len(xs)//3))
    for i in idxs:
        if y_bot[i] > 0:
            su = y_top[i] / y_bot[i]
            ax.annotate(f"{su:.0f}×",
                        xy=(xs[i], (y_top[i] * y_bot[i])**0.5),
                        fontsize=8, color=color, ha="center",
                        bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none", alpha=0.7))

datasets_rt = [
    ("Chess",       "runtime_chess.csv",       True),
    ("Connect",     "runtime_connect.csv",     True),
    ("Mushroom",    "runtime_mushroom.csv",    True),
    ("Pumsb",       "runtime_pumsb.csv",       True),
    ("Accidents",   "runtime_accidents.csv",   False),
    ("Retail",      "runtime_retail.csv",      False),
    ("T10I4D100K",  "runtime_t10i4d100k.csv",  False),
    ("T40I10D100K", "runtime_t40i10d100k.csv", False),
    ("Kosarak",     "runtime_kosarak.csv",     False),
]

DENSE_DS  = ["Chess", "Connect", "Mushroom", "Pumsb", "Accidents"]
SPARSE_DS = ["Retail", "T10I4D100K", "T40I10D100K", "Kosarak"]

# ══════════════════════════════════════════════════════════════════════════════
# Charts 1–9: Individual runtime charts (one per dataset)
# ══════════════════════════════════════════════════════════════════════════════
print("\n[1-9] Runtime vs minsup — individual charts")

for name, fname, has_base in datasets_rt:
    fpath = os.path.join(RESULTS, fname)
    if not os.path.exists(fpath):
        print(f"  SKIP {name}: {fname} not found")
        continue
    rows = read_csv(fname)
    ms   = [float(r["minsup_frac"]) * 100 for r in rows]
    opt  = [float(r["julia_opt_ms"])       for r in rows]
    spmf_raw = [float(r["spmf_ms"]) for r in rows]

    # Filter out invalid SPMF readings (-1 = SPMF failed/skipped)
    spmf_valid = [(x, y, s) for x, y, s in zip(ms, opt, spmf_raw) if s > 0]
    ms_s   = [v[0] for v in spmf_valid]
    opt_s  = [v[1] for v in spmf_valid]
    spmf_s = [v[2] for v in spmf_valid]

    fig, ax = plt.subplots(figsize=(8, 5))

    if spmf_s:
        ax.fill_between(ms_s, opt_s, spmf_s,
                        where=[s > o for s, o in zip(spmf_s, opt_s)],
                        alpha=0.10, color=COL_OPT, label="_fill")
        ax.semilogy(ms_s, spmf_s, "s--", color=COL_SPMF, label="SPMF (Java LCMFreq)",
                    markerfacecolor="white", markeredgewidth=2)

    ax.semilogy(ms, opt,  "o-",  color=COL_OPT,  label="Julia Opt (BitArray)",
                markerfacecolor="white", markeredgewidth=2)

    if has_base:
        base_raw = [r["baseline_ms"] for r in rows]
        base = [float(v) for v in base_raw if v not in ("N/A", "")]
        ms_b = [m for m, v in zip(ms, base_raw) if v not in ("N/A", "")]
        opt_b = [o for o, v in zip(opt, base_raw) if v not in ("N/A", "")]
        if base:
            ax.semilogy(ms_b, base, "^:", color=COL_BASE, label="Julia Baseline (Vector)",
                        markerfacecolor="white", markeredgewidth=2)
            annotate_speedup(ax, ms_b, base, opt_b, color=COL_BASE)

    # Speedup labels (opt vs spmf)
    if spmf_s:
        annotate_speedup(ax, ms_s, spmf_s, opt_s, color=COL_SPMF)

    ax.invert_xaxis()
    ax.set_xlabel("Minimum Support (%)", labelpad=8)
    ax.set_ylabel("Runtime (ms, log scale)", labelpad=8)
    ax.set_title(f"{name} — Runtime vs Minimum Support")
    ax.legend(loc="upper right")
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
    fig.tight_layout()
    savefig(fig, f"runtime_{name.lower().replace(' ', '_')}.png")


# ══════════════════════════════════════════════════════════════════════════════
# Chart 10: #Itemsets vs minsup — Dense datasets grouped
# ══════════════════════════════════════════════════════════════════════════════
print("[10] #Itemsets vs minsup — Dense datasets")

fig, ax = plt.subplots(figsize=(9, 5.5))
for name, fname, _ in datasets_rt:
    if name not in DENSE_DS: continue
    fpath = os.path.join(RESULTS, fname)
    if not os.path.exists(fpath): continue
    rows = read_csv(fname)
    ms   = [float(r["minsup_frac"]) * 100 for r in rows]
    cnt  = [int(r["itemset_count"])        for r in rows]
    ax.semilogy(ms, cnt, "o-", color=DS_COLORS[name], label=name,
                markerfacecolor="white", markeredgewidth=2)
ax.invert_xaxis()
ax.set_xlabel("Minimum Support (%)", labelpad=8)
ax.set_ylabel("#Frequent Itemsets (log scale)", labelpad=8)
ax.set_title("#Frequent Itemsets vs Minsup — Dense Datasets")
ax.legend(title="Dataset", title_fontsize=10)
ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
fig.tight_layout()
savefig(fig, "itemsets_dense.png")

# ══════════════════════════════════════════════════════════════════════════════
# Chart 11: #Itemsets vs minsup — Sparse datasets grouped
# ══════════════════════════════════════════════════════════════════════════════
print("[11] #Itemsets vs minsup — Sparse datasets")

fig, ax = plt.subplots(figsize=(9, 5.5))
for name, fname, _ in datasets_rt:
    if name not in SPARSE_DS: continue
    fpath = os.path.join(RESULTS, fname)
    if not os.path.exists(fpath): continue
    rows = read_csv(fname)
    ms   = [float(r["minsup_frac"]) * 100 for r in rows]
    cnt  = [int(r["itemset_count"])        for r in rows]
    ax.semilogy(ms, cnt, "o-", color=DS_COLORS[name], label=name,
                markerfacecolor="white", markeredgewidth=2)
ax.invert_xaxis()
ax.set_xlabel("Minimum Support (%)", labelpad=8)
ax.set_ylabel("#Frequent Itemsets (log scale)", labelpad=8)
ax.set_title("#Frequent Itemsets vs Minsup — Sparse Datasets")
ax.legend(title="Dataset", title_fontsize=10)
ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
fig.tight_layout()
savefig(fig, "itemsets_sparse.png")

# ══════════════════════════════════════════════════════════════════════════════
# Chart 12: #Itemsets vs minsup — All datasets (backward-compatible)
# ══════════════════════════════════════════════════════════════════════════════
print("[12] #Itemsets vs minsup — all datasets overlay")

fig, ax = plt.subplots(figsize=(10, 6))
for name, fname, _ in datasets_rt:
    fpath = os.path.join(RESULTS, fname)
    if not os.path.exists(fpath): continue
    rows = read_csv(fname)
    ms   = [float(r["minsup_frac"]) * 100 for r in rows]
    cnt  = [int(r["itemset_count"])        for r in rows]
    col  = DS_COLORS.get(name, "#888888")
    ax.semilogy(ms, cnt, "o-", color=col, label=name,
                markerfacecolor="white", markeredgewidth=2)

ax.invert_xaxis()
ax.set_xlabel("Minimum Support (%)", labelpad=8)
ax.set_ylabel("#Frequent Itemsets (log scale)", labelpad=8)
ax.set_title("#Frequent Itemsets vs Minimum Support — All 9 Datasets")
ax.legend(title="Dataset", title_fontsize=10, ncol=2)
ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
fig.tight_layout()
savefig(fig, "itemsets_all.png")


# ══════════════════════════════════════════════════════════════════════════════
# Chart 13: Speedup Radar chart — Julia Opt vs SPMF across all datasets
# ══════════════════════════════════════════════════════════════════════════════
print("[13] Speedup radar chart")

speedup_data = {}
for name, fname, has_base in datasets_rt:
    fpath = os.path.join(RESULTS, fname)
    if not os.path.exists(fpath): continue
    rows    = read_csv(fname)
    # Only rows with valid SPMF timing (> 0)
    valid   = [r for r in rows if float(r["spmf_ms"]) > 0]
    if not valid: continue
    su_spmf = sorted([float(r["spmf_ms"]) / float(r["julia_opt_ms"]) for r in valid])
    speedup_data[name] = {
        "vs_spmf_all": su_spmf,
        "vs_spmf_med": su_spmf[len(su_spmf) // 2],
        "vs_spmf_min": su_spmf[0],
        "vs_spmf_max": su_spmf[-1],
    }
    if has_base:
        base_valid = [r for r in rows if r["baseline_ms"] not in ("N/A", "") and float(r["baseline_ms"]) > 0]
        if base_valid:
            su_base = sorted([float(r["baseline_ms"]) / float(r["julia_opt_ms"]) for r in base_valid])
            speedup_data[name]["vs_base_med"] = su_base[len(su_base) // 2]

categories = [n for n, *_ in datasets_rt if n in speedup_data]
N          = len(categories)
angles     = np.linspace(0, 2 * np.pi, N, endpoint=False).tolist()

def close(lst): return lst + [lst[0]]

raw_med = [speedup_data[n]["vs_spmf_med"] for n in categories]
raw_min = [speedup_data[n]["vs_spmf_min"] for n in categories]
raw_max = [speedup_data[n]["vs_spmf_max"] for n in categories]

# Normalise each axis to [0, 1] by its own max → equal scale, no distortion
norm_med = [m / mx for m, mx in zip(raw_med, raw_max)]
norm_min = [m / mx for m, mx in zip(raw_min, raw_max)]
norm_max = [1.0] * N   # always 1 after normalisation

RADAR_MED = "#1E88E5"   # blue  – median line (most important)
RADAR_MAX = "#E91E63"   # pink  – max boundary
RADAR_MIN = "#FF9800"   # amber – min boundary

fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True))
ax.set_facecolor("#F8F9FA")

# Shaded band: light pink fill for max region, white mask below min
ax.fill(close(angles), close(norm_max), alpha=0.12, color=RADAR_MAX)
ax.fill(close(angles), close(norm_min), alpha=0.32, color="white")

ax.plot(close(angles), close(norm_max), "--", color=RADAR_MAX, alpha=0.80,
        linewidth=1.6, label="Max speedup boundary")
ax.plot(close(angles), close(norm_min), ":",  color=RADAR_MIN, alpha=0.90,
        linewidth=1.6, label="Min speedup boundary")
ax.plot(close(angles), close(norm_med), "o-", color=RADAR_MED,
        linewidth=2.5, markersize=9, markerfacecolor="white",
        markeredgewidth=2.5, label="Median speedup (normalised per axis)")

# ── In-chart value badge — inside at 58% of the median radius ─────────────
for angle, norm_v, raw_v in zip(angles, norm_med, raw_med):
    badge_r = max(0.12, norm_v * 0.58)
    ax.text(angle, badge_r, f"{raw_v:.0f}×",
            ha="center", va="center", fontsize=10,
            color=RADAR_MED, fontweight="bold",
            bbox=dict(boxstyle="round,pad=0.22", fc="white",
                      ec=RADAR_MED, alpha=0.92, linewidth=1.0))

# ── Dataset name ONLY at outer rim — no sub-label so no overlap ───────────
ax.set_xticks(angles)
ax.set_xticklabels([])

def _align(angle_rad):
    deg = np.degrees(angle_rad) % 360
    if deg < 20 or deg > 340:       return "left",   "center"
    elif deg < 80:                  return "left",   "bottom"
    elif deg < 100:                 return "center", "bottom"
    elif deg < 160:                 return "right",  "bottom"
    elif deg < 200:                 return "right",  "center"
    elif deg < 260:                 return "right",  "top"
    elif deg < 280:                 return "center", "top"
    else:                           return "left",   "top"

R_LABEL = 1.20
for angle, cat in zip(angles, categories):
    ha, va = _align(angle)
    ax.text(angle, R_LABEL, cat,
            ha=ha, va=va, fontsize=11, fontweight="bold",
            color=DS_COLORS.get(cat, "#333333"))
ax.set_yticklabels(["25%", "50%", "75%", "100%\n(max)"],
                   fontsize=8, color="#888888")
ax.tick_params(axis="y", pad=4)
# Hide the auto outer-frame ring (drawn at ylim=1.30) and redraw at r=1.0
ax.spines["polar"].set_visible(False)
ax.plot(np.linspace(0, 2 * np.pi, 300), [1.0] * 300,
        "-", color="#CCCCCC", linewidth=1.0, zorder=0)
# Legend below chart, clear of all axis labels
handles, labels_leg = ax.get_legend_handles_labels()
ax.legend(handles, labels_leg,
          loc="upper center", bbox_to_anchor=(0.5, -0.08),
          fontsize=9, framealpha=0.92, edgecolor="#cccccc", ncol=1)

fig.tight_layout()
fig.subplots_adjust(bottom=0.18)
savefig(fig, "speedup_radar.png")


# ══════════════════════════════════════════════════════════════════════════════
# Chart 14: Speedup grouped bar — vs SPMF and vs Baseline
# ══════════════════════════════════════════════════════════════════════════════
print("[14] Speedup grouped bar")

names    = [n for n in [n for n, *_ in datasets_rt] if n in speedup_data]
med_spmf = [speedup_data[n]["vs_spmf_med"] for n in names]
med_base = [speedup_data[n].get("vs_base_med", 0) for n in names]
min_spmf = [speedup_data[n]["vs_spmf_min"] for n in names]
max_spmf = [speedup_data[n]["vs_spmf_max"] for n in names]

x = np.arange(len(names))
w = 0.38

fig, ax = plt.subplots(figsize=(10, 5.5))

bars_spmf = ax.bar(x - w/2, med_spmf, w,
                   color=COL_SPMF, alpha=0.85, label="vs SPMF (Java)",
                   zorder=3, edgecolor="white", linewidth=0.8)
bars_base = ax.bar(x + w/2, med_base, w,
                   color=COL_BASE, alpha=0.85, label="vs Baseline (Vector)",
                   zorder=3, edgecolor="white", linewidth=0.8)

# Error bars for SPMF (min/max range)
ax.errorbar(x - w/2, med_spmf,
            yerr=[np.array(med_spmf) - np.array(min_spmf),
                  np.array(max_spmf) - np.array(med_spmf)],
            fmt="none", color="#2E7D32", linewidth=1.8, capsize=5, zorder=4)

for bar, val in zip(bars_spmf, med_spmf):
    if val > 0.5:
        ax.text(bar.get_x() + bar.get_width()/2, val + max(med_spmf)*0.02,
                f"{val:.0f}×", ha="center", va="bottom",
                fontsize=10, fontweight="bold", color=COL_SPMF)
for bar, val in zip(bars_base, med_base):
    if val > 0.5:
        ax.text(bar.get_x() + bar.get_width()/2, val + max(med_spmf)*0.02,
                f"{val:.0f}×", ha="center", va="bottom",
                fontsize=10, fontweight="bold", color=COL_BASE)

ax.set_xticks(x)
ax.set_xticklabels(names, fontsize=10, rotation=20, ha="right")
ax.set_ylabel("Speedup (x) — median over minsup sweep", labelpad=8)
ax.set_title("Julia Optimised — Median Speedup vs SPMF & Baseline (all 9 datasets)\n"
             "(error bars = min/max range for SPMF comparison)")
ax.legend()
ax.set_ylim(0, max(max_spmf + med_base) * 1.15)
ax.axhline(1, color="#999999", linewidth=1, linestyle="--", zorder=2)
fig.tight_layout()
savefig(fig, "speedup_bar.png")


# ══════════════════════════════════════════════════════════════════════════════
# Chart 15: Memory — heap allocations (log scale)
# ══════════════════════════════════════════════════════════════════════════════
print("[15] Memory chart")

mem_rows = read_csv("memory.csv")
ds_names = [r["dataset"]              for r in mem_rows]
opt_mib  = [float(r["opt_alloc_mib"]) for r in mem_rows]
base_mib = []
for r in mem_rows:
    v = None
    try: v = float(r["base_alloc_mib"])
    except: pass
    base_mib.append(v if v and v > 0 else 0)

x = np.arange(len(ds_names))
w = 0.38

fig, ax = plt.subplots(figsize=(9, 5.5))
bars_opt  = ax.bar(x - w/2, opt_mib,  w, color=COL_OPT,  alpha=0.85,
                   label="Julia Optimised (BitArray)", zorder=3,
                   edgecolor="white", linewidth=0.8)
bars_base = ax.bar(x + w/2, base_mib, w, color=COL_BASE, alpha=0.85,
                   label="Julia Baseline (Vector)", zorder=3,
                   edgecolor="white", linewidth=0.8)

for bar, val in zip(bars_opt, opt_mib):
    ax.text(bar.get_x() + bar.get_width()/2,
            val * 1.08, f"{val:.0f}", ha="center", va="bottom",
            fontsize=9, color=COL_OPT, fontweight="bold")
for bar, val in zip(bars_base, base_mib):
    if val > 0:
        ax.text(bar.get_x() + bar.get_width()/2,
                val * 1.08, f"{val:.0f}", ha="center", va="bottom",
                fontsize=9, color=COL_BASE, fontweight="bold")

ax.set_yscale("log")
ax.set_xticks(x)
ax.set_xticklabels(ds_names, rotation=20, ha="right")
ax.set_ylabel("Total heap allocated (MiB, log scale)", labelpad=8)
ax.set_title("Memory Usage: Total Heap Allocations During Mining — All 9 Datasets\n"
             "(Baseline N/A for Kosarak, Retail, T10/T40I4D100K, Accidents)")
ax.legend()
ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
fig.tight_layout()
savefig(fig, "memory.png")


# ══════════════════════════════════════════════════════════════════════════════
# Charts 16–17: Scalability (Retail, uniform subsampling, minsup=1%)
# ══════════════════════════════════════════════════════════════════════════════
print("[16] Scalability vs n_tx")

sc_rows = read_csv("scalability.csv")
pcts    = [int(r["pct"])            for r in sc_rows]
n_txs   = [int(r["n_tx"])           for r in sc_rows]
opt_ms  = [float(r["julia_opt_ms"]) for r in sc_rows]
spmf_ms = [float(r["spmf_ms"])      for r in sc_rows]
lin_ref = [opt_ms[0] * n / n_txs[0] for n in n_txs]

# Chart 10 — runtime vs n_tx
fig, ax = plt.subplots(figsize=(8, 5))
ax.fill_between(n_txs, opt_ms, spmf_ms, alpha=0.08, color=COL_OPT)
ax.plot(n_txs, spmf_ms, "s--", color=COL_SPMF, label="SPMF (Java)",
        markerfacecolor="white", markeredgewidth=2)
ax.plot(n_txs, opt_ms,  "o-",  color=COL_OPT,  label="Julia Opt (BitArray)",
        markerfacecolor="white", markeredgewidth=2)

for i, (n, o, s) in enumerate(zip(n_txs, opt_ms, spmf_ms)):
    ax.annotate(f"{s/o:.1f}×",
                xy=(n, (o*s)**0.5), fontsize=8, color=COL_SPMF,
                ha="center",
                bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none", alpha=0.7))

ax.xaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{x/1000:.0f}k"))
ax.set_xlabel("Number of transactions", labelpad=8)
ax.set_ylabel("Runtime (ms)", labelpad=8)
ax.set_title("Scalability: Runtime vs DB Size\nRetail dataset, minsup=1%")
ax.legend()
fig.tight_layout()
savefig(fig, "scalability_by_ntx.png")

# Chart 17 — runtime vs % with linear reference
print("[17] Scalability vs % (with linear reference)")
fig, ax = plt.subplots(figsize=(8, 5))
ax.plot(pcts, lin_ref, "--", color=COL_LIN,  linewidth=1.5,
        label="Linear reference (ideal)", zorder=2)
ax.plot(pcts, spmf_ms, "s--", color=COL_SPMF, label="SPMF (Java)",
        markerfacecolor="white", markeredgewidth=2, zorder=3)
ax.plot(pcts, opt_ms,  "o-",  color=COL_OPT,  label="Julia Opt",
        markerfacecolor="white", markeredgewidth=2, zorder=4)
ax.fill_between(pcts, opt_ms, lin_ref,
                where=[o > l for o, l in zip(opt_ms, lin_ref)],
                alpha=0.10, color="red", label="Super-linear overhead")

ax.set_xlabel("Dataset sampled (%)", labelpad=8)
ax.set_ylabel("Runtime (ms)", labelpad=8)
ax.set_title("Scalability: Runtime vs Sample Size\n"
             "Retail, minsup=1% (dashed = perfect linear scaling)")
ax.legend()
fig.tight_layout()
savefig(fig, "scalability_by_pct.png")


# ══════════════════════════════════════════════════════════════════════════════
# Charts 18–19: Transaction length effect (Bernoulli synthetic)
# ══════════════════════════════════════════════════════════════════════════════
tl_rows  = read_csv("txlen_effect.csv")
avg_lens = [int(r["avg_len"])        for r in tl_rows]
counts   = [int(r["itemset_count"])  for r in tl_rows]
times    = [float(r["julia_opt_ms"]) for r in tl_rows]

# Chart 18 — #itemsets
print("[18] TxLen -> #itemsets")
fig, ax = plt.subplots(figsize=(8, 5))
bars = ax.bar(avg_lens, counts, width=3.5, color=COL_OPT, alpha=0.80,
              zorder=3, edgecolor="white", linewidth=0.8)
ax.axvline(x=30, color="red", linestyle="--", linewidth=2,
           label="Phase transition (avg_len ≈ 30)", zorder=4)
ax.fill_betweenx([0, max(counts) * 1.1], 28, 32,
                 alpha=0.10, color="red")
ax.set_xlabel("Avg Transaction Length", labelpad=8)
ax.set_ylabel("#Frequent Itemsets", labelpad=8)
ax.set_title("#Frequent Itemsets vs Avg Transaction Length\n"
             "Bernoulli model — N=5 000 tx, 100 items, minsup=30%")
ax.legend()
ax.set_ylim(0, max(counts) * 1.15)
ax.yaxis.set_major_formatter(ticker.FuncFormatter(lambda x, _: f"{x:,.0f}"))
fig.tight_layout()
savefig(fig, "txlen_itemsets.png")

# Chart 19 — runtime
print("[19] TxLen -> runtime")
fig, ax = plt.subplots(figsize=(8, 5))
ax.fill_between(avg_lens, 0, times, alpha=0.15, color=COL_BASE)
ax.plot(avg_lens, times, "o-", color=COL_BASE, label="Julia Opt",
        markerfacecolor="white", markeredgewidth=2)
ax.axvline(x=30, color="red", linestyle="--", linewidth=2,
           label="Phase transition (avg_len ≈ 30)")
ax.fill_betweenx([0, max(times) * 1.1], 28, 32, alpha=0.10, color="red")
ax.set_xlabel("Avg Transaction Length", labelpad=8)
ax.set_ylabel("Runtime (ms)", labelpad=8)
ax.set_title("Runtime vs Avg Transaction Length\n"
             "Bernoulli model — N=5 000 tx, 100 items, minsup=30%")
ax.legend()
ax.set_ylim(0, max(times) * 1.15)
fig.tight_layout()
savefig(fig, "txlen_runtime.png")


# ── Summary ────────────────────────────────────────────────────────────────
print(f"\nAll {len(os.listdir(FIGS))} charts saved to data/results/figures/")
for f in sorted(os.listdir(FIGS)):
    if f.endswith(".png"):
        print(f"  ✓ {f}")

