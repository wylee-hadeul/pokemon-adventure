extends Node2D
## 개발용: 모든 포켓몬/사람/볼 그림을 한 화면에 그려 저장. godot --path . res://preview.tscn -- --out=/tmp/p.png
const Px = preload("res://scripts/px.gd")
const Data = preload("res://scripts/data.gd")


func _ready() -> void:
	queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var out := "/tmp/p.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 400, 700), Color("a5d6a7"))
	var i := 0
	for id in Data.MONS:
		var x := 30 + (i % 6) * 56
		var y := 64 + (i / 6) * 76
		Px.mon(self, id, Vector2(x, y), 0.9)
		i += 1
	Px.trainer(self, Vector2(40, 520), false)
	Px.trainer(self, Vector2(90, 520), true)
	Px.oak(self, Vector2(140, 520))
	for j in Data.BALLS.size():
		Px.ball(self, Vector2(190 + j * 22, 500), Data.BALLS[j])
