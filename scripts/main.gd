extends Node2D
## 포켓몬 모험: 화면 흐름 전체.
## 타이틀 → 캐릭터(남/여) → 오박사 → 스타팅 포켓몬 → 마을(모험/센터/상점/포켓몬/가방) → 스테이지 선택(무한) → 필드 ↔ 배틀 → 진화

const Data = preload("res://scripts/data.gd")
const Mon = preload("res://scripts/mon.gd")
const Px = preload("res://scripts/px.gd")
const FieldScript = preload("res://scripts/field.gd")
const BattleScript = preload("res://scripts/battle.gd")
const VoiceScript = preload("res://scripts/voice.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const SpritesScript = preload("res://scripts/sprites.gd")
const CoopScript = preload("res://scripts/coop.gd")

enum State { TITLE, CHAR, OAK, STARTER, TOWN, SHOP, CENTER, PARTY, BAG, STAGES, FIELD, MENU, BATTLE, EVOLVE, LOBBY, FRIEND, TRADE }

var state := State.TITLE
var view := Vector2(360, 640)
var font: FontFile
var voice
var sfx
var field
var battle
var ui: Node2D
var spr
var coop
var pending_stage: Array = []   # 친구가 출발한 스테이지 [s, seed]
var pvp_ret := State.TOWN
var trade_ret := State.TOWN
var log_lines: Array = []
var autoplay := false
var bot_dir := -1
var t := 0.0

# 저장되는 진행 상황
var character := "m"
var started := false
var party: Array = []
var box: Array = []
var items := {}
var money := 500
var best_stage := 0        # 클리어한 가장 높은 스테이지
var stage := 1             # 지금(또는 다음에) 갈 스테이지
var save_path := "user://save.cfg"

# 화면별 임시 상태
var char_pick := ""
var starter_pick := -1
var party_sel := -1        # 포켓몬 화면에서 고른 칸 (0~5 파티, 100+ 박스)
var bag_potion := false    # 상처약 쓸 포켓몬 고르는 중
var ret_state := State.TOWN
var toast := ""
var toast_t := 0.0
var trans_t := 0.0         # 배틀 들어가기 전 번쩍임
var pending_battle: Array = []
var cur_npc = null
var evo_queue: Array = []  # 진화할 포켓몬
var evo_mon = null
var evo_to := ""
var evo_t := -1.0
var evo_choose := false
var after_evo: Callable

# 대화창
var dlg: Array = []        # [{text, who}]
var dlg_text := ""
var dlg_shown := 0.0
var dlg_then: Callable
var choice: Array = []     # 예/아니오 같은 선택지
var choice_cb: Callable


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			autoplay = true
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.search", true)).contains("autoplay"):
		autoplay = true
	if autoplay:
		save_path = "user://save_autoplay.cfg"
	font = (load("res://fonts/Galmuri11.ttf") as FontFile).duplicate()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	spr = SpritesScript.new()
	add_child(spr)
	spr.bake()
	coop = CoopScript.new()
	coop.main = self
	add_child(coop)
	voice = VoiceScript.new()
	add_child(voice)
	sfx = SfxScript.new()
	add_child(sfx)
	field = FieldScript.new()
	field.main = self
	add_child(field)
	battle = BattleScript.new()
	battle.main = self
	battle.visible = false
	add_child(battle)
	ui = Node2D.new()
	add_child(ui)
	ui.draw.connect(_draw_ui)
	if autoplay:
		voice.enabled = false
		var ap = load("res://scripts/autoplay.gd").new()
		ap.main = self
		add_child(ap)
	load_game()
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()


func _on_resize() -> void:
	# 세로 화면(폰)은 꽉 채우고, 가로로 넓은 화면(PC)은 세로 비율로 가운데 표시
	var ws := Vector2(DisplayServer.window_get_size())
	var root := get_tree().root
	var want := Window.CONTENT_SCALE_ASPECT_KEEP if ws.x / max(ws.y, 1.0) > 0.68 else Window.CONTENT_SCALE_ASPECT_EXPAND
	if root.content_scale_aspect != want:
		root.content_scale_aspect = want
	view = get_viewport_rect().size


func set_state(s: int) -> void:
	state = s
	print("[state] ", State.keys()[s])
	field.visible = s == State.FIELD or s == State.MENU or s == State.FRIEND
	battle.visible = s == State.BATTLE


# ------------------------------------------------------------------ 한국어 조사

static func _has_final(ch: String) -> int:
	# 0: 받침 없음, 1: 받침 있음, 2: ㄹ 받침
	if ch >= "0" and ch <= "9":
		return {"0": 1, "1": 2, "2": 0, "3": 1, "4": 0, "5": 0, "6": 1, "7": 2, "8": 2, "9": 0}[ch]
	var c := ch.unicode_at(0)
	if c < 0xAC00 or c > 0xD7A3:
		return 0
	var f := (c - 0xAC00) % 28
	if f == 0:
		return 0
	return 2 if f == 8 else 1


static func josa(s: String) -> String:
	var pairs := [["(을)를", "을", "를"], ["(이)가", "이", "가"], ["(은)는", "은", "는"], ["(으)로", "으로", "로"], ["과(와)", "과", "와"], ["(이)야", "이야", "야"]]
	for p in pairs:
		var i := s.find(p[0])
		while i > 0:
			var f := _has_final(s[i - 1])
			var rep: String = p[1] if f == 1 or (f == 2 and p[0] != "(으)로") else p[2]
			s = s.substr(0, i) + rep + s.substr(i + p[0].length())
			i = s.find(p[0])
		if i == 0:
			s = s.substr(p[0].length())
	return s


# ------------------------------------------------------------------ 대화창

func say(lines: Array, who := "", then := Callable()) -> void:
	for l in lines:
		dlg.append({"text": josa(l), "who": who})
	if then.is_valid():
		dlg.append({"then": then})
	if dlg_text == "":
		_next_line()


func ask(question: String, options: Array, cb: Callable, who := "") -> void:
	say([question], who, _set_choice.bind(options, cb))


func _set_choice(options: Array, cb: Callable) -> void:
	choice = options
	choice_cb = cb


func dlg_busy() -> bool:
	return dlg_text != "" or not choice.is_empty()


func _next_line() -> void:
	dlg_text = ""
	while not dlg.is_empty():
		var d: Dictionary = dlg.pop_front()
		if d.has("then"):
			d.then.call()
			if dlg_text != "":
				return
			continue
		dlg_text = d.text
		dlg_shown = 0.0
		if d.who != "":
			voice.speak(dlg_text, d.who)
		return


func advance() -> void:
	if not choice.is_empty():
		return
	if dlg_shown < dlg_text.length():
		dlg_shown = 999.0
	else:
		sfx.play("select", -14.0)
		_next_line()


func pick_choice(i: int) -> void:
	if choice.is_empty():
		return
	choice = []
	dlg_text = ""
	var cb := choice_cb
	cb.call(i)
	if dlg_text == "" and not dlg.is_empty():
		_next_line()


func choice_rects() -> Array:
	var out: Array = []
	for i in choice.size():
		out.append(Rect2(view.x - 150, view.y - 168 - (choice.size() - i) * 40, 140, 36))
	return out


func show_toast(s: String) -> void:
	toast = josa(s)
	toast_t = 1.6


# ------------------------------------------------------------------ 저장

func save_game() -> void:
	var cf := ConfigFile.new()
	cf.set_value("p", "character", character)
	cf.set_value("p", "started", started)
	cf.set_value("p", "party", party.map(func(m): return m.to_dict()))
	cf.set_value("p", "box", box.map(func(m): return m.to_dict()))
	cf.set_value("p", "items", items)
	cf.set_value("p", "money", money)
	cf.set_value("p", "best", best_stage)
	cf.set_value("p", "stage", stage)
	cf.set_value("p", "voice", voice.enabled)
	cf.save(save_path)


func load_game() -> void:
	var cf := ConfigFile.new()
	if cf.load(save_path) != OK:
		return
	character = cf.get_value("p", "character", "m")
	started = cf.get_value("p", "started", false)
	party = cf.get_value("p", "party", []).map(func(d): return Mon.from_dict(d))
	box = cf.get_value("p", "box", []).map(func(d): return Mon.from_dict(d))
	items = cf.get_value("p", "items", {})
	money = cf.get_value("p", "money", 500)
	best_stage = cf.get_value("p", "best", 0)
	stage = cf.get_value("p", "stage", 1)
	if not autoplay:
		voice.enabled = cf.get_value("p", "voice", true)
	if party.is_empty():
		started = false


func new_game() -> void:
	party = []
	box = []
	items = {"pokeball": 5, "potion": 2}
	money = 500
	best_stage = 0
	stage = 1
	started = false


# ------------------------------------------------------------------ 진행 API (field/battle에서 호출)

func first_healthy():
	for m in party:
		if not m.fainted():
			return m
	return null


func heal_all() -> void:
	for m in party:
		m.heal_full()


func add_caught(m) -> String:
	if party.size() < 6:
		party.append(m)
		return josa("%s(은)는 동료가 되었다!" % m.name())
	box.append(m)
	return josa("%s(은)는 박스로 보내졌다!" % m.name())


func field_item(item: String) -> void:
	field.lock = true
	sfx.play("coin", -6.0)
	if item == "money":
		var amt: int = 100 + 50 * field.stage
		money += amt
		say(["%d원을 주웠다!" % amt], "", _field_resume)
	else:
		items[item] = items.get(item, 0) + 1
		say(["%s(을)를 주웠다!" % Data.ITEMS[item].name], "", _field_resume)


func _field_resume() -> void:
	field.lock = false
	save_game()


func field_trainer(n: Dictionary) -> void:
	cur_npc = n
	sfx.play("encounter", -8.0)
	var foes: Array = []
	for sp in n.team:
		foes.append(Mon.create(sp, n.lv))
	var line := "도전자구나! 이 관장을 쓰러뜨려 보거라!" if n.kind == "leader" else "앗, 눈이 마주쳤다! 승부다!"
	say(["%s: %s" % [n.name, line]], "trainer", func(): _go_battle(n.kind, foes, n.name))


func field_wild(sp: String, lv: int) -> void:
	cur_npc = null
	_go_battle("wild", [Mon.create(sp, lv)], "")


func _go_battle(kind: String, foes: Array, tname: String) -> void:
	if first_healthy() == null:
		field.lock = false
		return
	sfx.play("encounter", -6.0)
	pending_battle = [kind, foes, tname]
	trans_t = 0.7


func open_field_menu() -> void:
	if dlg_busy() or field.lock:
		return
	sfx.play("select", -10.0)
	set_state(State.MENU)


func on_battle_end(result: String, won: int, kind: String) -> void:
	if kind == "pvp":
		print("[pvp] ", result)
		log_lines.append("pvp " + result)
		set_state(pvp_ret)
		field.lock = false
		var line := "친구와의 대전에서 이겼다!" if result == "win" else ("친구와의 대전에서 졌다... 다음엔 꼭 이기자!" if result == "lose" else "대전이 끝났다.")
		say([line], character)
		return
	money += won
	print("[battle] ", kind, " ", result, " +", won, "원 money=", money)
	if result == "lose":
		var lost := money / 5
		money -= lost
		heal_all()
		set_state(State.TOWN)
		field.active = false
		say(["눈앞이 캄캄해졌다...", "%d원을 잃어버렸다..." % lost, "포켓몬센터로 서둘러 돌아왔다. 포켓몬들이 모두 회복되었다!"], "")
		save_game()
		return
	if cur_npc != null and result == "win":
		cur_npc.beaten = true
	var leader_won: bool = cur_npc != null and cur_npc.kind == "leader" and result == "win"
	cur_npc = null
	set_state(State.FIELD)
	_check_evolutions(func(): _after_battle(leader_won))


func _after_battle(leader_won: bool) -> void:
	set_state(State.FIELD)
	if leader_won:
		_stage_clear()
	else:
		field.lock = false
	save_game()


func _stage_clear() -> void:
	var s: int = field.stage
	var bonus := Data.clear_money(s)
	money += bonus
	best_stage = max(best_stage, s)
	stage = s + 1
	sfx.play("levelup", -4.0)
	print("[clear] stage ", s, " money=", money)
	save_game()
	say(["스테이지 %d 클리어!" % s, "%s에게서 배지와 상금 %d원을 받았다!" % [Data.area(s).leader, bonus]], "")
	ask("다음 스테이지로 갈까?", ["다음 스테이지", "마을로"], _clear_choice)


func _clear_choice(i: int) -> void:
	if i == 0:
		start_stage(stage)
	else:
		go_town()


func start_stage(s: int, sd := -1) -> void:
	stage = max(1, s)
	var echo := sd < 0
	if sd < 0:
		sd = randi() % 1000000
	field.setup(stage, sd)
	set_state(State.FIELD)
	show_toast("스테이지 %d  %s" % [stage, Data.area(stage).name])
	if echo and coop.connected():
		coop.send({"t": "stage", "s": stage, "seed": sd})
	save_game()


# ------------------------------------------------------------------ 같이 하기

func partner_stage(s: int, sd: int) -> void:
	pending_stage = [s, sd]


func _can_follow() -> bool:
	if not started or dlg_busy() or trans_t > 0.0:
		return false
	if state == State.FIELD and field.lock:
		return false
	return state in [State.TOWN, State.STAGES, State.FIELD, State.MENU, State.FRIEND, State.SHOP, State.CENTER, State.PARTY, State.BAG, State.LOBBY]


func partner_request(k: String) -> void:
	if state in [State.BATTLE, State.EVOLVE, State.TRADE, State.TITLE, State.CHAR, State.OAK, State.STARTER] or trans_t > 0.0 or dlg_busy() or party.is_empty():
		coop.answer(k, false)
		return
	if state == State.FIELD:
		field.lock = true
	sfx.play("encounter", -8.0)
	var what := "대전" if k == "battle" else "교환"
	ask("친구가 %s을 신청했어! 할까?" % what, ["좋아!", "다음에"], func(i): _answer_req(k, i == 0))


func _answer_req(k: String, ok: bool) -> void:
	if state == State.FIELD:
		field.lock = false
	coop.answer(k, ok)


func open_friend_menu() -> void:
	if dlg_busy() or field.lock:
		return
	sfx.play("select", -10.0)
	set_state(State.FRIEND)


func _copy_healed(d: Dictionary):
	var m = Mon.from_dict(d)
	m.heal_full()
	return m


func start_pvp(pdicts: Array) -> void:
	if state == State.BATTLE or party.is_empty() or pdicts.is_empty():
		coop.send({"t": "forfeit"})
		return
	dlg.clear()
	dlg_text = ""
	choice = []
	pvp_ret = State.FIELD if field.active and state in [State.FIELD, State.MENU, State.FRIEND] else State.TOWN
	var mine: Array = party.map(func(m): return _copy_healed(m.to_dict()))
	var foes: Array = pdicts.map(func(d): return _copy_healed(d))
	field.lock = true
	sfx.play("encounter", -6.0)
	set_state(State.BATTLE)
	battle.start("pvp", foes, "친구", mine)


func open_trade() -> void:
	dlg.clear()
	dlg_text = ""
	choice = []
	trade_ret = State.FIELD if field.active and state in [State.FIELD, State.MENU, State.FRIEND] else State.TOWN
	set_state(State.TRADE)


func close_trade(msg: String) -> void:
	if state != State.TRADE:
		return
	set_state(trade_ret)
	field.lock = false
	say([msg], "")


func on_partner_left() -> void:
	show_toast("친구와 연결이 끊겼어요")
	pending_stage = []
	if state == State.BATTLE and battle.pvp:
		battle.pvp_foe_left()
	elif state == State.TRADE:
		close_trade("친구와 연결이 끊겼다.")
	elif state == State.FRIEND:
		set_state(State.FIELD)


func go_town() -> void:
	field.active = false
	field.lock = false
	set_state(State.TOWN)
	save_game()


# ------------------------------------------------------------------ 진화

func _check_evolutions(then: Callable) -> void:
	evo_queue = party.filter(func(m): return not m.fainted() and m.evo_target() != "")
	after_evo = then
	_next_evo()


func _next_evo() -> void:
	if evo_queue.is_empty():
		evo_mon = null
		var cb := after_evo
		cb.call()
		return
	evo_mon = evo_queue.pop_front()
	evo_to = evo_mon.evo_target()
	set_state(State.EVOLVE)
	evo_t = -1.0
	evo_choose = false
	if evo_to == "*eeveelution":
		say(["어라...? %s의 모습이...!" % evo_mon.name(), "이브이가 어떤 모습으로 진화할지 골라 주세요!"], "", func(): evo_choose = true)
	else:
		say(["어라...? %s의 모습이...!" % evo_mon.name()], "", _evo_anim)


func choose_eeveelution(i: int) -> void:
	if not evo_choose:
		return
	evo_choose = false
	evo_to = Data.EEVEELUTIONS[i]
	_evo_anim()


func _evo_anim() -> void:
	evo_t = 0.0
	sfx.play("heal", -4.0, 0.7)


func _evo_done() -> void:
	evo_t = -1.0
	var old: String = evo_mon.name()
	evo_mon.evolve(evo_to)
	sfx.play("levelup", -2.0)
	voice.cry(evo_mon.name())
	print("[evolve] ", old, " -> ", evo_mon.name())
	say(["축하합니다! %s(은)는 %s(으)로 진화했다!" % [old, evo_mon.name()]], "", _next_evo)


# ------------------------------------------------------------------ 갱신

func _process(delta: float) -> void:
	t += delta
	if dlg_text != "":
		dlg_shown += delta * (60.0 if autoplay else 28.0)
	toast_t = max(toast_t - delta, 0.0)
	if trans_t > 0.0:
		trans_t -= delta
		if trans_t <= 0.0:
			_begin_battle()
	if state == State.FIELD or state == State.MENU or state == State.FRIEND:
		field.update(delta, bot_dir if not dlg_busy() and trans_t <= 0.0 else -1)
	if not pending_stage.is_empty() and _can_follow():
		var ps := pending_stage
		pending_stage = []
		start_stage(ps[0], ps[1])
		say(["친구가 스테이지 %d(으)로 출발했다! 같이 가자!" % ps[0]], "")
	if evo_t >= 0.0:
		evo_t += delta
		if evo_t >= 3.0:
			_evo_done()
	ui.queue_redraw()


func _begin_battle() -> void:
	var b := pending_battle
	pending_battle = []
	if b.is_empty():
		return
	set_state(State.BATTLE)
	battle.start(b[0], b[1], b[2])


# ------------------------------------------------------------------ 입력

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if state == State.LOBBY and event.keycode >= KEY_0 and event.keycode <= KEY_9:
			press("key:%d" % (event.keycode - KEY_0))
			return
		if state == State.LOBBY and event.keycode == KEY_BACKSPACE:
			press("key:지우기")
			return
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_Z]:
			if dlg_busy():
				advance()
			elif state == State.BATTLE:
				battle.advance()
			elif state == State.TITLE:
				press("start")
		return
	if not (event is InputEventScreenTouch and event.pressed):
		return
	tap(event.position)


