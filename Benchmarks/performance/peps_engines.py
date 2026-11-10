#!/usr/bin/env python3
"""Compare existing TN engines on identical large PEPS data and saved paths."""
import json,os,sys
from common import write_json
from peps_workloads import OUT
from run import HERE,kernel_snapshot,run_process,suite_snapshot


def main():
    rows=[];before=kernel_snapshot();sources=suite_snapshot()
    env=os.environ.copy()
    for name in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
        env[name]='1'
    for case in ('peps-norm-5x5-D4','peps-norm-6x6-D3'):
        for method in ('Dot','ArrayDotTranspose'):
            job={'case':case,'path':'cotengra.hyper3s','method':method}
            job_path=OUT/(case+'-'+method+'.job.json');write_json(job_path,job)
            output=OUT/(case+'-'+method+'.tn.json')
            child_env={**env,'TN_PEPS_ROOT':str(OUT),'TN_PEPS_JOB':str(job_path),'TN_PEPS_OUTPUT':str(output)}
            print(case,method,flush=True)
            process=run_process(['wolframscript','-local','/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel',
                '-file',str(HERE/'peps_engines.wls')],child_env,output.with_suffix('.log'),150,output.with_suffix('.rss.txt'))
            row=json.loads(output.read_text()) if output.exists() else {**job,'status':'failed'}
            row['process']=process
            if process['status']!='ok':row['status']='failed'
            rows.append(row)
            print(row['status'],row.get('samples_seconds'),flush=True)
            write_json(OUT/'engines.json',{'results':rows,'kernel_unchanged':before==kernel_snapshot(),
                'suite_unchanged':sources==suite_snapshot(),'kernel_files':before,'suite_files':sources})
    return int(any(x['status']!='ok' for x in rows))

if __name__=='__main__':sys.exit(main())
