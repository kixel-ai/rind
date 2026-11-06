import collections, re, statistics, sys, os
d = sys.argv[1]
t = collections.defaultdict(list)
for f in sorted(os.listdir(d)):
    tree = f.split('-')[0]
    for line in open(os.path.join(d, f)):
        m = re.match(r'test (\S+) +\.\.\. bench: +([\d,]+) ns/iter', line)
        if m:
            t[(tree, m.group(1))].append(int(m.group(2).replace(',', '')))
med = {k: statistics.median(v) for k, v in t.items()}
names = sorted({k[1] for k in med})
rows = collections.OrderedDict()
for n in names:
    alg, fn, case = n.split('/')
    op, lib = fn.split('-')
    rows.setdefault((alg, op, case), {})[lib] = (med.get(('main', n)), med.get(('branch', n)))
print('| case | rind main ns | rind branch ns | branch/main | aws ns | aws/rind main | aws/rind branch |')
print('|---|---|---|---|---|---|---|')
def key(k):
    alg, op, case = k
    a, m = re.match(r'a(\d+)-m(\d+)', case).groups()
    return (alg, op, int(a) != 13, int(m), int(a))
for k in sorted(rows, key=key):
    r = rows[k]
    rm, rb = r['rind']
    am, ab = r['aws']
    aws = (am + ab) / 2
    print(f'| {k[0]} {k[1]} {k[2]} | {rm} | {rb} | {rb/rm:.3f} | {aws:.0f} | {aws/rm:.2f} | {aws/rb:.2f} |')
