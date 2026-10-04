extends RefCounted
## 픽셀 아트 그리기. 게임 화면 자체가 저해상도(360폭)로 렌더된 뒤 확대되므로 도형이 그대로 픽셀이 된다.
## 포켓몬은 원점(0,0)이 발밑 중앙, 약 48px 크기. s로 확대한다.

const OL := Color("181818")


static func ell(c: Vector2, r: Vector2, rot := 0.0, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


## 외곽선 있는 타원
static func blob(ci: CanvasItem, c: Vector2, r: Vector2, col: Color, rot := 0.0) -> void:
	ci.draw_colored_polygon(ell(c, r + Vector2(1.5, 1.5), rot), OL)
	ci.draw_colored_polygon(ell(c, r, rot), col)


static func poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	var cl := pts.duplicate()
	cl.append(pts[0])
	ci.draw_polyline(cl, OL, 2.5)
	ci.draw_colored_polygon(pts, col)


static func eye(ci: CanvasItem, p: Vector2, r := 2.6) -> void:
	ci.draw_circle(p, r, OL)
	ci.draw_circle(p + Vector2(-0.7, -0.8), r * 0.38, Color.WHITE)


static func mon(ci: CanvasItem, id: String, pos: Vector2, s := 1.0, back := false, mod := Color.WHITE) -> void:
	ci.draw_set_transform(pos, 0.0, Vector2(-s if back else s, s))
	match id:
		"pikachu": _pikachu(ci, false)
		"raichu": _pikachu(ci, true)
		"eevee": _eevee(ci, "eevee")
		"vaporeon": _eevee(ci, "vaporeon")
		"jolteon": _eevee(ci, "jolteon")
		"flareon": _eevee(ci, "flareon")
		"squirtle": _turtle(ci, 0)
		"wartortle": _turtle(ci, 1)
		"blastoise": _turtle(ci, 2)
		"bulbasaur": _bulb(ci, 0)
		"ivysaur": _bulb(ci, 1)
		"venusaur": _bulb(ci, 2)
		"charmander": _char(ci, 0)
		"charmeleon": _char(ci, 1)
		"charizard": _char(ci, 2)
		"pidgey": _bird(ci, false)
		"pidgeotto": _bird(ci, true)
		"rattata": _rattata(ci)
		"caterpie": _caterpie(ci)
		"sandshrew": _sandshrew(ci)
		"zubat": _zubat(ci)
		"oddish": _oddish(ci)
		"psyduck": _psyduck(ci)
		"growlithe": _growlithe(ci)
		"geodude": _geodude(ci)
		"magikarp": _magikarp(ci)
		"gyarados": _gyarados(ci)
		"voltorb": _voltorb(ci)
	if mod != Color.WHITE:
		ci.draw_rect(Rect2(-30, -60, 60, 62), Color(mod, 0.0))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ 스타팅 계열

static func _pikachu(ci: CanvasItem, raichu: bool) -> void:
	var body := Color("ff9e2c") if raichu else Color("f8d030")
	# 꼬리
	if raichu:
		ci.draw_line(Vector2(-10, -10), Vector2(-26, -30), OL, 3.0)
		poly(ci, PackedVector2Array([Vector2(-26, -30), Vector2(-34, -40), Vector2(-24, -42), Vector2(-20, -32)]), Color("f8d030"))
	else:
		poly(ci, PackedVector2Array([Vector2(-8, -10), Vector2(-20, -18), Vector2(-14, -22), Vector2(-26, -36), Vector2(-18, -38), Vector2(-10, -24), Vector2(-14, -20), Vector2(-4, -14)]), body)
	blob(ci, Vector2(0, -10), Vector2(12, 11), body)
	# 귀
	var tip := Color("6d4c41") if raichu else OL
	for sx in [-1.0, 1.0]:
		var ear := PackedVector2Array([Vector2(sx * 5, -30), Vector2(sx * 15, -50), Vector2(sx * 11, -28)])
		poly(ci, ear, body)
		ci.draw_colored_polygon(PackedVector2Array([Vector2(sx * 12, -44), Vector2(sx * 15, -50), Vector2(sx * 13.5, -43)]), tip)
	blob(ci, Vector2(0, -27), Vector2(12, 10), body)
	eye(ci, Vector2(-5, -29))
	eye(ci, Vector2(5, -29))
	ci.draw_circle(Vector2(-9, -24), 3.0, Color("e53935"))
	ci.draw_circle(Vector2(9, -24), 3.0, Color("e53935"))
	ci.draw_line(Vector2(-2, -23), Vector2(2, -23), OL, 1.5)
	blob(ci, Vector2(-6, -1), Vector2(4, 3), body)
	blob(ci, Vector2(6, -1), Vector2(4, 3), body)


static func _eevee(ci: CanvasItem, kind: String) -> void:
	var body := Color("b5794b")
	var fluff := Color("f3e0b8")
	match kind:
		"vaporeon":
			body = Color("5ec4e8")
			fluff = Color("f5f0c8")
		"jolteon":
			body = Color("f8d030")
			fluff = Color("ffffff")
		"flareon":
			body = Color("f08030")
			fluff = Color("ffe082")
	# 꼬리
	if kind == "vaporeon":
		poly(ci, PackedVector2Array([Vector2(-10, -10), Vector2(-26, -20), Vector2(-34, -30), Vector2(-28, -12), Vector2(-14, -4)]), body)
	elif kind == "jolteon":
		poly(ci, PackedVector2Array([Vector2(-10, -12), Vector2(-24, -22), Vector2(-20, -14), Vector2(-28, -10), Vector2(-14, -4)]), body)
	else:
		blob(ci, Vector2(-16, -18), Vector2(9, 11), body, -0.5)
		blob(ci, Vector2(-20, -24), Vector2(5, 5), fluff)
	blob(ci, Vector2(0, -10), Vector2(11, 10), body)
	for sx in [-6.0, 6.0]:
		blob(ci, Vector2(sx, -1), Vector2(3.5, 3), body)
	# 귀
	for sx in [-1.0, 1.0]:
		if kind == "vaporeon":
			poly(ci, PackedVector2Array([Vector2(sx * 8, -34), Vector2(sx * 20, -40), Vector2(sx * 12, -28)]), Color("f5f0c8"))
		else:
			poly(ci, PackedVector2Array([Vector2(sx * 5, -34), Vector2(sx * 16, -54), Vector2(sx * 13, -30)]), body)
	# 목 털
	if kind == "jolteon":
		poly(ci, PackedVector2Array([Vector2(-12, -20), Vector2(-16, -14), Vector2(-8, -14), Vector2(-6, -8), Vector2(0, -14), Vector2(6, -8), Vector2(8, -14), Vector2(16, -14), Vector2(12, -20)]), fluff)
	elif kind != "vaporeon":
		blob(ci, Vector2(0, -18), Vector2(11, 6), fluff)
	blob(ci, Vector2(0, -30), Vector2(10, 9), body)
	if kind == "flareon":
		blob(ci, Vector2(0, -39), Vector2(5, 4), fluff)
	eye(ci, Vector2(-4, -31))
	eye(ci, Vector2(4, -31))
	ci.draw_circle(Vector2(0, -26), 1.2, OL)


static func _turtle(ci: CanvasItem, stage: int) -> void:
	var skin := Color("7ec8e3") if stage == 0 else (Color("6fa8dc") if stage == 1 else Color("4f7fc8"))
	var shell := Color("a0662f")
	var sc := 1.0 + stage * 0.15
	# 꼬리
	if stage == 0:
		ci.draw_arc(Vector2(-14, -8), 5.0, PI * 0.5, PI * 2.0, 10, skin, 4.0)
	elif stage == 1:
		blob(ci, Vector2(-16, -10), Vector2(8, 6), Color("e8eef8"))
	blob(ci, Vector2(-7, -14) * sc, Vector2(10, 14) * sc, shell)
	blob(ci, Vector2(0, -13) * sc, Vector2(11, 13) * sc, Color("f3d98a"))
	for i in 3:
		ci.draw_line(Vector2(-7, -18 + i * 6) * sc, Vector2(7, -18 + i * 6) * sc, Color("c9a65e"), 1.5)
	if stage == 2:
		for sx in [-1.0, 1.0]:
			blob(ci, Vector2(sx * 12, -30), Vector2(4, 4), Color("9e9e9e"))
			ci.draw_rect(Rect2(Vector2(sx * 12 - 3, -40), Vector2(6, 10)), Color("9e9e9e"))
	blob(ci, Vector2(-12, -14) * sc, Vector2(4, 3), skin)
	blob(ci, Vector2(12, -14) * sc, Vector2(4, 3), skin)
	blob(ci, Vector2(-6, -1), Vector2(4.5, 3), skin)
	blob(ci, Vector2(6, -1), Vector2(4.5, 3), skin)
	blob(ci, Vector2(0, -31) * sc, Vector2(10, 9) * sc, skin)
	if stage == 1:
		for sx in [-1.0, 1.0]:
			blob(ci, Vector2(sx * 11, -38), Vector2(4, 6), Color("e8eef8"), sx * 0.4)
	eye(ci, Vector2(-4, -32) * sc, 2.4 + stage * 0.3)
	eye(ci, Vector2(4, -32) * sc, 2.4 + stage * 0.3)
	ci.draw_line(Vector2(-3, -26) * sc, Vector2(3, -26) * sc, OL, 1.5)


static func _bulb(ci: CanvasItem, stage: int) -> void:
	var skin := Color("7fc8a9")
	var sc := 1.0 + stage * 0.15
	# 몸 (네 발)
	blob(ci, Vector2(0, -10) * sc, Vector2(16, 9) * sc, skin)
	for sx in [-11.0, -4.0, 4.0, 11.0]:
		blob(ci, Vector2(sx * sc, -2), Vector2(3.5, 3), skin)
	# 등의 씨앗/꽃
	match stage:
		0:
			blob(ci, Vector2(-4, -22), Vector2(10, 9), Color("5fa463"))
			ci.draw_line(Vector2(-4, -30), Vector2(-4, -14), Color("3e7d42"), 1.5)
		1:
			for a in [-0.9, -0.3, 0.3, 0.9]:
				blob(ci, Vector2(-4, -26) + Vector2(sin(a) * 12, -cos(a) * 6), Vector2(7, 3), Color("4caf50"), a)
			blob(ci, Vector2(-4, -30), Vector2(6, 6), Color("f48fb1"))
		_:
			for i in 5:
				var a := TAU * i / 5.0
				blob(ci, Vector2(-4, -32) * sc + Vector2(cos(a) * 9, sin(a) * 5), Vector2(7, 5), Color("f06292"), a)
			blob(ci, Vector2(-4, -32) * sc, Vector2(5, 4), Color("ffee58"))
			blob(ci, Vector2(-4, -22) * sc, Vector2(14, 4), Color("388e3c"))
	# 머리
	blob(ci, Vector2(10, -16) * sc, Vector2(10, 8) * sc, skin)
	ci.draw_circle(Vector2(4, -20) * sc, 1.5, Color("4f8f78"))
	ci.draw_circle(Vector2(14, -10) * sc, 1.5, Color("4f8f78"))
	ci.draw_circle(Vector2(7, -18) * sc, 2.8, Color("e53935"))
	ci.draw_circle(Vector2(15, -18) * sc, 2.8, Color("e53935"))
	ci.draw_circle(Vector2(7, -18) * sc, 1.2, Color.WHITE)
	ci.draw_circle(Vector2(15, -18) * sc, 1.2, Color.WHITE)
	ci.draw_line(Vector2(8, -12) * sc, Vector2(14, -12) * sc, OL, 1.5)


static func _char(ci: CanvasItem, stage: int) -> void:
	var skin := Color("f08030") if stage != 1 else Color("e04b2a")
	var belly := Color("f8d878")
	var sc := 1.0 + stage * 0.2
	# 꼬리 불꽃
	ci.draw_line(Vector2(-8, -8) * sc, Vector2(-20, -16) * sc, skin, 4.0)
	blob(ci, Vector2(-22, -22) * sc, Vector2(4, 6), Color("ff7043"))
	ci.draw_circle(Vector2(-22, -21) * sc, 2.5, Color("ffee58"))
	if stage == 2:
		for sx in [-1.0, 1.0]:
			poly(ci, PackedVector2Array([Vector2(sx * 6, -30), Vector2(sx * 28, -52), Vector2(sx * 30, -30), Vector2(sx * 12, -22)]), Color("4aa3a3"))
	blob(ci, Vector2(0, -14) * sc, Vector2(10, 12) * sc, skin)
	blob(ci, Vector2(0, -12) * sc, Vector2(6, 8) * sc, belly)
	blob(ci, Vector2(-6, -1), Vector2(4, 3), skin)
	blob(ci, Vector2(6, -1), Vector2(4, 3), skin)
	blob(ci, Vector2(0, -32) * sc, Vector2(9, 9) * sc, skin)
	if stage == 1:
		poly(ci, PackedVector2Array([Vector2(-2, -40) * sc, Vector2(-8, -50) * sc, Vector2(2, -41) * sc]), skin)
	if stage == 2:
		for sx in [-1.0, 1.0]:
			poly(ci, PackedVector2Array([Vector2(sx * 4, -40) * sc, Vector2(sx * 8, -50) * sc, Vector2(sx * 8, -38) * sc]), skin)
	eye(ci, Vector2(-4, -33) * sc, 2.4)
	eye(ci, Vector2(4, -33) * sc, 2.4)
	ci.draw_line(Vector2(-3, -27) * sc, Vector2(3, -27) * sc, OL, 1.5)


# ------------------------------------------------------------------ 야생

static func _bird(ci: CanvasItem, big: bool) -> void:
	var body := Color("b5895a")
	var sc := 1.3 if big else 1.0
	poly(ci, PackedVector2Array([Vector2(-10, -12) * sc, Vector2(-22, -6) * sc, Vector2(-20, -2) * sc, Vector2(-8, -6) * sc]), Color("8d6440"))
	blob(ci, Vector2(0, -12) * sc, Vector2(12, 11) * sc, body)
	blob(ci, Vector2(2, -9) * sc, Vector2(7, 7) * sc, Color("f3e0b8"))
	for sx in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(sx * 8, -18) * sc, Vector2(sx * 20, -8) * sc, Vector2(sx * 10, -6) * sc]), Color("8d6440"))
	blob(ci, Vector2(2, -27) * sc, Vector2(9, 8) * sc, body)
	if big:
		poly(ci, PackedVector2Array([Vector2(-4, -36) * sc, Vector2(-10, -46) * sc, Vector2(2, -38) * sc, Vector2(0, -46) * sc, Vector2(6, -36) * sc]), Color("e53935"))
	eye(ci, Vector2(-2, -28) * sc)
	eye(ci, Vector2(6, -28) * sc)
	poly(ci, PackedVector2Array([Vector2(1, -24) * sc, Vector2(5, -24) * sc, Vector2(3, -20) * sc]), Color("424242"))
	ci.draw_line(Vector2(-4, -1), Vector2(-4, 1), Color("e8a33a"), 2.0)
	ci.draw_line(Vector2(4, -1), Vector2(4, 1), Color("e8a33a"), 2.0)


