extends Node2D
## 턴제 배틀: 싸우기 / 가방 / 포켓몬 / 도망. 타입 상성, 급소, 포획(볼 흔들림), 경험치/레벨업, 트레이너 교체.
## 진행은 "단계(steps)" 큐로 처리한다: 메시지(탭해서 넘김), 즉시 실행, 연출 대기.

const Data = preload("res://scripts/data.gd")
const Mon = preload("res://scripts/mon.gd")
const Px = preload("res://scripts/px.gd")

var main
var kind := "wild"          # wild / trainer / leader
var trainer_name := ""
var enemy_party: Array = []
var enemy
var me                      # 지금 싸우는 내 포켓몬
var mode := "steps"         # steps / menu / moves / bag / party / done
var forced_switch := false
var steps: Array = []
var text := ""
var shown := 0.0
var msg_wait := 0.0
var anim_t := 0.0
var e_hp := 0.0             # 표시용 HP (부드럽게 줄어든다)
var p_hp := 0.0
var e_shake := 0.0
var p_shake := 0.0
var e_flash := 0.0
var ball = null             # 던진 볼 연출 {kind, t, shakes, caught}
var e_visible := true
var p_visible := true
var result := ""
var money_won := 0
var rng := RandomNumberGenerator.new()
var t := 0.0
var escape_tries := 0
var my_party: Array = []
var pvp := false
var pvp_my_act = null       # 방장: 내 행동 / 참가자: 보냈음 표시
var pvp_foe_act = null
var pvp_pending_sw := -1    # 친구가 먼저 보낸 교체 (연출이 거기까지 오기 전)
var waiting_foe_sw := false


func start(k: String, foes: Array, tname := "", mine: Array = []) -> void:
	rng.randomize()
	kind = k
	pvp = k == "pvp"
	my_party = mine if not mine.is_empty() else main.party
	pvp_my_act = null
	pvp_foe_act = null
	pvp_pending_sw = -1
	waiting_foe_sw = false
	trainer_name = tname
	enemy_party = foes
	enemy = foes[0]
	me = _first_healthy()
	e_hp = enemy.hp
	p_hp = me.hp
	steps.clear()
	mode = "steps"
	result = ""
	money_won = 0
	ball = null
	e_visible = true
	p_visible = true
	escape_tries = 0
	if kind == "wild":
		_msg("앗! 야생 %s(이)가 튀어나왔다!" % enemy.name())
		_do(_enemy_cry)
	else:
		if not pvp:
			var line := "내가 이 지역의 관장이다! 실력을 보여 줘!" if kind == "leader" else "눈이 마주치면 포켓몬 승부지!"
			_msg("%s: %s" % [trainer_name, line], "trainer")
		else:
			_msg("친구와의 포켓몬 승부!")
		_msg("%s(은)는 %s(을)를 내보냈다!" % [trainer_name, enemy.name()])
		_do(_enemy_cry)
	_send_out_me(true)
	_do(_to_menu)
	visible = true


# ------------------------------------------------------------------ 단계 큐

func _msg(s: String, speaker := "") -> void:
	steps.append({"msg": s, "speaker": speaker})


func _do(f: Callable) -> void:
	steps.append({"do": f})


func _wait(sec: float) -> void:
	steps.append({"wait": sec})


## 지금 단계 바로 다음에 끼워 넣는다
func _front(arr: Array) -> void:
	for i in range(arr.size() - 1, -1, -1):
		steps.insert(0, arr[i])


func _send_out_me(first: bool) -> void:
	var line := ("가라! %s!" % me.name()) if first else ("가라! %s!" % me.name())
	_msg(line, main.character)
	_do(_show_me)
	_wait(0.4)


func _show_me() -> void:
	p_visible = true
	p_hp = me.hp
	main.voice.cry(me.name())


func _enemy_cry() -> void:
	main.voice.cry(enemy.name())


func _first_healthy():
	for m in my_party:
		if not m.fainted():
			return m
	return null


func _to_menu() -> void:
	mode = "menu"
	text = main.josa("%s(은)는 무엇을 할까?" % me.name())
	shown = 999.0


