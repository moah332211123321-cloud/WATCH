"""python -I cls.py <classes.jsonl> <exact-or-prefix>... : print class summaries"""
import sys, json
sys.stdout.reconfigure(encoding='utf-8')
pre = tuple(sys.argv[2:])
for l in open(sys.argv[1], encoding='utf-8'):
    c = json.loads(l)
    if c['name'].startswith(pre):
        print('==', c['name'], 'extends', c['super'], c['ifaces'])
        print('  methods:', ' '.join(c['methods']))
        if c['ifields']: print('  fields:', ' '.join(f'{n}:{t}' for n, t in c['ifields']))
        for k, (t, v) in c['statics'].items():
            if v is not None: print(f'  {k} = {v!r}')
