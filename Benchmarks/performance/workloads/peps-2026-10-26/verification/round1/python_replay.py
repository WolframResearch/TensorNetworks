import os
for k in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):os.environ[k]='1'
import sys,json,time,statistics,inspect
from pathlib import Path
import numpy as np,cotengra as ctg
from threadpoolctl import threadpool_info
out=Path(__file__).resolve().parent;here=out.parents[1];sys.path.insert(0,str(here))
from common import write_json
from python_bench import path_stats
m=json.loads((out/'replay/manifest.json').read_text());rows=[]
for c in m['cases']:
 if 'reference' not in c:continue
 arrays=[np.fromfile(out/'replay'/s['file'],dtype='<f8').reshape(s['shape']) for s in c['tensors']]
 f=ctg.array_contract_expression(c['labels'],[],shapes=[a.shape for a in arrays],optimize=c['paths']['cotengra.hyper3s'],cache=False,autojit=False)
 start=time.perf_counter();first=float(f(*arrays,backend='numpy'));first_seconds=time.perf_counter()-start;values=[first];times=[]
 for _ in range(3):
  start=time.perf_counter();v=float(f(*arrays,backend='numpy'));times.append(time.perf_counter()-start);values.append(v)
 error=max(abs(v-c['reference'])/abs(c['reference']) for v in values);assert error<=1e-9
 rows.append({'case':c['id'],'first_seconds':first_seconds,'samples_seconds':times,'median_seconds':statistics.median(times),'relative_error':error,'value':values[-1]})
 print(rows[-1],flush=True)
 # Independent physical-state calculation for the smallest grid: contract only the ket, keep every physical leg.
 if c['side']==3:
  n=c['site_tensors'];physical=[inds[-1] for inds in c['labels'][:n]]
  wave_fn=ctg.array_contract_expression(c['labels'][:n],physical,shapes=[a.shape for a in arrays[:n]],optimize='greedy',cache=False,autojit=False)
  psi=wave_fn(*arrays[:n],backend='numpy');assert psi.shape==(2,)*n
  norm2=float(np.vdot(psi,psi));wave={'case':c['id'],'wavefunction_shape':list(psi.shape),'independent_norm_squared':norm2,'relative_error':abs(norm2-c['reference'])/abs(c['reference'])};assert wave['relative_error']<=1e-9
bad_paths=[]
for path in ([[0,0]],[[0,2]],[],[[0]],[[0,1],[0,1]]):
 try:path_stats([[0],[0]],[],{0:2},path)
 except (ValueError,IndexError,TypeError) as exc:bad_paths.append({'path':path,'exception':type(exc).__name__,'message':str(exc)})
 else:raise AssertionError(f'invalid path passed: {path}')
write_json(out/'python-replay.json',{'versions':{'numpy':np.__version__,'cotengra':ctg.__version__},'results':rows,'independent_wavefunction_norm':wave,'malformed_paths':bad_paths,'numpy_config':np.show_config(mode='dicts'),'threadpool_info':threadpool_info(),'requested_threads':1,'effective_numpy_threads':'unavailable on Accelerate'})
