extends RefCounted
## 게임 데이터: 포켓몬, 기술, 타입 상성, 아이템, 스테이지, 대사.

const TYPES := {
	"normal": {"name": "노말", "col": Color("a8a878")},
	"fire": {"name": "불꽃", "col": Color("f08030")},
	"water": {"name": "물", "col": Color("6890f0")},
	"grass": {"name": "풀", "col": Color("78c850")},
	"electric": {"name": "전기", "col": Color("f8d030")},
	"flying": {"name": "비행", "col": Color("a890f0")},
	"bug": {"name": "벌레", "col": Color("a8b820")},
	"ground": {"name": "땅", "col": Color("e0c068")},
	"rock": {"name": "바위", "col": Color("b8a038")},
	"poison": {"name": "독", "col": Color("a040a0")},
}

## 공격 타입 → 방어 타입 배율 (없으면 1배)
const CHART := {
	"normal": {"rock": 0.5},
	"fire": {"fire": 0.5, "water": 0.5, "grass": 2.0, "bug": 2.0, "rock": 0.5},
	"water": {"fire": 2.0, "water": 0.5, "grass": 0.5, "ground": 2.0, "rock": 2.0},
	"grass": {"fire": 0.5, "water": 2.0, "grass": 0.5, "flying": 0.5, "bug": 0.5, "ground": 2.0, "rock": 2.0, "poison": 0.5},
	"electric": {"water": 2.0, "grass": 0.5, "electric": 0.5, "flying": 2.0, "ground": 0.0},
	"flying": {"grass": 2.0, "electric": 0.5, "bug": 2.0, "rock": 0.5},
	"bug": {"fire": 0.5, "grass": 2.0, "flying": 0.5, "poison": 0.5},
	"ground": {"fire": 2.0, "grass": 0.5, "electric": 2.0, "flying": 0.0, "bug": 0.5, "rock": 2.0, "poison": 2.0},
	"rock": {"fire": 2.0, "flying": 2.0, "bug": 2.0, "ground": 0.5},
	"poison": {"grass": 2.0, "ground": 0.5, "rock": 0.5, "poison": 0.5},
}

static func effect(atk_type: String, def_types: Array) -> float:
	var m := 1.0
	for t in def_types:
		m *= CHART.get(atk_type, {}).get(t, 1.0)
	return m


## [이름, 타입, 위력, 명중, 우선도]
const MOVES := {
	"tackle": ["몸통박치기", "normal", 40, 100, 0],
	"scratch": ["할퀴기", "normal", 40, 100, 0],
	"quick_attack": ["전광석화", "normal", 40, 100, 1],
	"bite": ["물기", "normal", 60, 100, 0],
	"take_down": ["돌진", "normal", 90, 85, 0],
	"hyper_fang": ["필살앞니", "normal", 80, 90, 0],
	"slash": ["베어가르기", "normal", 70, 100, 0],
	"splash": ["튀어오르기", "normal", 0, 100, 0],
	"thundershock": ["전기쇼크", "electric", 40, 100, 0],
	"spark": ["스파크", "electric", 65, 100, 0],
	"thunderbolt": ["10만볼트", "electric", 90, 100, 0],
	"thunder": ["번개", "electric", 110, 70, 0],
	"ember": ["불꽃세례", "fire", 40, 100, 0],
	"flame_wheel": ["화염자동차", "fire", 60, 100, 0],
	"flamethrower": ["화염방사", "fire", 90, 100, 0],
	"fire_blast": ["불대문자", "fire", 110, 85, 0],
	"bubble": ["거품", "water", 40, 100, 0],
	"water_gun": ["물대포", "water", 40, 100, 0],
	"water_pulse": ["물의파동", "water", 60, 100, 0],
	"hydro_pump": ["하이드로펌프", "water", 110, 80, 0],
	"vine_whip": ["덩굴채찍", "grass", 45, 100, 0],
	"absorb": ["흡수", "grass", 30, 100, 0],
	"razor_leaf": ["잎날가르기", "grass", 55, 95, 0],
	"solar_beam": ["솔라빔", "grass", 120, 90, 0],
	"poison_sting": ["독침", "poison", 25, 100, 0],
	"sludge": ["오물공격", "poison", 65, 100, 0],
	"gust": ["바람일으키기", "flying", 40, 100, 0],
	"wing_attack": ["날개치기", "flying", 60, 100, 0],
	"bug_bite": ["벌레먹기", "bug", 60, 100, 0],
	"mud_slap": ["진흙뿌리기", "ground", 30, 100, 0],
	"dig": ["구멍파기", "ground", 80, 100, 0],
	"rock_throw": ["돌떨구기", "rock", 50, 90, 0],
	"rock_slide": ["스톤샤워", "rock", 75, 90, 0],
}