func tap(p: Vector2) -> void:
	if trans_t > 0.0:
		return
	if not choice.is_empty():
		var rs := choice_rects()
		for i in rs.size():
			if rs[i].has_point(p):
				sfx.play("select", -10.0)
				pick_choice(i)
				return
		return
	if dlg_text != "":
		advance()
		return
	if state == State.BATTLE:
		battle.tap(p)
		return
	if state == State.FIELD:
		return  # 필드는 field.gd가 직접 처리
	for b in buttons():
		if b.rect.has_point(p):
			press(b.id)
			return


func buttons() -> Array:
	var out: Array = []
	var v := view
	var bw := v.x - 48
	match state:
		State.TITLE:
			if started:
				out.append(_b("continue", Rect2(24, v.y - 200, bw, 52), "이어하기", Color("e53935")))
				out.append(_b("new", Rect2(24, v.y - 136, bw, 44), "처음부터 시작", Color("546e7a")))
			else:
				out.append(_b("start", Rect2(24, v.y - 180, bw, 56), "모험 시작!", Color("e53935")))
		State.CHAR:
			out.append(_b("char_m", Rect2(16, 120, v.x * 0.5 - 24, 300), "", Color(0, 0, 0, 0)))
			out.append(_b("char_f", Rect2(v.x * 0.5 + 8, 120, v.x * 0.5 - 24, 300), "", Color(0, 0, 0, 0)))
			if char_pick != "":
				out.append(_b("char_ok", Rect2(24, v.y - 130, bw, 52), "이 캐릭터로 결정!", Color("43a047")))
		State.STARTER:
			for i in 5:
				out.append(_b("starter:%d" % i, _starter_rect(i), "", Color(0, 0, 0, 0)))
			if starter_pick >= 0:
				out.append(_b("starter_ok", Rect2(24, v.y - 100, bw, 48), "이 포켓몬으로 할래!", Color("43a047")))
		State.TOWN:
			var labels := [["adventure", "모험 떠나기", Color("e53935")], ["center", "포켓몬센터", Color("ec407a")], ["shop", "프렌들리숍", Color("1e88e5")],
				["party", "포켓몬", Color("43a047")], ["bag", "가방", Color("fb8c00")],
				["coop", "친구와 함께" if coop.connected() else "같이 하기", Color("f9a825")], ["voice", "음성: " + ("켜짐" if voice.enabled else "꺼짐"), Color("607d8b")]]
			out.append(_b(labels[0][0], Rect2(16, v.y - 262, v.x - 32, 56), labels[0][1], labels[0][2]))
			for i in range(1, 7):
				var k := i - 1
				out.append(_b(labels[i][0], Rect2(16 + (k % 2) * (v.x * 0.5 - 8), v.y - 198 + (k / 2) * 52, v.x * 0.5 - 24, 46), labels[i][1], labels[i][2]))
		State.SHOP:
			for i in Data.SHOP_ORDER.size():
				var it: String = Data.SHOP_ORDER[i]
				out.append(_b("buy:" + it, Rect2(v.x - 104, 112 + i * 70, 88, 30), "1개 사기", Color("43a047")))
				out.append(_b("buy5:" + it, Rect2(v.x - 104, 146 + i * 70, 88, 26), "5개 사기", Color("2e7d32")))
			out.append(_b("back", Rect2(16, v.y - 72, bw + 16, 52), "나가기", Color("546e7a")))
		State.CENTER:
			out.append(_b("heal", Rect2(24, v.y - 200, bw, 56), "회복시켜 주세요", Color("ec407a")))
			out.append(_b("back", Rect2(24, v.y - 130, bw, 48), "나가기", Color("546e7a")))
		State.PARTY:
			for i in party.size():
				out.append(_b("p:%d" % i, Rect2(8, 56 + i * 50, v.x - 16, 46), "", Color(0, 0, 0, 0)))
			var by := 56 + 6 * 50 + 30
			for i in box.size():
				if i >= 24:
					break
				out.append(_b("x:%d" % i, Rect2(8 + (i % 6) * ((v.x - 16) / 6.0), by + (i / 6) * 50, (v.x - 16) / 6.0 - 4, 46), "", Color(0, 0, 0, 0)))
			out.append(_b("back", Rect2(v.x - 84, 12, 72, 30), "닫기", Color("546e7a")))
		State.BAG:
			if bag_potion:
				for i in party.size():
					out.append(_b("p:%d" % i, Rect2(8, 96 + i * 50, v.x - 16, 46), "", Color(0, 0, 0, 0)))
			else:
				out.append(_b("use_potion", Rect2(v.x - 104, 70 + 4 * 52 + 8, 88, 34), "사용", Color("ab47bc")))
			out.append(_b("back", Rect2(v.x - 84, 12, 72, 30), "닫기", Color("546e7a")))
		State.STAGES:
			var cy := 230.0
			var dx := [-10, -1, 1, 10]
			var lab := ["-10", "-1", "+1", "+10"]
			for i in 4:
				out.append(_b("st:%d" % dx[i], Rect2(16 + i * (v.x - 32) / 4.0, cy, (v.x - 32) / 4.0 - 6, 44), lab[i], Color("455a64")))
			out.append(_b("st_best", Rect2(16, cy + 54, v.x * 0.5 - 22, 38), "최고 기록+1", Color("8e24aa")))
			out.append(_b("st_one", Rect2(v.x * 0.5 + 6, cy + 54, v.x * 0.5 - 22, 38), "처음(1)", Color("8e24aa")))
			out.append(_b("go", Rect2(24, v.y - 150, bw, 56), "출발!", Color("e53935")))
			out.append(_b("back", Rect2(24, v.y - 84, bw, 44), "마을로", Color("546e7a")))
		State.MENU:
			var labels2 := [["party", "포켓몬"], ["bag", "가방"], ["town", "마을로 돌아가기"], ["close", "닫기"]]
			for i in 4:
				out.append(_b(labels2[i][0], Rect2(v.x - 200, 48 + i * 50, 188, 44), labels2[i][1], Color("37474f") if i < 3 else Color("546e7a")))
		State.LOBBY:
			if coop.connected():
				out.append(_b("req_battle", Rect2(24, 330, bw, 52), "대전 신청", Color("e53935")))
				out.append(_b("req_trade", Rect2(24, 392, bw, 52), "교환 신청", Color("1e88e5")))
				out.append(_b("leave", Rect2(24, 454, bw, 44), "연결 끊기", Color("6d4c41")))
			elif coop.net.status == "hosting" or coop.net.status == "connecting":
				out.append(_b("leave", Rect2(24, v.y - 150, bw, 48), "취소", Color("6d4c41")))
			else:
				out.append(_b("host", Rect2(24, 150, bw, 52), "방 만들기", Color("e53935")))
				var keys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "지우기", "0", "참가"]
				var kw := (v.x - 48 - 16) / 3.0
				for i in 12:
					var col := Color("455a64")
					if keys[i] == "참가":
						col = Color("43a047") if coop.code_input.length() == 4 else Color("9e9e9e")
					out.append(_b("key:" + keys[i], Rect2(24 + (i % 3) * (kw + 8), 330 + (i / 3) * 52, kw, 46), keys[i], col))
			out.append(_b("back", Rect2(v.x - 84, 12, 72, 30), "뒤로", Color("546e7a")))
		State.FRIEND:
			var labels3 := [["req_battle", "대전 신청"], ["req_trade", "교환 신청"], ["close", "닫기"]]
			for i in 3:
				out.append(_b(labels3[i][0], Rect2(v.x - 200, 48 + i * 50, 188, 44), labels3[i][1], Color("f57f17") if i < 2 else Color("546e7a")))
		State.TRADE:
			for i in party.size():
				out.append(_b("p:%d" % i, Rect2(8, 80 + i * 50, v.x * 0.5 - 12, 46), "", Color(0, 0, 0, 0)))
			if coop.my_offer >= 0 and coop.their_offer != null and not coop.my_ok:
				out.append(_b("trade_ok", Rect2(24, v.y - 130, bw, 52), "교환하기!", Color("43a047")))
			out.append(_b("trade_cancel", Rect2(24, v.y - 68, bw, 44), "그만두기", Color("6d4c41")))
		State.EVOLVE:
			if evo_choose:
				for i in 3:
					out.append(_b("evo:%d" % i, Rect2(12 + i * (v.x - 24) / 3.0, 300, (v.x - 24) / 3.0 - 8, 120), "", Color(0, 0, 0, 0)))
	return out


