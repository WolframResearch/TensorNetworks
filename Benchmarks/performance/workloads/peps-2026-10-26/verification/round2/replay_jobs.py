import os
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
    os.environ[key]='1'
import sys,json
from pathlib import Path
OUT=Path(__file__).resolve().parent;HERE=OUT.parents[1]
sys.path.insert(0,str(HERE))
from common import write_json
from run import run_process,kernel_snapshot,suite_snapshot
SRC=HERE/'workloads/peps-2026-10-26'
results=[]
for source,worker in [('execution.json','peps_execute.wls'),('engines.json','peps_engines.wls')]:
    for old in json.loads((SRC/source).read_text())['results']:
        if old.get('backend')!='tn':continue
        job={k:old[k] for k in ('case','path','method') if k in old}
        tag='-'.join(job.values());jp=OUT/(tag+'.job.json');op=OUT/(tag+'.json')
        write_json(jp,job)
        env={**os.environ,'TN_PEPS_ROOT':str(OUT),'TN_PEPS_JOB':str(jp),'TN_PEPS_OUTPUT':str(op)}
        cmd=['wolframscript','-local','/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel','-file',str(HERE/worker)]
        print('START',tag,flush=True)
        proc=run_process(cmd,env,OUT/(tag+'.log'),150,OUT/(tag+'.rss.txt'))
        row=json.loads(op.read_text()) if op.exists() else {'status':'no_output'}
        row['process']=proc;row['command']=cmd
        row['expected_status']=old['status']
        if old['status']=='failed':
            assert row['status']=='failed' and row.get('failure_reason')==old['failure_reason']
        else:
            assert row['status']=='ok' and proc['status']=='ok'
        results.append(row);write_json(OUT/'replay-results.json',{'results':results})
        print('DONE',tag,row['status'],row.get('failure_reason'),row.get('samples_seconds'),flush=True)
before=json.loads((OUT/'before.json').read_text())
assert kernel_snapshot()==before['kernel'] and suite_snapshot()==before['suite']
write_json(OUT/'after.json',{'kernel':kernel_snapshot(),'suite':suite_snapshot(),'unchanged':True})
