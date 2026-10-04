extends Node
## 자동 플레이 테스트 봇.
##   godot --path . -- --autoplay [--fresh] [--shots=DIR] [--stages=N] [--time=SEC] [--char=f] [--starter=0..4] [--start=S]
## 첫 진행(캐릭터/스타팅) → 상점 → 스테이지를 연속으로 클리어하며 화면을 저장한다.

const Data = preload("res://scripts/data.gd")

var main
var cd := 0.5
var elapsed := 0.0
var shots_dir := ""
var shot_n := 0
var last_state := -1
var last_mode := ""
var stages_goal := 3
var time_limit := 240.0
var char_pref := "m"
var starter_pref := 0
var start_stage := 1
var cleared := 0
var shopped := false
var path_fail := 0
var evo_test := false


func _ready() -> void:
	process_priority = -10
	for a in OS.get_cmdline_user_args():
		if a == "--fresh":
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://save_autoplay.cfg"))
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots_dir)
		elif a.begins_with("--stages="):
			stages_goal = int(a.substr(9))
		elif a.begins_with("--time="):
			time_limit = float(a.substr(7))
		elif a.begins_with("--char="):
			char_pref = a.substr(7)
		elif a.begins_with("--starter="):
			starter_pref = int(a.substr(10))
		elif a == "--evo":
			evo_test = true
		elif a.begins_with("--start="):
			start_stage = int(a.substr(8))
	if FileAccess.file_exists("user://save_autoplay.cfg") == false:
		main.load_game()


func shot(tag: String) -> void:
	if shots_dir == "" or shot_n > 80:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%03d_%s.png" % [shots_dir, shot_n, tag])
	shot_n += 1


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > time_limit:
		print("[autoplay] time limit. cleared=", cleared, " best=", main.best_stage, " money=", main.money)
		get_tree().quit()
		return
	var S = main.State
	if main.state != last_state:
		last_state = main.state
		shot(S.keys()[main.state])
	if main.state == S.BATTLE and main.battle.mode != last_mode:
		last_mode = main.battle.mode
		if last_mode in ["menu", "moves", "bag", "party"] and shot_n < 60:
			shot("battle_" + last_mode)
	main.bot_dir = -1
	if evo_test and not main.party.is_empty() and main.state == S.TOWN:
		evo_test = false
		var m = main.party[0]
		m.level = 24
		m.exp = m.exp_for(25) - 5
		m.heal_full()
		print("[autoplay] evo test: ", m.name(), " Lv24")
	if main.state == S.FIELD and not main.dlg_busy():
		main.bot_dir = _field_dir()
	cd -= delta
	if cd > 0.0:
		return
	cd = 0.25
	if not main.choice.is_empty():
		if main.choice.size() == 2 and main.choice[0] == "다음 스테이지":
			cleared += 1
			print("[autoplay] cleared ", cleared, "/", stages_goal)
			if cleared >= stages_goal:
				shot("clear")
				print("[autoplay] DONE best=", main.best_stage, " money=", main.money, " party=", main.party.map(func(m): return "%s Lv%d" % [m.name(), m.level]), " box=", main.box.size())
				get_tree().create_timer(0.5).timeout.connect(get_tree().quit)
				cd = 99.0
				return
			# 체력이 많이 깎였으면 마을로 가서 회복
			var hurt := 0.0
			for m in main.party:
				hurt += 1.0 - float(m.hp) / m.max_hp()
			main.pick_choice(1 if hurt > main.party.size() * 0.4 else 0)
		else:
			main.pick_choice(0)
		return
	if main.dlg_text != "":
		cd = 0.15
		if main.dlg_shown >= main.dlg_text.length():
			main.advance()
		return
	match main.state:
		S.TITLE:
			main.press("continue" if main.started else "start")
		S.CHAR:
			main.press("char_" + char_pref) if main.char_pick == "" else main.press("char_ok")
		S.STARTER:
			if main.starter_pick < 0:
				main.press("starter:%d" % starter_pref)
			else:
				shot("starter_pick")
				main.press("starter_ok")
		S.TOWN:
			var hurt := false
			for m in main.party:
				if m.hp < m.max_hp():
					hurt = true
			if hurt:
				main.press("center")
			elif not shopped:
				main.press("shop")
			else:
				main.press("adventure")
		S.CENTER:
			var all_ok := true
			for m in main.party:
				if m.hp < m.max_hp():
					all_ok = false
			main.press("back" if all_ok else "heal")
		S.SHOP:
			if not shopped:
				main.press("buy5:pokeball")
				if main.money >= 400:
					main.press("buy:greatball")
				if main.money >= 300 and main.items.get("potion", 0) < 3:
					main.press("buy:potion")
				shopped = true
				shot("shop_after")
			else:
				main.press("back")
		S.STAGES:
			if main.stage < start_stage:
				main.stage = start_stage
			shot("stages")
			main.press("go")
		S.MENU:
			main.press("close")
		S.PARTY, S.BAG:
			main.press("back")
		S.EVOLVE:
			if main.evo_choose:
				main.press("evo:1")
		S.BATTLE:
			_battle()


func _battle() -> void:
	var b = main.battle
	match b.mode:
		"steps":
			cd = 0.1
			if b.shown >= b.text.length():
				b.advance()
		"menu":
			var e = b.enemy
			var me = b.me
			if me.hp < me.max_hp() * 0.3 and main.items.get("potion", 0) > 0:
				b.press("bag")
			elif b.kind == "wild" and main.party.size() < 6 and e.hp < e.max_hp() * 0.6 and _ball() != "":
				b.press("bag")
			else:
				b.press("fight")
		"bag":
			var me2 = b.me
			if me2.hp < me2.max_hp() * 0.3 and main.items.get("potion", 0) > 0:
				b.press("item:potion")
			elif _ball() != "" and b.kind == "wild":
				b.press("item:" + _ball())
			else:
				b.press("back")
			if b.mode == "bag":
				b.press("back")
		"moves":
			var best := 0
			var bv := -1.0
			for i in b.me.moves.size():
				var m: Array = Data.MOVES[b.me.moves[i]]
				var v: float = m[2] * Data.effect(m[1], b.enemy.types()) * (1.5 if b.me.types().has(m[1]) else 1.0) * m[3] / 100.0
				if v > bv:
					bv = v
					best = i
			b.press("move:%d" % best)
		"party":
			for i in main.party.size():
				if not main.party[i].fainted() and main.party[i] != b.me:
					b.press("mon:%d" % i)
					return
			b.press("back")


func _ball() -> String:
	for k in ["greatball", "pokeball", "ultraball"]:
		if main.items.get(k, 0) > 0:
			return k
	return ""


## 필드: BFS로 관장 앞 칸까지 (아이템이 가까우면 먼저 줍는다)
func _field_dir() -> int:
	var f = main.field
	if f.lock or f.draw_pos.distance_to(Vector2(f.pos)) > 0.05:
		return -1
	var goal := Vector2i(-99, -99)
	for n in f.npcs:
		if n.kind == "leader" and not n.beaten:
			goal = n.pos + Vector2i(0, 1)
	var dist := {f.pos: -1}
	var q: Array = [f.pos]
	var found := false
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == goal:
			found = true
			break
		for d in 4:
			var nc: Vector2i = c + f.DIRS[d]
			if dist.has(nc) or not f._walkable(nc):
				continue
			dist[nc] = d if dist[c] == -1 else dist[c]
			q.append(nc)
	if not found:
		path_fail += 1
		if path_fail % 60 == 1:
			print("[autoplay] no path to leader from ", f.pos)
		return randi() % 4
	return dist[goal]