static func _rattata(ci: CanvasItem) -> void:
	var body := Color("a070c8")
	ci.draw_arc(Vector2(-18, -10), 7.0, PI * 0.2, PI * 1.6, 10, body, 3.0)
	blob(ci, Vector2(0, -10), Vector2(15, 9), body)
	blob(ci, Vector2(2, -6), Vector2(8, 4), Color("f3e0b8"))
	for sx in [-1.0, 1.0]:
		blob(ci, Vector2(sx * 10, -30), Vector2(6, 6), body)
		blob(ci, Vector2(sx * 10, -30), Vector2(3, 3), Color("f8bbd0"))
	blob(ci, Vector2(0, -22), Vector2(11, 9), body)
	ci.draw_circle(Vector2(-5, -24), 3.0, Color("e53935"))
	ci.draw_circle(Vector2(5, -24), 3.0, Color("e53935"))
	ci.draw_circle(Vector2(-5, -24), 1.0, Color.WHITE)
	ci.draw_circle(Vector2(5, -24), 1.0, Color.WHITE)
	ci.draw_rect(Rect2(-2.5, -18, 5, 5), Color.WHITE)
	ci.draw_rect(Rect2(-2.5, -18, 5, 5), OL, false, 1.0)
	for sy in [-20.0, -18.0]:
		ci.draw_line(Vector2(-6, sy), Vector2(-14, sy - 2), OL, 1.0)
		ci.draw_line(Vector2(6, sy), Vector2(14, sy - 2), OL, 1.0)