func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	e_hp = move_toward(e_hp, enemy.hp, delta * max(20.0, enemy.max_hp() * 0.8))
	p_hp = move_toward(p_hp, me.hp, delta * max(20.0, me.max_hp() * 0.8))
	e_shake = max(e_shake - delta, 0.0)
	p_shake = max(p_shake - delta, 0.0)
	e_flash = max(e_flash - delta, 0.0)
	if ball:
		ball.t += delta
	if mode == "steps":
		_run_steps(delta)
	queue_redraw()


func _run_steps(delta: float) -> void:
	if msg_wait > 0.0:
		msg_wait -= delta
		shown += delta * 40.0
		if main.autoplay and shown >= text.length() and msg_wait < 0.0:
			msg_wait = 0.0
		return
	while not steps.is_empty():
		var s: Dictionary = steps.pop_front()
		if s.has("do"):
			s.do.call()
			if mode != "steps":
				return
			continue
		if s.has("wait"):
			msg_wait = s.wait
			text = text
			return
		if s.has("msg"):
			text = main.josa(s.msg)
			shown = 0.0
			msg_wait = 99.0  # 탭할 때까지 (오토플레이는 자동)
			if main.autoplay:
				msg_wait = 0.5
			if s.speaker != "":
				var spoken: String = s.msg.split(": ", true, 1)[-1]
				main.voice.speak(spoken, s.speaker)
			return
	if mode == "steps":
		_to_menu()


func advance() -> void:
	if mode != "steps":
		return
	if shown < text.length():
		shown = 999.0
	elif msg_wait > 50.0:
		msg_wait = 0.0


# ------------------------------------------------------------------ 행동

func choose_move(i: int) -> void:
	if mode != "moves" or i >= me.moves.size():
		return
	if pvp:
		_pvp_choose({"type": "move", "id": me.moves[i]})
		return
	_turn({"type": "move", "id": me.moves[i]})


func use_item(item: String) -> void:
	if mode != "bag" or main.items.get(item, 0) <= 0:
		return
	if pvp:
		text = "친구와의 대전에서는 가방을 쓸 수 없다!"
		shown = 999.0
		return
	if Data.BALLS.has(item):
		if kind != "wild":
			text = "트레이너의 포켓몬은 잡을 수 없다!"
			shown = 999.0
			return
		main.items[item] -= 1
		_turn({"type": "ball", "id": item})
	elif item == "potion":
		if me.hp >= me.max_hp():
			text = "HP가 가득 차 있다!"
			shown = 999.0
			return
		main.items[item] -= 1
		_turn({"type": "potion"})


func switch_to(idx: int) -> void:
	if mode != "party":
		return
	var m = my_party[idx]
	if m.fainted() or m == me:
		return
	if forced_switch:
		forced_switch = false
		me = m
		mode = "steps"
		if pvp:
			main.coop.send({"t": "fsw", "i": idx})
		_send_out_me(false)
		_do(_to_menu)
		return
	if pvp:
		_pvp_choose({"type": "switch", "i": idx})
		return
	_turn({"type": "switch", "mon": m})


func try_run() -> void:
	if mode != "menu":
		return
	if pvp:
		mode = "steps"
		main.coop.send({"t": "forfeit"})
		_msg("승부를 포기했다...")
		_do(_finish.bind("lose"))
		return
	if kind != "wild":
		mode = "steps"
		_msg("안 돼! 트레이너와의 승부에서 도망칠 수는 없다!")
		return
	escape_tries += 1
	var ok: bool = me.spd() >= enemy.spd() or rng.randf() < 0.5 + escape_tries * 0.15
	mode = "steps"
	if ok:
		_msg("무사히 도망쳤다!")
		_do(_finish.bind("run"))
	else:
		_msg("도망칠 수 없었다!")
		_enemy_attack()


func _enemy_move() -> String:
	var best: String = enemy.moves[0]
	var best_v := -1.0
	for mv in enemy.moves:
		var m: Array = Data.MOVES[mv]
		var v: float = m[2] * Data.effect(m[1], me.types()) * (1.5 if enemy.types().has(m[1]) else 1.0)
		if v > best_v:
			best_v = v
			best = mv
	if rng.randf() < 0.35:
		best = enemy.moves[rng.randi() % enemy.moves.size()]
	return best


