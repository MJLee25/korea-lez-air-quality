"""Generate the timing table directly from final HAC inference records."""
from pathlib import Path
import pandas as pd

PAPER = Path(__file__).resolve().parents[1]
data = pd.read_csv(PAPER / "monthly_results/inference_impacts.csv")
data = data[(data.covariance == "HAC12") & (data.component == "Total")]
scenarios = [
    ("Assigned months", "monthly", "trends"),
    ("Phase 2: Jan. 2018", "jan2018", "jan2018_trends"),
    ("Phase 3: July 2020", "jul2020", "jul2020_trends"),
    ("Phase 3: Dec. 2020", "dec2020", "dec2020_trends"),
]
pollutants = {"NO2": r"NO$_2$", "CO": "CO", "SO2": r"SO$_2$", "O3": r"O$_3$", "PM10": r"PM$_{10}$"}
lines = []
records = []
for label, base, trend in scenarios:
    for i, (y, tex) in enumerate(pollutants.items()):
        b = data[(data.specification == base) & (data.outcome == y)].iloc[0]
        t = data[(data.specification == trend) & (data.outcome == y)].iloc[0]
        assert b.n == t.n == 38532 and b.units == t.units == 247
        cells = [label if i == 0 else "", tex,
                 f"{b.estimate:.3f} ({b.se:.3f})", f"[{b.low:.3f}, {b.high:.3f}]",
                 f"{t.estimate:.3f} ({t.se:.3f})", f"[{t.low:.3f}, {t.high:.3f}]"]
        lines.append(" & ".join(cells) + r"\\")
        records.extend([dict(scenario=label, trend=False, **b.to_dict()),
                        dict(scenario=label, trend=True, **t.to_dict())])
    lines.append(r"\addlinespace")
(PAPER / "tables/timing_sensitivity.tex").write_text("\n".join(lines) + "\n")
pd.DataFrame(records).to_csv(PAPER / "monthly_results/timing_sensitivity.csv", index=False)
print(pd.DataFrame(records).query("outcome == 'NO2'")[["scenario", "trend", "estimate", "low", "high"]].to_string(index=False))
