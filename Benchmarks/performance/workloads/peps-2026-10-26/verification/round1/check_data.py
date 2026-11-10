import os
for k in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'): os.environ[k]='1'
import sys,json,hashlib,collections,math,statistics,inspect
from pathlib import Path
here=Path(__file__).resolve().parents[2];sys.path.insert(0,str(here))
import numpy as np, cotengra as ctg
from python_bench import path_stats
from common import digest,write_json
from run import kernel_snapshot,suite_snapshot
src=here/'workloads/peps-2026-10-26';out=Path(__file__).resolve().parent; replay=out/'replay';replay.mkdir(exist_ok=True)
parsed={f:json.loads((src/f).read_text()) for f in ('manifest.json','tn-plans.json','execution.json','engines.json','evidence.json')}
m=parsed['manifest.json'];archive=np.load(src/'site-tensors.npz');files={};counts=[];costs=[]
for c in m['cases']:
 n=c['side']**2;e=2*c['side']*(c['side']-1);assert c['site_tensors']==n and len(c['tensors'])==2*n
 labels=c['labels'];assert len(labels)==2*n
 expected=[[] for _ in range(n)];edge=0
 for i in range(c['side']):
  for j in range(c['side']):
   for di,dj in ((1,0),(0,1)):
    if i+di<c['side'] and j+dj<c['side']:
     expected[i*c['side']+j].append(edge);expected[(i+di)*c['side']+j+dj].append(edge);edge+=1
 assert edge==e and labels[:n]==[inds+[e+k] for k,inds in enumerate(expected)]
 assert labels[n:]==[[x+e+n for x in inds]+[e+k] for k,inds in enumerate(expected)]
 assert set(collections.Counter(sum(labels,[])).values())=={2}
 assert c['tensors'][:n]==c['tensors'][n:]
 for s,inds in zip(c['tensors'],labels):
  a=archive[s['file']];assert a.shape==tuple(s['shape']);assert a.dtype.kind=='f' and np.isfinite(a).all()
  assert list(a.shape)==[c['bond']]*(len(inds)-1)+[2]
  assert abs(np.linalg.norm(a)-1)<1e-14
  raw=np.asarray(a,dtype='<f8',order='C').tobytes(order='C');assert hashlib.sha256(raw).hexdigest()==s['sha256'];assert len(raw)==s['bytes']
  (replay/s['file']).write_bytes(raw);files[s['file']]=s['sha256']
 assert c['input_bytes']==sum(s['bytes'] for s in c['tensors'])
 sizes={int(k):v for k,v in c['sizes'].items()};assert all(sizes[x]==(2 if e<=x<e+n else c['bond']) for x in sizes)
 for name,p in c['paths'].items():
  s=path_stats(labels,[],sizes,p);assert s==c['costs'][name]
  tree=ctg.ContractionTree.from_path(labels,[],sizes,path=p)
  assert int(tree.max_size())==s['largest_intermediate_elements'] and int(tree.contraction_cost())==s['scalar_product_terms']
  costs.append({'case':c['id'],'path':name,**s,'MiB':s['largest_intermediate_elements']*8/2**20})
 counts.append({'case':c['id'],'sites':n,'bonds':e,'reference':c.get('reference')})
write_json(replay/'manifest.json',m)
assert set(archive.files)==set(files)
e=parsed['evidence.json'];assert digest(src/'site-tensors.npz')==e['site_archive_sha256']
assert kernel_snapshot()==e['kernel_files']
assert all(digest(here/k)==v for k,v in e['source_sha256'].items())
snapshot_checks={}
for name in ('execution.json','engines.json'):
 d=parsed[name];assert d['kernel_unchanged'] and d['suite_unchanged'];assert d['kernel_files']==kernel_snapshot()
 snapshot_checks[name]={'recorded_suite_files':len(d['suite_files']),'all_recorded_current_match':all(digest(here/k)==v for k,v in d['suite_files'].items())}
 for row in d['results']:
  if row['status']=='ok':
   c=next(c for c in m['cases'] if c['id']==row['case']);assert abs(row['value']-c['reference'])/abs(c['reference'])<=1e-9
   assert row['relative_error']<=1e-9 and len(row['samples_seconds'])==3
  elif row.get('backend')=='preflight': assert row['status']=='not_executed_memory_estimate' and row['largest_intermediate_bytes']>256*2**20
summary={'versions':{'python':sys.version,'numpy':np.__version__,'cotengra':ctg.__version__},'case_counts':counts,'archive_files':len(files),'costs':costs,'snapshot_checks':snapshot_checks,'api_signatures':{n:str(inspect.signature(getattr(ctg,n))) for n in ('array_contract_expression','HyperOptimizer','RandomGreedyOptimizer')}}
write_json(out/'data-checks.json',summary)
print(json.dumps({k:v for k,v in summary.items() if k!='costs'},indent=2))
print(json.dumps([v for v in costs if v['path'] in ('tn.automatic','cotengra.hyper3s')],indent=2))
