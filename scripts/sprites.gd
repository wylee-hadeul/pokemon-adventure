extends Node
## 진짜 도트 그림.
##  - 사람(주인공/오박사/간호사): 12x16 픽셀을 문자열로 직접 찍은 그림
##  - 포켓몬/볼: 시작할 때 작게 구운 뒤(SubViewport) 외곽선·명암을 픽셀 단위로 다시 칠한다
## 화면에는 정수 배율(2x, 3x...)로 키워서 그리므로 픽셀이 또렷하게 보인다.

const Px = preload("res://scripts/px.gd")
const Data = preload("res://scripts/data.gd")

const CELL := 56          # 포켓몬 한 칸
const MON_SCALE := 0.8    # 구울 때 크기 (약 48px)
const BALL_CELL := 16
const OL := Color("181818")

var baked := false
var mon_tex := {}         # id -> [보통, 흰 실루엣]
var ball_tex := {}
var people := {}          # 키 -> ImageTexture

# ------------------------------------------------------------------ 사람 도트 (12x16)
# k 외곽선, c 모자, h 머리, s 피부, t 옷, w 흰색, p 바지, r 넥타이, g 회색 머리
const DOWN := [
	"...kkkkkk...",
	"..kccwwcck..",
	".kcccccccck.",
	".kkkkkkkkkk.",
	".khsssssshk.",
	".kskssssksk.",
	".kssssssssk.",
	"..kssssssk..",
	".kttttttttk.",
	"ksttwwttttsk",
	"ksttttttttsk",
	".kkttttttkk.",
	"..kppppppk..",
	"..kppkkppk..",
	"..kppkkppk..",
	"..kkk..kkk..",
]
const UP := [
	"...kkkkkk...",
	"..kcccccck..",
	".kcccccccck.",
	".kkkkkkkkkk.",
	".khhhhhhhhk.",
	".khhhhhhhhk.",
	".khhhhhhhhk.",
	"..khhhhhhk..",
	".kttttttttk.",
	"ksttttttttsk",
	"ksttttttttsk",
	".kkttttttkk.",
	"..kppppppk..",
	"..kppkkppk..",
	"..kppkkppk..",
	"..kkk..kkk..",
]
const SIDE := [
	"...kkkkkk...",
	"..kcccccck..",
	".kcccccccck.",
	".kkkkkkkkkkk",
	".khhhssssk..",
	".khhssssksk.",
	".khhsssssssk",
	"..khsssssk..",
	"...kssssk...",
	"..ktttttk...",
	"..kttstttk..",
	"..kkttttkk..",
	"...kppppk...",
	"...kppppk...",
	"...kpkkpk...",
	"...kkkkkk...",
]
const OAK := [
	"...kkkkkk...",
	"..kggggggk..",
	".kggggggggk.",
	".kgssssssgk.",
	".kssssssssk.",
	".kskssssksk.",
	".kssssssssk.",
	"..ksskkssk..",
	"..kwwrrwwk..",
	".kwwwrrwwwk.",
	"kswwwrrwwwsk",
	"kswwwwwwwwsk",
	".kwwwwwwwwk.",
	".kwwkppkwwk.",
	"..kppkkppk..",
	"..kkk..kkk..",
]
# 걷는 프레임: 다리 줄만 바꾼다 [줄 번호, 내용]
const STEP_A := [[14, "..kkk.kppk.."], [15, "......kkk..."]]
const STEP_B := [[14, "..kppk.kkk.."], [15, "...kkk......"]]
const SIDE_STEP := [[14, "..kpk..kpk.."], [15, "..kkk..kkk.."]]

