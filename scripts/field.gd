extends Node2D
## 필드(스테이지 맵). 구불구불한 길, 풀숲(야생 포켓몬), 나무, 트레이너, 아이템, 맨 위의 관장.
## 한 칸씩 움직이는 격자 이동. 화면 좌표로 직접 그린다(카메라 오프셋 수동 적용).

const Data = preload("res://scripts/data.gd")
const Px = preload("res://scripts/px.gd")

const T := 16
const W := 20
const H := 38
enum { GROUND, GRASS, TREE, PATH, FLOWER, ROCK }

var main
var stage := 1
var area: Dictionary
var tiles := PackedByteArray()
var rng := RandomNumberGenerator.new()
var pos := Vector2i.ZERO      # 플레이어 칸
var draw_pos := Vector2.ZERO  # 보간된 그리기 위치 (칸 단위)
var dir := 0                  # 0 아래 1 오른쪽 2 위 3 왼쪽
var step_n := 0
var move_cd := 0.0
var held := -1                # 누르고 있는 방향
var finger := -1
var npcs: Array = []          # {pos, dir, kind:"trainer"/"leader", name, team, beaten}
var items: Array = []         # {pos, item, taken}
var active := false
var lock := false             # 대화/배틀 중 이동 금지
var t := 0.0
var cam_y := 0.0


func setup(s: int) -> void:
	stage = s
	area = Data.area(s)
	rng.randomize()
	tiles = PackedByteArray()
	tiles.resize(W * H)
	tiles.fill(GROUND)
	# 테두리 나무
	for y in H:
		for x in W:
			if x == 0 or x == W - 1 or y == 0 or (y == 1 and x != W / 2):
				tiles[y * W + x] = TREE
	# 구불구불한 길 (아래 → 위)
	var px := W / 2
	var path_cells := {}
	for y in range(H - 2, 1, -1):
		path_cells[Vector2i(px, y)] = true
		path_cells[Vector2i(px + 1, y)] = true
		if y % 3 == 0:
			var nx: int = clampi(px + rng.randi_range(-3, 3), 3, W - 5)
			while px != nx:
				px += sign(nx - px)
				path_cells[Vector2i(px, y)] = true
				path_cells[Vector2i(px + 1, y)] = true
	# 위쪽은 관장 앞까지 가운데로
	for y in range(2, 6):
		for x in range(min(px, W / 2), max(px, W / 2) + 2):
			path_cells[Vector2i(x, y)] = true
	for c in path_cells:
		tiles[c.y * W + c.x] = PATH
	# 풀숲
	for i in 9 + stage / 2:
		var gx := rng.randi_range(1, W - 7)
		var gy := rng.randi_range(6, H - 5)
		var gw := rng.randi_range(3, 7)
		var gh := rng.randi_range(2, 4)
		for y in range(gy, gy + gh):
			for x in range(gx, gx + gw):
				if _tile(x, y) == GROUND or (_tile(x, y) == PATH and rng.randf() < 0.5):
					tiles[y * W + x] = GRASS
	# 나무/바위/꽃 (길은 막지 않는다)
	for y in range(3, H - 1):
		for x in range(1, W - 1):
			if _tile(x, y) != GROUND:
				continue
			var r := rng.randf()
			if r < 0.07:
				tiles[y * W + x] = TREE if stage % 4 != 2 else ROCK
			elif r < 0.1:
				tiles[y * W + x] = FLOWER
	pos = Vector2i(W / 2, H - 2)
	draw_pos = Vector2(pos)
	dir = 2
	# 트레이너 2명 + 관장
	npcs.clear()
	var lv: int = Data.wild_level(s)
	var cand: Array = []
	for c in path_cells:
		if c.y > 8 and c.y < H - 6:
			cand.append(c)
	cand.shuffle()
	var names := ["반바지 꼬마", "짧은치마", "곤충채집 소년", "등산가", "낚시꾼", "아가씨"]
	for i in 2:
		if cand.is_empty():
			break
		var c: Vector2i = cand.pop_back()
		var side := Vector2i(-1, 0) if _walkable(c + Vector2i(-1, 0)) and c.x > 2 else Vector2i(2, 0)
		var npos := c + side
		if not _inside(npos):
			continue
		tiles[npos.y * W + npos.x] = GROUND
		var pool: Array = area.pool
		var team := [pool[rng.randi() % pool.size()]]
		if s >= 3:
			team.append(pool[rng.randi() % pool.size()])
		npcs.append({"pos": npos, "dir": 3 if side.x > 0 else 1, "kind": "trainer", "name": names[rng.randi() % names.size()], "team": team, "lv": lv + (1 if s > 1 else 0), "beaten": false})
	var lpos := Vector2i(W / 2, 2)
	tiles[lpos.y * W + lpos.x] = PATH
	var lteam: Array = area.team.slice(0, clampi(1 + (s + 1) / 2, 2, 3))
	npcs.append({"pos": lpos, "dir": 0, "kind": "leader", "name": area.leader, "team": lteam, "lv": lv + (2 if s == 1 else 3), "beaten": false})
	# 아이템 볼
	items.clear()
	var item_pool := ["potion", "greatball", "potion", "money", "ultraball"]
	for i in 3:
		for tries in 40:
			var ip := Vector2i(rng.randi_range(2, W - 3), rng.randi_range(6, H - 4))
			if _tile(ip.x, ip.y) == GROUND or _tile(ip.x, ip.y) == FLOWER:
				items.append({"pos": ip, "item": item_pool[rng.randi() % item_pool.size()], "taken": false})
				break
	active = true
	lock = false
	held = -1
	cam_y = pos.y * T


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < W and c.y < H


