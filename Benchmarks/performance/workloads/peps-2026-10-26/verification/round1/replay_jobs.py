import os
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):os.environ[key]='1'
import sys,json,statistics,time
from pathlib import Path
out=Path(__file__).resolve().parent;here=out.parents[1];sys.path.insert(0,str(here))
from run import run_process,kernel_snapshot,suite_snapshot
from common import write_json
replay=out/'replay';before=kernel_snapshot();suite=suite_snapshot();rows=[]
jobs=[{'case':c,'path':p} for c in ('peps-norm-5x5-D4','peps-norm-6x6-D3') for p in ('cotengra.random128','cotengra.hyper3s')]
jobs += [{'case':c,'path':'cotengra.hyper3s','method':method} for c in ('peps-norm-5x5-D4','peps-norm-6x6-D3') for method in ('Dot','ArrayDotTranspose')]
for i,job in enumerate(jobs):
 jp=out/f'job-{i}.json';write_json(jp,job);op=out/f'job-{i}-output.json'
 env={**os.environ,'TN_PEPS_ROOT':str(replay),'TN_PEPS_JOB':str(jp),'TN_PEPS_OUTPUT':str(op)}
 script=here/('peps_engines.wls' if 'method' in job else 'peps_execute.wls')
 command=['wolframscript','-local','/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel','-file',str(script)]
 print('START',i,job,flush=True)
 proc=run_process(command,env,out/f'job-{i}.log',150,out/f'job-{i}.rss.txt')
 row={**job,'command':command,'process':proc,'output':json.loads(op.read_text()) if op.exists() else None};rows.append(row)
 write_json(out/'replay-results.json',{'results':rows,'kernel_unchanged':before==kernel_snapshot(),'suite_unchanged':suite==suite_snapshot(),'kernel_files':before,'suite_files':suite})
 print('DONE',i,row['output'],proc,flush=True)
