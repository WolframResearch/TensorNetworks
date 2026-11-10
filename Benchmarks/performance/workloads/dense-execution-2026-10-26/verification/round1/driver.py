import os
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
    os.environ[key]='1'
import ast, collections, hashlib, json, math, re, signal, statistics, subprocess, sys, time
from pathlib import Path
import numpy as np

REPO=Path(__file__).resolve().parents[4]
HERE=REPO/'Benchmarks/performance'
OUT=Path(__file__).resolve().parent
TARGET=HERE/'workloads/dense-execution-2026-10-26'
PRIOR=HERE/'workloads/peps-2026-10-26'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def save(name,value): (OUT/name).write_text(json.dumps(value,indent=2)+'\n')
def kernel_snapshot():
    paths=sorted((REPO/'TensorNetworks/Kernel').rglob('*.wl'))+[REPO/'TensorNetworks/PacletInfo.wl']
    return {str(p.relative_to(REPO)):sha(p) for p in paths}

# Use the existing runner functions verbatim, without importing unrelated corpus generators.
tree=ast.parse((HERE/'run.py').read_text())
funcs=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ('run_process','stop_process_group')]
exec(compile(ast.Module(body=funcs,type_ignores=[]),str(HERE/'run.py'),'exec'))

before=kernel_snapshot()
manifest=json.loads((PRIOR/'manifest.json').read_text())
checks=[]
with np.load(PRIOR/'site-tensors.npz',allow_pickle=False) as archive:
    for c in manifest['cases']:
        counts=collections.Counter(x for labels in c['labels'] for x in labels)
        assert set(counts.values())=={2}
        assert all(len(x)==len(set(x)) for x in c['labels'])
        for spec in c['tensors']:
            path=HERE/'results/peps-workloads'/spec['file']
            assert sha(path)==spec['sha256']
            assert path.stat().st_size==spec['bytes']==8*math.prod(spec['shape'])
            a=np.fromfile(path,dtype='<f8').reshape(spec['shape'])
            assert np.array_equal(a,archive[spec['file']])
        active=[set(x) for x in c['labels']]
        for pair in c['paths']['cotengra.hyper3s']:
            assert len(pair)==2 and len(set(pair))==2
            assert all(0<=p<len(active) for p in pair)
            a,b=[active[p] for p in pair]
            active=[x for p,x in enumerate(active) if p not in pair]+[a^b]
        assert active==[set()]
        checks.append({'case':c['id'],'tensor_specs_checked':len(c['tensors']),
                       'closed_binary_unique_per_operand':True,'refined_path_valid':True,
                       'refined_path_json_sha256':hashlib.sha256(json.dumps(c['paths']['cotengra.hyper3s'],separators=(',',':')).encode()).hexdigest(),
                       'reference':c.get('reference')})
save('preflight.json',{'kernel_files_before':before,'runner_sha256':sha(HERE/'run.py'),
                     'target_files_before':{str(p.relative_to(TARGET)):sha(p) for p in TARGET.rglob('*') if p.is_file()},
                     'manifest_sha256':sha(PRIOR/'manifest.json'),'npz_sha256':sha(PRIOR/'site-tensors.npz'),
                     'checks':checks})
methods=['public_ArrayDot','public_Dot','standalone_existing_ArrayDot','standalone_2D_Dot']
jobs=[]
for round_index in range(3):
    order=methods if round_index==0 else list(reversed(methods)) if round_index==1 else methods[2:]+methods[:2]
    for case in (['peps-norm-5x5-D4','peps-norm-6x6-D3'] if round_index!=1 else ['peps-norm-6x6-D3','peps-norm-5x5-D4']):
        jobs.extend((case,method,2048,round_index) for method in order)
jobs += [('peps-norm-5x5-D4',m,768,0) for m in ('public_ArrayDot','public_Dot','standalone_existing_Dot','standalone_2D_Dot','standalone_fused_2D_Dot')]
jobs += [('peps-norm-5x5-D4','standalone_fused_2D_Dot',2048,0),
         ('peps-norm-5x5-D4','standalone_existing_Dot',2048,0),
         ('peps-norm-6x6-D3','standalone_existing_Dot',768,0),
         ('peps-norm-6x6-D3','public_ArrayDot',768,0)]
records=[]
for index,(case,method,limit,round_index) in enumerate(jobs):
    name=f'{index:02d}-{case}-{method}-{limit}-r{round_index}'
    env={**os.environ,'TN_PROBE_HERE':str(HERE),'TN_PROBE_OUT':str(OUT/f'{name}.json'),
         'TN_PROBE_CASE':case,'TN_PROBE_LIMIT_MIB':str(limit),'TN_PROBE_METHODS':method,
         'TN_VERIFY_GUARDS':str(OUT/f'{name}.guards.json')}
    command=['wolframscript','-local','/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel','-file',str(OUT/'worker.wls')]
    print(f'{index+1}/{len(jobs)} {name}',flush=True)
    info=run_process(command,env,OUT/f'{name}.log',180,OUT/f'{name}.rss.txt')
    info.update(case=case,method=method,limit_mib=limit,round=round_index,command=command)
    if (OUT/f'{name}.json').exists(): info['probe']=json.loads((OUT/f'{name}.json').read_text())
    if (OUT/f'{name}.guards.json').exists(): info['guards']=json.loads((OUT/f'{name}.guards.json').read_text())
    records.append(info)
    save('run.json',{'protocol':'Fresh one-method workers, serial, 3 counterbalanced repetitions; first call ClearSystemCache; remaining 3 samples warm; RSS is complete worker including startup and 4 evaluations, sampled 50 ms.','jobs':records})
    row=info.get('probe',{}).get('records',[{}])[0]
    print({k:row.get(k) for k in ('name','first_seconds','samples_seconds','ok','failure')},flush=True)
after=kernel_snapshot()
save('postflight.json',{'kernel_files_after':after,'kernel_sources_unchanged':before==after,
                     'target_files_after':{str(p.relative_to(TARGET)):sha(p) for p in TARGET.rglob('*') if p.is_file()}})