func _b(id: String, r: Rect2, label: String, col: Color) -> Dictionary:
	return {"id": id, "rect": r, "label": label, "col": col}


func _starter_rect(i: int) -> Rect2:
	var y := 300.0 if i < 3 else 360.0
	var x := view.x * 0.5 + (i - 1) * 90.0 if i < 3 else view.x * 0.5 + (i - 3.5) * 90.0
	return Rect2(x - 32, y - 28, 64, 56)


func press(id: String) -> void:
	sfx.play("select", -10.0)
	match id:
		"start", "new":
			new_game()
			char_pick = ""
			set_state(State.CHAR)
			say(["먼저 너는 남자니? 여자니?", "캐릭터를 골라 주세요!"], "")
		"continue":
			go_town()
			say(["다시 만나서 반갑다! 모험을 계속하거라!"], "oak")
		"char_m", "char_f":
			char_pick = id.substr(5)
			var line := "나는 남자 트레이너! 최고의 포켓몬 마스터가 될 거야!" if char_pick == "m" else "나는 여자 트레이너! 포켓몬들이랑 꼭 최고가 될 거야!"
			voice.speak(line, char_pick)
			show_toast(line)
		"char_ok":
			character = char_pick
			set_state(State.OAK)
			say(Data.LINES.oak, "oak", func(): set_state(State.STARTER))
		"starter_ok":
			var sp: String = Data.STARTERS[starter_pick]
			var m = Mon.create(sp, 5)
			party = [m]
			items["pokeball"] = items.get("pokeball", 0) + 5
			started = true
			save_game()
			voice.cry(m.name())
			say(["%s(을)를 받았다!" % m.name()], "")
			say(Data.LINES.oak_after, "oak", func(): go_town())
		"adventure":
			set_state(State.STAGES)
		"center":
			set_state(State.CENTER)
			say(["포켓몬센터에 어서 오세요! 포켓몬을 회복시켜 드릴까요?"], "f")
		"heal":
			heal_all()
			sfx.play("heal", -4.0)
			save_game()
			say(["맡기신 포켓몬은 모두 건강해졌어요!", "또 오세요!"], "f")
		"shop":
			set_state(State.SHOP)
			say(["어서 오세요! 몬스터볼은 공짜랍니다!"], "f")
		"party":
			ret_state = State.TOWN if state == State.TOWN else State.MENU
			party_sel = -1
			set_state(State.PARTY)
		"bag":
			ret_state = State.TOWN if state == State.TOWN else State.MENU
			bag_potion = false
			set_state(State.BAG)
		"voice":
			voice.enabled = not voice.enabled
			save_game()
			if voice.enabled:
				voice.speak("음성을 켰어요!", character)
		"back":
			if state == State.LOBBY:
				set_state(State.TOWN)
			elif state == State.BAG and bag_potion:
				bag_potion = false
			elif state == State.PARTY or state == State.BAG:
				set_state(ret_state)
			else:
				go_town()
		"use_potion":
			if items.get("potion", 0) > 0:
				bag_potion = true
			else:
				show_toast("상처약이 없다!")
		"go":
			start_stage(stage)
		"st_best":
			stage = best_stage + 1
		"st_one":
			stage = 1
		"town":
			go_town()
		"close":
			set_state(State.FIELD)
		"coop":
			set_state(State.LOBBY)
		"host":
			coop.host_room()
		"leave":
			coop.leave()
		"req_battle":
			coop.request("battle")
			if state == State.FRIEND:
				set_state(State.FIELD)
		"req_trade":
			coop.request("trade")
			if state == State.FRIEND:
				set_state(State.FIELD)
		"trade_ok":
			coop.trade_ok()
		"trade_cancel":
			coop.trade_cancel()
		_:
			if id.begins_with("starter:"):
				starter_pick = int(id.substr(8))
				voice.cry(Data.MONS[Data.STARTERS[starter_pick]].name)
			elif id.begins_with("buy:") or id.begins_with("buy5:"):
				var n := 5 if id.begins_with("buy5:") else 1
				_buy(id.substr(id.find(":") + 1), n)
			elif id.begins_with("st:"):
				stage = clampi(stage + int(id.substr(3)), 1, 9999)
			elif id.begins_with("key:"):
				var k := id.substr(4)
				if k == "지우기":
					coop.code_input = coop.code_input.substr(0, max(coop.code_input.length() - 1, 0))
				elif k == "참가":
					if coop.code_input.length() == 4:
						coop.join_room(coop.code_input)
				elif coop.code_input.length() < 4:
					coop.code_input += k
			elif id.begins_with("p:") and state == State.TRADE:
				coop.offer(int(id.substr(2)))
			elif id.begins_with("p:"):
				_party_tap(int(id.substr(2)))
			elif id.begins_with("x:"):
				_party_tap(100 + int(id.substr(2)))
			elif id.begins_with("evo:"):
				choose_eeveelution(int(id.substr(4)))


