#!/usr/bin/env python3
"""Run bounded PEPS norms with saved paths; compare path quality in unchanged TN."""
import json,os,statistics,sys,time
from pathlib import Path
import cotengra as ctg
import numpy as np
from common import digest,write_json
from peps_workloads import OUT
from run import HERE,REPO,kernel_snapshot,run_process,suite_snapshot


def arrays_for(case):
    arrays=[]
    for spec in case['tensors']:
        p=OUT/spec['file'];assert digest(p)==spec['sha256']
        arrays.append(np.fromfile(p,dtype='<f8').reshape(spec['shape']))
    return arrays


def execute_python(case,path_name,arrays):
    sizes={int(k):v for k,v in case['sizes'].items()}
    expression=ctg.array_contract_expression(case['labels'],[],shapes=[a.shape for a in arrays],
        optimize=case['paths'][path_name],cache=False,autojit=False)
    start=time.perf_counter();first=expression(*arrays,backend='numpy')
    first_seconds=time.perf_counter()-start
    timings=[];values=[]
    for _ in range(3):
        start=time.perf_counter();value=expression(*arrays,backend='numpy')
        timings.append(time.perf_counter()-start);values.append(float(value))
    reference=float(first)
    assert reference>0 and np.isfinite(reference)
    if 'reference' not in case:case['reference']=reference
    error=max(abs(x-case['reference'])/abs(case['reference']) for x in [reference,*values])
    return {'case':case['id'],'backend':'cotengra.numpy','path':path_name,'first_seconds':first_seconds,
            'samples_seconds':timings,'relative_error':error,'value':values[-1],'status':'ok' if error<1e-9 else 'failed'}


def main():
    p=OUT/'manifest.json';manifest=json.loads(p.read_text());results=[];jobs=[]
    before=kernel_snapshot();sources=suite_snapshot()
    env=os.environ.copy()
    for name in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
        env[name]='1'
    for case in manifest['cases']:
        for name,cost in case['costs'].items():
            if cost['largest_intermediate_elements']*8>256*2**20:
                results.append({'case':case['id'],'path':name,'backend':'preflight','status':'not_executed_memory_estimate',
                    'largest_intermediate_bytes':cost['largest_intermediate_elements']*8})
        best='cotengra.hyper3s'
        if case['costs'][best]['largest_intermediate_elements']*8>256*2**20:continue
        arrays=arrays_for(case)
        print('Python reference',case['id'],flush=True)
        row=execute_python(case,best,arrays);assert row['status']=='ok';results.append(row)
        write_json(p,manifest)
        # Keep the path fixed in each comparison. This isolates order quality from executor cost.
        path_names=['tn.automatic','cotengra.random128','cotengra.hyper3s']
        for name in path_names:
            if case['costs'][name]['largest_intermediate_elements']*8>256*2**20:continue
            job={'case':case['id'],'path':name}
            job_path=OUT/(case['id']+'-'+name+'.job.json');write_json(job_path,job)
            output=OUT/(case['id']+'-'+name+'.tn.json')
            log=output.with_suffix('.log');rss=output.with_suffix('.rss.txt')
            job_env={**env,'TN_PEPS_ROOT':str(OUT),'TN_PEPS_JOB':str(job_path),'TN_PEPS_OUTPUT':str(output)}
            print('TN',case['id'],name,flush=True)
            process=run_process(['wolframscript','-local','/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel',
                                 '-file',str(HERE/'peps_execute.wls')],job_env,log,150,rss)
            row=json.loads(output.read_text()) if output.exists() else {**job,'backend':'tn','status':'failed'}
            row['process']=process
            if process['status']!='ok':row['status']='failed'
            results.append(row)
            write_json(OUT/'execution.json',{'results':results,'kernel_unchanged':kernel_snapshot()==before,
                'suite_unchanged':suite_snapshot()==sources,'kernel_files':before,'suite_files':sources,
                'python_metadata':{'numpy':np.__version__,'cotengra':ctg.__version__,'blas':np.show_config(mode='dicts'),
                    'requested_threads':1,'effective_numpy_threads':'unavailable on Accelerate'}})
            print(row['status'],row.get('samples_seconds'),flush=True)
    assert before==kernel_snapshot() and sources==suite_snapshot()
    return int(any(x['status']=='failed' for x in results))

if __name__=='__main__':sys.exit(main())
