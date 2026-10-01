from pathlib import Path
import hashlib
import json
import os
import re
import zipfile
from lxml import html
import numpy as np
import pandas as pd

PAPER = Path(__file__).resolve().parents[1]
ROOT = Path(os.environ.get('LEZ_PROJECT_ROOT', PAPER.parents[2]))
OUT = Path(os.environ.get('LEZ_VALIDATION_OUTPUT', PAPER / 'validation_reproduction'))
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = Path(os.environ['LEZ_SOURCE_DIR']) if 'LEZ_SOURCE_DIR' in os.environ else next(p for p in (ROOT / '코드및데이터').glob('*20260920-re') if p.is_dir())
EVIDENCE = next(SOURCE.glob('04_*'))
INPUT = next(p.parent for p in EVIDENCE.rglob('grid_points.csv'))
KEYS = ['ID', 'year', 'month']


def compare_panel():
    supplied = pd.read_csv(SOURCE / '02_final_data.csv').sort_values(KEYS).reset_index(drop=True)
    replay = pd.read_csv(OUT / 'reproduced/final_data.csv').sort_values(KEYS).reset_index(drop=True)
    assert set(supplied.columns) == set(replay.columns)
    assert supplied[KEYS].equals(replay[KEYS])
    checks = []
    for c in supplied:
        if pd.api.types.is_numeric_dtype(supplied[c]) and supplied[c].dtype != bool:
            delta = np.abs(supplied[c].to_numpy() - replay[c].to_numpy())
            checks.append(dict(variable=c, rows=len(supplied), max_abs_difference=float(delta.max()),
                passed=bool(np.allclose(supplied[c], replay[c], atol=1e-8, rtol=1e-12))))
        else:
            checks.append(dict(variable=c, rows=len(supplied), max_abs_difference=None,
                passed=bool(supplied[c].astype(str).str.lower().equals(replay[c].astype(str).str.lower()))))
    c = pd.DataFrame(checks)
    c.to_csv(OUT / 'independent_R_reproduction_check.csv', index=False)
    print('Panel match:', bool(c.passed.all()), 'rows:', len(supplied), 'columns:', len(c),
          'max numeric difference:', c.max_abs_difference.max(), flush=True)
    weights = pd.read_csv(INPUT / 'grid_area_weights.csv')
    grid = pd.read_csv(INPUT / 'grid_points.csv')
    spatial = dict(grid_points=len(grid), weight_entries=len(weights),
        duplicate_ID_grid_keys=int(weights.duplicated(['ID', 'grid_id']).sum()),
        nonpositive_weights=int((weights.weight <= 0).sum()),
        max_row_sum_error=float((weights.groupby('ID').weight.sum() - 1).abs().max()),
        grid_id_matches_row_index=bool(np.array_equal(grid.grid_id, np.arange(1, len(grid) + 1))),
        missing_grid_ids=len(set(weights.grid_id) - set(grid.grid_id)),
        region_IDs_match=set(weights.ID) == set(supplied.ID))
    (OUT / 'spatial_weight_checks.json').write_text(json.dumps(spatial, indent=2))


