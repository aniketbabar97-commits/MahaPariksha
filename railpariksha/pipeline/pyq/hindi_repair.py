"""Repairs the mechanical Devanagari glitches PDF text extraction leaves in native-Hindi PYQ text:
split vowel signs (ा+े for ो), the i-matra placed before its consonant, nukta after a matra,
a zero-width joiner between a consonant and its matra, and a space before anusvara."""
import json,glob,re,sys
from hindi_glitch import scan, CONS, MATRA, VIR, NUK
SPLIT={'ाे':'ो','ाै':'ौ','ेा':'ो','ैा':'ौ','ाॅ':'ॉ','ॅा':'ॉ','ाॆ':'ो','ाॊ':'ौ'}
def repair(t):
    if not re.search(r'[ऀ-ॿ]',t): return t
    for k,v in SPLIT.items(): t=t.replace(k,v)
    # ZWJ/ZWNJ between a consonant (or nukta) and a matra/virama: pure extraction noise.
    t=re.sub(r'(?<=[क-हक़-य़़])[‌‍](?=[ा-ौ्])','',t)
    # space before anusvara/chandrabindu/visarga
    t=re.sub(r' +([ँंः])',r'\1',t)
    # nukta after a matra -> before it
    t=re.sub(r'([ा-ौ])़',r'़\1',t)
    # i-matra before its consonant cluster: ि + C(़)?(्C(़)?)* -> cluster + ि
    t=re.sub(r'(?<![\u0915-\u0939\u0958-\u095F\u093C\u094D])\u093F((?:[\u0915-\u0939\u0958-\u095F]\u093C?)(?:\u094D[\u0915-\u0939\u0958-\u095F]\u093C?)*)',r'\1ि',t)
    return t

HALANT_OK={'अर्थात्','वाक्','विद्युत्','जलविद्युत्','रवैद्युत्','बृहत्','वृहत्','बृहद्','वृहद्','हृद्','पश्चात्','परिषद्','पृथक्','द्विक्','तत्','दृक्','विषुवत्','यंत्रवत्','सूत्रवत्','सतत्','बलात्','माध्यस्थम्','संसद्','तोल्काप्पियम्','अकस्मात्','त्वक्','शिवम्','यकृत्','अभिज्ञानशाकुन्तलम्','अभिज्ञानशाकुंतलम्','कृषिगत्','तिर्यक्','जगत्','महान्','भगवान्','विद्वान्','श्रीमान्','साक्षात्','सम्राट्','सत्','भवत्','स्वयम्','अहम्','इदम्','ओम्','ॐ','किम्','शरद्','तद्','यद्','एतद्','षट्','पृथक्','साक्षात्'}
def _halant_join(m):
    x=m.group(1)
    if x in HALANT_OK or x.endswith('विद्'): return m.group(0)
    return x+m.group(2)
NO_JOIN={'भूमि','त्रि','प्रति','कि','यदि','जबकि','क्योंकि','अति','रति','गति','मति','कृषि','राशि','हानि','शक्ति','व्यक्ति','स्थिति','वृद्धि','विधि','निधि','तिथि','संधि','ऋषि','मुनि','पति','अग्नि','कवि','रवि','हरि','गिरि','रुचि','कीर्ति','शांति','क्रांति','भ्रांति','संपत्ति','प्रकृति','आकृति','स्मृति','आवृत्ति','प्रवृत्ति','जाति','भीति','नीति','रीति','प्रीति'}
def build_joiner(texts):
    """Data-driven repair of PDF line-wrap splits inside words (स्थि ति, प्लास्टि क, वेल्डिं ग).
    A bigram X Y (X ending in i-matra/anusvara, Y starting with a consonant) is joined only when
    the joined token XY is itself common in the corpus (>=5, >=2x the split form) and X is rarer
    than 3x XY, so real two-word phrases such as भूमि का or प्रति व्यक्ति are left alone."""
    import collections
    s=' '.join(texts)
    tok=collections.Counter(re.findall(r'[ऀ-ॿ]+',s))
    big=collections.Counter(re.findall(r'(?<![ऀ-ॿ])([ऀ-ॿ]+[िं]) ([क-ह][ऀ-ॿ]*)(?![ऀ-ॿ])',s))
    joins={}
    for (x,y),n in big.items():
        j=tok.get(x+y,0)
        if x in NO_JOIN: continue
        if j>=5 and j>=2*n and tok.get(x,0)<=3*j: joins[(x,y)]=x+y
    pat=re.compile(r'(?<![ऀ-ॿ])('+'|'.join(sorted({re.escape(x) for x,_ in joins},key=len,reverse=True))+r') ('+'|'.join(sorted({re.escape(y) for _,y in joins},key=len,reverse=True))+r')(?![ऀ-ॿ])') if joins else None
    def fix(t):
        if not re.search(r'[ऀ-ॿ]',t): return t
        t=re.sub(r'([ऀ-ॿ]+्) ([ऀ-ॿ]+)',_halant_join,t)
        if pat: t=pat.sub(lambda m: joins.get((m.group(1),m.group(2)), m.group(0)),t)
        for k,v in MANUAL.items(): t=t.replace(k,v)
        return t
    return fix, joins