func _turn(action: Dictionary) -> void:
	mode = "steps"
	var emv := _enemy_move()
	match action.type:
		"move":
			var pm: String = action.id
			var p_first: bool
			var pp: int = Data.MOVES[pm][4]
			var ep: int = Data.MOVES[emv][4]
			if pp != ep:
				p_first = pp > ep
			elif me.spd() != enemy.spd():
				p_first = me.spd() > enemy.spd()
			else:
				p_first = rng.randf() < 0.5
			if p_first:
				_do(_attack_now.bind(me, enemy, pm, true))
				_do(_second.bind(false, emv))
			else:
				_do(_attack_now.bind(enemy, me, emv, false))
				_do(_second.bind(true, pm))
		"ball":
			_throw(action.id)
		"potion":
			_msg("상처약을 사용했다!")
			_do(_potion_heal)
			_msg("%s의 HP가 회복되었다!" % me.name())
			_enemy_attack()
		"switch":
			_msg("돌아와, %s!" % me.name())
			_do(_swap_mon.bind(action.mon))
			_send_out_me(false)
			_enemy_attack()


## 두 번째로 행동하는 쪽 (둘 다 살아 있을 때만)
func _second(is_me: bool, mv: String) -> void:
	if enemy.fainted() or me.fainted():
		return
	if is_me:
		_attack_now(me, enemy, mv, true)
	else:
		_attack_now(enemy, me, mv, false)


func _enemy_attack() -> void:
	_do(_enemy_attack_now)


func _enemy_attack_now() -> void:
	if not enemy.fainted() and not me.fainted():
		_attack_now(enemy, me, _enemy_move(), false)


func _potion_heal() -> void:
	me.hp = min(me.max_hp(), me.hp + Data.ITEMS.potion.heal)
	main.sfx.play("heal", -6.0)


func _swap_mon(nm) -> void:
	p_visible = false
	me = nm


func _prefix(is_me: bool) -> String:
	if is_me:
		return ""
	if pvp:
		return "친구의 "
	return "야생 " if kind == "wild" else "상대 "


func _attack_now(att, deff, mv: String, is_me: bool) -> void:
	var m: Array = Data.MOVES[mv]
	var out: Array = []
	out.append({"msg": "%s%s의 %s!" % [_prefix(is_me), att.name(), m[0]], "speaker": ""})
	if m[2] <= 0:
		out.append({"msg": "그러나 아무 일도 일어나지 않았다!", "speaker": ""})
		_front(out)
		return
	if rng.randi_range(1, 100) > m[3]:
		out.append({"msg": "그러나 빗나갔다!", "speaker": ""})
		_front(out)
		return
	var r: Array = Mon.damage(att, deff, mv, rng)
	_hit_steps(out, att, deff, mv, is_me, r)


func _hit_steps(out: Array, att, deff, mv: String, is_me: bool, r: Array) -> void:
	out.append({"do": _apply_hit.bind(att, deff, mv, r[0], r[1], is_me)})
	out.append({"wait": 0.5})
	if r[2]:
		out.append({"msg": "급소에 맞았다!", "speaker": ""})
	if r[1] >= 2.0:
		out.append({"msg": "효과가 굉장했다!", "speaker": ""})
	elif r[1] == 0.0:
		out.append({"msg": "효과가 없는 것 같다...", "speaker": ""})
	elif r[1] < 1.0:
		out.append({"msg": "효과가 별로인 듯하다...", "speaker": ""})
	out.append({"do": _check_faint.bind(deff, not is_me)})
	_front(out)


func _apply_hit(att, deff, mv: String, dmg: int, eff: float, is_me: bool) -> void:
	deff.hp = max(0, deff.hp - dmg)
	main.sfx.play("hit", -4.0, 1.2 if eff > 1.0 else 0.9)
	if is_me:
		e_shake = 0.4
		e_flash = 0.4
	else:
		p_shake = 0.4
	if mv == "absorb":
		att.hp = min(att.max_hp(), att.hp + max(1, dmg / 2))


