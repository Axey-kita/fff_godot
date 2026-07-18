# 骑士 (knight)
class_name KnightCharacter

const PROJ_SWORD = preload("res://assets/IMG-20260702-011106.png")

static func get_config() -> Dictionary:
	print("[Knight] get_config() start, loading images...")
	var idle_img = load("res://assets/IMG-20260702-005046.png")
	var jump_img = load("res://assets/IMG-20260702-005057.png")
	var atk_img = load("res://assets/IMG-20260702-010935.png")
	var ult_img = load("res://assets/IMG-20260702-005138.png")
	print("[Knight] images loaded: idle=", idle_img != null, " jump=", jump_img != null, " attack=", atk_img != null, " ult=", ult_img != null)
	if idle_img == null:
		printerr("[Knight] idle image FAILED: res://assets/IMG-20260702-005046.png")
		print("[Knight] ResourceLoader.exists=", ResourceLoader.exists("res://assets/IMG-20260702-005046.png"))
	return {
		"id": "knight", "name": "骑士", "hp": 100, "max_energy": 100, "energy_regen": 0.05,
		"speed": 2.25, "attack_range": 44, "attack_damage": 5,
		"attack_cooldown": 60, "attack_delay": 8, "attack_duration": 68,
		"fields": {}, "world_arrays": [],
		"images": {
			"idle": idle_img,
			"walk": idle_img,
			"jump": jump_img,
			"attack": atk_img,
			"ult": ult_img,
		},
		"dex": {
			"icon": "⚔️",
			"intro": "剑锋划破硝烟，盾面刻满战痕。他从不闪避，因为身后即是王座——凡人之躯，亦可铸就城墙。冲锋的号角撕裂长夜，铁蹄踏碎一切犹豫。\n\"难道你只有这点觉悟吗？\"",
			"stats": [{"label": "生命", "value": "100"}, {"label": "能量上限", "value": "100"}],
			"skills": [
				{"name": "挥砍（普通攻击）", "desc": "对近身敌人造成 5 点伤害。", "meta": "消耗：无 ｜ 冷却：1 秒"},
				{"name": "剑气（技能一）", "desc": "向前方发射一道飞行剑气，造成 10 点伤害。", "meta": "消耗：20 能量 ｜ 冷却：8 秒"},
				{"name": "招架（技能二）", "desc": "进入格挡姿态，持续 0.8 秒，期间可反弹敌方飞行道具，成功反弹后恢复 20 点能量。", "meta": "消耗：30 能量 ｜ 冷却：10 秒"},
				{"name": "爆发斩（大招）", "desc": "消耗全部能量，对近距离敌人（半径约 128 像素）造成 40 点伤害并击飞；对远处敌人则发射大型剑气，造成 25 点伤害。", "meta": "消耗：100 能量 ｜ 冷却：5 秒"},
			]
		},
	}

static func create_skills() -> Array:
	return [
		Skill.new("skill1", "剑气", 480, 20, Callable(), Callable(_skill1)),
		Skill.new("skill2", "招架", 600, 30, func(owner: Fighter): return owner.grounded, Callable(_skill2)),
		Skill.new("ult", "爆发斩", 300, 100, Callable(), Callable(_ult)),
	]

static func _skill1(owner: Fighter) -> Dictionary:
	var dir = owner.facing
	var px = owner.pos_x + (owner.w if dir == 1 else 0)
	var py = owner.pos_y + 30
	GameWorld.projectiles.append({"x":px-16,"y":py-10,"w":32,"h":20,"vx":5*dir,"vy":0,"life":90,"damage":10,"owner":owner,"type":"knight_sword","color":Color(0.53,0.87,1.0),"reflected":false,"img":PROJ_SWORD})
	Fighter.emit_particles(px, py, 30, Color(0.53,0.87,1.0), 5, 6, "circle")
	return {"success": true}

static func _skill2(owner: Fighter) -> Dictionary:
	owner.blocking = true
	owner.block_timer = 48
	Fighter.emit_particles(owner.pos_x + owner.w/2, owner.pos_y + owner.h/2, 25, Color(1.0,0.87,0.27), 4, 6, "star")
	return {"success": true}

static func _ult(owner: Fighter) -> Dictionary:
	GameWorld.hit_stop = 20
	Fighter.emit_particles(owner.pos_x + owner.w/2, owner.pos_y + owner.h/2, 100, Color(1.0,0.67,0.0), 12, 14, "star")
	var radius = 128.0
	var target = GameWorld.get_opponent(owner)
	var dist = sqrt(pow(owner.pos_x+owner.w/2 - target.pos_x - target.w/2, 2) + pow(owner.pos_y+owner.h/2 - target.pos_y - target.h/2, 2))
	if dist < radius:
		Fighter.apply_damage(target, 40, owner)
		target.vy = -10
		target.vx = owner.facing * 8
	else:
		GameWorld.projectiles.append({"x":owner.pos_x+(owner.w if owner.facing>0 else -80),"y":owner.pos_y-10,"w":70,"h":70,"vx":10*owner.facing,"vy":0,"life":35,"damage":25,"owner":owner,"type":"knight_ult","color":Color(1.0,0.87,0.27),"reflected":false})
	return {"success": true}
