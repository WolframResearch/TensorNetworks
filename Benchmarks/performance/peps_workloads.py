#!/usr/bin/env python3
"""Practical PEPS norm workloads: path quality, memory estimates and execution."""
import hashlib,json,math,os,statistics,sys,time
from pathlib import Path
import numpy as np
import cotengra as ctg
from common import digest,write_json
from python_bench import path_stats
from run import HERE,REPO,kernel_snapshot,run_process,suite_snapshot

OUT=HERE/'results/peps-workloads'

def generate():
    cases=[]
    for side,bond in ((3,4),(4,3),(4,4),(5,3),(5,4),(6,3),(6,4),(8,2)):
        ident=f'peps-norm-{side}x{side}-D{bond}'
        rng=np.random.default_rng(20261026+100*side+bond)
        labels=[[] for _ in range(side*side)]; edge=0
        for i in range(side):
            for j in range(side):
                for di,dj in ((1,0),(0,1)):
                    if i+di<side and j+dj<side:
                        labels[i*side+j].append(edge);labels[(i+di)*side+j+dj].append(edge);edge+=1
        ket=[inds+[edge+k] for k,inds in enumerate(labels)]
        bra=[[x+edge+side*side for x in inds]+[edge+k] for k,inds in enumerate(labels)]
        specs=[]
        for k,inds in enumerate(ket):
            a=rng.normal(size=[bond]*(len(inds)-1)+[2]);a/=np.linalg.norm(a)
            path=OUT/f'{ident}-t{k}.bin';np.asarray(a,dtype='<f8',order='C').tofile(path)
            specs.append({'file':path.name,'shape':list(a.shape),'sha256':digest(path),'bytes':path.stat().st_size})
        sizes={x:bond for inds in ket+bra for x in inds}
        for k in range(side*side):sizes[edge+k]=2
        case={'id':ident,'side':side,'bond':bond,'labels':ket+bra,'sizes':{str(k):v for k,v in sizes.items()},
              'tensors':specs+specs,'site_tensors':side*side,'input_bytes':sum(x['bytes'] for x in specs)*2,
              'paths':{},'planning_seconds':{}}
        for name,opt in (('cotengra.greedy',ctg.GreedyOptimizer(accel=False)),
                         ('cotengra.random128',ctg.RandomGreedyOptimizer(max_repeats=128,seed=20261026,accel=False,parallel=False))):
            start=time.perf_counter();path=opt(case['labels'],[],sizes);elapsed=time.perf_counter()-start
            case['paths'][name]=[list(p) for p in path];case['planning_seconds'][name]=elapsed
        opt=ctg.HyperOptimizer(methods=['greedy'],max_time=3,max_repeats=128,parallel=False,optlib='random',
            reconf_opts={'subtree_size':8,'maxiter':32},simulated_annealing_opts=None,slicing_opts=None,
            slicing_reconf_opts=None,on_trial_error='raise',progbar=False)
        start=time.perf_counter();tree=opt.search(case['labels'],[],sizes);elapsed=time.perf_counter()-start
        case['paths']['cotengra.hyper3s']=[list(p) for p in tree.get_path()];case['planning_seconds']['cotengra.hyper3s']=elapsed
        cases.append(case);write_json(OUT/'manifest.json',{'cases':cases})
        print(ident,{name:path_stats(case['labels'],[],sizes,path) for name,path in case['paths'].items()},flush=True)
    return cases

if __name__=='__main__':
    OUT.mkdir(parents=True,exist_ok=True)
    write_json(OUT/'source-before.json',{'kernel':kernel_snapshot(),'suite':suite_snapshot()})
    generate()
