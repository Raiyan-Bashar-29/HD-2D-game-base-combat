# Builds data/powers/arima.tres and data/action/arima_loadout.tres from the converter's moves.json.
import json, sys
src, repo = sys.argv[1], sys.argv[2]
moves = {m['state']: m for m in json.load(open(src))['moves']}
C = 'res://src/content/combat/'
MAXBOX = 8.0
FOCUS = round(500 / 3000 * 100)

def v3(a): return 'Vector3(%s)' % ', '.join('%g' % round(x, 3) for x in a)

def move(state, sid, ext):
    m = moves[state]
    size = m.get('hitbox_size') or [1.0, 1.7, 2.0]
    off = m.get('hitbox_offset') or [0.0, 0.85, -1.0]
    size = [min(x, MAXBOX) for x in size]
    off = [off[0], min(off[1], size[1] / 2), max(off[2], -MAXBOX / 2)]
    out = ['[sub_resource type="Resource" id="%s"]' % sid, 'script = ExtResource("%s")' % ext,
        'id = &"move/arima_%d"' % state]
    for k in ('startup', 'active', 'recovery', 'chain_after', 'iframes_from', 'iframes_to', 'power'):
        out.append('%s = %g' % (k, round(m[k], 3)))
    out += ['hits = %d' % m['hits'], 'poise = %d' % m['poise'], 'knockback = %g' % round(m['knockback'], 2),
        'hitbox_size = ' + v3(size), 'hitbox_offset = ' + v3(off), 'travel_speed = %g' % round(m['travel_speed'], 2)]
    return '\n'.join(out) + '\n'

def kit():
    ext = [('kit', 'powers/power_kit.gd'), ('power', 'powers/power.gd'), ('form', 'powers/mechanisms/form_mechanism.gd'),
        ('gauge', 'powers/gauge_rule.gd'), ('move', 'action_move.gd'), ('skill', 'skill.gd'), ('status', 'status_effect.gd'),
        ('mod', 'stat_modifier.gd'), ('look', 'look_def.gd'), ('pskill', 'passives/passive_skill.gd')]
    o = ['[gd_resource type="Resource" script_class="PowerKit" format=3]', '']
    o += ['[ext_resource type="Script" path="%s%s" id="%s"]' % (C, p, i) for i, p in ext]
    o += ['[ext_resource type="Resource" path="res://data/passives/%s.tres" id="%s"]' % (p, p) for p in ('reaper', 'counter')]
    o.append('')
    stages = [('ixa', [200, 201, 202, 203], [(350, 'ixa_throw'), (550, 'narukami_pincer'), (560, 'narukami_squad')], None, 'Color(0.8, 0.85, 1, 1)'),
        ('owl', [2200, 2201, 2202, 2203, 2211], [(3050, 'owl_slash'), (3100, 'owl_flower'), (3150, 'owl_call')], 1.15, 'Color(0.55, 0.45, 0.7, 1)')]
    powers = ['SubResource("p_change")']
    o.append('[sub_resource type="Resource" id="resolve_mod"]\nscript = ExtResource("mod")\nstat = &"defence"\nop = 1\nvalue = 1.2\n')
    o.append('[sub_resource type="Resource" id="resolve"]\nscript = ExtResource("status")\nid = &"status/arima_resolve"\nname_key = "combat.status.arima_resolve.name"\nunit = 1\nduration = 2.0\nmodifiers = Array[ExtResource("mod")]([SubResource("resolve_mod")])\n')
    for name, chain, specials, attack, tint in stages:
        for s in chain: o.append(move(s, 'm%d' % s, 'move'))
        mods = ''
        if attack:
            o.append('[sub_resource type="Resource" id="%s_mod"]\nscript = ExtResource("mod")\nstat = &"attack"\nop = 1\nvalue = %g\n' % (name, attack))
            mods = 'modifiers = Array[ExtResource("mod")]([SubResource("%s_mod")])\n' % name
        o.append('[sub_resource type="Resource" id="%s_status"]\nscript = ExtResource("status")\nid = &"status/form_arima_%s"\nname_key = "combat.form.arima_%s.name"\nduration = 0.0\n%stags = Array[StringName]([&"form"])\n' % (name, name, name, mods))
        o.append('[sub_resource type="Resource" id="%s_look"]\nscript = ExtResource("look")\nlook_id = &"look/arima_%s"\ntint = %s\nlabel_key = "combat.form.arima_%s.name"\n' % (name, name, tint, name))
        o.append('[sub_resource type="Resource" id="%s_form"]\nscript = ExtResource("form")\nstatus = SubResource("%s_status")\nattack_chain = Array[ExtResource("move")]([%s])\nlook = SubResource("%s_look")\nname_key = "combat.form.arima_%s.name"\n' % (name, name, ', '.join('SubResource("m%d")' % s for s in chain), name, name))
        for state, pid in specials:
            o.append(move(state, 'm%d' % state, 'move'))
            o.append('[sub_resource type="Resource" id="s_%s"]\nscript = ExtResource("skill")\nid = &"skill/arima_%s"\nname_key = "combat.power.arima_%s.name"\ncost_pool = &"focus"\ncost = %d\ntarget = 0\nstatuses = Array[ExtResource("status")]([SubResource("resolve")])\n' % (pid, pid, pid, FOCUS))
            o.append('[sub_resource type="Resource" id="p_%s"]\nscript = ExtResource("power")\npower_id = &"power/arima_%s"\nname_key = "combat.power.arima_%s.name"\ndesc_key = "combat.power.arima_%s.desc"\nskill = SubResource("s_%s")\nmove = SubResource("m%d")\ncooldown = 4.0\nrequires_statuses = Array[StringName]([&"status/form_arima_%s"])\n' % (pid, pid, pid, pid, pid, state, name))
            powers.append('SubResource("p_%s")' % pid)
    o.append('[sub_resource type="Resource" id="cycle"]\nscript = ExtResource("form")\nexclusive_group = &"arima_quinque"\ncycle = Array[ExtResource("form")]([SubResource("ixa_form"), SubResource("owl_form")])\n')
    o.append('[sub_resource type="Resource" id="p_change"]\nscript = ExtResource("power")\npower_id = &"power/arima_quinque"\nname_key = "combat.power.arima_quinque.name"\ndesc_key = "combat.power.arima_quinque.desc"\nmechanism = SubResource("cycle")\ncooldown = 1.0\n')
    o.append('[sub_resource type="Resource" id="focus_max"]\nscript = ExtResource("mod")\nstat = &"max_focus"\nop = 0\nvalue = 100.0\nsource = &"kit/arima"\n')
    o.append('[sub_resource type="Resource" id="focus_start"]\nscript = ExtResource("mod")\nstat = &"start_focus"\nop = 0\nvalue = 0.0\nsource = &"kit/arima"\n')
    o.append('[sub_resource type="Resource" id="focus_rule"]\nscript = ExtResource("gauge")\npool = &"focus"\non_hit_dealt = 4.0\non_hit_taken = 2.0\n')
    o.append('[resource]\nscript = ExtResource("kit")\nkit_id = &"kit/arima"\nname_key = "combat.kit.arima.name"\ndesc_key = "combat.kit.arima.desc"\npowers = Array[ExtResource("power")]([%s])\npassive_skills = Array[ExtResource("pskill")]([ExtResource("reaper"), ExtResource("counter")])\nstat_bonuses = Array[ExtResource("mod")]([SubResource("focus_max"), SubResource("focus_start")])\ngauges = Array[ExtResource("gauge")]([SubResource("focus_rule")])' % ', '.join(powers))
    open(repo + '/data/powers/arima.tres', 'w').write('\n'.join(o) + '\n')