static func _caterpie(ci: CanvasItem) -> void:
	var g := Color("7cc04b")
	for i in 4:
		blob(ci, Vector2(-14 + i * 7, -6 - i * 2), Vector2(6, 6), g)
		ci.draw_circle(Vector2(-14 + i * 7, -2 - i * 2), 2.0, Color("f8d878"))
	blob(ci, Vector2(10, -20), Vector2(9, 9), g)
	poly(ci, PackedVector2Array([Vector2(8, -28), Vector2(6, -36), Vector2(12, -29)]), Color("e53935"))
	ci.draw_circle(Vector2(8, -22), 3.0, OL)
	ci.draw_circle(Vector2(8, -22), 1.8, Color("ffeb3b"))
	ci.draw_circle(Vector2(15, -18), 2.0, OL)


static func _sandshrew(ci: CanvasItem) -> void:
	var body := Color("e8c25a")
	blob(ci, Vector2(0, -14), Vector2(12, 13), body)
	for i in 3:
		ci.draw_line(Vector2(-9, -20 + i * 6), Vector2(9, -20 + i * 6), Color("a07b2a"), 2.0)
	blob(ci, Vector2(0, -10), Vector2(6, 7), Color("f6e7b8"))
	blob(ci, Vector2(0, -30), Vector2(9, 8), body)
	for sx in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(sx * 5, -36), Vector2(sx * 9, -42), Vector2(sx * 9, -34)]), body)
	eye(ci, Vector2(-4, -31))
	eye(ci, Vector2(4, -31))
	blob(ci, Vector2(-6, -1), Vector2(4, 3), body)
	blob(ci, Vector2(6, -1), Vector2(4, 3), body)


