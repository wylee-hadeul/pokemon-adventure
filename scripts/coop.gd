extends Node
## 같이 하기 (2인, 코드로 연결). 브라우저끼리 직접 연결(WebRTC, PeerJS).
##  - 서로의 위치를 주고받아 같은 스테이지에서 함께 돌아다닌다 (맵은 같은 시드로 똑같이 만든다)
##  - 한 명이 스테이지에 출발하면 친구도 같이 따라간다
##  - 대전: 방장이 턴 결과(명중/피해/급소)를 계산해서 보내고, 둘 다 같은 결과를 연출한다
##  - 교환: 서로 한 마리씩 올리고 둘 다 OK하면 바꾼다

const Mon = preload("res://scripts/mon.gd")
const NetScript = preload("res://scripts/net.gd")

var main
var net
var partner := ""
var code := ""
var code_input := ""
var p_char := "f"
var p_party: Array = []      # 친구 포켓몬 (dict)
var p_where := ""            # town / field / battle
var p_stage := 0
var p_seed := 0
var p_pos := Vector2i.ZERO
var p_draw := Vector2.ZERO
var p_dir := 0
var p_step := 0
var send_t := 0.0
var last_pos := ""
var pending_req := ""        # 내가 보낸 신청 (답을 기다리는 중)
# 교환
var my_offer := -1
var their_offer = null
var my_ok := false
var their_ok := false


func _ready() -> void:
	net = NetScript.new()
	add_child(net)
	net.joined.connect(_on_joined)
	net.left.connect(_on_left)
	net.received.connect(_on_msg)


func connected() -> bool:
	return net.active() and partner != ""


func host_room() -> void:
	code = "%04d" % randi_range(0, 9999)
	net.host(code)


func join_room(c: String) -> void:
	code = c
	net.join(c)


func leave() -> void:
	if connected():
		send({"t": "bye"})
	net.leave()
	partner = ""
	p_where = ""


func send(d: Dictionary) -> void:
	if partner != "":
		net.send(partner, d)


func party_dicts(arr: Array) -> Array:
	return arr.map(func(m): return m.to_dict())


func send_party() -> void:
	send({"t": "party", "party": party_dicts(main.party), "char": main.character})


func _on_joined(from: String) -> void:
	if partner != "" and partner != from:
		return
	partner = from
	send({"t": "hello", "char": main.character, "party": party_dicts(main.party)})
	main.sfx.play("levelup", -6.0)
	main.show_toast("친구와 연결됐어요!")
	print("[coop] joined ", from, " host=", net.is_host)


func _on_left(from: String) -> void:
	if from != partner:
		return
	partner = ""
	p_where = ""
	main.on_partner_left()


func _process(delta: float) -> void:
	if not connected():
		return
	p_draw = p_draw.move_toward(Vector2(p_pos), delta / 0.15)
	if p_draw.distance_to(Vector2(p_pos)) > 3.0:
		p_draw = Vector2(p_pos)
	send_t -= delta
	if send_t > 0.0:
		return
	send_t = 0.1
	var f = main.field
	var w := "town"
	if main.state == main.State.BATTLE or main.state == main.State.EVOLVE:
		w = "battle"
	elif f.active and (main.state == main.State.FIELD or main.state == main.State.MENU or main.state == main.State.FRIEND):
		w = "field"
	var d := {"t": "pos", "w": w, "s": f.stage, "seed": f.seed, "x": f.pos.x, "y": f.pos.y, "d": f.dir, "st": f.step_n}
	var key := JSON.stringify(d)
	if key != last_pos or randf() < 0.05:
		last_pos = key
		send(d)


func partner_on_my_map() -> bool:
	var f = main.field
	return connected() and p_where == "field" and p_stage == f.stage and p_seed == f.seed


func request(kind: String) -> void:
	if not connected():
		main.show_toast("친구와 연결되어 있지 않아요")
		return
	pending_req = kind
	send({"t": "req", "k": kind, "party": party_dicts(main.party)})
	main.show_toast("친구에게 %s을 신청했어요... 기다리는 중" % ("대전" if kind == "battle" else "교환"))


func answer(kind: String, ok: bool) -> void:
	send({"t": "ans", "k": kind, "ok": ok, "party": party_dicts(main.party)})
	if ok:
		_begin(kind)


func _begin(kind: String) -> void:
	if kind == "battle":
		main.start_pvp(p_party)
	else:
		my_offer = -1
		their_offer = null
		my_ok = false
		their_ok = false
		main.open_trade()


# ------------------------------------------------------------------ 교환

func offer(idx: int) -> void:
	my_offer = idx
	my_ok = false
	their_ok = false
	send({"t": "offer", "i": idx, "mon": main.party[idx].to_dict()})


func trade_ok() -> void:
	if my_offer < 0 or their_offer == null:
		return
	my_ok = true
	send({"t": "trade_ok"})
	_try_trade()


func trade_cancel() -> void:
	send({"t": "trade_cancel"})
	main.close_trade("교환을 그만두었다.")


func _try_trade() -> void:
	if not (my_ok and their_ok and my_offer >= 0 and their_offer != null):
		return
	var got = Mon.from_dict(their_offer)
	var gave: String = main.party[my_offer].name()
	main.party[my_offer] = got
	my_ok = false
	their_ok = false
	my_offer = -1
	their_offer = null
	main.save_game()
	send_party()
	main.sfx.play("catch", -4.0)
	main.voice.cry(got.name())
	main.log_lines.append("trade %s -> %s" % [gave, got.name()])
	main.close_trade(main.josa("%s(을)를 보내고 %s(을)를 받았다!" % [gave, got.name()]))


# ------------------------------------------------------------------ 메시지

func _on_msg(_from: String, d: Dictionary) -> void:
	match d.get("t", ""):
		"hello", "party":
			p_char = d.get("char", "f")
			p_party = d.get("party", [])
		"bye":
			_on_left(partner)
		"pos":
			p_where = d.w
			var np := Vector2i(int(d.x), int(d.y))
			if int(d.s) != p_stage or int(d.seed) != p_seed:
				p_draw = Vector2(np)
			p_stage = int(d.s)
			p_seed = int(d.seed)
			p_pos = np
			p_dir = int(d.d)
			p_step = int(d.st)
		"stage":
			main.partner_stage(int(d.s), int(d.seed))
		"req":
			p_party = d.get("party", p_party)
			main.partner_request(d.k)
		"ans":
			p_party = d.get("party", p_party)
			pending_req = ""
			if d.ok:
				_begin(d.k)
			else:
				main.show_toast("친구가 지금은 안 된대요")
		"act":
			main.battle.pvp_foe_action(d.a)
		"turn":
			main.battle.pvp_play(d.ev, false)
		"fsw":
			main.battle.pvp_foe_switch(int(d.i))
		"forfeit":
			main.battle.pvp_foe_forfeit()
		"offer":
			their_offer = d.mon
			my_ok = false
			their_ok = false
		"trade_ok":
			their_ok = true
			_try_trade()
		"trade_cancel":
			main.close_trade("친구가 교환을 그만두었다.")