func _check_faint(m, is_me: bool) -> void:
	if not m.fainted():
		return
	var out: Array = []
	if pvp:
		_pvp_faint(m, is_me)
		return
	if is_me:
		out.append({"do": _hide_me})
		out.append({"msg": "%s(은)는 쓰러졌다!" % m.name(), "speaker": ""})
		if _first_healthy() != null:
			out.append({"do": _force_switch})
		else:
			out.append({"msg": "눈앞이 캄캄해졌다...", "speaker": ""})
			out.append({"do": _finish.bind("lose")})
	else:
		out.append({"do": _hide_enemy})
		out.append({"msg": "%s%s(은)는 쓰러졌다!" % [_prefix(false), m.name()], "speaker": ""})
		var gain := int(m.data().exp * m.level / 7.0 * (1.5 if kind != "wild" else 1.0))
		out.append({"msg": "%s(은)는 경험치를 %d 얻었다!" % [me.name(), gain], "speaker": ""})
		out.append({"do": _give_exp.bind(gain)})
		var idx := enemy_party.find(m)
		if idx + 1 < enemy_party.size():
			var nxt = enemy_party[idx + 1]
			out.append({"msg": "%s(은)는 %s(을)를 내보냈다!" % [trainer_name, nxt.name()], "speaker": ""})
			out.append({"do": _next_enemy.bind(nxt)})
		else:
			if kind != "wild":
				money_won = enemy.level * (100 if kind == "leader" else 30)
				out.append({"msg": "%s과(와)의 승부에서 이겼다!" % trainer_name, "speaker": ""})
				out.append({"msg": "상금으로 %d원을 받았다!" % money_won, "speaker": ""})
			else:
				money_won = enemy.level * 10
				out.append({"msg": "%d원을 주웠다!" % money_won, "speaker": ""})
			out.append({"do": _finish.bind("win")})
	_front(out)


func _hide_me() -> void:
	p_visible = false


func _hide_enemy() -> void:
	e_visible = false
	main.sfx.play("shake", -6.0, 0.6)


func _force_switch() -> void:
	forced_switch = true
	mode = "party"
	text = "다음 포켓몬을 골라 주세요"
	shown = 999.0


func _give_exp(gain: int) -> void:
	var lv_msgs: Array = me.gain_exp(gain)
	var more: Array = []
	for s in lv_msgs:
		more.append({"do": _lvup_sound})
		more.append({"msg": s, "speaker": ""})
	_front(more)


func _lvup_sound() -> void:
	main.sfx.play("levelup", -4.0)


func _next_enemy(nxt) -> void:
	enemy = nxt
	e_hp = enemy.hp
	e_visible = true
	main.voice.cry(enemy.name())


func _throw(b: String) -> void:
	var res: Array = Mon.catch_try(enemy, b, rng)
	_msg("%s(을)를 던졌다!" % Data.ITEMS[b].name)
	_do(_ball_out.bind(b, res[0], res[1]))
	_wait(0.7)
	for i in res[0]:
		_do(_shake_sound)
		_wait(0.7)
	if res[1]:
		_do(_catch_sound)
		_msg("신난다! %s(을)를 잡았다!" % enemy.name())
		_do(_store_caught)
	else:
		_do(_ball_break)
		var fails := ["앗! 볼에서 나와 버렸다!", "아깝다! 조금만 더 하면 잡을 수 있었는데!", "으앗! 거의 잡았는데!"]
		_msg(fails[min(res[0], 2)])
		_enemy_attack()


func _ball_out(b: String, shakes: int, caught: bool) -> void:
	ball = {"kind": b, "t": 0.0, "shakes": shakes, "caught": caught}
	e_visible = false


func _shake_sound() -> void:
	main.sfx.play("shake", -6.0)


func _catch_sound() -> void:
	main.sfx.play("catch", -2.0)


func _store_caught() -> void:
	var where: String = main.add_caught(enemy)
	_front([{"msg": where, "speaker": ""}, {"do": _finish.bind("caught")}])