# Residual glitches from PDFs whose font dropped whole conjunct glyphs; exact-string fixes checked by hand.
MANUAL={'नवोद्भि द्के':'नवोद्भिद् के','वस्त़ु':'वस्तु','नि त ':'निश्चित ','व्यि ':'व्यक्ति ','व्यि यों':'व्यक्तियों','पंि ':'पंक्ति ','संि या':'संक्रिया','दृि कोण':'दृष्टिकोण','चक्रवृि ':'चक्रवृद्धि ','की वृि ':'की वृद्धि ','माि का':'माध्यिका','प्रत्‍येक ि ति':'प्रत्येक स्थिति','पर ि त है':'पर स्थित है','में ि त माबल':'में स्थित मार्बल','की ि ज्या':'की त्रिज्या','अथशाि यों':'अर्थशास्त्रियों','अथशास्त्र':'अर्थशास्त्र','दिण की ओर':'दक्षिण की ओर','नि त तक का':'निश्चित तर्क का','समान तक का':'समान तर्क का','उसी तक का':'उसी तर्क का','पुनर्जा गरण':'पुनर्जागरण','सांख्यि की':'सांख्यिकी','आंकड़ोो':'आंकड़ों','हृास':'ह्रास','धाुत':'धातु','कंट्रोोल':'कंट्रोल','क्लाॉाॉक':'क्लॉक','काीजिए':'कीजिए','दाऍं':'दाएँ','एैड':'ऐड','ऐलुम़ ^ि नियम':'ऐलुमिनियम','पावरलिफ्ट िंग':'पावरलिफ्टिंग','वेटलिफ्ट िंग':'वेटलिफ्टिंग','बॉडीबिल्ड िंग':'बॉडीबिल्डिंग','विुंडोज':'विंडोज','स्क्रि प्ट':'स्क्रिप्ट','मोज़ि ला':'मोज़िला','मस्ति ष्क':'मस्तिष्क','क्रि स्टल':'क्रिस्टल','अस्ति त्व':'अस्तित्व','संक्षि प्त':'संक्षिप्त','स्वि ट्जरलैंड':'स्विट्जरलैंड','व्यक्ति त्व':'व्यक्तित्व','व्यक्ति गत':'व्यक्तिगत','सिक्कि म':'सिक्किम','क्लि क':'क्लिक','उपस्थि त':'उपस्थित','धात्वि क':'धात्विक','यादृच्छि क':'यादृच्छिक','स्थि त':'स्थित','व्यवस्थि त':'व्यवस्थित','स्थि र':'स्थिर','ऐच्छि क':'ऐच्छिक'}
if __name__=='__main__':
    changed=0; before=0; after=0; samples=[]
    files=sorted(glob.glob('content/pyq/*.json'))
    texts=[]
    for f in files:
        for q in json.load(open(f)):
            for key in ('q_hi','e_hi'):
                if q.get(key): texts.append(q[key])
            texts+= q.get('o_hi') or []
    join_fix, joins = build_joiner(texts)
    print('join rules:',len(joins))
    _rep=repair
    def repair(t): return join_fix(_rep(t))
    for f in files:
        qs=json.load(open(f)); dirty=False
        for q in qs:
            for key in ('q_hi','e_hi'):
                t=q.get(key)
                if t:
                    b=len(scan(t)); n=repair(t)
                    if n!=t:
                        a=len(scan(n)); before+=b; after+=a; dirty=True; changed+=1
                        if len(samples)<12 and b>a: samples.append((t[:70].replace('\n',' '), n[:70].replace('\n',' ')))
                        q[key]=n
            if q.get('o_hi'):
                new=[repair(o) for o in q['o_hi']]
                if new!=q['o_hi']:
                    before+=sum(len(scan(o)) for o in q['o_hi']); after+=sum(len(scan(o)) for o in new); dirty=True; changed+=1; q['o_hi']=new
        if dirty and '--apply' in sys.argv:
            open(f,'w',encoding='utf-8').write('[\n' + ',\n'.join(json.dumps(r, ensure_ascii=False) for r in qs) + '\n]\n')
    print(f'fields changed: {changed}; issues in changed fields: {before} -> {after}')
    for a,b in samples: print('  -',a,'\n  +',b)