def verify_cv():
    station = pd.read_csv(OUT / 'reproduced/interpolation_station_input.csv')
    rows = []
    sums = {}
    duplicate_xy = []
    for (year, month, v), g in station.groupby(['year', 'month', 'variable'], sort=True):
        xy = g[['x', 'y']].to_numpy()
        val = g.value.to_numpy()
        d2 = ((xy[:, None, :] - xy[None, :, :]) ** 2).sum(axis=2)
        np.fill_diagonal(d2, np.inf)
        if (d2 == 0).any():
            duplicate_xy.append(dict(year=year, month=month, variable=v, colocated_pairs=int((d2 == 0).sum() // 2)))
        w = 1 / np.maximum(d2, 1e-16)
        w /= w.sum(axis=1)[:, None]
        preds = {'IDW': w @ val, 'Nearest': val[d2.argmin(axis=1)]}
        if v == 'avg_rain':
            block = np.floor(xy / 100000).astype(int)
            blocked = d2.copy()
            blocked[(block[:, None, :] == block[None, :, :]).all(axis=2)] = np.inf
            assert (np.isfinite(blocked).sum(axis=1) >= 3).all()
            bw = 1 / np.maximum(blocked, 1e-16)
            bw /= bw.sum(axis=1)[:, None]
            preds['IDW_block100km'] = bw @ val
            preds['Nearest_block100km'] = val[blocked.argmin(axis=1)]
        for method, pred in preds.items():
            e = pred - val
            sums.setdefault((v, method), np.zeros(4))
            sums[(v, method)] += [len(e), np.abs(e).sum(), (e ** 2).sum(), e.sum()]
        rows.append(dict(year=year, month=month, variable=v, stations=len(g)))
    calculated = []
    for (v, method), (n, ae, se, e) in sums.items():
        calculated.append(dict(variable=v, method=method, n=int(n), MAE=ae/n, RMSE=np.sqrt(se/n), bias=e/n))
    cv = pd.DataFrame(calculated)
    cv.to_csv(OUT / 'independently_recomputed_cv.csv', index=False)
    published = pd.read_csv(EVIDENCE / 'cv_summary.csv')
    z = cv.merge(published, on=['variable', 'method'], suffixes=('_new', '_reported'), validate='one_to_one')
    for col in ['n', 'MAE', 'RMSE', 'bias']:
        z[col + '_difference'] = z[col + '_new'] - z[col + '_reported']
    z.to_csv(OUT / 'cv_independent_comparison.csv', index=False)
    support = pd.DataFrame(rows).merge(pd.read_csv(EVIDENCE / 'interpolation_support.csv'),
        on=['year', 'month', 'variable'], suffixes=('_new', '_reported'), validate='one_to_one')
    pd.DataFrame(duplicate_xy).to_csv(OUT / 'colocated_station_cv_groups.csv', index=False)
    summary = dict(method_variable_groups=len(z), max_error=z.filter(regex='_difference$').abs().max().to_dict(),
        all_support_counts_match=bool((support.stations_new == support.stations_reported).all()),
        support_groups=len(support), colocated_cv_groups=len(duplicate_xy),
        rain_valid_station_months=int(station.variable.eq('avg_rain').sum()))
    (OUT / 'cv_reproduction_summary.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2), flush=True)


def verify_rain_archive():
    archive = next(EVIDENCE.glob('*.zip'))
    supplied = pd.read_csv(INPUT / 'rain_official_comparison.csv')
    checked = []
    with zipfile.ZipFile(archive) as z:
        for name in z.namelist():
            if not name.endswith('.html'):
                continue
            st, year = map(int, Path(name).stem.split('_'))
            raw = z.read(name)
            s = raw.decode('utf-8-sig')
            tree = html.fromstring(s)
            totals = [r for r in tree.xpath('//table//tr') if
                      r.xpath('./th|./td') and r.xpath('./th|./td')[0].text_content().strip() == '합계']
            assert len(totals) == 1
            cells = totals[0].xpath('./th|./td')
            assert len(cells) == 13
            ref = supplied[(supplied.stnId == st) & (supplied.year == year)].sort_values('month')
            assert len(ref) == 12
            values = pd.to_numeric(pd.Series([c.text_content().strip() for c in cells[1:]]), errors='coerce').to_numpy()
            checked.append(dict(stnId=st, year=year,
                selected_station_year_element=all(bool(re.search(fr'value="{v}"\s+selected=', s)) for v in [st, year, 21]),
                raw_bytes_sha256_matches=hashlib.sha256(raw).hexdigest() == ref.source_sha256.iloc[0],
                lf_normalized_sha256_matches=hashlib.sha256(raw.replace(b'\r\n', b'\n')).hexdigest() == ref.source_sha256.iloc[0],
                monthly_totals_match=bool(np.allclose(values, ref.official_month_total, equal_nan=True, atol=1e-10, rtol=0))))
    check = pd.DataFrame(checked)
    check.to_csv(OUT / 'rain_archived_html_check.csv', index=False)
    report = dict(archived_station_years=len(check), monthly_cells=len(check)*12,
                  all_selection_and_monthly_value_checks_pass=bool(check[['selected_station_year_element', 'monthly_totals_match']].all().all()),
                  raw_bytes_hash_matches=int(check.raw_bytes_sha256_matches.sum()),
                  lf_normalized_hash_matches=int(check.lf_normalized_sha256_matches.sum()),
                  hash_note='Stored source_sha256 hashes LF-normalized HTML text, not the CRLF bytes inside the archive.')
    (OUT / 'rain_archive_summary.json').write_text(json.dumps(report, indent=2))
    print('Rain archive:', report, flush=True)


if __name__ == '__main__':
    compare_panel()
    verify_cv()
    verify_rain_archive()