static func _zubat(ci: CanvasItem) -> void:
	var body := Color("5e8fd8")
	var wing := Color("9b6fc8")
	for sx in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(sx * 6, -26), Vector2(sx * 26, -38), Vector2(sx * 22, -26), Vector2(sx * 28, -18), Vector2(sx * 8, -18)]), wing)
	blob(ci, Vector2(0, -24), Vector2(10, 11), body)
	for sx in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(sx * 3, -32), Vector2(sx * 7, -44), Vector2(sx * 9, -30)]), body)
	ci.draw_colored_polygon(ell(Vector2(0, -21), Vector2(6, 4)), Color("3a1a3a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -24), Vector2(-2, -24), Vector2(-3, -20)]), Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(2, -24), Vector2(4, -24), Vector2(3, -20)]), Color.WHITE)
	ci.draw_line(Vector2(-3, -12), Vector2(-4, -6), body, 2.5)
	ci.draw_line(Vector2(3, -12), Vector2(4, -6), body, 2.5)


static func _oddish(ci: CanvasItem) -> void:
	for a in [-0.7, -0.25, 0.25, 0.7]:
		blob(ci, Vector2(0, -26) + Vector2(sin(a) * 10, -cos(a) * 12), Vector2(4, 10), Color("43a047"), a)
	blob(ci, Vector2(0, -14), Vector2(11, 10), Color("3f5fb8"))
	ci.draw_circle(Vector2(-4, -15), 2.2, Color("e53935"))
	ci.draw_circle(Vector2(4, -15), 2.2, Color("e53935"))
	blob(ci, Vector2(-5, -2), Vector2(4, 3), Color("3f5fb8"))
	blob(ci, Vector2(5, -2), Vector2(4, 3), Color("3f5fb8"))


static func _psyduck(ci: CanvasItem) -> void:
	var y := Color("f8d850")
	blob(ci, Vector2(0, -12), Vector2(12, 11), y)
	blob(ci, Vector2(0, -30), Vector2(12, 11), y)
	for sx in [-1.0, 1.0]:
		ci.draw_line(Vector2(sx * 10, -16), Vector2(sx * 12, -36), OL, 4.0)
		ci.draw_line(Vector2(sx * 10, -16), Vector2(sx * 12, -36), y, 2.5)
	blob(ci, Vector2(0, -25), Vector2(7, 4), Color("f6e7b8"))
	for sx in [-1.0, 1.0]:
		ci.draw_circle(Vector2(sx * 5, -32), 3.0, Color.WHITE)
		ci.draw_circle(Vector2(sx * 5, -32), 1.0, OL)
	for i in 3:
		ci.draw_line(Vector2(-2 + i * 2, -41), Vector2(-3 + i * 3, -46), OL, 1.5)
	blob(ci, Vector2(-6, -1), Vector2(5, 3), Color("f6e7b8"))
	blob(ci, Vector2(6, -1), Vector2(5, 3), Color("f6e7b8"))


static func _growlithe(ci: CanvasItem) -> void:
	var body := Color("f08a3a")
	var cream := Color("f6e0b0")
	blob(ci, Vector2(-16, -16), Vector2(7, 9), cream, -0.4)
	blob(ci, Vector2(0, -10), Vector2(14, 9), body)
	for i in 3:
		ci.draw_line(Vector2(-8 + i * 6, -16), Vector2(-6 + i * 6, -8), OL, 1.5)
	for sx in [-9.0, -3.0, 4.0, 10.0]:
		blob(ci, Vector2(sx, -1), Vector2(3, 3), body)
	blob(ci, Vector2(6, -20), Vector2(9, 7), cream)
	blob(ci, Vector2(8, -28), Vector2(9, 8), body)
	blob(ci, Vector2(8, -34), Vector2(6, 4), cream)
	for sx in [1.0, 15.0]:
		poly(ci, PackedVector2Array([Vector2(sx - 3, -32), Vector2(sx, -40), Vector2(sx + 3, -32)]), body)
	eye(ci, Vector2(5, -28))
	eye(ci, Vector2(12, -28))
	ci.draw_circle(Vector2(10, -23), 1.5, OL)


static func _geodude(ci: CanvasItem) -> void:
	var rock := Color("9e9e8e")
	for sx in [-1.0, 1.0]:
		ci.draw_line(Vector2(sx * 10, -16), Vector2(sx * 22, -20), OL, 6.0)
		ci.draw_line(Vector2(sx * 10, -16), Vector2(sx * 22, -20), rock, 4.0)
		blob(ci, Vector2(sx * 24, -22), Vector2(5, 5), rock)
	blob(ci, Vector2(0, -16), Vector2(13, 12), rock)
	ci.draw_line(Vector2(-6, -24), Vector2(-2, -20), Color("6d6d60"), 1.5)
	ci.draw_line(Vector2(6, -8), Vector2(9, -12), Color("6d6d60"), 1.5)
	ci.draw_line(Vector2(-7, -20), Vector2(-2, -18), OL, 2.0)
	ci.draw_line(Vector2(7, -20), Vector2(2, -18), OL, 2.0)
	eye(ci, Vector2(-4, -16), 2.0)
	eye(ci, Vector2(4, -16), 2.0)
	ci.draw_line(Vector2(-3, -10), Vector2(3, -10), OL, 1.5)


static func _magikarp(ci: CanvasItem) -> void:
	var body := Color("f05a28")
	poly(ci, PackedVector2Array([Vector2(-14, -16), Vector2(-24, -26), Vector2(-22, -8)]), Color("f8d878"))
	blob(ci, Vector2(0, -16), Vector2(14, 11), body)
	poly(ci, PackedVector2Array([Vector2(-4, -26), Vector2(4, -34), Vector2(8, -25)]), Color("f8d878"))
	ci.draw_arc(Vector2(10, -14), 3.0, 0.0, PI, 6, Color("f8d878"), 1.5)
	eye(ci, Vector2(6, -19), 3.0)
	ci.draw_line(Vector2(12, -12), Vector2(18, -6), Color("f8d878"), 1.5)
	for i in 3:
		ci.draw_arc(Vector2(-4 + i * 5, -16), 3.0, -0.8, 0.8, 5, Color("c9461f"), 1.0)


static func _gyarados(ci: CanvasItem) -> void:
	var body := Color("4a7fd0")
	ci.draw_line(Vector2(-14, -6), Vector2(-24, -20), OL, 9.0)
	ci.draw_line(Vector2(-14, -6), Vector2(-24, -20), body, 7.0)
	blob(ci, Vector2(-6, -10), Vector2(12, 8), body)
	blob(ci, Vector2(-4, -8), Vector2(8, 4), Color("f6e7b8"))
	ci.draw_line(Vector2(0, -12), Vector2(6, -34), OL, 12.0)
	ci.draw_line(Vector2(0, -12), Vector2(6, -34), body, 10.0)
	blob(ci, Vector2(8, -40), Vector2(11, 9), body)
	poly(ci, PackedVector2Array([Vector2(2, -50), Vector2(0, -58), Vector2(8, -50), Vector2(12, -58), Vector2(14, -48)]), Color("e8eef8"))
	ci.draw_colored_polygon(ell(Vector2(12, -35), Vector2(6, 3)), Color("3a1a1a"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(8, -37), Vector2(10, -37), Vector2(9, -33)]), Color.WHITE)
	ci.draw_line(Vector2(3, -44), Vector2(10, -42), OL, 2.0)
	ci.draw_circle(Vector2(8, -42), 1.8, Color("e53935"))


static func _voltorb(ci: CanvasItem) -> void:
	blob(ci, Vector2(0, -14), Vector2(13, 13), Color("f5f5f5"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-13, -14), Vector2(-12, -19), Vector2(-9, -23), Vector2(-4, -26), Vector2(4, -26), Vector2(9, -23), Vector2(12, -19), Vector2(13, -14)]), Color("e53935"))
	ci.draw_line(Vector2(-13, -14), Vector2(13, -14), OL, 1.5)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-8, -16), Vector2(-2, -13), Vector2(-8, -11)]), OL)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(8, -16), Vector2(2, -13), Vector2(8, -11)]), OL)