func _ball_break() -> void:
	ball = null
	e_visible = true


# ------------------------------------------------------------------ 친구와 대전

func _pvp_choose(a: Dictionary) -> void:
	mode = "wait"
	text = "친구를 기다리는 중..."
	shown = 999.0
	if main.coop.net.is_host:
		pvp_my_act = a
		_pvp_try_resolve()
	else:
		pvp_my_act = a
		main.coop.send({"t": "act", "a": a})


func pvp_foe_action(a: Dictionary) -> void:
	if not visible or not pvp:
		return
	pvp_foe_act = a
	_pvp_try_resolve()


## 방장만: 두 행동이 다 모이면 턴 결과를 계산해서 보내고 연출
func _pvp_try_resolve() -> void:
	if not main.coop.net.is_host or pvp_my_act == null or pvp_foe_act == null or mode != "wait":
		return
	var ev := _pvp_resolve(pvp_my_act, pvp_foe_act)
	pvp_my_act = null
	pvp_foe_act = null
	main.coop.send({"t": "turn", "ev": ev})
	pvp_play(ev, true)


func _pvp_resolve(ha: Dictionary, ga: Dictionary) -> Array:
	var ev: Array = []
	var act := {"h": me, "g": enemy}
	var hp := {}
	var acts := {"h": ha, "g": ga}
	for who in ["h", "g"]:
		if acts[who].type == "switch":
			var arr: Array = my_party if who == "h" else enemy_party
			act[who] = arr[int(acts[who].i)]
			ev.append({"who": who, "k": "sw", "i": int(acts[who].i)})
	hp["h"] = act.h.hp
	hp["g"] = act.g.hp
	var movers: Array = []
	for who in ["h", "g"]:
		if acts[who].type == "move":
			movers.append(who)
	if movers.size() == 2:
		var hm: Array = Data.MOVES[ha.id]
		var gm: Array = Data.MOVES[ga.id]
		var h_first: bool
		if hm[4] != gm[4]:
			h_first = hm[4] > gm[4]
		elif act.h.spd() != act.g.spd():
			h_first = act.h.spd() > act.g.spd()
		else:
			h_first = rng.randf() < 0.5
		movers = ["h", "g"] if h_first else ["g", "h"]
	for who in movers:
		var other := "g" if who == "h" else "h"
		if hp[who] <= 0 or hp[other] <= 0:
			continue
		var mv: String = acts[who].id
		var m: Array = Data.MOVES[mv]
		var e := {"who": who, "k": "mv", "mv": mv, "miss": false, "dmg": 0, "eff": 1.0, "crit": false}
		if m[2] > 0:
			if rng.randi_range(1, 100) > m[3]:
				e.miss = true
			else:
				var r: Array = Mon.damage(act[who], act[other], mv, rng)
				e.dmg = r[0]
				e.eff = r[1]
				e.crit = r[2]
				hp[other] = max(0, hp[other] - r[0])
				if mv == "absorb":
					hp[who] = min(act[who].max_hp(), hp[who] + max(1, r[0] / 2))
		ev.append(e)
	return ev


## 턴 결과 연출 (방장/참가자 모두 같은 결과)
func pvp_play(ev: Array, i_am_host: bool) -> void:
	if not visible or not pvp:
		return
	mode = "steps"
	steps.clear()
	for e in ev:
		var mine: bool = (e.who == "h") == i_am_host
		if e.k == "sw":
			if mine:
				_msg("돌아와, %s!" % me.name())
				_do(_swap_mon.bind(my_party[int(e.i)]))
				_send_out_me(false)
			else:
				var nm = enemy_party[int(e.i)]
				_msg("친구는 %s(을)를 내보냈다!" % nm.name())
				_do(_next_enemy.bind(nm))
		else:
			_do(_pvp_attack.bind(e, mine))