func _tile(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W or y >= H:
		return TREE
	return tiles[y * W + x]


func _walkable(c: Vector2i) -> bool:
	var tt := _tile(c.x, c.y)
	if tt == TREE or tt == ROCK:
		return false
	for n in npcs:
		if n.pos == c:
			return false
	return true


# ------------------------------------------------------------------ 입력

func dpad_center() -> Vector2:
	return Vector2(74, main.view.y - 96)


func menu_rect() -> Rect2:
	return Rect2(main.view.x - 70, 8, 62, 26)


func _dir_from(v: Vector2) -> int:
	if v.length() < 10.0:
		return -1
	if abs(v.x) > abs(v.y):
		return 1 if v.x > 0 else 3
	return 0 if v.y > 0 else 2


func _input(event: InputEvent) -> void:
	if not active or main.state != main.State.FIELD or main.dlg_busy() or lock:
		held = -1
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if menu_rect().has_point(event.position):
				main.open_field_menu()
				get_viewport().set_input_as_handled()
				return
			if event.position.distance_to(dpad_center()) < 80.0:
				finger = event.index
				held = _dir_from(event.position - dpad_center())
		elif event.index == finger:
			finger = -1
			held = -1
	elif event is InputEventScreenDrag and event.index == finger:
		held = _dir_from(event.position - dpad_center())


func _key_dir() -> int:
	if Input.is_physical_key_pressed(KEY_DOWN) or Input.is_physical_key_pressed(KEY_S):
		return 0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		return 1
	if Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_W):
		return 2
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		return 3
	return -1


# ------------------------------------------------------------------ 갱신

const DIRS := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]


func update(delta: float, bot_dir := -1) -> void:
	t += delta
	draw_pos = draw_pos.move_toward(Vector2(pos), delta / 0.15)
	cam_y = lerp(cam_y, draw_pos.y * T, min(1.0, delta * 10.0))
	move_cd -= delta
	if lock or main.state != main.State.FIELD:
		queue_redraw()
		return
	var d := held
	if bot_dir >= 0:
		d = bot_dir
	var k := _key_dir()
	if k >= 0:
		d = k
	if d >= 0 and move_cd <= 0.0 and draw_pos.distance_to(Vector2(pos)) < 0.05:
		dir = d
		var np: Vector2i = pos + DIRS[d]
		if _walkable(np):
			pos = np
			step_n += 1
			move_cd = 0.15
			_on_step()
		else:
			move_cd = 0.12
	queue_redraw()


func _on_step() -> void:
	# 아이템
	for it in items:
		if not it.taken and it.pos == pos:
			it.taken = true
			main.field_item(it.item)
			return
	# 트레이너/관장: 바로 옆에 오면 승부
	for n in npcs:
		if n.beaten:
			continue
		var dd: Vector2i = n.pos - pos
		if abs(dd.x) + abs(dd.y) == 1 or (n.kind == "trainer" and _in_sight(n)):
			lock = true
			main.field_trainer(n)
			return
	# 풀숲: 야생 포켓몬
	if _tile(pos.x, pos.y) == GRASS and rng.randf() < 0.11:
		lock = true
		var pool: Array = area.pool
		var sp: String = pool[rng.randi() % pool.size()]
		if sp == "pikachu" and rng.randf() < 0.6:
			sp = pool[0]  # 피카츄는 드물게
		var lv: int = Data.wild_level(stage) + rng.randi_range(-1, 1)
		main.field_wild(sp, max(2, lv))


## 트레이너 시선 (바라보는 방향 3칸)
func _in_sight(n: Dictionary) -> bool:
	for i in range(1, 4):
		if n.pos + DIRS[n.dir] * i == pos:
			return true
	return false


# ------------------------------------------------------------------ 그리기

