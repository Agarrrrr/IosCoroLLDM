"""Ownership tests for marks that must belong to one particular stem."""


def stem_direction(stem, heads, scale=1, fallback='up'):
    """Use the stem's endpoints, including displaced seconds in a chord.

    A head to the left of a stem is not sufficient evidence of an up stem:
    seconds and wide down-stem chords can use that same geometry.
    """
    x, top, bottom = stem
    up = [abs(y-bottom) for hx,y in heads if abs(hx+6.65*scale-x) < .8*scale]
    down = [abs(y-top) for hx,y in heads if abs(hx+.14*scale-x) < .8*scale]
    u, d = min(up, default=float('inf')), min(down, default=float('inf'))
    if min(u,d) < 1.5*scale and abs(u-d) > .2*scale:
        return 'up' if u < d else 'down'
    return fallback


def flag_level(symbol, x, baseline, stem_x, stem_tip, direction, scale=1):
    """Opus flag origins sit about one staff space from the stem tip.

    Testing distance from the note head can borrow a flag from another staff.
    Match orientation and the actual stem endpoint instead.
    """
    if symbol not in ({'j', 'r'} if direction == 'up' else {'J', 'R'}):
        return 0
    if abs(x - stem_x) >= .8 * scale or abs(baseline - stem_tip) > 8 * scale:
        return 0
    return 2 if symbol in {'r', 'R'} else 1


def mark_anchor(events, system, staff, x, scale=1):
    """Locate printed time on the physical staff before choosing its singers.

    An inactive singer must not move a printed mark into a later measure.
    """
    pool = [e for e in events if e.get('page') == system['page']
            and system['first'] <= e['measure'] <= system['last']
            and e.get('staff') == staff and 'x' in e and not e['rest']]
    if not pool:
        pool = [e for e in events if e.get('page') == system['page']
                and system['first'] <= e['measure'] <= system['last']
                and e.get('staff') == staff and 'x' in e]
    return min(pool, key=lambda e: abs(e['x'] + 3*scale - x)) if pool else None
