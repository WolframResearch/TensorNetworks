#!/usr/bin/env python3
"""Run PEPS norm scaling, path quality and bounded existing-engine comparisons."""
import argparse,json,os,sys
# Set native controls before importing NumPy through any dependency.
for thread_control in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
    os.environ[thread_control]='1'
from pathlib import Path
import cotengra as ctg
import peps_workloads,peps_execute,peps_engines
from common import digest,write_json
from python_bench import path_stats
from run import HERE,kernel_snapshot,run_process,suite_snapshot


def merge_plans(output):
    manifest=json.loads((output/'manifest.json').read_text())
    plans=json.loads((output/'tn-plans.json').read_text())
    assert len(manifest['cases'])==len(plans['records'])
    for case,record in zip(manifest['cases'],plans['records']):
        assert case['id']==record['id'] and record['same_form'] is True
        case['paths'].update({'tn.greedy':record['greedy_path'],'tn.automatic':record['automatic_path']})
        case['planning_seconds'].update({'tn.greedy':record['greedy_plan_seconds'],'tn.automatic':record['automatic_plan_seconds']})
        sizes={int(k):v for k,v in case['sizes'].items()}
        case['costs']={name:path_stats(case['labels'],[],sizes,path) for name,path in case['paths'].items()}
        for name,path in case['paths'].items():
            tree=ctg.ContractionTree.from_path(case['labels'],[],sizes,path=path)
            assert int(tree.max_size())==case['costs'][name]['largest_intermediate_elements']
            assert int(tree.contraction_cost())==case['costs'][name]['scalar_product_terms']
    manifest['protocol']={'description':'Exact real open-boundary PEPS norm, physical dimension2; squared bra/ket network',
        'python_search':'128 seeded random greedy trials; or unseeded random HyperOptimizer with greedy/subtree8,maxiter32,3-second budget',
        'max_intermediate_bytes_for_execution':256*2**20,'tn_additional_memory_limit_bytes':768*2**20,
        'tn_timeout_per_call_seconds':30,'samples_per_completed_job':3,
        'notes':['Planning and largest-intermediate values are measured/derived independently from numeric runtime.',
                 'Preflight exclusions are estimates, not observed OOMs. Largest intermediate is not total peak RAM.',
                 'ArrayDot and alternate engines use the same scalar reference, arrays and fixed saved paths.',
                 'Effective NumPy Accelerate thread count is unavailable; cross-runtime speed gaps cannot be fully attributed to TN.',
                 'The 3-second planner budget must be included for a one-off task and amortized only for repeated tasks.']}
    write_json(output/'manifest.json',manifest)
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--planning-only',action='store_true')
    args=parser.parse_args();output=args.out.resolve();output.mkdir(parents=True,exist_ok=False)
    for module in (peps_workloads,peps_execute,peps_engines):module.OUT=output
    before=kernel_snapshot();sources=suite_snapshot()
    peps_workloads.generate()
    env={**os.environ,'TN_PEPS_ROOT':str(output)}
    proc=run_process(['wolframscript','-local','/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel',
        '-file',str(HERE/'peps_planning.wls')],env,output/'planning.log',300,output/'planning.rss.txt')
    if proc['status']!='ok':raise RuntimeError('TN planning failed; see planning.log')
    merge_plans(output)
    if not args.planning_only:
        if peps_execute.main()!=0:raise RuntimeError('A PEPS ArrayDot execution failed')
        # Alternate engines may hit the explicit resource budget. Preserve these outcomes.
        peps_engines.main()
        alt=json.loads((output/'engines.json').read_text())
        if any(x['status']!='ok' and not x.get('failure_reason','').startswith(('memory_limit_','time_limit_')) for x in alt['results']):
            raise RuntimeError('An alternate engine produced an invalid result or unclassified failure')
    write_json(output/'audit.json',{'status':'completed','planning_only':args.planning_only,'kernel_files':before,
        'suite_files':sources,'kernel_unchanged':before==kernel_snapshot(),'suite_unchanged':sources==suite_snapshot(),
        'manifest_sha256':digest(output/'manifest.json')})
    assert before==kernel_snapshot() and sources==suite_snapshot()
    return 0

if __name__=='__main__':sys.exit(main())
