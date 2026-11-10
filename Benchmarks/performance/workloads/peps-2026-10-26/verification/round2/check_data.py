import os
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
    os.environ[key]='1'
import sys, json, hashlib, math, statistics, time, collections, shutil
from pathlib import Path
import numpy as np
import cotengra as ctg

HERE=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(HERE))
from common import digest,write_json
from run import kernel_snapshot,suite_snapshot
from python_bench import path_stats
OUT=Path(__file__).resolve().parent
SRC=HERE/'workloads/peps-2026-10-26'
manifest=json.loads((SRC/'manifest.json').read_text())
execution=json.loads((SRC/'execution.json').read_text())
engines=json.loads((SRC/'engines.json').read_text())
evidence=json.loads((SRC/'evidence.json').read_text())
archive=np.load(SRC/'site-tensors.npz')
out={'versions':{'python':sys.version,'numpy':np.__version__,'cotengra':ctg.__version__},'checks':{},'cases':[],'python_replay':[],'search_trials':[]}
checks=out['checks']
checks['kernel_hashes_match']=kernel_snapshot()==evidence['kernel_files']==execution['kernel_files']==engines['kernel_files']
checks['archive_hash']=digest(SRC/'site-tensors.npz')==evidence['site_archive_sha256']
checks['current_sources']={n:digest(HERE/n)==h for n,h in evidence['source_sha256'].items()}
checks['original_sources']={n:digest((SRC/'measurement-sources'/n) if (SRC/'measurement-sources'/n).exists() else HERE/n)==h for n,h in evidence['measurement_source_sha256'].items()}
checks['measurement_table_sources']={n:h==execution['suite_files'][n]==engines['suite_files'][n] for n,h in evidence['measurement_source_sha256'].items() if n in execution['suite_files'] and n in engines['suite_files']}
all_keys=set()
for c in manifest['cases']:
    n=c['side'];D=c['bond'];count=n*n;specs=c['tensors']
    labels=[[] for _ in range(count)];edge=0
    for i in range(n):
        for j in range(n):
            for di,dj in ((1,0),(0,1)):
                if i+di<n and j+dj<n:
                    labels[i*n+j].append(edge);labels[(i+di)*n+j+dj].append(edge);edge+=1
    ket=[inds+[edge+k] for k,inds in enumerate(labels)]
    bra=[[x+edge+count for x in inds]+[edge+k] for k,inds in enumerate(labels)]
    assert c['labels']==ket+bra and edge==2*n*(n-1)
    assert specs[:count]==specs[count:] and len(specs)==2*count
    rng=np.random.default_rng(20261026+100*n+D)
    arrays=[]
    for k,spec in enumerate(specs[:count]):
        a=archive[spec['file']];all_keys.add(spec['file'])
        assert list(a.shape)==spec['shape']==[D]*(len(ket[k])-1)+[2]
        assert a.dtype==np.float64 and np.isfinite(a).all() and np.isrealobj(a)
        assert abs(np.linalg.norm(a)-1)<1e-14
        raw=np.asarray(a,dtype='<f8',order='C').tobytes()
        assert hashlib.sha256(raw).hexdigest()==spec['sha256'] and len(raw)==spec['bytes']
        (OUT/spec['file']).write_bytes(raw)
        generated=rng.normal(size=a.shape);generated/=np.linalg.norm(generated)
        assert np.array_equal(a,generated)
        arrays.append(a)
    sizes={int(k):v for k,v in c['sizes'].items()}
    assert all(sizes[l]==dim for a,ls in zip(arrays+arrays,c['labels']) for l,dim in zip(ls,a.shape))
    occurrences=collections.Counter(l for ls in c['labels'] for l in ls)
    assert set(occurrences.values())=={2}
    assert c['input_bytes']==sum(s['bytes'] for s in specs)
    costs={}
    for name,p in c['paths'].items():
        # Independent shrinking-index simulation, using multiplicities of labels.
        remaining=[set(x) for x in c['labels']];largest=0;terms=0
        for i,j in p:
            assert i!=j and 0<=i<len(remaining) and 0<=j<len(remaining)
            union=remaining[i]|remaining[j]
            rest=[r for k,r in enumerate(remaining) if k not in (i,j)]
            needed=set().union(*rest)
            new=union&needed
            terms+=math.prod(sizes[x] for x in union)
            largest=max(largest,math.prod(sizes[x] for x in new))
            remaining=rest+[new]
        assert remaining==[set()]
        tree=ctg.ContractionTree.from_path(c['labels'],[],sizes,path=p)
        assert largest==int(tree.max_size())==c['costs'][name]['largest_intermediate_elements']
        assert terms==int(tree.contraction_cost())==c['costs'][name]['scalar_product_terms']
        assert path_stats(c['labels'],[],sizes,p)==c['costs'][name]
        costs[name]={'largest_bytes':largest*8,'scalar_product_terms':terms}
    rows=[r for r in execution['results']+engines['results'] if r['case']==c['id']]
    expected_excluded={p for p,co in costs.items() if co['largest_bytes']>256*2**20}
    actual_excluded={r['path'] for r in rows if r['status']=='not_executed_memory_estimate'}
    assert expected_excluded==actual_excluded
    for r in rows:
        if r['status']=='ok':
            ref=c['reference'];value=r['value']
            assert math.isfinite(ref) and ref>0 and math.isfinite(value)
            direct=abs(value-ref)/abs(ref)
            assert direct<1e-9 and 0<=r['relative_error']<1e-9 and r['relative_error']+1e-30>=direct
            assert costs[r['path']]['largest_bytes']<=256*2**20
            assert len(r['samples_seconds'])==3 and all(t>0 and math.isfinite(t) for t in r['samples_seconds'])
            if r['backend']=='tn':assert r['first_ok'] is True and r['correct'] is True and r['process']['status']=='ok'
        elif r['status']=='not_executed_memory_estimate':
            assert r['largest_intermediate_bytes']==costs[r['path']]['largest_bytes']
        else:
            assert r['failure_reason']=='memory_limit_768MiB' and not r['first_ok'] and not r['samples_seconds']
    out['cases'].append({'case':c['id'],'reference':c.get('reference'),'costs':costs,'retained_rows':len(rows)})
    if 'reference' in c:
        expression=ctg.array_contract_expression(c['labels'],[],shapes=[a.shape for a in arrays+arrays],optimize=c['paths']['cotengra.hyper3s'],cache=False,autojit=False)
        values=[];times=[]
        for _ in range(4):
            start=time.perf_counter();v=float(expression(*(arrays+arrays),backend='numpy'));times.append(time.perf_counter()-start);values.append(v)
        errors=[abs(v-c['reference'])/c['reference'] for v in values]
        assert max(errors)<1e-9 and min(values)>0
        out['python_replay'].append({'case':c['id'],'first_seconds':times[0],'samples_seconds':times[1:],'values':values,'relative_errors':errors})
    if c['id'] in ('peps-norm-5x5-D4','peps-norm-6x6-D3'):
        for trial in range(3):
            opt=ctg.RandomGreedyOptimizer(max_repeats=128,seed=20261026,accel=False,parallel=False)
            start=time.perf_counter();path=opt(c['labels'],[],sizes);elapsed=time.perf_counter()-start
            assert [list(p) for p in path]==c['paths']['cotengra.random128']
            out['search_trials'].append({'case':c['id'],'search':'random128','trial':trial,'seconds':elapsed,'same_saved_path':True})
            opt=ctg.HyperOptimizer(methods=['greedy'],max_time=3,max_repeats=128,parallel=False,optlib='random',reconf_opts={'subtree_size':8,'maxiter':32},simulated_annealing_opts=None,slicing_opts=None,slicing_reconf_opts=None,on_trial_error='raise',progbar=False)
            start=time.perf_counter();tree=opt.search(c['labels'],[],sizes);elapsed=time.perf_counter()-start
            out['search_trials'].append({'case':c['id'],'search':'hyper3s','trial':trial,'seconds':elapsed,'largest_bytes':int(tree.max_size())*8})
    write_json(OUT/'data-checks.json',out)
    print(c['id'],'OK',flush=True)
assert set(archive.files)==all_keys
checks['all_archive_keys_used']=True
checks['all_original_references_above_old_floor']=all(c.get('reference',1)>1e-300 for c in manifest['cases'])
checks['minimum_reference']=min(c['reference'] for c in manifest['cases'] if 'reference' in c)
checks['all_structural_checks_passed']=True
write_json(OUT/'manifest.json',manifest)
write_json(OUT/'data-checks.json',out)
write_json(OUT/'before.json',{'kernel':kernel_snapshot(),'suite':suite_snapshot()})
print(json.dumps(checks,indent=2),flush=True)