func _pvp_attack(e: Dictionary, mine: bool) -> void:
	var att = me if mine else enemy
	var deff = enemy if mine else me
	if att.fainted() or deff.fainted():
		return
	var m: Array = Data.MOVES[e.mv]
	var out: Array = []
	out.append({"msg": "%s%s의 %s!" % [_prefix(mine), att.name(), m[0]], "speaker": ""})
	if m[2] <= 0:
		out.append({"msg": "그러나 아무 일도 일어나지 않았다!", "speaker": ""})
		_front(out)
	elif e.miss:
		out.append({"msg": "그러나 빗나갔다!", "speaker": ""})
		_front(out)
	else:
		_hit_steps(out, att, deff, e.mv, mine, [int(e.dmg), float(e.eff), bool(e.crit)])


func _pvp_faint(m, is_me: bool) -> void:
	var out: Array = []
	if is_me:
		out.append({"do": _hide_me})
		out.append({"msg": "%s(은)는 쓰러졌다!" % m.name(), "speaker": ""})
		if _first_healthy() != null:
			out.append({"do": _force_switch})
		else:
			out.append({"msg": "친구에게 졌다...", "speaker": ""})
			out.append({"do": _finish.bind("lose")})
	else:
		out.append({"do": _hide_enemy})
		out.append({"msg": "친구의 %s(은)는 쓰러졌다!" % m.name(), "speaker": ""})
		var left := enemy_party.filter(func(x): return not x.fainted())
		if left.is_empty():
			out.append({"msg": "친구와의 승부에서 이겼다!", "speaker": ""})
			out.append({"do": _finish.bind("win")})
		else:
			out.append({"do": _wait_foe_switch})
	_front(out)


func _wait_foe_switch() -> void:
	if pvp_pending_sw >= 0:
		var i := pvp_pending_sw
		pvp_pending_sw = -1
		_apply_foe_switch(i)
		return
	waiting_foe_sw = true
	mode = "wait"
	text = "친구가 다음 포켓몬을 고르는 중..."
	shown = 999.0


func pvp_foe_switch(i: int) -> void:
	if not visible or not pvp:
		return
	if waiting_foe_sw:
		waiting_foe_sw = false
		mode = "steps"
		_apply_foe_switch(i)
	else:
		pvp_pending_sw = i


func _apply_foe_switch(i: int) -> void:
	var nm = enemy_party[i]
	_front([{"msg": main.josa("친구는 %s(을)를 내보냈다!" % nm.name()), "speaker": ""}, {"do": _next_enemy.bind(nm)}])


func pvp_foe_forfeit() -> void:
	if not visible or not pvp or mode == "done":
		return
	steps.clear()
	mode = "steps"
	_msg("친구가 승부를 포기했다! 이겼다!")
	_do(_finish.bind("win"))


func pvp_foe_left() -> void:
	if not visible or not pvp or mode == "done":
		return
	steps.clear()
	mode = "steps"
	_msg("친구와의 연결이 끊겼다...")
	_do(_finish.bind("run"))


func _finish(r: String) -> void:
	result = r
	mode = "done"
	main.on_battle_end(r, money_won, kind)


# ------------------------------------------------------------------ 레이아웃/입력

func buttons() -> Array:
	var v: Vector2 = main.view
	var out: Array = []
	var by := v.y - 190.0
	match mode:
		"menu":
			var labels := [["fight", "싸우기", Color("e53935")], ["bag", "가방", Color("fb8c00")], ["party", "포켓몬", Color("43a047")], ["run", "기권" if pvp else "도망", Color("1e88e5")]]
			for i in 4:
				out.append({"id": labels[i][0], "rect": Rect2(8 + (i % 2) * 176, by + (i / 2) * 64, 168, 56), "label": labels[i][1], "col": labels[i][2]})
		"moves":
			for i in me.moves.size():
				var m: Array = Data.MOVES[me.moves[i]]
				out.append({"id": "move:%d" % i, "rect": Rect2(8 + (i % 2) * 176, by + (i / 2) * 64, 168, 56), "label": m[0], "col": Data.TYPES[m[1]].col.darkened(0.15), "sub": Data.TYPES[m[1]].name})
			out.append({"id": "back", "rect": Rect2(8, by + 136, v.x - 16, 40), "label": "뒤로", "col": Color("546e7a")})
		"bag":
			var i := 0
			for it in Data.SHOP_ORDER:
				var n: int = main.items.get(it, 0)
				if n <= 0:
					continue
				out.append({"id": "item:" + it, "rect": Rect2(8 + (i % 2) * 176, by + (i / 2) * 44 - 30, 168, 38), "label": "%s x%d" % [Data.ITEMS[it].name, n], "col": Color("455a64"), "ball": it})
				i += 1
			out.append({"id": "back", "rect": Rect2(8, by + 136, v.x - 16, 40), "label": "뒤로", "col": Color("546e7a")})
		"party":
			for i in my_party.size():
				out.append({"id": "mon:%d" % i, "rect": Rect2(8, 70 + i * 54, v.x - 16, 48), "kind": "mon", "mon": my_party[i]})
			if not forced_switch:
				out.append({"id": "back", "rect": Rect2(v.x - 76, 30, 68, 30), "label": "뒤로", "col": Color("546e7a")})
	return out


