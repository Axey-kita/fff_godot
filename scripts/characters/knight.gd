# 骑士 (knight)
class_name KnightCharacter

const PROJ_SWORD = preload("res://assets/fx_sword_projectile.png")
const KNIGHT_ANI_DIR = "res://assets/char_ani/knight/"

static func get_config() -> Dictionary:
	return {
		"id": "knight", "name": "骑士", "hp": 100, "max_energy": 100, "energy_regen": 0.05,
		"speed": 2.25, "attack_range": 44, "attack_damage": 5,
		"attack_cooldown": 60, "attack_delay": 8, "attack_duration": 30,
		"fields": {}, "world_arrays": [],
		"animations": {
			"idle": FrameAnimation.load_from_frames(KNIGHT_ANI_DIR + "idle/", "knight_idle_f_", [{"index": 1, "duration": 999.0}], true),
			"walk": FrameAnimation.load_from_frames(KNIGHT_ANI_DIR + "walk/", "knight_walk_f_", [{"index": 1, "duration": 999.0}], true),
			"jump": FrameAnimation.load_from_frames(KNIGHT_ANI_DIR + "jump/", "knight_jump_f_", [{"index": 1, "duration": 999.0}], true),
			"attack": FrameAnimation.load_from_frames(KNIGHT_ANI_DIR + "attack/", "knight_attack_f_", [{"index": 1, "duration": 0.5}], false),
			"ult": FrameAnimation.load_from_frames(KNIGHT_ANI_DIR + "ult/", "knight_ult_f_", [{"index": 1, "duration": 3.0}], false),
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
		GameWorld.projectiles.append({"x":owner.pos_x+(owner.w if owner.facing>0 else -80),"y":owner.pos_y-10,"w":70,"h":70,"vx":10*owner.facing,"vy":0,"life":35,"damage":25,"owner":owner,"type":"knight_ult","color":Color(1.0,0.87,0.27),"reflected":false,"img":PROJ_SWORD})
	return {"success": true}

## 输入处理（替代 input_handler.gd 中的 _input_knight）
static func handle_input(owner: Fighter, keys: Dictionary) -> int:
	var mx = 0
	if not owner.charging:
		if keys.left: mx = -1
		if keys.right: mx = 1
		if keys.up and owner.grounded and not owner.shield_active:
			owner.vy = -10
			owner.grounded = false
		if keys.attack and not owner.shield_active and owner.attack_cooldown <= 0 and not owner.attacking:
			owner.attacking = true
			owner.attack_timer = 30
			owner.attack_delay = 8
			owner.attack_hit_dealt = false
			owner.attack_cooldown = 60
			owner.state = "attack"
			keys.attack = false
		if keys.skill1 and not owner.shield_active:
			var s = owner.get_skill("skill1")
			if s:
				var r = s.try_use(owner)
				if r.get("success"):
					keys.skill1 = false
		if keys.skill2 and not owner.shield_active:
			var s = owner.get_skill("skill2")
			if s:
				var r = s.try_use(owner)
				if r.get("success"):
					keys.skill2 = false
	if keys.ult and not owner.shield_active:
		var s = owner.get_skill("ult")
		if s:
			var r = s.try_use(owner)
			if r.get("success"):
				keys.ult = false
	Fighter.apply_movement(owner, mx, 2.25)
	Fighter.update_state(owner, mx)
	return mx