## 포켓몬: 타입, 종족값[HP,공격,방어,스피드], 포획률, 기초경험치, 진화, 배우는 기술
const MONS := {
	"pikachu": {"name": "피카츄", "types": ["electric"], "base": [35, 55, 40, 90], "catch": 190, "exp": 112, "evo": [22, "raichu"],
		"learn": [[1, "thundershock"], [1, "quick_attack"], [12, "spark"], [20, "thunderbolt"], [30, "thunder"]]},
	"raichu": {"name": "라이츄", "types": ["electric"], "base": [60, 90, 55, 110], "catch": 75, "exp": 218,
		"learn": [[1, "thundershock"], [1, "quick_attack"], [12, "spark"], [20, "thunderbolt"], [30, "thunder"]]},
	"eevee": {"name": "이브이", "types": ["normal"], "base": [55, 55, 50, 55], "catch": 45, "exp": 65, "evo": [25, "*eeveelution"],
		"learn": [[1, "tackle"], [1, "quick_attack"], [10, "bite"], [18, "take_down"]]},
	"vaporeon": {"name": "샤미드", "types": ["water"], "base": [130, 65, 60, 65], "catch": 45, "exp": 184,
		"learn": [[1, "water_gun"], [1, "bite"], [25, "water_pulse"], [36, "hydro_pump"]]},
	"jolteon": {"name": "쥬피썬더", "types": ["electric"], "base": [65, 65, 60, 130], "catch": 45, "exp": 184,
		"learn": [[1, "thundershock"], [1, "bite"], [25, "thunderbolt"], [36, "thunder"]]},
	"flareon": {"name": "부스터", "types": ["fire"], "base": [65, 130, 60, 65], "catch": 45, "exp": 184,
		"learn": [[1, "ember"], [1, "bite"], [25, "flamethrower"], [36, "fire_blast"]]},
	"squirtle": {"name": "꼬부기", "types": ["water"], "base": [44, 48, 65, 43], "catch": 45, "exp": 63, "evo": [16, "wartortle"],
		"learn": [[1, "tackle"], [1, "bubble"], [9, "water_gun"], [18, "bite"], [24, "water_pulse"], [38, "hydro_pump"]]},
	"wartortle": {"name": "어니부기", "types": ["water"], "base": [59, 63, 80, 58], "catch": 45, "exp": 142, "evo": [36, "blastoise"],
		"learn": [[1, "tackle"], [1, "bubble"], [9, "water_gun"], [18, "bite"], [24, "water_pulse"], [38, "hydro_pump"]]},
	"blastoise": {"name": "거북왕", "types": ["water"], "base": [79, 83, 100, 78], "catch": 45, "exp": 239,
		"learn": [[1, "tackle"], [1, "bubble"], [9, "water_gun"], [18, "bite"], [24, "water_pulse"], [38, "hydro_pump"]]},
	"bulbasaur": {"name": "이상해씨", "types": ["grass", "poison"], "base": [45, 49, 49, 45], "catch": 45, "exp": 64, "evo": [16, "ivysaur"],
		"learn": [[1, "tackle"], [1, "vine_whip"], [9, "poison_sting"], [15, "razor_leaf"], [25, "sludge"], [34, "solar_beam"]]},
	"ivysaur": {"name": "이상해풀", "types": ["grass", "poison"], "base": [60, 62, 63, 60], "catch": 45, "exp": 142, "evo": [32, "venusaur"],
		"learn": [[1, "tackle"], [1, "vine_whip"], [9, "poison_sting"], [15, "razor_leaf"], [25, "sludge"], [34, "solar_beam"]]},
	"venusaur": {"name": "이상해꽃", "types": ["grass", "poison"], "base": [80, 82, 83, 80], "catch": 45, "exp": 236,
		"learn": [[1, "tackle"], [1, "vine_whip"], [9, "poison_sting"], [15, "razor_leaf"], [25, "sludge"], [34, "solar_beam"]]},
	"charmander": {"name": "파이리", "types": ["fire"], "base": [39, 52, 43, 65], "catch": 45, "exp": 62, "evo": [16, "charmeleon"],
		"learn": [[1, "scratch"], [1, "ember"], [12, "flame_wheel"], [20, "slash"], [28, "flamethrower"], [40, "fire_blast"]]},
	"charmeleon": {"name": "리자드", "types": ["fire"], "base": [58, 64, 58, 80], "catch": 45, "exp": 142, "evo": [36, "charizard"],
		"learn": [[1, "scratch"], [1, "ember"], [12, "flame_wheel"], [20, "slash"], [28, "flamethrower"], [40, "fire_blast"]]},
	"charizard": {"name": "리자몽", "types": ["fire", "flying"], "base": [78, 84, 78, 100], "catch": 45, "exp": 240,
		"learn": [[1, "scratch"], [1, "ember"], [12, "flame_wheel"], [20, "slash"], [28, "flamethrower"], [36, "wing_attack"], [40, "fire_blast"]]},
	"pidgey": {"name": "구구", "types": ["normal", "flying"], "base": [40, 45, 40, 56], "catch": 255, "exp": 50, "evo": [18, "pidgeotto"],
		"learn": [[1, "tackle"], [1, "gust"], [9, "quick_attack"], [20, "wing_attack"]]},
	"pidgeotto": {"name": "피죤", "types": ["normal", "flying"], "base": [63, 60, 55, 71], "catch": 120, "exp": 122,
		"learn": [[1, "tackle"], [1, "gust"], [9, "quick_attack"], [20, "wing_attack"]]},
	"rattata": {"name": "꼬렛", "types": ["normal"], "base": [30, 56, 35, 72], "catch": 255, "exp": 51,
		"learn": [[1, "tackle"], [4, "quick_attack"], [10, "bite"], [20, "hyper_fang"]]},
	"caterpie": {"name": "캐터피", "types": ["bug"], "base": [45, 30, 35, 45], "catch": 255, "exp": 39,
		"learn": [[1, "tackle"], [6, "bug_bite"]]},
	"sandshrew": {"name": "모래두지", "types": ["ground"], "base": [50, 75, 85, 40], "catch": 255, "exp": 60,
		"learn": [[1, "scratch"], [5, "mud_slap"], [17, "slash"], [24, "dig"]]},
	"zubat": {"name": "주뱃", "types": ["poison", "flying"], "base": [40, 45, 35, 55], "catch": 255, "exp": 49,
		"learn": [[1, "poison_sting"], [5, "bite"], [13, "wing_attack"], [24, "sludge"]]},
	"oddish": {"name": "뚜벅쵸", "types": ["grass", "poison"], "base": [45, 50, 55, 30], "catch": 255, "exp": 64,
		"learn": [[1, "absorb"], [5, "poison_sting"], [14, "razor_leaf"], [26, "sludge"]]},
	"psyduck": {"name": "고라파덕", "types": ["water"], "base": [50, 52, 48, 55], "catch": 190, "exp": 64,
		"learn": [[1, "scratch"], [4, "water_gun"], [16, "water_pulse"], [30, "hydro_pump"]]},
	"growlithe": {"name": "가디", "types": ["fire"], "base": [55, 70, 45, 60], "catch": 190, "exp": 70,
		"learn": [[1, "bite"], [1, "ember"], [15, "flame_wheel"], [28, "flamethrower"]]},
	"geodude": {"name": "꼬마돌", "types": ["rock", "ground"], "base": [40, 80, 100, 20], "catch": 255, "exp": 60,
		"learn": [[1, "tackle"], [6, "rock_throw"], [16, "dig"], [22, "rock_slide"]]},
	"magikarp": {"name": "잉어킹", "types": ["water"], "base": [20, 10, 55, 80], "catch": 255, "exp": 40, "evo": [20, "gyarados"],
		"learn": [[1, "splash"], [15, "tackle"]]},
	"gyarados": {"name": "갸라도스", "types": ["water", "flying"], "base": [95, 125, 79, 81], "catch": 45, "exp": 189,
		"learn": [[1, "bite"], [20, "water_pulse"], [25, "wing_attack"], [35, "hydro_pump"]]},
	"voltorb": {"name": "찌리리공", "types": ["electric"], "base": [40, 30, 50, 100], "catch": 190, "exp": 66,
		"learn": [[1, "tackle"], [6, "thundershock"], [15, "spark"], [29, "thunderbolt"]]},
}