const PALETTES := {
	"m": {"c": Color("e53935"), "h": Color("3e2723"), "t": Color("e53935"), "p": Color("3949ab")},
	"f": {"c": Color("fafafa"), "h": Color("6d3b1f"), "t": Color("26a69a"), "p": Color("ec407a")},
	"m2": {"c": Color("1e88e5"), "h": Color("212121"), "t": Color("1e88e5"), "p": Color("424242")},
	"f2": {"c": Color("ffca28"), "h": Color("f57f17"), "t": Color("ab47bc"), "p": Color("5e35b1")},
	"nurse": {"c": Color("fafafa"), "h": Color("f48fb1"), "t": Color("f8bbd0"), "p": Color("fafafa")},
	"trainer": {"c": Color("43a047"), "h": Color("4e342e"), "t": Color("66bb6a"), "p": Color("6d4c41")},
	"leader": {"c": Color("6a1b9a"), "h": Color("212121"), "t": Color("8e24aa"), "p": Color("311b92")},
	"oak": {"c": Color("bdbdbd"), "h": Color("bdbdbd"), "t": Color("fafafa"), "p": Color("6d5a44")},
}
const BASE := {"k": Color("181818"), "s": Color("f6cfa8"), "w": Color("fafafa"), "r": Color("c0392b"), "g": Color("c8c8c8")}


func _ready() -> void:
	for pal in PALETTES:
		if pal == "oak":
			people["oak"] = _person(OAK, [], pal, false)
			continue
		for d in 4:
			for f in 3:
				people["%s_%d_%d" % [pal, d, f]] = _person_dir(pal, d, f)


func _person_dir(pal: String, d: int, f: int) -> ImageTexture:
	# d: 0 아래 1 오른쪽 2 위 3 왼쪽 / f: 0 서기 1,2 걷기
	var rows: Array = DOWN if d == 0 else (UP if d == 2 else SIDE)
	var mods: Array = []
	if f > 0:
		if d == 1 or d == 3:
			mods = SIDE_STEP
		else:
			mods = STEP_A if f == 1 else STEP_B
	return _person(rows, mods, pal, d == 3)