func _draw() -> void:
	if not active:
		return
	var v: Vector2 = main.view
	var ox := (v.x - W * T) * 0.5
	var view_h: float = v.y - 200.0  # 아래 200px는 조작판
	var oy: float = clamp(view_h * 0.55 - cam_y, view_h - H * T, 40.0)
	var y0: int = max(0, int(-oy / T) - 1)
	var y1: int = min(H, int((v.y - oy) / T) + 2)
	var g: Color = area.ground
	draw_rect(Rect2(Vector2.ZERO, v), area.tree.darkened(0.3))
	for y in range(y0, y1):
		for x in W:
			var p := Vector2(ox + x * T, oy + y * T)
			var tt := tiles[y * W + x]
			draw_rect(Rect2(p, Vector2(T, T)), g if (x + y) % 2 == 0 else g.darkened(0.04))
			match tt:
				PATH:
					draw_rect(Rect2(p, Vector2(T, T)), Color("e6d3a3"))
					if (x * 7 + y * 3) % 5 == 0:
						draw_rect(Rect2(p + Vector2(5, 6), Vector2(2, 2)), Color("c9b27c"))
				GRASS:
					var gc: Color = area.grass
					draw_rect(Rect2(p, Vector2(T, T)), gc)
					for i in 3:
						var bx := p.x + 2 + i * 5
						draw_colored_polygon(PackedVector2Array([Vector2(bx, p.y + 14), Vector2(bx + 2, p.y + 4 + (i % 2) * 2), Vector2(bx + 4, p.y + 14)]), gc.darkened(0.3))
				TREE:
					var tc: Color = area.tree
					draw_rect(Rect2(p + Vector2(6, 10), Vector2(4, 6)), Color("6d4c41"))
					draw_circle(p + Vector2(8, 7), 7.5, tc.darkened(0.25))
					draw_circle(p + Vector2(8, 6), 6.5, tc)
					draw_circle(p + Vector2(6, 4), 2.0, tc.lightened(0.2))
				ROCK:
					draw_circle(p + Vector2(8, 9), 7.0, Color("5d5d55"))
					draw_circle(p + Vector2(8, 8), 6.0, Color("8d8d80"))
				FLOWER:
					for fp in [Vector2(4, 5), Vector2(11, 10)]:
						draw_circle(p + fp, 2.0, Color("ff8a80") if (x + y) % 2 == 0 else Color("fff59d"))
						draw_circle(p + fp, 0.8, Color("ffeb3b"))
	# 출구 표시 (관장 뒤)
	var ex := Vector2(ox + (W / 2) * T, oy + 1 * T)
	draw_rect(Rect2(ex, Vector2(T, T)), Color("e6d3a3"))
	# 아이템
	for it in items:
		if not it.taken:
			Px.ball(self, Vector2(ox + it.pos.x * T + 8, oy + it.pos.y * T + 9), "pokeball", 5.0)
	# NPC
	for n in npcs:
		var np := Vector2(ox + n.pos.x * T, oy + n.pos.y * T)
		var col := Color("8e24aa") if n.kind == "leader" else Color("43a047")
		Px.walker(self, np, col, Color("3e2723"), n.dir, 0)
		if not n.beaten and n.kind == "leader":
			var a: float = 0.5 + 0.5 * sin(t * 4.0)
			draw_string(main.font, np + Vector2(-2, -4), "관장", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 0.5, a))
	# 플레이어
	var pp := Vector2(ox + draw_pos.x * T, oy + draw_pos.y * T)
	var on_grass := _tile(pos.x, pos.y) == GRASS
	Px.walker(self, pp, Color("e53935") if main.character == "m" else Color("4fb3a9"), Color("5a3825") if main.character == "f" else Color("c62828"), dir, step_n)
	if on_grass:
		var gc: Color = area.grass
		draw_rect(Rect2(pp + Vector2(2, 11), Vector2(12, 5)), gc)
	# 상단 정보 + 메뉴 버튼
	draw_rect(Rect2(0, 0, v.x, 40), Color(0, 0, 0, 0.45))
	draw_string(main.font, Vector2(10, 26), "스테이지 %d  %s" % [stage, area.name], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	var mr := menu_rect()
	draw_rect(mr, Color("37474f"))
	draw_rect(mr, Color.WHITE, false, 1.0)
	draw_string(main.font, mr.position + Vector2(16, 18), "메뉴", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
	# 조작판 (게임기 몸체 느낌)
	draw_rect(Rect2(0, v.y - 200, v.x, 200), Color("c62828"))
	draw_rect(Rect2(0, v.y - 200, v.x, 4), Color("8e0000"))
	draw_string(main.font, Vector2(v.x - 170, v.y - 110), "풀숲에 들어가면", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	draw_string(main.font, Vector2(v.x - 170, v.y - 94), "야생 포켓몬이 나와요!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	draw_string(main.font, Vector2(v.x - 170, v.y - 70), "맨 위의 관장을 이기면", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	draw_string(main.font, Vector2(v.x - 170, v.y - 54), "스테이지 클리어!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.8))
	Px.ball(self, Vector2(v.x - 40, v.y - 160), "pokeball", 14.0)
	# 방향키
	var c := dpad_center()
	draw_circle(c, 62.0, Color(0, 0, 0, 0.25))
	for i in 4:
		var dv: Vector2 = Vector2(DIRS[i])
		var on := held == i
		var bc := c + dv * 34.0
		draw_rect(Rect2(bc - Vector2(17, 17), Vector2(34, 34)), Color(1, 1, 1, 0.45 if on else 0.22))
		var tri := PackedVector2Array([bc + dv * 9.0, bc + dv.orthogonal() * 7.0 - dv * 4.0, bc - dv.orthogonal() * 7.0 - dv * 4.0])
		draw_colored_polygon(tri, Color(1, 1, 1, 0.9))