func _buy(it: String, n: int) -> void:
	var price: int = Data.ITEMS[it].price * n
	if money < price:
		show_toast("돈이 모자라요!")
		return
	money -= price
	items[it] = items.get(it, 0) + n
	sfx.play("coin", -6.0)
	show_toast("%s %d개를 샀다!" % [Data.ITEMS[it].name, n])
	save_game()


func _party_tap(i: int) -> void:
	if state == State.BAG:
		var m = party[i]
		if m.fainted() or m.hp >= m.max_hp():
			show_toast("지금은 쓸 수 없다!")
			return
		items.potion -= 1
		m.hp = min(m.max_hp(), m.hp + Data.ITEMS.potion.heal)
		sfx.play("heal", -6.0)
		show_toast("%s의 HP가 회복되었다!" % m.name())
		bag_potion = false
		save_game()
		return
	if party_sel < 0:
		party_sel = i
		return
	if party_sel == i:
		party_sel = -1
		return
	# 두 칸 바꾸기 (파티↔파티, 파티↔박스)
	var a := party_sel
	var b := i
	party_sel = -1
	if a >= 100 and b >= 100:
		return
	if a >= 100:
		var tmp := a
		a = b
		b = tmp
	if b >= 100:
		var bi := b - 100
		var pm = party[a]
		party[a] = box[bi]
		box[bi] = pm
	else:
		var tmp2 = party[a]
		party[a] = party[b]
		party[b] = tmp2
	sfx.play("pickup", -8.0)
	save_game()