func _person(rows: Array, mods: Array, pal: String, flip: bool) -> ImageTexture:
	var r := rows.duplicate()
	for m in mods:
		r[m[0]] = m[1]
	var img := Image.create(12, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var p: Dictionary = PALETTES[pal]
	for y in 16:
		var line: String = r[y]
		for x in 12:
			var ch := line[x]
			if ch == ".":
				continue
			var col: Color = p.get(ch, BASE.get(ch, Color.MAGENTA))
			img.set_pixel(11 - x if flip else x, y, col)
	return ImageTexture.create_from_image(img)


## 사람: pos = 발밑 가운데, sc = 정수 배율
func person(ci: CanvasItem, key: String, pos: Vector2, sc: int) -> void:
	var tex: Texture2D = people.get(key)
	if tex == null:
		return
	var sz := Vector2(12, 16) * sc
	ci.draw_texture_rect(tex, Rect2((pos - Vector2(sz.x * 0.5, sz.y)).round(), sz), false)


func walker_key(pal: String, d: int, step: int) -> String:
	var f := 0
	if step > 0:
		f = 1 + step % 2
	return "%s_%d_%d" % [pal, d, f]


# ------------------------------------------------------------------ 포켓몬/볼 굽기

class Painter extends Node2D:
	var jobs: Array = []

	func _draw() -> void:
		for j in jobs:
			if j[0] == "mon":
				Px.mon(self, j[1], j[2], MON_SCALE)
			else:
				Px.ball(self, j[2], j[1], 6.0)


func bake() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var ids: Array = Data.MONS.keys()
	var cols := 8
	var rows := int(ceil(ids.size() / float(cols))) + 1
	var vp := SubViewport.new()
	vp.size = Vector2i(cols * CELL, rows * CELL)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := Painter.new()
	vp.add_child(painter)
	for i in ids.size():
		var cx := (i % cols) * CELL
		var cy := (i / cols) * CELL
		painter.jobs.append(["mon", ids[i], Vector2(cx + CELL * 0.5, cy + CELL - 4)])
	var by := (rows - 1) * CELL
	for i in Data.BALLS.size():
		painter.jobs.append(["ball", Data.BALLS[i], Vector2(i * BALL_CELL + 8, by + 8)])
	add_child(vp)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	if img == null or img.is_empty():
		return
	img.convert(Image.FORMAT_RGBA8)
	for i in ids.size():
		var cell := img.get_region(Rect2i((i % cols) * CELL, (i / cols) * CELL, CELL, CELL))
		_pixelize(cell, true)
		mon_tex[ids[i]] = [ImageTexture.create_from_image(cell), ImageTexture.create_from_image(_silhouette(cell))]
	for i in Data.BALLS.size():
		var bc := img.get_region(Rect2i(i * BALL_CELL, by, BALL_CELL, BALL_CELL))
		_pixelize(bc, false)
		ball_tex[Data.BALLS[i]] = ImageTexture.create_from_image(bc)
	baked = true


## 알파를 0/1로, 바깥 테두리는 1px 외곽선, 위는 밝게 아래는 어둡게 (도트 명암)
func _pixelize(img: Image, shade: bool) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				solid[y * w + x] = 1
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	# 혼자 떨어진 점(잡티) 지우기
	for y in h:
		for x in w:
			if solid[y * w + x] == 0:
				continue
			var n := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx2: int = x + dx
					var ny2: int = y + dy
					if (dx != 0 or dy != 0) and nx2 >= 0 and ny2 >= 0 and nx2 < w and ny2 < h and solid[ny2 * w + nx2] == 1:
						n += 1
			if n <= 1:
				solid[y * w + x] = 0
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	var edge := PackedByteArray()
	edge.resize(w * h)
	for y in h:
		for x in w:
			if solid[y * w + x] == 0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h or solid[ny * w + nx] == 0:
					edge[y * w + x] = 1
					break
	for i in w * h:
		if edge[i] == 1:
			img.set_pixel(i % w, i / w, OL)
	if not shade:
		return
	var src: Image = img.duplicate()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if solid[y * w + x] == 0 or edge[y * w + x] == 1:
				continue
			var c := src.get_pixel(x, y)
			if _is_dark(c):
				continue
			var up := src.get_pixel(x, y - 1)
			var dn := src.get_pixel(x, y + 1)
			var rt := src.get_pixel(x + 1, y)
			if _is_dark(dn) or _is_dark(rt):
				img.set_pixel(x, y, c.darkened(0.22))
			elif _is_dark(up):
				img.set_pixel(x, y, c.lightened(0.25))


func _is_dark(c: Color) -> bool:
	return c.a > 0.5 and c.r + c.g + c.b < 0.3


func _silhouette(src: Image) -> Image:
	var img: Image = src.duplicate()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				img.set_pixel(x, y, Color.WHITE)
	return img


## 포켓몬: pos = 발밑, sc = 정수 배율, back = 좌우 반전, white = 흰 실루엣(진화 연출)
func mon(ci: CanvasItem, id: String, pos: Vector2, sc: int, back := false, white := false) -> void:
	if not mon_tex.has(id):
		Px.mon(ci, id, pos, MON_SCALE * sc, back)
		return
	var tex: Texture2D = mon_tex[id][1 if white else 0]
	var sz := Vector2(CELL, CELL) * sc
	var tl := (pos - Vector2(sz.x * 0.5, sz.y - 4 * sc)).round()
	if back:
		ci.draw_set_transform(Vector2(tl.x + sz.x, tl.y), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(tex, Rect2(Vector2.ZERO, sz), false)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_texture_rect(tex, Rect2(tl, sz), false)


func ball(ci: CanvasItem, kind: String, center: Vector2, sc: int) -> void:
	if not ball_tex.has(kind):
		Px.ball(ci, center, kind, 6.0 * sc)
		return
	var sz := Vector2(BALL_CELL, BALL_CELL) * sc
	ci.draw_texture_rect(ball_tex[kind], Rect2((center - sz * 0.5).round(), sz), false)


# ------------------------------------------------------------------ 필드 타일 (16x16 도트, 지역 색마다 따로)

var tile_cache := {}


## 지역별 타일 텍스처 묶음: ground0, ground1, path, grass, tree, rock, flower0, flower1
func tiles(area: Dictionary) -> Dictionary:
	var key: String = area.name
	if tile_cache.has(key):
		return tile_cache[key]
	var g: Color = area.ground
	var out := {}
	out.ground0 = _tex(_ground(g))
	out.ground1 = _tex(_ground(g.darkened(0.05)))
	out.path = _tex(_path())
	out.grass = _tex(_grass(area.grass))
	out.tree = _tex(_tree(_ground(g), area.tree))
	out.rock = _tex(_rock(_ground(g)))
	out.flower0 = _tex(_flower(_ground(g), Color("ff8a80")))
	out.flower1 = _tex(_flower(_ground(g.darkened(0.05)), Color("fff59d")))
	tile_cache[key] = out
	return out


func _tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


func _blank(c: Color) -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return img


func _ground(g: Color) -> Image:
	var img := _blank(g)
	for p in [Vector2i(3, 4), Vector2i(11, 9), Vector2i(7, 13), Vector2i(13, 2)]:
		img.set_pixelv(p, g.darkened(0.12))
	img.set_pixel(4, 4, g.lightened(0.1))
	return img


func _path() -> Image:
	var c := Color("e6d3a3")
	var img := _blank(c)
	for p in [Vector2i(5, 6), Vector2i(12, 11), Vector2i(2, 13), Vector2i(10, 2)]:
		img.set_pixelv(p, Color("c9b27c"))
	return img


func _grass(gc: Color) -> Image:
	var img := _blank(gc)
	var dk := gc.darkened(0.35)
	var lt := gc.lightened(0.2)
	for oy in [0, 8]:
		for bx in ([1, 6, 11] if oy == 0 else [3, 8, 13]):
			for y in range(oy + 2, oy + 8):
				img.set_pixel(bx + 1, y, dk)
			for y in range(oy + 4, oy + 8):
				if bx >= 0:
					img.set_pixel(bx, y, dk)
				if bx + 2 < 16:
					img.set_pixel(bx + 2, y, dk)
			img.set_pixel(bx + 1, oy + 1, lt)
	return img


func _tree(base: Image, tc: Color) -> Image:
	var img: Image = base.duplicate()
	var trunk := Color("6d4c41")
	for y in range(11, 16):
		for x in range(6, 10):
			img.set_pixel(x, y, OL if x == 6 or x == 9 or y == 15 else trunk)
	var c := Vector2(7.5, 6.5)
	for y in 15:
		for x in 16:
			var d := Vector2(x, y).distance_to(c)
			if d > 7.3:
				continue
			var col: Color
			if d > 6.3:
				col = OL
			elif x + y < 9:
				col = tc.lightened(0.25)
			elif x + y > 17:
				col = tc.darkened(0.3)
			else:
				col = tc
			img.set_pixel(x, y, col)
	img.set_pixel(5, 4, tc.lightened(0.45))
	img.set_pixel(10, 8, tc.darkened(0.15))
	return img


func _rock(base: Image) -> Image:
	var img: Image = base.duplicate()
	var c := Vector2(7.5, 9.0)
	for y in 16:
		for x in 16:
			var d := Vector2(x, (y - c.y) * 1.25 + c.y).distance_to(c)
			if d > 7.3:
				continue
			var col := Color("8d8d80")
			if d > 6.3:
				col = OL
			elif x + y < 13:
				col = Color("b0b0a2")
			elif x + y > 20:
				col = Color("5d5d55")
			img.set_pixel(x, y, col)
	return img


func _flower(base: Image, pc: Color) -> Image:
	var img: Image = base.duplicate()
	for fp in [Vector2i(4, 5), Vector2i(11, 10)]:
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			img.set_pixelv(fp + d, pc)
		img.set_pixelv(fp, Color("ffeb3b"))
	return img