# ------------------------------------------------------------------ 사람/볼/타일

## 트레이너 (배틀 화면용, 원점 발밑, 약 70px)
static func trainer(ci: CanvasItem, pos: Vector2, female: bool, s := 1.0, back := false) -> void:
	ci.draw_set_transform(pos, 0.0, Vector2(-s if back else s, s))
	var skin := Color("f6cfa8")
	var hair := Color("5a3825")
	var top := Color("e53935") if not female else Color("4fb3a9")
	var cap := Color("e53935") if not female else Color("f5f5f5")
	if female:
		blob(ci, Vector2(0, -52), Vector2(12, 16), hair)  # 긴 머리
	blob(ci, Vector2(-5, -8), Vector2(4, 9), Color("3949ab") if not female else Color("e57373"))
	blob(ci, Vector2(5, -8), Vector2(4, 9), Color("3949ab") if not female else Color("e57373"))
	blob(ci, Vector2(0, -28), Vector2(11, 13), top)
	ci.draw_rect(Rect2(-11, -22, 22, 3), Color("fafafa"))
	blob(ci, Vector2(0, -50), Vector2(10, 10), skin)
	ci.draw_colored_polygon(ell(Vector2(0, -56), Vector2(11, 6)), cap)
	ci.draw_rect(Rect2(0, -56, 14, 3), cap)
	if not back:
		eye(ci, Vector2(-3, -49), 1.6)
		eye(ci, Vector2(4, -49), 1.6)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func oak(ci: CanvasItem, pos: Vector2, s := 1.0) -> void:
	ci.draw_set_transform(pos, 0.0, Vector2(s, s))
	var skin := Color("f2c9a0")
	blob(ci, Vector2(-5, -8), Vector2(4, 9), Color("6d5a44"))
	blob(ci, Vector2(5, -8), Vector2(4, 9), Color("6d5a44"))
	blob(ci, Vector2(0, -30), Vector2(13, 16), Color("fafafa"))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-4, -44), Vector2(4, -44), Vector2(0, -30)]), Color("c0392b"))
	blob(ci, Vector2(0, -54), Vector2(10, 11), skin)
	blob(ci, Vector2(0, -62), Vector2(11, 5), Color("bdbdbd"))
	blob(ci, Vector2(-10, -56), Vector2(3, 5), Color("bdbdbd"))
	blob(ci, Vector2(10, -56), Vector2(3, 5), Color("bdbdbd"))
	ci.draw_line(Vector2(-6, -56), Vector2(-2, -56), OL, 1.5)
	ci.draw_line(Vector2(2, -56), Vector2(6, -56), OL, 1.5)
	ci.draw_arc(Vector2(0, -50), 3.0, 0.3, PI - 0.3, 6, OL, 1.2)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func ball(ci: CanvasItem, pos: Vector2, kind: String, r := 7.0) -> void:
	var top := Color("e53935")
	match kind:
		"greatball": top = Color("1e88e5")
		"ultraball": top = Color("333333")
		"masterball": top = Color("8e24aa")
	ci.draw_circle(pos, r + 1.0, OL)
	ci.draw_circle(pos, r, Color("f5f5f5"))
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI + PI * i / 9.0
		pts.append(pos + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, top)
	if kind == "greatball":
		ci.draw_rect(Rect2(pos + Vector2(-r * 0.7, -r * 0.6), Vector2(r * 0.35, r * 0.35)), Color("e53935"))
		ci.draw_rect(Rect2(pos + Vector2(r * 0.35, -r * 0.6), Vector2(r * 0.35, r * 0.35)), Color("e53935"))
	elif kind == "ultraball":
		ci.draw_rect(Rect2(pos + Vector2(-r * 0.6, -r * 0.7), Vector2(r * 1.2, r * 0.3)), Color("fdd835"))
	elif kind == "masterball":
		ci.draw_circle(pos + Vector2(-r * 0.5, -r * 0.5), r * 0.2, Color("f48fb1"))
		ci.draw_circle(pos + Vector2(r * 0.5, -r * 0.5), r * 0.2, Color("f48fb1"))
	ci.draw_line(pos - Vector2(r, 0), pos + Vector2(r, 0), OL, 1.5)
	ci.draw_circle(pos, r * 0.32, OL)
	ci.draw_circle(pos, r * 0.2, Color("f5f5f5"))


