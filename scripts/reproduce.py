"""Run the archived workflow in a fresh, isolated directory.

Public mode never needs original observations. Models/probe require separately
provided private panels and must write outside the repository.
"""
from pathlib import Path
import argparse
import json
import os
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['public', 'probe', 'models'])
    parser.add_argument('--output', type=Path)
    parser.add_argument('--data-dir', type=Path)
    parser.add_argument('--rscript', default='Rscript')
    args = parser.parse_args()
    executable = shutil.which(args.rscript)
    if executable is None:
        parser.error('Rscript not found. Add it to PATH or pass --rscript /path/to/Rscript.')
    dest = (args.output or ROOT / 'generated/public').resolve()
    if args.mode != 'public':
        if args.output is None or args.data_dir is None:
            parser.error('Private runs require both --data-dir and --output.')
        if dest == ROOT or ROOT in dest.parents:
            parser.error('Private model outputs must be outside the public repository.')
        args.data_dir = args.data_dir.resolve()
        for name in ['02_final_data.csv', 'nearest_panel.csv', 'analysis_coordinates.csv']:
            if not (args.data_dir / name).is_file():
                parser.error(f'Missing required private input: {name}. See docs/DATA_ACCESS.md.')
    if dest.exists():
        parser.error(f'Output already exists: {dest}. Choose a new directory; no results were overwritten.')
    dest.mkdir(parents=True)
    work = dest / 'OnlineResource2'
    shutil.copytree(ROOT / 'OnlineResource2', work,
                    ignore=shutil.ignore_patterns('__pycache__', '*.pyc', 'inputs'))
    env = os.environ.copy()
    # Force all data selection to the isolated run, avoiding ambient project paths.
    env['LEZ_PROJECT_ROOT'] = str(dest)
    env['LEZ_DATA_DIR'] = str(work / 'inputs')
    env.pop('LEZ_INCLUDE_2025', None)
    env.pop('LEZ_VALIDATION_CSV', None)
    if args.mode != 'public':
        (work / 'inputs').mkdir()
        for name in ['02_final_data.csv', 'nearest_panel.csv', 'analysis_coordinates.csv']:
            shutil.copy2(args.data_dir / name, work / 'inputs' / name)
    commands = []
    r = lambda file, *extra: [executable, str(work / 'analysis' / file), *extra]
    py = lambda file: [sys.executable, str(work / 'analysis' / file)]
    if args.mode != 'public':
        commands.append(r('monthly_analysis_journal.R', 'audit'))
        commands.append(r('monthly_analysis_journal.R', 'probe' if args.mode == 'probe' else 'models'))
    if args.mode == 'models':
        commands += [r('monthly_analysis_journal.R', 'events'), r('monthly_inference_journal.R')]
    if args.mode != 'probe':
        commands += [[executable, str(ROOT / 'scripts/check_aggregate_caches.R')],
                     r('monthly_outputs_journal.R'), r('seasonal_comparisons_journal.R'),
                     r('journal_outputs.R'), py('timing_outputs.py'), py('validation_outputs.py'),
                     r('verify_public.R' if args.mode == 'public' else 'verify_monthly.R')]
    if args.mode == 'models':
        commands.append(r('check_event_warnings.R'))
    report = {'mode': args.mode, 'status': 'running', 'steps': [],
              'observation_data_required': args.mode != 'public'}
    report_path = dest / 'run_report.json'
    try:
        with (dest / 'run.log').open('w', encoding='utf-8') as log:
            for cmd in commands:
                title = ' '.join([Path(cmd[0]).name, Path(cmd[1]).name, *cmd[2:]])
                print(title, flush=True)
                log.write('\n>>> ' + title + '\n'); log.flush()
                started = time.monotonic()
                done = subprocess.run(cmd, cwd=dest, env=env, stdout=log, stderr=subprocess.STDOUT)
                report['steps'].append({'command': title, 'returncode': done.returncode,
                                        'seconds': round(time.monotonic() - started, 2)})
                if done.returncode:
                    raise RuntimeError(f'{title} failed. See {dest / "run.log"}')
        if args.mode == 'public':
            import numpy as np
            import pandas as pd
            checks = []
            for name in ['seasonal_omnibus.csv', 'seasonal_pairwise.csv', 'pooled_multiplicity.csv',
                         'timing_sensitivity.csv', 'interpolation_validation.csv']:
                expected = pd.read_csv(ROOT / 'OnlineResource2/monthly_results' / name)
                actual = pd.read_csv(work / 'monthly_results' / name)
                pd.testing.assert_frame_equal(expected, actual, check_exact=False,
                    check_dtype=False, atol=1e-9, rtol=1e-9)
                checks.append({'file': name, 'rows': len(actual), 'match': True})
            for expected in (ROOT / 'OnlineResource2/tables').glob('*.tex'):
                actual = work / 'tables' / expected.name
                if expected.read_text(encoding='utf-8') != actual.read_text(encoding='utf-8'):
                    raise AssertionError(f'Regenerated table differs: {expected.name}')
            report['reference_comparisons'] = checks
            report['table_fragments_matched'] = 13
        report['status'] = 'PASS'
    except Exception as error:
        report['status'] = 'FAIL'
        report['error'] = str(error)
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {report_path}', flush=True)


if __name__ == '__main__':
    main()
