"""Format independently reproduced station holdout results, without refitting."""
from pathlib import Path
import os
import shutil
import pandas as pd

PAPER = Path(__file__).resolve().parents[1]
ROOT = Path(os.environ.get('LEZ_PROJECT_ROOT', PAPER.parents[2]))
source = ROOT / 'audits/ema_revision_20260928/independently_recomputed_cv.csv'
data = pd.read_csv(source)
shutil.copy2(source, PAPER / 'monthly_results/interpolation_validation.csv')
variables = [
    ('NO2_도시대기', r'NO$_2$ (ppb)'),
    ('CO_도시대기', 'CO (ppb)'),
    ('SO2_도시대기', r'SO$_2$ (ppb)'),
    ('O3_도시대기', r'O$_3$ (ppb)'),
    ('PM10_도시대기', r'PM$_{10}$ ($\mu$g/m$^3$)'),
    ('avg_temp', r'Temperature ($^\circ$C)'),
    ('sun_time', 'Sunshine (h/day)'),
    ('stagnant_days', 'Low-wind equivalent (days)'),
    ('avg_wind', 'Wind speed (m/s)'),
    ('avg_humid', r'Relative humidity (\%)'),
    ('avg_rain', 'Precipitation (mm/day)'),
]
lines = [r'\begin{tabular}{@{}lrrrrr@{}}', r'\toprule',
         r'& & \multicolumn{2}{c}{IDW} & \multicolumn{2}{c}{Nearest}\\',
         r'Variable & Holdouts & MAE & RMSE & MAE & RMSE\\', r'\midrule']
for variable, label in variables:
    a = data[(data.variable == variable) & (data.method == 'IDW')].iloc[0]
    b = data[(data.variable == variable) & (data.method == 'Nearest')].iloc[0]
    assert a['n'] == b['n']
    lines.append(f'{label} & {int(a["n"]):,} & {a.MAE:.3f} & {a.RMSE:.3f} & {b.MAE:.3f} & {b.RMSE:.3f}' + r'\\')
lines.extend([r'\bottomrule', r'\end{tabular}'])
(PAPER / 'tables/interpolation_validation.tex').write_text('\n'.join(lines) + '\n')
print('Generated station validation table and archived all 34 summary rows.')
