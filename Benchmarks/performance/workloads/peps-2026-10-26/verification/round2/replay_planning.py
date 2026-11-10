import os
for key in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','BLIS_NUM_THREADS'):
    os.environ[key]='1'
import sys,json
from pathlib import Path
OUT=Path(__file__).resolve().parent;HERE=OUT.parents[1]
sys.path.insert(0,str(HERE))
from common import write_json
from run import run_process,kernel_snapshot,suite_snapshot
manifest=json.loads((OUT/'manifest.json').read_text())
results=[]
for trial in range(3):
    cmd=['wolframscript','-local','/Applications/Wolfram 15.01.app/Contents/MacOS/WolframKernel','-file',str(HERE/'peps_planning.wls')]
    proc=run_process(cmd,{**os.environ,'TN_PEPS_ROOT':str(OUT)},OUT/f'planning-{trial}.log',120,OUT/f'planning-{trial}.rss.txt')
    assert proc['status']=='ok'
    plans=json.loads((OUT/'tn-plans.json').read_text())
    (OUT/'tn-plans.json').rename(OUT/f'tn-plans-{trial}.json')
    assert len(plans['records'])==len(manifest['cases'])
    for c,p in zip(manifest['cases'],plans['records']):
        assert c['id']==p['id'] and p['same_form']
        assert c['paths']['tn.automatic']==p['automatic_path']
        assert c['paths']['tn.greedy']==p['greedy_path']
    results.append({'trial':trial,'command':cmd,'process':proc,'plans':plans})
    write_json(OUT/'planning-results.json',{'trials':results,'all_saved_paths_match':True})
    print('planning trial',trial,'all 8 saved paths match',flush=True)
before=json.loads((OUT/'before.json').read_text())
assert kernel_snapshot()==before['kernel'] and suite_snapshot()==before['suite']