# ------------------------------------------------------------------ 그리기

func _txt(p: Vector2, s: String, size := 11, col := Color("303030"), align := HORIZONTAL_ALIGNMENT_LEFT, w := -1.0) -> void:
	ui.draw_string(font, p, s, align, w, size, col)


func _ctxt(y: float, s: String, size := 11, col := Color("303030")) -> void:
	ui.draw_string(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, view.x, size, col)


func _panel(r: Rect2, col := Color("f8f8f8"), edge := Color("303030")) -> void:
	ui.draw_rect(r, col)
	ui.draw_rect(r, edge, false, 2.0)


func _button(b: Dictionary) -> void:
	if b.label == "":
		return
	var r: Rect2 = b.rect
	ui.draw_rect(r, b.col)
	ui.draw_rect(r, Color("202020"), false, 2.0)
	ui.draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, 3)), Color(1, 1, 1, 0.3))
	var fs := 22 if r.size.y >= 44 else 11
	ui.draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + fs * 0.4), b.label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Color.WHITE)


func _hp_bar(p: Vector2, w: float, m) -> void:
	var k: float = float(m.hp) / m.max_hp()
	ui.draw_rect(Rect2(p - Vector2(1, 1), Vector2(w + 2, 7)), Color("303030"))
	ui.draw_rect(Rect2(p, Vector2(w * k, 5)), Color("48c048") if k > 0.5 else (Color("f8c020") if k > 0.2 else Color("e83020")))


func _mon_row(r: Rect2, m, hl: bool) -> void:
	_panel(r, Color("ffe082") if hl else (Color("e0e0e0") if m.fainted() else Color("f8f8f8")))
	spr.mon(ui, m.id, r.position + Vector2(28, r.size.y), 1)
	_txt(r.position + Vector2(56, 18), m.name())
	_txt(r.position + Vector2(140, 18), "Lv%d" % m.level)
	var tx := 190.0
	for ty in m.types():
		var tr := Rect2(r.position + Vector2(tx, 6), Vector2(40, 15))
		ui.draw_rect(tr, Data.TYPES[ty].col)
		_txt(tr.position + Vector2(0, 12), Data.TYPES[ty].name, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 40)
		tx += 44
	_hp_bar(r.position + Vector2(56, 28), 150, m)
	_txt(r.position + Vector2(214, 38), "%d/%d" % [m.hp, m.max_hp()] if not m.fainted() else "기절")