const STARTERS := ["pikachu", "eevee", "squirtle", "bulbasaur", "charmander"]
const EEVEELUTIONS := ["vaporeon", "jolteon", "flareon"]

# ------------------------------------------------------------------ 아이템
const ITEMS := {
	"pokeball": {"name": "몬스터볼", "price": 0, "rate": 1.0, "desc": "기본 볼. 공짜!", "col": Color("e53935")},
	"greatball": {"name": "슈퍼볼", "price": 200, "rate": 1.5, "desc": "몬스터볼보다 잘 잡힌다", "col": Color("1e88e5")},
	"ultraball": {"name": "하이퍼볼", "price": 600, "rate": 2.0, "desc": "아주 잘 잡힌다", "col": Color("fdd835")},
	"masterball": {"name": "마스터볼", "price": 1000, "rate": 255.0, "desc": "반드시 잡힌다!", "col": Color("8e24aa")},
	"potion": {"name": "상처약", "price": 300, "heal": 30, "desc": "HP를 30 회복", "col": Color("ab47bc")},
}
const SHOP_ORDER := ["pokeball", "greatball", "ultraball", "masterball", "potion"]
const BALLS := ["pokeball", "greatball", "ultraball", "masterball"]

# ------------------------------------------------------------------ 스테이지 (무한)
const AREAS := [
	{"name": "상록숲", "pool": ["caterpie", "pidgey", "rattata", "oddish", "pikachu"], "ground": Color("8bc34a"), "grass": Color("4caf50"), "tree": Color("2e7d32"),
		"leader": "숲의 관장 민우", "team": ["pidgeotto", "oddish", "caterpie"]},
	{"name": "바위산 동굴", "pool": ["zubat", "geodude", "sandshrew", "rattata"], "ground": Color("a1887f"), "grass": Color("8d6e63"), "tree": Color("5d4037"),
		"leader": "바위 관장 웅", "team": ["geodude", "sandshrew", "zubat"]},
	{"name": "푸른 호숫가", "pool": ["psyduck", "magikarp", "oddish", "voltorb", "pidgey"], "ground": Color("aed581"), "grass": Color("66bb6a"), "tree": Color("388e3c"),
		"leader": "물 관장 이슬", "team": ["psyduck", "gyarados", "magikarp"]},
	{"name": "불꽃 화산", "pool": ["growlithe", "geodude", "voltorb", "rattata", "sandshrew"], "ground": Color("bcaaa4"), "grass": Color("a1887f"), "tree": Color("6d4c41"),
		"leader": "불꽃 관장 강철", "team": ["growlithe", "geodude", "voltorb"]},
]

static func area(s: int) -> Dictionary:
	return AREAS[(s - 1) % AREAS.size()]


static func wild_level(s: int) -> int:
	return 1 + s * 2 + s / 4


static func clear_money(s: int) -> int:
	return 300 + 100 * s


const LINES := {
	"oak": [
		"어서 오너라! 포켓몬의 세계에 온 것을 환영한다!",
		"나는 오박사라고 한다. 사람들은 나를 포켓몬 박사라고 부르지.",
		"이 세계에는 포켓몬이라 불리는 신기한 생물들이 살고 있단다.",
		"자, 여기 있는 몬스터볼 다섯 개 중에서 너와 함께할 첫 포켓몬을 골라 보거라!",
	],
	"oak_after": ["좋은 선택이다! 그 포켓몬을 소중히 대해 주거라.", "몬스터볼 다섯 개도 가져가거라. 포켓몬을 잡을 때 쓰는 거란다.", "그럼, 모험을 떠나 보거라!"],
}