## 필드용 작은 사람 (16px 타일)
static func walker(ci: CanvasItem, pos: Vector2, col: Color, hair: Color, dir: int, step: int) -> void:
	var p := pos + Vector2(8, 8)
	ci.draw_rect(Rect2(p + Vector2(-5, 2), Vector2(10, 6)), col)
	var lo := 1.0 if step % 2 == 0 else -1.0
	ci.draw_rect(Rect2(p + Vector2(-4, 7), Vector2(3, 2 + lo)), Color("37474f"))
	ci.draw_rect(Rect2(p + Vector2(1, 7), Vector2(3, 2 - lo)), Color("37474f"))
	ci.draw_rect(Rect2(p + Vector2(-5, -7), Vector2(10, 9)), Color("f6cfa8"))
	ci.draw_rect(Rect2(p + Vector2(-6, -9), Vector2(12, 4)), hair)
	if dir != 2:  # 뒤돌아보면 눈이 안 보인다
		var ex := -2.0 if dir == 3 else (2.0 if dir == 1 else 0.0)
		ci.draw_rect(Rect2(p + Vector2(-3 + ex, -4), Vector2(1.5, 2)), OL)
		ci.draw_rect(Rect2(p + Vector2(2 + ex, -4), Vector2(1.5, 2)), OL)
	else:
		ci.draw_rect(Rect2(p + Vector2(-5, -7), Vector2(10, 5)), hair)