func _draw_ui() -> void:
	var v := view
	match state:
		State.TITLE: _draw_title()
		State.CHAR: _draw_char()
		State.OAK, State.STARTER: _draw_lab()
		State.TOWN, State.CENTER, State.SHOP: _draw_town()
		State.PARTY: _draw_party()
		State.BAG: _draw_bag()
		State.STAGES: _draw_stages()
		State.MENU:
			ui.draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.35))
			_panel(Rect2(v.x - 208, 40, 204, 212))
			_txt(Vector2(16, 30), "돈 %d원" % money, 11, Color.WHITE)
		State.EVOLVE: _draw_evolve()
		State.LOBBY: _draw_lobby()
		State.TRADE: _draw_trade()
		State.FRIEND:
			ui.draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.35))
			_panel(Rect2(v.x - 208, 40, 204, 162))
	if state == State.SHOP:
		_draw_shop()
	for b in buttons():
		_button(b)
	if trans_t > 0.0:
		var k := int(trans_t * 12.0) % 2
		ui.draw_rect(Rect2(Vector2.ZERO, v), Color(0, 0, 0, 0.85) if k == 0 else Color(1, 1, 1, 0.6))
	if toast_t > 0.0:
		var tw := font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 24
		var tr := Rect2((v.x - tw) * 0.5, 52, tw, 26)
		ui.draw_rect(tr, Color(0, 0, 0, 0.75 * min(1.0, toast_t * 3.0)))
		_txt(tr.position + Vector2(0, 17), toast, 11, Color(1, 1, 1, min(1.0, toast_t * 3.0)), HORIZONTAL_ALIGNMENT_CENTER, tw)
	if dlg_text != "":
		_draw_dialog()
	for i in choice.size():
		var r: Rect2 = choice_rects()[i]
		_panel(r, Color("fafafa"), Color("3060a0"))
		_txt(r.position + Vector2(0, 24), choice[i], 11, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_dialog() -> void:
	var r := Rect2(6, view.y - 160, view.x - 12, 96)
	ui.draw_rect(r, Color("f8f8f8"))
	ui.draw_rect(r, Color("3060a0"), false, 3.0)
	ui.draw_rect(r.grow(-4), Color("303030"), false, 1.0)
	var s := dlg_text.substr(0, int(dlg_shown))
	ui.draw_multiline_string(font, r.position + Vector2(14, 28), s, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 11, 4, Color("303030"))
	if dlg_shown >= dlg_text.length() and choice.is_empty() and int(t * 3.0) % 2 == 0:
		ui.draw_colored_polygon(PackedVector2Array([r.end - Vector2(20, 16), r.end - Vector2(10, 16), r.end - Vector2(15, 10)]), Color("e53935"))


func _draw_title() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("78c8f0"))
	ui.draw_rect(Rect2(0, v.y * 0.55, v.x, v.y * 0.45), Color("7cc576"))
	for i in 5:
		var cx := fmod(i * 97.0 + t * 8.0, v.x + 80) - 40
		ui.draw_circle(Vector2(cx, 80 + i * 23 % 60), 16, Color.WHITE)
		ui.draw_circle(Vector2(cx + 16, 84 + i * 23 % 60), 12, Color.WHITE)
	_ctxt(150, "포켓몬 모험", 44, Color("1a3f8f"))
	_ctxt(148, "포켓몬 모험", 44, Color("ffcb05"))
	_ctxt(180, "~ 끝없는 스테이지 ~", 11, Color("1a3f8f"))
	var bob := sin(t * 3.0) * 3.0
	spr.mon(ui, "pikachu", Vector2(v.x * 0.5 - 70, v.y * 0.55 + 40 + bob), 3)
	spr.mon(ui, "charmander", Vector2(v.x * 0.5 + 76, v.y * 0.55 + 40 - bob), 3)
	spr.ball(ui, "pokeball", Vector2(v.x * 0.5 + 4, v.y * 0.55 - 40 + bob * 2.0), 2)
	if int(t * 2.0) % 2 == 0:
		_ctxt(v.y - 220, "버튼을 눌러 시작하세요", 11, Color("1b3a1b"))


func _draw_char() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("fff3e0"))
	_ctxt(70, "캐릭터를 고르세요", 22)
	var opts := [["m", "남자", 0.0], ["f", "여자", v.x * 0.5 - 8]]
	for o in opts:
		var r := Rect2(16 + o[2], 120, v.x * 0.5 - 24, 300)
		var sel: bool = char_pick == o[0]
		_panel(r, Color("bbdefb") if o[0] == "m" else Color("f8bbd0"), Color("e53935") if sel else Color("303030"))
		if sel:
			ui.draw_rect(r.grow(-4), Color("e53935"), false, 2.0)
		var bob := sin(t * 5.0) * 3.0 if sel else 0.0
		spr.person(ui, spr.walker_key(o[0], 0, int(t * 4.0) if sel else 0), r.position + Vector2(r.size.x * 0.5, 240), 8)
		_txt(r.position + Vector2(0, 274), o[1], 22, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _draw_lab() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("e8e0d0"))
	for y in range(0, int(v.y), 32):
		for x in range(0, int(v.x), 32):
			if (x / 32 + y / 32) % 2 == 0:
				ui.draw_rect(Rect2(x, y, 32, 32), Color("ddd3c0"))
	ui.draw_rect(Rect2(0, 0, v.x, 90), Color("a1887f"))
	ui.draw_rect(Rect2(20, 20, 70, 50), Color("90caf9"))
	ui.draw_rect(Rect2(v.x - 90, 20, 70, 50), Color("90caf9"))
	_ctxt(54, "오박사 연구소", 22, Color.WHITE)
	if state == State.OAK:
		spr.person(ui, "oak", Vector2(v.x * 0.5, 330), 8)
		spr.person(ui, spr.walker_key(character, 2, 0), Vector2(v.x * 0.5 + 110, 430), 5)
		return
	# 테이블 위 몬스터볼 5개
	ui.draw_rect(Rect2(24, 260, v.x - 48, 140), Color("8d6e63"))
	ui.draw_rect(Rect2(24, 260, v.x - 48, 140), Color("4e342e"), false, 2.0)
	if starter_pick < 0:
		spr.person(ui, "oak", Vector2(v.x * 0.5, 256), 4)
	for i in 5:
		var r := _starter_rect(i)
		var c := r.get_center()
		var sel := starter_pick == i
		spr.ball(ui, "pokeball", c + Vector2(0, -6.0 + (round(sin(t * 8.0) * 2.0) * 2.0 if sel else 0.0)), 2)
		if sel:
			ui.draw_rect(r, Color("ffeb3b"), false, 2.0)
	if starter_pick >= 0:
		var sp: String = Data.STARTERS[starter_pick]
		var d: Dictionary = Data.MONS[sp]
		_panel(Rect2(24, 100, v.x - 48, 140), Color("fffde7"))
		spr.mon(ui, sp, Vector2(90, 228), 2)
		_txt(Vector2(160, 140), d.name, 22)
		var tx := 160.0
		for ty in d.types:
			ui.draw_rect(Rect2(tx, 152, 50, 18), Data.TYPES[ty].col)
			_txt(Vector2(tx, 166), Data.TYPES[ty].name + " 타입", 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 50)
			tx += 56
		var desc := {"pikachu": "전기 쥐 포켓몬", "eevee": "진화 포켓몬. 세 가지로 진화!", "squirtle": "꼬마거북 포켓몬", "bulbasaur": "씨앗 포켓몬", "charmander": "도롱뇽 포켓몬"}
		_txt(Vector2(160, 196), desc.get(sp, ""), 11)
	else:
		_ctxt(150, "몬스터볼을 눌러 보세요!", 22, Color("5d4037"))
		var names := ""
		for sp in Data.STARTERS:
			names += Data.MONS[sp].name + "  "
		_ctxt(190, names.strip_edges(), 11, Color("5d4037"))


