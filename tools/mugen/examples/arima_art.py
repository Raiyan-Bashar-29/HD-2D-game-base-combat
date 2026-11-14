# Builds assets/fan/arima_kisho/art.tres (a MemberArt) from sprites.json and the PlaySnd lines of the .cns files.
import json, re, os, sys
src, repo = sys.argv[1], sys.argv[2]
A = 'assets/fan/arima_kisho'
info = json.load(open(f'{repo}/{A}/sprites.json'))
STATES = [200, 201, 202, 203, 350, 550, 560, 2200, 2201, 2202, 2203, 2211, 3050, 3100, 3150]
ANIM = {2211: 2206}

def air_ticks():
    out, cur = {}, None
    for line in open(f'{src}/Arima_Kisho.air', encoding='utf-8', errors='replace'):
        line = line.split(';')[0].strip()
        m = re.match(r'\[begin action (\d+)\]', line, re.I)
        if m: cur = out.setdefault(int(m.group(1)), []); continue
        p = [x.strip() for x in line.split(',')]
        if cur is not None and len(p) >= 5 and re.fullmatch(r'-?\d+', p[0]) and re.fullmatch(r'-?\d+', p[4]):
            cur.append(max(0, int(p[4])))
    return out

def sounds():
    ticks, out = air_ticks(), {}
    for name in ('Arima_Kisho.cns', 'Arima_Kisho_black.cns'):
        state, block = None, None
        def flush():
            if state in STATES and block and block.get('type', '').lower() == 'playsnd':
                v = re.match(r's?\s*(\d+)\s*,\s*(\d+)', block.get('value', ''), re.I)
                if not v: return
                wav = f'sounds/{v.group(1)}_{v.group(2)}.wav'
                if not os.path.exists(f'{repo}/{A}/{wav}'): return
                t, trig = 0.0, block.get('trigger1', '').lower()
                m = re.match(r'time\s*=\s*(\d+)', trig)
                e = re.match(r'animelem\s*=\s*(\d+)', trig)
                if m: t = int(m.group(1)) / 60
                elif e: t = sum(ticks.get(ANIM.get(state, state), [])[:int(e.group(1)) - 1]) / 60
                if (round(t, 3), wav) not in out.setdefault(state, []): out[state].append((round(t, 3), wav))
        for line in open(f'{src}/{name}', encoding='utf-8', errors='replace'):
            line = line.split(';')[0].strip()
            m = re.match(r'\[statedef\s+(-?\d+)', line, re.I)
            if m: flush(); state, block = int(m.group(1)), None; continue
            if re.match(r'\[state\b', line, re.I): flush(); block = {}; continue
            if block is not None and '=' in line:
                k, v = line.split('=', 1); block.setdefault(k.strip().lower(), v.strip())
        flush()
    return {s: sorted(v) for s, v in out.items()}

snd = sounds()
ext, subs, entries, ids = [], [], [], {}
def res(kind, path):
    if path not in ids:
        ids[path] = 'e%d' % len(ids)
        ext.append('[ext_resource type="%s" path="res://%s/%s" id="%s"]' % (kind, A, path, ids[path]))
    return 'ExtResource("%s")' % ids[path]
for s in STATES:
    st = info['strips'][str(ANIM.get(s, s))]
    o = ['[sub_resource type="Resource" id="m%d"]' % s, 'script = ExtResource("move")',
        'strip = ' + res('Texture2D', st['file']), 'frames = %d' % st['frames'],
        'feet = Vector2i(%d, %d)' % tuple(st['feet']), 'seconds = %g' % round(st['seconds'], 3)]
    mine = snd.get(s, [])
    if mine:
        o.append('sounds = Array[AudioStream]([%s])' % ', '.join(res('AudioStream', w) for _, w in mine))
        o.append('sound_at = Array[float]([%s])' % ', '.join('%g' % t for t, _ in mine))
    subs.append('\n'.join(o) + '\n')
    entries.append('&"move/arima_%d": SubResource("m%d")' % (s, s))
sheet, layout = res('Texture2D', 'sheet.png'), res('Resource', 'sheet_layout.tres')
head = ['[gd_resource type="Resource" script_class="MemberArt" format=3]', '',
    '[ext_resource type="Script" path="res://src/content/combat/member_art.gd" id="art"]',
    '[ext_resource type="Script" path="res://src/content/combat/move_art.gd" id="move"]'] + ext + ['']
tail = ['[resource]', 'script = ExtResource("art")', 'sheet = ' + sheet, 'layout = ' + layout,
    'pixel_size = %g' % round(info['pixel_size'], 5), 'ground_offset = %g' % round(info['sheet']['ground_offset'], 4),
    'moves = Dictionary[StringName, ExtResource("move")]({\n%s\n})' % ',\n'.join(entries), '']
open(f'{repo}/{A}/art.tres', 'w').write('\n'.join(head + subs + tail))
for s in STATES: print(s, snd.get(s))