def loadout():
    ext = [('def', 'combatant_def.gd'), ('curve', 'level_curve.gd'), ('move', 'action_move.gd'), ('set', 'move_set.gd'),
        ('loadout', 'action_loadout.gd'), ('atb', 'atb_rules.gd')]
    o = ['[gd_resource type="Resource" script_class="ActionLoadout" format=3]', '']
    o += ['[ext_resource type="Script" path="%s%s" id="%s"]' % (C, p, i) for i, p in ext]
    o += ['[ext_resource type="Resource" path="res://data/powers/arima.tres" id="kit"]', '']
    chain = [200, 201, 202, 203]
    for s in chain: o.append(move(s, 'm%d' % s, 'move'))
    o.append('[sub_resource type="Resource" id="dodge"]\nscript = ExtResource("move")\nstartup = 0.0\nactive = 0.3\nrecovery = 0.15\niframes_to = 0.3\nperfect_window = 0.1\ntravel_speed = 6.0\n')
    o.append('[sub_resource type="Resource" id="moves"]\nscript = ExtResource("set")\nattack_chain = Array[ExtResource("move")]([%s])\ndodge = SubResource("dodge")\n' % ', '.join('SubResource("m%d")' % s for s in chain))
    o.append('[sub_resource type="Resource" id="curve"]\nscript = ExtResource("curve")\ngrowth = Dictionary[StringName, float]({\n&"attack": 2.0,\n&"max_hp": 6.0\n})\n')
    o.append('[sub_resource type="Resource" id="fighter"]\nscript = ExtResource("def")\ncombatant_id = &"arima"\nname_key = "combat.member.arima.name"\nfaction = &"player"\nbase_stats = Dictionary[StringName, float]({\n&"attack": 12.0,\n&"defence": 10.0,\n&"max_hp": 60.0,\n&"max_mp": 12.0\n})\nattack_tags = Array[StringName]([&"blade"])\npower_kit = ExtResource("kit")\nlevel_curve = SubResource("curve")\npassive_budget = 4\npassive_budget_per_level = 1\n')
    o.append('[sub_resource type="Resource" id="atb"]\nscript = ExtResource("atb")\n')
    o.append('[resource]\nscript = ExtResource("loadout")\nfighter = SubResource("fighter")\nmoves = SubResource("moves")\natb = SubResource("atb")')
    open(repo + '/data/action/arima_loadout.tres', 'w').write('\n'.join(o) + '\n')

kit(); loadout()