func _draw_town() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("8fd3f5"))
	ui.draw_rect(Rect2(0, 230, v.x, v.y - 230), Color("7cc576"))
	ui.draw_rect(Rect2(v.x * 0.5 - 14, 230, 28, v.y), Color("e6d3a3"))
	# 건물: 포켓몬센터 / 숍 / 연구소
	_house(Vector2(18, 120), Color("e53935"), "P", "센터")
	_house(Vector2(v.x - 128, 120), Color("1e88e5"), "M", "숍")
	_txt(Vector2(12, 26), "마을", 22, Color("1a3f8f"))
	_panel(Rect2(v.x - 150, 8, 142, 50), Color("fffde7"))
	_txt(Vector2(v.x - 142, 28), "돈  %d원" % money)
	_txt(Vector2(v.x - 142, 48), "배지  %d개" % best_stage)
	spr.person(ui, spr.walker_key(character, 0, 0), Vector2(v.x * 0.5, 324), 4)
	if coop.connected():
		spr.person(ui, spr.walker_key(coop.p_char + "2", 0, 0), Vector2(v.x * 0.5 - 70, 324), 4)
		_txt(Vector2(v.x * 0.5 - 100, 254), "친구", 11, Color("e65100"), HORIZONTAL_ALIGNMENT_CENTER, 60)
	for i in party.size():
		var px := v.x * 0.5 + (i - (party.size() - 1) * 0.5) * 50.0 + (40.0 if party.size() == 1 else 0.0)
		spr.mon(ui, party[i].id, Vector2(px, 372), 1)
	if state == State.CENTER:
		ui.draw_rect(Rect2(Vector2.ZERO, v), Color(1, 0.92, 0.95, 0.92))
		_ctxt(80, "포켓몬센터", 22, Color("c2185b"))
		spr.person(ui, "nurse_0_0", Vector2(v.x * 0.5, 240), 6)
		for i in party.size():
			var m = party[i]
			spr.ball(ui, "pokeball", Vector2(v.x * 0.5 - 75 + i * 30, 270), 1)
			_hp_bar(Vector2(v.x * 0.5 - 87 + i * 30, 284), 24, m)


func _house(p: Vector2, roof: Color, mark: String, label: String) -> void:
	ui.draw_rect(Rect2(p + Vector2(0, 36), Vector2(110, 70)), Color("fafafa"))
	ui.draw_rect(Rect2(p + Vector2(0, 36), Vector2(110, 70)), Color("303030"), false, 2.0)
	ui.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 40), p + Vector2(55, 0), p + Vector2(118, 40)]), roof)
	ui.draw_rect(Rect2(p + Vector2(42, 72), Vector2(26, 34)), Color("5d4037"))
	ui.draw_rect(Rect2(p + Vector2(42, 42), Vector2(26, 22)), roof)
	_txt(p + Vector2(42, 60), mark, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 26)
	_txt(p + Vector2(0, 122), label, 11, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, 110)


func _draw_shop() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("e3f2fd"))
	_ctxt(44, "프렌들리숍", 22, Color("1565c0"))
	_panel(Rect2(16, 60, v.x - 32, 36), Color("fffde7"))
	_txt(Vector2(28, 84), "가진 돈: %d원" % money, 11)
	for i in Data.SHOP_ORDER.size():
		var it: String = Data.SHOP_ORDER[i]
		var d: Dictionary = Data.ITEMS[it]
		var r := Rect2(16, 106 + i * 70, v.x - 32, 66)
		_panel(r)
		if Data.BALLS.has(it):
			spr.ball(ui, it, r.position + Vector2(26, 33), 2)
		else:
			ui.draw_rect(Rect2(r.position + Vector2(16, 18), Vector2(20, 30)), d.col)
			ui.draw_rect(Rect2(r.position + Vector2(20, 12), Vector2(12, 8)), Color("9e9e9e"))
		_txt(r.position + Vector2(50, 22), d.name, 11)
		_txt(r.position + Vector2(50, 40), "무료!" if d.price == 0 else "%d원" % d.price, 11, Color("e53935") if d.price == 0 else Color("1565c0"))
		_txt(r.position + Vector2(50, 58), d.desc + "  (가진 수 %d)" % items.get(it, 0), 11, Color("616161"))


func _draw_party() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("e8f5e9"))
	_txt(Vector2(12, 34), "포켓몬", 22)
	for i in party.size():
		_mon_row(Rect2(8, 56 + i * 50, v.x - 16, 46), party[i], party_sel == i)
	var by := 56 + 6 * 50 + 30
	_txt(Vector2(12, by - 8), "박스 (%d마리)  - 두 칸을 차례로 누르면 자리를 바꿔요" % box.size(), 11)
	for i in min(box.size(), 24):
		var r := Rect2(8 + (i % 6) * ((v.x - 16) / 6.0), by + (i / 6) * 50, (v.x - 16) / 6.0 - 4, 46)
		_panel(r, Color("ffe082") if party_sel == 100 + i else Color("fafafa"))
		spr.mon(ui, box[i].id, r.position + Vector2(r.size.x * 0.5, 40), 1)
		_txt(r.position + Vector2(2, 44), "Lv%d" % box[i].level, 11)


func _draw_bag() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("fff3e0"))
	_txt(Vector2(12, 34), "가방", 22)
	if bag_potion:
		_txt(Vector2(12, 80), "누구에게 상처약을 쓸까? (남은 %d개)" % items.get("potion", 0), 11)
		for i in party.size():
			_mon_row(Rect2(8, 96 + i * 50, v.x - 16, 46), party[i], false)
		return
	for i in Data.SHOP_ORDER.size():
		var it: String = Data.SHOP_ORDER[i]
		var r := Rect2(8, 70 + i * 52, v.x - 16, 46)
		_panel(r)
		if Data.BALLS.has(it):
			spr.ball(ui, it, r.position + Vector2(22, 23), 2)
		else:
			ui.draw_rect(Rect2(r.position + Vector2(14, 10), Vector2(16, 26)), Data.ITEMS[it].col)
		_txt(r.position + Vector2(44, 20), Data.ITEMS[it].name, 11)
		_txt(r.position + Vector2(44, 38), Data.ITEMS[it].desc, 11, Color("757575"))
		_txt(r.position + Vector2(v.x - 130, 28), "x %d" % items.get(it, 0), 22)
	_txt(Vector2(16, v.y - 40), "돈: %d원" % money, 11)