func tap(p: Vector2) -> void:
	if mode == "steps":
		advance()
		return
	for b in buttons():
		if b.rect.has_point(p):
			press(b.id)
			return


func press(id: String) -> void:
	main.sfx.play("select", -12.0)
	match id:
		"fight":
			mode = "moves"
		"bag":
			mode = "bag"
		"party":
			mode = "party"
		"run":
			try_run()
		"back":
			_to_menu()
		_:
			if id.begins_with("move:"):
				choose_move(int(id.substr(5)))
			elif id.begins_with("item:"):
				use_item(id.substr(5))
			elif id.begins_with("mon:"):
				switch_to(int(id.substr(4)))


# ------------------------------------------------------------------ 그리기

func _info_box(r: Rect2, m, hp_disp: float, show_num: bool) -> void:
	draw_rect(r, Color("f8f8e8"))
	draw_rect(r, Color("303030"), false, 2.0)
	var f: Font = main.font
	draw_string(f, r.position + Vector2(8, 16), m.name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("303030"))
	draw_string(f, r.position + Vector2(r.size.x - 44, 16), "Lv%d" % m.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("303030"))
	var bar := Rect2(r.position + Vector2(30, 24), Vector2(r.size.x - 40, 7))
	draw_string(f, r.position + Vector2(8, 32), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f0a020"))
	draw_rect(bar.grow(1), Color("303030"))
	var k: float = clamp(hp_disp / m.max_hp(), 0.0, 1.0)
	var col := Color("48c048") if k > 0.5 else (Color("f8c020") if k > 0.2 else Color("e83020"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), col)
	if show_num:
		draw_string(f, r.position + Vector2(r.size.x - 74, 48), "%d/%d" % [int(round(hp_disp)), m.max_hp()], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("303030"))
		var need: float = m.exp_for(m.level + 1) - m.exp_for(m.level)
		var have: float = m.exp - m.exp_for(m.level)
		draw_rect(Rect2(r.position + Vector2(8, r.size.y - 6), Vector2(r.size.x - 16, 3)), Color("9e9e9e"))
		draw_rect(Rect2(r.position + Vector2(8, r.size.y - 6), Vector2((r.size.x - 16) * clamp(have / max(need, 1.0), 0.0, 1.0), 3)), Color("40a8f8"))


func _draw() -> void:
	var v: Vector2 = main.view
	var f: Font = main.font
	var area: Dictionary = Data.area(main.stage)
	# 배경
	draw_rect(Rect2(0, 0, v.x, v.y), Color("f8f8f0"))
	draw_rect(Rect2(0, 0, v.x, 330), area.ground.lightened(0.35))
	draw_rect(Rect2(0, 200, v.x, 130), area.ground.lightened(0.15))
	# 받침
	draw_colored_polygon(Px.ell(Vector2(258, 150), Vector2(70, 16)), area.grass.darkened(0.1))
	draw_colored_polygon(Px.ell(Vector2(96, 310), Vector2(84, 18)), area.grass.darkened(0.1))
	# 상대
	if e_visible and enemy:
		var ex := sin(t * 40.0) * 4.0 if e_shake > 0.0 else 0.0
		if e_flash <= 0.0 or int(e_flash * 16.0) % 2 == 0:
			main.spr.mon(self, enemy.id, Vector2(258 + ex, 154), 2)
	if ball:
		var bk: float = min(ball.t / 0.6, 1.0)
		var bp := Vector2(lerp(80.0, 258.0, bk), lerp(320.0, 140.0, bk) - sin(bk * PI) * 80.0)
		if bk >= 1.0:
			bp = Vector2(258, 140) + Vector2(sin(ball.t * 14.0) * 3.0 * float(int(ball.t / 0.7) <= ball.shakes), 0)
		main.spr.ball(self, ball.kind, bp, 1)
	# 내 포켓몬 (뒷모습 대신 좌우 반전)
	if p_visible and me:
		var px := sin(t * 40.0) * 4.0 if p_shake > 0.0 else 0.0
		main.spr.mon(self, me.id, Vector2(96 + px, 316), 3, true)
	if enemy:
		_info_box(Rect2(10, 34, 178, 42), enemy, e_hp, false)
	if me:
		_info_box(Rect2(172, 228, 180, 60), me, p_hp, true)
	# 메시지 창
	var mr := Rect2(6, 336, v.x - 12, 72)
	if mode == "party":
		draw_rect(Rect2(0, 0, v.x, v.y), Color("f0f0e0"))
		draw_string(f, Vector2(12, 48), "포켓몬" if not forced_switch else "다음 포켓몬을 골라 주세요", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("303030"))
	else:
		draw_rect(mr, Color("f8f8f8"))
		draw_rect(mr, Color("3060a0"), false, 3.0)
		draw_rect(mr.grow(-4), Color("303030"), false, 1.0)
		var shown_text := text.substr(0, int(shown))
		draw_multiline_string(f, mr.position + Vector2(12, 24), shown_text, HORIZONTAL_ALIGNMENT_LEFT, mr.size.x - 24, 11, 3, Color("303030"))
		if mode == "steps" and shown >= text.length() and int(t * 3.0) % 2 == 0:
			draw_colored_polygon(PackedVector2Array([mr.end - Vector2(18, 14), mr.end - Vector2(10, 14), mr.end - Vector2(14, 9)]), Color("e53935"))
	for b in buttons():
		if b.get("kind", "") == "mon":
			_mon_row(b)
			continue
		var r: Rect2 = b.rect
		draw_rect(r, b.col)
		draw_rect(r, Color("202020"), false, 2.0)
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 3)), Color(1, 1, 1, 0.3))
		var tx := 12.0
		if b.has("ball") and Data.BALLS.has(b.ball):
			main.spr.ball(self, b.ball, r.position + Vector2(14, r.size.y * 0.5), 1)
			tx = 28.0
		var fs := 22 if r.size.y > 50 else 11
		draw_string(f, r.position + Vector2(tx, r.size.y * 0.5 + fs * 0.4), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		if b.has("sub"):
			draw_string(f, r.position + Vector2(r.size.x - 40, r.size.y - 8), b.sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.85))


func _mon_row(b: Dictionary) -> void:
	var m = b.mon
	var r: Rect2 = b.rect
	var f: Font = main.font
	var cur: bool = m == me
	draw_rect(r, Color("90caf9") if cur else (Color("e0e0e0") if m.fainted() else Color("f8f8f8")))
	draw_rect(r, Color("303030"), false, 2.0)
	main.spr.mon(self, m.id, r.position + Vector2(28, 46), 1)
	draw_string(f, r.position + Vector2(56, 18), m.name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("303030"))
	draw_string(f, r.position + Vector2(150, 18), "Lv%d" % m.level, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("303030"))
	var bar := Rect2(r.position + Vector2(56, 28), Vector2(150, 6))
	draw_rect(bar.grow(1), Color("303030"))
	var k: float = float(m.hp) / m.max_hp()
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Color("48c048") if k > 0.5 else (Color("f8c020") if k > 0.2 else Color("e83020")))
	draw_string(f, r.position + Vector2(216, 36), "%d/%d" % [m.hp, m.max_hp()] if not m.fainted() else "기절", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("303030"))
