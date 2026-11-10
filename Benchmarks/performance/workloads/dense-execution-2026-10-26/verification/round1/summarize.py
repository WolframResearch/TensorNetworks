import os
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
    os.environ[key]='1'
import collections,hashlib,json,statistics,time
from pathlib import Path
import numpy as np
OUT=Path(__file__).resolve().parent
HERE=OUT.parents[1]
manifest=json.loads((HERE/'workloads/peps-2026-10-26/manifest.json').read_text())
run=json.loads((OUT/'run.json').read_text())
groups=collections.defaultdict(list)
for job in run['jobs']:
    groups[(job['case'],job['method'],job['limit_mib'])].append(job)
rows=[]
for (case,method,limit),jobs in groups.items():
    records=[j['probe']['records'][0] for j in jobs]
    cold=[r['first_seconds'] for r in records]
    warm=[x for r in records for x in r.get('samples_seconds',[])]
    values=[x for r in records for x in [r['first_value'],*r.get('samples_values',[])] if x is not None]
    rss=[j['sampled_process_tree_peak_rss_bytes'] for j in jobs]
    errors=[abs(x-next(c for c in manifest['cases'] if c['id']==case)['reference'])/abs(next(c for c in manifest['cases'] if c['id']==case)['reference']) for x in values]
    rows.append({'case':case,'method':method,'limit_mib':limit,'workers':len(jobs),
                 'cleared_first_seconds':cold,'cleared_first_median_seconds':statistics.median(cold),
                 'warm_samples_seconds':warm,'warm_median_seconds':statistics.median(warm) if warm else None,
                 'whole_worker_sampled_peak_rss_mib':[x/2**20 for x in rss],
                 'values':sorted(set(values)),'max_direct_relative_error_recomputed':max(errors) if errors else None,
                 'all_ok':all(r['ok'] for r in records),'failures':[r.get('failure') for r in records if not r['ok']],
                 'source_definition_guards_unchanged':all(j['probe']['definitions_unchanged'] and j['guards']['all_preexisting_function_definitions_unchanged'] for j in jobs),
                 'startup_and_other_overhead_seconds':[j['process_wall_seconds']-sum([r['first_seconds'],*r.get('samples_seconds',[])]) for j,r in zip(jobs,records)]})
independent=[]
for case in ('peps-norm-5x5-D4','peps-norm-6x6-D3'):
    c=next(c for c in manifest['cases'] if c['id']==case)
    state=[(np.fromfile(HERE/'results/peps-workloads'/spec['file'],dtype='<f8').reshape(spec['shape']),list(labels)) for spec,labels in zip(c['tensors'],c['labels'])]
    started=time.monotonic()
    for pair in c['paths']['cotengra.hyper3s']:
        (a,i),(b,j)=[state[p] for p in pair]
        common=[x for x in i if x in j]
        value=np.tensordot(a,b,axes=([i.index(x) for x in common],[j.index(x) for x in common]))
        labels=[x for x in i if x not in j]+[x for x in j if x not in i]
        state=[x for p,x in enumerate(state) if p not in pair]+[(value,labels)]
    value=float(state[0][0])
    independent.append({'case':case,'method':'NumPy tensordot, same archived path, no planner',
                        'value':value,'reference':c['reference'],'direct_relative_error':abs(value-c['reference'])/abs(c['reference']),
                        'execution_seconds_unbenchmarked_crosscheck':time.monotonic()-started})
summary={'rows':rows,'independent_scalar_crosscheck':independent,
         'all_workers_completed':all(j['status']=='ok' for j in run['jobs']),
         'all_rss_samples_valid':all(j['rss_sampling_errors']==0 for j in run['jobs'])}
(OUT/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for r in rows:
    print(r['case'],r['method'],r['limit_mib'],r['cleared_first_seconds'],r['warm_median_seconds'],r['whole_worker_sampled_peak_rss_mib'],r['all_ok'])
print(independent)
