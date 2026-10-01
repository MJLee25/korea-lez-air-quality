"""Nearest-station sensitivity on the primary panel's identical areal support."""
from pathlib import Path
import hashlib
import json
import os
import numpy as np
import pandas as pd

PAPER = Path(__file__).resolve().parents[1]
ROOT = Path(os.environ.get('LEZ_PROJECT_ROOT', PAPER.parents[2]))
DATA = Path(os.environ.get('LEZ_DATA_DIR', ROOT / '코드및데이터'))
SOURCE = Path(os.environ['LEZ_SOURCE_DIR']) if 'LEZ_SOURCE_DIR' in os.environ else next(p for p in DATA.glob('*20260920-re') if p.is_dir())
EVIDENCE = next(SOURCE.glob('04_*'))
INPUT = next(EVIDENCE.rglob('grid_points.csv')).parent
STATION = Path(os.environ.get('LEZ_STATION_INPUT', ROOT / 'audits/ema_revision_20260928/reproduced/interpolation_station_input.csv'))
primary = pd.read_csv(SOURCE / '02_final_data.csv')
station = pd.read_csv(STATION)
grid = pd.read_csv(INPUT / 'grid_points.csv')
weights = pd.read_csv(INPUT / 'grid_area_weights.csv')
ids = np.sort(primary.ID.unique())
region_index = np.searchsorted(ids, weights.ID.to_numpy())
grid_index = weights.grid_id.to_numpy() - 1
assert np.array_equal(grid.grid_id, np.arange(1, len(grid) + 1))
assert np.allclose(np.bincount(region_index, weights=weights.weight), 1)
xy = grid[['x', 'y']].to_numpy()
outputs = []
support = []
for (year, month, variable), g in station.groupby(['year', 'month', 'variable'], sort=True):
    # Code breaks exact-distance ties by station identifier, not file ordering.
    g = g.sort_values('station_id')
    sx = g[['x', 'y']].to_numpy()
    d2 = ((xy[:, None, :] - sx[None, :, :]) ** 2).sum(axis=2)
    nearest = d2.argmin(axis=1)
    pred = g.value.to_numpy()[nearest]
    values = np.bincount(region_index, weights=weights.weight.to_numpy() * pred[grid_index], minlength=len(ids))
    outputs.append(pd.DataFrame(dict(ID=ids, year=year, month=month, variable=variable, value=values)))
    support.append(dict(year=year, month=month, variable=variable, stations=len(g)))
    if month == 12 and variable == 'sun_time':
        print('Nearest interpolation completed:', year, flush=True)
wide = pd.concat(outputs).pivot(index=['ID', 'year', 'month'], columns='variable', values='value').reset_index()
environment = list(station.variable.unique())
nearest = primary.drop(columns=environment).merge(wide, on=['ID', 'year', 'month'], validate='one_to_one')
nearest = nearest[primary.columns].sort_values(['ID', 'year', 'month'])
assert len(nearest) == 38844 and not nearest.isna().any().any()
assert len(support) == 16 * 156
published = pd.read_csv(EVIDENCE / 'interpolation_support.csv')
z = pd.DataFrame(support).merge(published, on=['year', 'month', 'variable'], validate='one_to_one', suffixes=('_new', '_reported'))
assert (z.stations_new == z.stations_reported).all()
nearest['processing_version'] = '20260929-nearest-sensitivity'
dest = PAPER / 'inputs/nearest_panel.csv'
nearest.to_csv(dest, index=False, encoding='utf-8-sig')
manifest = dict(method='Nearest eligible station to each fixed grid-cell centre, intersection-area weighted by district',
    tie_break='ascending station_id', rows=len(nearest), environmental_variables=environment,
    primary_sha256=hashlib.sha256((SOURCE / '02_final_data.csv').read_bytes()).hexdigest(),
    station_input_sha256=hashlib.sha256(STATION.read_bytes()).hexdigest(),
    nearest_sha256=hashlib.sha256(dest.read_bytes()).hexdigest(),
    same_stations_months_covariates_boundaries_and_area_weights=True)
(PAPER / 'inputs/nearest_manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
print('Saved', dest, flush=True)
