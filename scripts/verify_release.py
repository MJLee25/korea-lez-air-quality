"""Check public file exclusions, checksums, result coverage and aggregate math."""
from pathlib import Path
import csv
import hashlib
import json
import re
import sys
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'OnlineResource2/monthly_results'
EXCLUDED = {'.git', 'generated', '__pycache__'}


def release_files():
    return sorted(p for p in ROOT.rglob('*') if p.is_file()
                  and not any(x in EXCLUDED for x in p.relative_to(ROOT).parts)
                  and p.suffix != '.pyc')


def main():
    files = release_files()
    restricted = {'02_final_data.csv', 'nearest_panel.csv', 'interpolation_station_input.csv',
                  'air_raw_month_with_metadata.csv.gz', 'kma_raw_selected.csv.gz'}
    for p in files:
        rel = p.relative_to(ROOT)
        assert p.name not in restricted, f'Restricted observations: {rel}'
        assert not any(x.lower() in {'inputs', 'review_data', 'private', 'data'} for x in rel.parts), rel
        assert p.suffix.lower() not in {'.zip','.gz','.geojson','.gpkg','.shp','.xlsx','.xls'}, rel
        if p.suffix.lower() == '.rds':
            assert rel.parts[:3] == ('OnlineResource2','monthly_results','inference_cache_journal'), rel
        assert p.stat().st_size < 100 * 1024**2, f'File exceeds GitHub normal file limit: {rel}'
    manifest_path = ROOT / 'manifest_sha256.csv'
    assert manifest_path.exists(), 'Missing release checksum manifest'
    with manifest_path.open(encoding='utf-8', newline='') as f:
        manifest = list(csv.DictReader(f))
    listed = {x['path'] for x in manifest}
    actual = {p.relative_to(ROOT).as_posix() for p in files if p != manifest_path}
    assert listed == actual, f'Manifest coverage differs: {listed ^ actual}'
    for row in manifest:
        assert hashlib.sha256((ROOT/row['path']).read_bytes()).hexdigest() == row['sha256'], row['path']

    inventory = json.loads((ROOT/'docs/result_inventory.json').read_text(encoding='utf-8'))
    assert len(inventory) == 20
    assert sum(x['item'].startswith('Table') for x in inventory) == 16
    assert sum(x['item'].startswith('Figure') for x in inventory) == 4
    for item in inventory:
        for field in ['artifact','preview','script']:
            if item[field]: assert (ROOT/item[field]).is_file(), item
        for data in item['data'].split(';'):
            if data: assert (ROOT/data).is_file(), data

    read = lambda name: pd.read_csv(OUT / (name+'.csv'))
    impacts = read('inference_impacts')
    hac = impacts.query('covariance == "HAC12"')
    coefs = read('inference_coefficients').query('covariance == "HAC12"')
    groups = hac.groupby(['specification','outcome'])
    assert len(groups) == 131 and len(hac) == 393
    assert len(read('event_summary')) == 20
    assert len(read('seasonal_omnibus')) == 10
    assert len(read('seasonal_pairwise')) == 60
    assert len(read('pooled_multiplicity')) == 5
    assert len(read('interpolation_validation')) == 34
    assert len(read('timing_sensitivity')) == 40
    assert np.isfinite(hac[['estimate','se','low','high']].to_numpy()).all()
    assert (hac.se > 0).all()
    np.testing.assert_allclose(hac.low, hac.estimate-1.96*hac.se, atol=1e-9)
    np.testing.assert_allclose(hac.high, hac.estimate+1.96*hac.se, atol=1e-9)
    assert (hac.n == hac.units * hac.periods).all()
    for (spec,y), g in groups:
        z = g.set_index('component')
        np.testing.assert_allclose(z.loc['Direct','estimate']+z.loc['Indirect','estimate'],
                                   z.loc['Total','estimate'], atol=1e-9)
        b = coefs[(coefs.specification==spec)&(coefs.outcome==y)].set_index('term').estimate
        np.testing.assert_allclose((b['lez']+b['w_lez'])/(1-b['lambda']), z.loc['Total','estimate'],atol=1e-9)
    def holm(p):
        values=np.asarray(p); order=np.argsort(values); answer=np.empty_like(values)
        answer[order]=np.minimum(1,np.maximum.accumulate(values[order]*(len(values)-np.arange(len(values)))))
        return answer
    for name in ['seasonal_omnibus','seasonal_pairwise','pooled_multiplicity']:
        d=read(name)
        np.testing.assert_allclose(d.p_holm, holm(d.p), atol=1e-12,rtol=1e-8)
    audit=read('data_audit')
    assert (audit.missing==0).all() and (audit.units==247).all()
    assert (read('overlap_audit').changed==0).all()
    print(json.dumps({'status':'PASS','manifest_files':len(manifest),'table_figure_items':20,
        'sdm_combinations':131,'event_combinations':20,'validation_summaries':34,
        'seasonal_omnibus':10,'seasonal_pairwise':60,'pooled_tests':5,
        'restricted_file_scan':'PASS','note':'No raw-data refitting performed by this check.'},indent=2))


if __name__ == '__main__':
    main()
