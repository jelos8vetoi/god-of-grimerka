"""ДВОР: прогон экономики забега по таблицам проекта (не замер в игре).
Доходы врагов и боёв — из godot/scripts/golda67/g67_data.gd (FOES, waves, ROOM_GOLDA); новое — из DVOR_RUN_ECONOMY.md.
python tools/dvor_econ_sim.py"""
import random
FOE = {'shest': 4, 'semka': 5, 'smotr': 18}
W = {'first': [[('shest', 3)], [('shest', 2), ('semka', 1)]], 'gsk': [[('shest', 3), ('semka', 1)], [('shest', 3), ('semka', 2)]],
     'elite': [[('smotr', 1), ('shest', 2)], [('shest', 2), ('semka', 2)]], 'ambush': [[('shest', 3), ('semka', 1)], [('shest', 2), ('semka', 1)]],
     'patrol': [[('shest', 2)], [('semka', 1)]], 'unload': [[('shest', 2), ('semka', 1)], [('shest', 2)]]}
BAG = {'first': 20, 'gsk': 20, 'elite': 40, 'ambush': 30, 'patrol': 15, 'unload': 20}
def kills(k): return sum(FOE[f] * n for w in W[k] for f, n in w)
PRICE = {'shawarma': 30, 'double': 55, 'togo': 70, 'thermos': 25, 'buff': 80, 'art': 90, 'up2': 60, 'up3': 90, 'rare': 130, 'swap': 20}

def run(r, style, chain=0):
    """style: 'fighter' — все бои; 'careful' — только обязательные; 'explorer' — обязательные, события, тайники и один бой по выбору."""
    g = 0; fights = 0; buffs = 0
    must = ['first', 'elite']; opt = ['gsk', 'ambush', 'patrol', 'unload']
    take = must + (opt if style == 'fighter' else ([r.choice(opt)] if style == 'explorer' else []))
    mul = 1 + 0.25 * chain
    for k in take:
        g += (kills(k) + BAG[k]) * mul; fights += 1
        if k == 'elite': buffs += 1
        if k == 'gsk' and r.random() < 0.5: buffs += 1          # «баф или расходник» при трёх волнах
    buffs += 1                                                    # гарантированный источник бафа забега
    if style != 'careful':
        for ev in r.sample(['fridge', 'arm', 'stuck', 'keys', 'queue'], 2):
            if ev == 'fridge': g += 30 if r.random() < 0.7 else 10
            elif ev == 'arm':
                if r.random() < 0.5: buffs += 1
                else: g -= 20
            elif ev == 'stuck': g += 20 if r.random() < 0.3 else 0
            elif ev == 'keys': buffs += 1 if r.random() < 0.8 else 0
        if r.random() < 0.33:                                     # один конфликт с выбором стороны раз в три забега
            c = r.choice(['parking', 'school', 'garage'])
            if c == 'parking': g += 25
            elif c == 'school': g += 30 + kills('patrol') * mul
            else: buffs += 1
    if style == 'explorer':
        for st in r.sample(['trunk', 'box', 'store', 'roofs', 'tower', 'g64'], 3):
            if st == 'trunk': g += r.randint(20, 35)
            elif st in ('store', 'roofs', 'g64', 'tower'): buffs += 1
    return g, fights, buffs

def buy(g):
    """Что можно купить: жадно — сначала лечение, потом усиление."""
    n = 0; items = []
    for it in ('shawarma', 'buff', 'up2', 'shawarma', 'rare', 'up3', 'togo'):
        p = PRICE[it] + (5 if it == 'shawarma' and 'shawarma' in items else 0)
        if g >= p: g -= p; items.append(it); n += 1
    return n, items

if __name__ == '__main__':
    r = random.Random(67); N = 4000
    print('| Стиль забега | ЦЕПЬ НА УДАЧУ | Боёв | Голда: среднее | 10-й–90-й процентиль | Бафов и артефактов к Мише | Покупок на эти деньги |')
    print('|---|---|---|---|---|---|---|')
    for style, nm in (('careful', 'осторожный: только обязательные бои'), ('explorer', 'исследователь: события, тайники, один бой по выбору'), ('fighter', 'боец: все бои и события')):
        for chain in (0, 3):
            res = [run(r, style, chain) for _ in range(N)]; gs = sorted(x[0] for x in res)
            avg = sum(gs) / N; nb = sum(x[2] for x in res) / N; nf = sum(x[1] for x in res) / N; shop = sum(buy(x[0])[0] for x in res) / N
            print('| %s | %s | %.1f | %d | %d–%d | %.1f + купленные | %.1f |' % (nm, 'III' if chain else 'нет', nf, avg, gs[N // 10], gs[N * 9 // 10], nb, shop))
