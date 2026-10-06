import json,glob,re,collections,sys
CONS=set('कखगघङचछजझञटठडढणतथदधनपफबभमयरलवशषसहळ')|{chr(c) for c in range(0x958,0x960)}|{'\u0931','\u0929'}
MATRA=set('ािीुूृेैोौॉॅॆॊ'); VIR='्'; NUK='़'; ANUS='ंँः'; VOW=set('अआइईउऊऋएऐओऔऑ')
def scan(t):
    out=[]; prev=''
    for i,ch in enumerate(t):
        if ch in MATRA:
            if prev in CONS or prev==NUK: pass
            elif prev==' ' or prev=='' or prev in MATRA or prev in VOW or prev in ANUS: out.append(('matra_misplaced', t[max(0,i-4):i+4]))
            else: out.append(('matra_after_other', t[max(0,i-4):i+4]))
        elif ch==NUK:
            if prev not in CONS: out.append(('nukta_misplaced', t[max(0,i-4):i+4]))
        elif ch==VIR:
            if prev not in CONS and prev!=NUK: out.append(('virama_misplaced', t[max(0,i-4):i+4]))
        elif ch in ANUS:
            if not (prev in CONS or prev in MATRA or prev in VOW or prev==NUK): out.append(('anusvara_misplaced', t[max(0,i-4):i+4]))
        prev=ch
    return out
if __name__=='__main__':
    tot=collections.Counter(); affected=collections.Counter(); ex=collections.defaultdict(list); nq=collections.Counter()
    for f in sorted(glob.glob('content/pyq/*.json')):
        exam=f.split('/')[-1][:-5]
        for q in json.load(open(f)):
            nq[exam]+=1; found=[]
            for t in [q.get('q_hi','')]+list(q.get('o_hi',[]))+[q.get('e_hi','')]:
                if t and re.search(r'[ऀ-ॿ]',t): found+=scan(t)
            if found:
                affected[exam]+=1
                for k,e in found:
                    tot[k]+=1
                    if len(ex[k])<6: ex[k].append(e)
    print('affected:',dict(affected),'of',sum(nq.values()))
    print('issues:',dict(tot))
    for k,v in ex.items(): print(k,v)
