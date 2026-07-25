# 弓箭手 (archer)
class_name ArcherCharacter

const PROJ_ARROW = preload("res://assets/16-20260703142620.png")
const PROJ_ARROW_FIRE = preload("res://assets/18-20260703142934.png")
const PROJ_ARROW_ULT = preload("res://assets/IMG-20260703-143031.png")
const PROJ_ARROW_ULT_FIRE = preload("res://assets/IMG-20260703-143038.png")
const ARCHER_ANI_DIR = "res://assets/char_ani/archer/"

static func get_config() -> Dictionary:
	return {
		"id": "archer", "name": "弓箭手", "hp": 80, "max_energy": 100, "energy_regen": 0.07,
		"speed": 2.0, "attack_range": 0, "attack_damage": 0,
		"attack_cooldown": 0, "attack_delay": 0, "attack_duration": 0,
		"fields": {"arrows":10,"max_arrows":10,"arrow_regen_timer":0,"arrow_regen_rate":480,"fire_arrow_buff":false,"fire_arrow_timer":0,"tracking_buff":false,"tracking_timer":0,"charging_attack":false,"charge_start_time":0},
		"world_arrays": [],
		"animations": {
			"idle": FrameAnimation.load_from_frames(ARCHER_ANI_DIR + "idle/", "archer_idle_f_", [{"index": 1, "duration": 999.0}], true),
			"walk": FrameAnimation.load_from_frames(ARCHER_ANI_DIR + "walk/", "archer_walk_f_", [{"index": 1, "duration": 999.0}], true),
			"jump": FrameAnimation.load_from_frames(ARCHER_ANI_DIR + "jump/", "archer_jump_f_", [{"index": 1, "duration": 999.0}], true),
			"attack": FrameAnimation.load_from_frames(ARCHER_ANI_DIR + "attack/", "archer_attack_f_", [{"index": 1, "duration": 2.0}], false),
			"ult": FrameAnimation.load_from_frames(ARCHER_ANI_DIR + "ult/", "archer_ult_f_", [{"index": 1, "duration": 3.0}], false),
			"charge": FrameAnimation.load_from_frames(ARCHER_ANI_DIR + "charge/", "archer_charge_f_", [{"index": 1, "duration": 999.0}], true),
		},
		"dex": {
			"icon": "🏹",
			"intro": "箭羽无声，掠影无形。他的箭从不落空，就像风从不问方向——在你进入射程的那一刻，终点已被标记。距离是他的盟友，而你，只是靶心上的一个点。\n\"跑吧，我喜欢猎物挣扎的样子。\"",
			"stats": [{"label": "生命", "value": "80"}, {"label": "能量上限", "value": "100"}],
			"skills": [
				{"name": "射箭（普通攻击）", "desc": "长按蓄力，松开发射。蓄力时间影响伤害和能量消耗：0~1 秒：5 伤害 / 5 能量；1~2 秒：8 伤害 / 10 能量；2 秒以上：12 伤害 / 15 能量。可移动和跳跃。", "meta": "消耗：5~15 能量 ｜ 冷却：无"},
				{"name": "火矢（技能一）", "desc": "为射箭附加火焰效果，持续 7 秒。箭矢消失后产生一团火焰，对手站在火焰上每 0.5 秒受到 2 点伤害。", "meta": "消耗：20 能量 ｜ 冷却：15 秒"},
				{"name": "追踪（技能二）", "desc": "射出的箭矢具有轻微追踪效果，持续 10 秒。", "meta": "消耗：20 能量 ｜ 冷却：15 秒"},
				{"name": "箭雨（大招）", "desc": "从天上降下 20 支箭矢落在自身附近，每支造成 5 点伤害（受火矢加成，附带火焰效果）。", "meta": "消耗：100 能量 ｜ 冷却：8 秒"},
			]
		},
	}

static func create_skills() -> Array:
	return [
		Skill.new("skill1", "火矢", 900, 20, func(owner: Fighter): return not owner.fire_arrow_buff, Callable(_skill1)),
		Skill.new("skill2", "追踪", 900, 20, func(owner: Fighter): return not owner.tracking_buff, Callable(_skill2)),
		Skill.new("ult", "箭雨", 480, 100, Callable(), Callable(_ult)),
	]

static func _skill1(owner: Fighter) -> Dictionary:
	owner.fire_arrow_buff = true
	owner.fire_arrow_timer = 600
	Fighter.emit_particles(owner.pos_x+owner.w/2, owner.pos_y+owner.h/2, 30, Color(1.0,0.27,0.0), 4, 6, "star")
	return {"success": true}

static func _skill2(owner: Fighter) -> Dictionary:
	owner.tracking_buff = true
	owner.tracking_timer = 600
	Fighter.emit_particles(owner.pos_x+owner.w/2, owner.pos_y+owner.h/2, 30, Color(0.27,0.87,1.0), 4, 6, "star")
	return {"success": true}

static func _ult(owner: Fighter) -> Dictionary:
	for i in 20:
		var angle = randf() * PI * 2
		var dist = randf() * 150
		var center_x = owner.pos_x + owner.w/2
		var tx = center_x + cos(angle) * dist
		var ult_img = PROJ_ARROW_ULT_FIRE if owner.fire_arrow_buff else PROJ_ARROW_ULT
		GameWorld.projectiles.append({"x":tx-16,"y":-30-randf()*50,"w":32,"h":20,"vx":(randf()-0.5)*0.5,"vy":3+randf()*2,"life":120,"damage":5,"owner":owner,"type":"arrow_ult","color":Color(0.8,0.53,0.0),"reflected":false,"img":ult_img,"is_fire":owner.fire_arrow_buff})
	return {"success": true}

# ══════════════════════════════════════════════════════════════════
#  update_systems — 每帧逻辑（CharacterSystems 调度）
# ══════════════════════════════════════════════════════════════════
static func update_systems(f: Fighter):
	if f.char_id != "archer" or f.hp <= 0:
		return

	# ── 箭矢自动回复 ──
	if f.arrows < f.max_arrows:
		f.arrow_regen_timer += 1
		if f.arrow_regen_timer >= f.arrow_regen_rate:
			f.arrow_regen_timer = 0
			f.arrows += 1

	# ── 火矢 buff 计时 ──
	if f.fire_arrow_buff:
		f.fire_arrow_timer -= 1
		if f.fire_arrow_timer <= 0:
			f.fire_arrow_buff = false

	# ── 追踪 buff 计时 ──
	if f.tracking_buff:
		f.tracking_timer -= 1
		if f.tracking_timer <= 0:
			f.tracking_buff = false
