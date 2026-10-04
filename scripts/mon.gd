extends RefCounted
## 포켓몬 한 마리. 능력치 계산, 기술, 경험치/레벨업, 진화, 저장.

const Data = preload("res://scripts/data.gd")

var id := "pikachu"
var level := 5
var exp := 0
var hp := 1
var moves: Array = []   # 기술 id (최대 4개)


static func create(species: String, lv: int):
	var m = load("res://scripts/mon.gd").new()
	m.id = species
	m.level = lv
	m.exp = m.exp_for(lv)
	m.moves = []
	for e in Data.MONS[species].learn:
		if e[0] <= lv:
			m._add_move(e[1])
	m.hp = m.max_hp()
	return m


func data() -> Dictionary:
	return Data.MONS[id]


func name() -> String:
	return data().name


func types() -> Array:
	return data().types


func _stat(i: int) -> int:
	return int(2.0 * data().base[i] * level / 100.0) + 5


func max_hp() -> int:
	return int(2.0 * data().base[0] * level / 100.0) + level + 10


func atk() -> int:
	return _stat(1)


func def() -> int:
	return _stat(2)


func spd() -> int:
	return _stat(3)


func fainted() -> bool:
	return hp <= 0


func heal_full() -> void:
	hp = max_hp()


## 레벨 n에 필요한 누적 경험치 (중간 빠르기: n^3을 살짝 완화)
func exp_for(n: int) -> int:
	return int(pow(n, 3) * 0.8)


func _add_move(mv: String) -> String:
	if moves.has(mv):
		return ""
	moves.append(mv)
	if moves.size() > 4:
		return moves.pop_front()  # 가장 오래된 기술을 잊는다
	return ""


## 경험치를 얻고, 일어난 일(레벨업/새 기술)을 메시지 목록으로 돌려준다
func gain_exp(amount: int) -> Array:
	var msgs: Array = []
	exp += amount
	while level < 100 and exp >= exp_for(level + 1):
		var old_max := max_hp()
		level += 1
		hp += max_hp() - old_max
		msgs.append("%s의 레벨이 %d(으)로 올랐다!" % [name(), level])
		for e in data().learn:
			if e[0] == level:
				var forgot := _add_move(e[1])
				var mn: String = Data.MOVES[e[1]][0]
				if forgot != "":
					msgs.append("%s는 %s를 잊고 %s를 배웠다!" % [name(), Data.MOVES[forgot][0], mn])
				elif mn != "":
					msgs.append("%s는 %s를 배웠다!" % [name(), mn])
	return msgs


## 진화할 수 있으면 진화 대상 id ("*eeveelution"이면 선택 필요)
func evo_target() -> String:
	var evo = data().get("evo")
	if evo != null and level >= evo[0]:
		return evo[1]
	return ""


func evolve(to: String) -> void:
	var ratio: float = float(hp) / max(1, max_hp())
	id = to
	hp = max(1, int(max_hp() * ratio))
	for e in data().learn:
		if e[0] <= level:
			_add_move(e[1])


func to_dict() -> Dictionary:
	return {"id": id, "lv": level, "exp": exp, "hp": hp, "moves": moves}


static func from_dict(d: Dictionary):
	var m = load("res://scripts/mon.gd").new()
	m.id = d.id
	m.level = int(d.lv)
	m.exp = int(d.exp)
	m.hp = int(d.hp)
	m.moves = d.moves.duplicate()
	return m


# ------------------------------------------------------------------ 전투 공식

## 피해량과 상성 배율을 돌려준다
static func damage(att, deff, mv: String, rng: RandomNumberGenerator) -> Array:
	var m: Array = Data.MOVES[mv]
	var power: int = m[2]
	if power <= 0:
		return [0, 1.0, false]
	var eff := Data.effect(m[1], deff.types())
	var stab := 1.5 if att.types().has(m[1]) else 1.0
	var crit := rng.randf() < 0.0625
	var base: float = ((2.0 * att.level / 5.0 + 2.0) * power * att.atk() / max(1, deff.def())) / 50.0 + 2.0
	var dmg: float = base * stab * eff * rng.randf_range(0.85, 1.0) * (1.5 if crit else 1.0)
	if eff > 0.0:
		dmg = max(1.0, dmg)
	return [int(dmg), eff, crit]


## 포획 판정: 흔들림 횟수(0~3)와 성공 여부
static func catch_try(target, ball: String, rng: RandomNumberGenerator) -> Array:
	var rate: float = Data.ITEMS[ball].rate
	if rate >= 255.0:
		return [3, true]
	var mx: float = target.max_hp()
	var a: float = (3.0 * mx - 2.0 * target.hp) * target.data().catch * rate / (3.0 * mx)
	var p: float = clamp(a / 255.0, 0.02, 1.0)
	var shakes := 0
	for i in 3:
		if rng.randf() < pow(p, 0.33):
			shakes += 1
		else:
			break
	return [shakes, shakes == 3]  # 세 번 다 흔들리면 성공 (전체 확률 ≈ p)