func _draw_stages() -> void:
	var v := view
	var a: Dictionary = Data.area(stage)
	ui.draw_rect(Rect2(Vector2.ZERO, v), a.ground.lightened(0.3))
	_ctxt(40, "스테이지 선택", 22)
	_ctxt(62, "원하는 스테이지를 골라서 가요 (끝없이 계속!)", 11, Color("424242"))
	_panel(Rect2(24, 76, v.x - 48, 144), Color("fffde7"))
	_ctxt(124, "스테이지 %d" % stage, 44, Color("c62828"))
	_ctxt(150, a.name, 22, Color("2e7d32"))
	var lv := Data.wild_level(stage)
	_ctxt(176, "야생 포켓몬 Lv%d 정도 / 관장 Lv%d" % [lv, lv + 3], 11)
	var cleared := "클리어함!" if stage <= best_stage else ("도전!" if stage == best_stage + 1 else "아직 안 가 본 곳")
	_ctxt(200, "최고 기록: 스테이지 %d   %s" % [best_stage, cleared], 11, Color("6a1b9a"))
	# 나오는 포켓몬
	var pool: Array = a.pool
	_ctxt(350, "나오는 포켓몬", 11)
	for i in pool.size():
		var x: float = v.x * 0.5 + (i - (pool.size() - 1) * 0.5) * 60.0
		spr.mon(ui, pool[i], Vector2(x, 412), 1)
		_txt(Vector2(x - 30, 426), Data.MONS[pool[i]].name, 11, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, 60)
	var my = first_healthy()
	if my != null and my.level + 3 < lv:
		_ctxt(456, "※ 내 포켓몬보다 많이 강할 수 있어요!", 11, Color("c62828"))


func _draw_lobby() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("fff8e1"))
	_txt(Vector2(12, 34), "같이 하기", 22, Color("e65100"))
	var st: String = coop.net.status
	if not coop.net.available:
		_ctxt(80, "같이 하기는 웹(브라우저)에서만 돼요", 11, Color("c62828"))
	if coop.connected():
		_ctxt(80, "친구와 연결됐어요!  (방 코드 %s)" % coop.code, 11, Color("2e7d32"))
		spr.person(ui, spr.walker_key(character, 0, 0), Vector2(v.x * 0.5 - 70, 200), 5)
		spr.person(ui, spr.walker_key(coop.p_char + "2", 0, 0), Vector2(v.x * 0.5 + 70, 200), 5)
		_txt(Vector2(v.x * 0.5 - 110, 218), "나", 11, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, 80)
		_txt(Vector2(v.x * 0.5 + 30, 218), "친구", 11, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, 80)
		for i in coop.p_party.size():
			var d: Dictionary = coop.p_party[i]
			spr.mon(ui, d.id, Vector2(v.x * 0.5 - (coop.p_party.size() - 1) * 26 + i * 52, 290), 1)
			_txt(Vector2(v.x * 0.5 - (coop.p_party.size() - 1) * 26 + i * 52 - 26, 306), "Lv%d" % int(d.lv), 11, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, 52)
		_ctxt(520, "모험을 떠나면 친구도 같은 스테이지로 따라와요!", 11, Color("5d4037"))
		_ctxt(538, "필드에서도 [친구] 버튼으로 대전/교환을 할 수 있어요", 11, Color("5d4037"))
		return
	if st == "hosting":
		_ctxt(150, "방을 만들었어요! 친구에게 코드를 알려 주세요", 11)
		_panel(Rect2(60, 180, v.x - 120, 100), Color("ffecb3"))
		_ctxt(250, coop.code, 44, Color("e65100"))
		if int(t * 2.0) % 2 == 0:
			_ctxt(320, "친구를 기다리는 중...", 11)
		return
	if st == "connecting":
		_ctxt(250, "연결하는 중...", 22)
		return
	_ctxt(80, "방을 만들거나, 친구 방 코드 4자리를 넣고 참가하세요", 11)
	if st == "error":
		_ctxt(110, "연결 실패: %s  (코드를 확인하고 다시 해 보세요)" % coop.net.error, 11, Color("c62828"))
	_panel(Rect2(60, 230, v.x - 120, 76), Color("eceff1"))
	for i in 4:
		var ch: String = coop.code_input[i] if i < coop.code_input.length() else "_"
		_txt(Vector2(80 + i * (v.x - 160) / 4.0, 286), ch, 44, Color("37474f"), HORIZONTAL_ALIGNMENT_CENTER, (v.x - 160) / 4.0)
	_ctxt(222, "친구 방 코드", 11)


func _draw_trade() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("e1f5fe"))
	_txt(Vector2(12, 34), "포켓몬 교환", 22, Color("0277bd"))
	_txt(Vector2(12, 66), "보낼 포켓몬을 고르세요", 11)
	for i in party.size():
		var r := Rect2(8, 80 + i * 50, v.x * 0.5 - 12, 46)
		var m = party[i]
		_panel(r, Color("ffe082") if coop.my_offer == i else Color("fafafa"))
		spr.mon(ui, m.id, r.position + Vector2(28, 46), 1)
		_txt(r.position + Vector2(58, 20), m.name())
		_txt(r.position + Vector2(58, 38), "Lv%d" % m.level)
	var pr := Rect2(v.x * 0.5 + 4, 80, v.x * 0.5 - 12, 200)
	_panel(pr, Color("f3e5f5"))
	_txt(pr.position + Vector2(0, 20), "친구가 보낼 포켓몬", 11, Color("6a1b9a"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	if coop.their_offer != null:
		var d: Dictionary = coop.their_offer
		spr.mon(ui, d.id, pr.position + Vector2(pr.size.x * 0.5, 150), 2)
		_txt(pr.position + Vector2(0, 172), "%s  Lv%d" % [Data.MONS[d.id].name, int(d.lv)], 11, Color("303030"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	else:
		_txt(pr.position + Vector2(0, 110), "고르는 중...", 11, Color("757575"), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x)
	var stt := ""
	if coop.my_ok and not coop.their_ok:
		stt = "친구의 확인을 기다리는 중..."
	elif coop.their_ok and not coop.my_ok:
		stt = "친구는 준비됐어요! [교환하기]를 누르세요"
	_ctxt(v.y - 146, stt, 11, Color("2e7d32"))


func _draw_evolve() -> void:
	var v := view
	ui.draw_rect(Rect2(Vector2.ZERO, v), Color("101828"))
	if evo_mon == null:
		return
	var c := Vector2(v.x * 0.5, 280)
	if evo_choose:
		_ctxt(120, "어떤 모습으로 진화할까?", 22, Color.WHITE)
		for i in 3:
			var r := Rect2(12 + i * (v.x - 24) / 3.0, 300, (v.x - 24) / 3.0 - 8, 120)
			_panel(r, Color("263238"), Color("ffeb3b"))
			spr.mon(ui, Data.EEVEELUTIONS[i], r.position + Vector2(r.size.x * 0.5, 100), 2)
			_txt(r.position + Vector2(0, 112), Data.MONS[Data.EEVEELUTIONS[i]].name, 11, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		return
	var id: String = evo_mon.id
	if evo_t >= 0.0:
		# 점점 빨라지며 두 모습이 번갈아 깜빡인다
		var speed := 2.0 + evo_t * evo_t * 3.0
		if fmod(evo_t * speed, 1.0) > 0.5 and evo_to != "*eeveelution":
			id = evo_to
		for i in 12:
			var a := t * 2.0 + i * TAU / 12.0
			ui.draw_circle(c + Vector2(cos(a), sin(a)) * (60.0 + evo_t * 30.0) + Vector2(0, -40), 3.0, Color(1, 1, 0.7, 0.8))
		spr.mon(ui, id, c, 3, false, evo_t > 0.5 and evo_t < 2.7)
	else:
		spr.mon(ui, id, c, 3)
