# 影武者 (shadowwarrior)
class_name ShadowwarriorCharacter

static func get_config() -> Dictionary:
	return {
		"id": "shadowwarrior", "name": "影武者", "hp": 90, "max_energy": 100, "energy_regen": 0.05,
		"speed": 2.1, "attack_range": 44, "attack_damage": 5,
		"attack_cooldown": 60, "attack_delay": 8, "attack_duration": 68,
		"fields": {"stealth_active":false,"stealth_timer":0,"last_skill_time":-999,"retreat_timer":0,"retreat_dir":1,"break_strike_timer":0,"pending_trap":false,"shadow_trap_active":false,"shadow_trap":{},"pending_clones":false,"clone_reveal_timer":0,"iaido_active":false,"iaido_timer":0,"iaido_frozen":false,"iaido_dir":1,"iaido_slash":{}},
		"world_arrays": ["phantoms"],
		"images": {
			"idle": load("res://assets/无标题61_20260708190607.png"),
			"walk": load("res://assets/无标题75_20260709014958.png"),
			"jump": load("res://assets/无标题62_20260708190832.png"),
			"attack": load("res://assets/无标题73_20260708195446.png"),
			"ult": load("res://assets/无标题68_20260708195710.png"),
		},
		"dex": {
			"icon": "🥷",
			"intro": "影随身动，刃自暗生。他不与你正面相搏，只在你的呼吸之间往返穿梭——当你终于看清那道残影时，刀锋早已归鞘。\n\"你砍中的，从来都不是我。\"",
			"stats": [{"label": "生命", "value": "90"}, {"label": "能量上限", "value": "100"}],
			"skills": [
				{"name": "胧月·斩（普通攻击）", "desc": "挥刀劈砍，造成 5 点伤害。", "meta": "消耗：无 ｜ 冷却：1 秒"},
				{"name": "影缚·袭（技能一）", "desc": "在原地生成暗影替身陷阱（存在 5 秒）。敌人靠近时替身化为影球包裹并抓取敌人，包裹造成 5 点伤害，随后炸裂造成 10 点伤害。", "meta": "消耗：15 能量 ｜ 冷却：12 秒"},
				{"name": "幻影·舞（技能二）", "desc": "生成 2 个幻影分身（各 5 点血量），以 0.8 倍移速冲向敌人，仅能使用胧月·斩。敌方会优先攻击分身。分身存在时，本体移速提升至 1.1 倍。", "meta": "消耗：25 能量 ｜ 冷却：20 秒"},
				{"name": "影舞流·居合（大招）", "desc": "向前快速位移并留下一道刀光，自身姿态定格。刀光命中造成 10 点伤害并抓取，3 秒后爆炸造成 30 点伤害。", "meta": "消耗：100 能量 ｜ 冷却：8 秒"},
				{"name": "夜樱·隐（特殊机制）", "desc": "使用技能1/2 后 1 秒内使用胧月·斩，改为后撤并隐身（对手视角消失），获得 1 秒无敌，最多维持 6 秒。隐身下胧月·斩变为破影一击（前冲，10 点伤害）。任意攻击/技能/大招都会解除隐身。", "meta": "—"},
			]
		},
	}

static func create_skills() -> Array:
	return [
		Skill.new("attack", "胧月·斩", 60, 0, func(owner: Fighter): return owner.attack_cooldown <= 0 and not owner.attacking, Callable(_attack)),
		Skill.new("skill1", "影缚·袭", 720, 15, func(owner: Fighter): return not owner.shadow_trap_active, Callable(_skill1)),
		Skill.new("skill2", "幻影·舞", 1200, 25, Callable(), Callable(_skill2)),
		Skill.new("ult", "影舞流·居合", 480, 100, func(owner: Fighter): return owner.energy >= 100 and not owner.iaido_active, Callable(_ult)),
	]

static func _attack(owner: Fighter) -> Dictionary:
	owner.attacking = true
	owner.attack_timer = 68
	owner.attack_delay = 8
	owner.attack_hit_dealt = false
	owner.attack_cooldown = 60
	owner.state = "attack"
	return {"success": true}

static func _skill1(owner: Fighter) -> Dictionary:
	owner.pending_trap = true
	owner.last_skill_time = GameWorld.frame
	Fighter.emit_particles(owner.pos_x+owner.w/2, owner.pos_y+owner.h/2, 20, Color(0.4,0.2,0.67), 4, 6, "star")
	return {"success": true}

static func _skill2(owner: Fighter) -> Dictionary:
	owner.pending_clones = true
	owner.clone_reveal_timer = 30
	owner.last_skill_time = GameWorld.frame
	Fighter.emit_particles(owner.pos_x+owner.w/2, owner.pos_y+owner.h/2, 30, Color(0.53,0.27,0.8), 5, 7, "star")
	return {"success": true}

static func _ult(owner: Fighter) -> Dictionary:
	var dir = owner.facing
	owner.iaido_active = true
	owner.iaido_timer = 180
	owner.iaido_dir = dir
	owner.iaido_frozen = true
	owner.iaido_slash = {"x":owner.pos_x+(owner.w if dir==1 else -360),"y":owner.pos_y-4,"w":360,"h":owner.h+8,"dir":dir,"hit_dealt":false}
	Fighter.emit_particles(owner.pos_x+owner.w/2, owner.pos_y+owner.h/2, 40, Color(0.53,0.27,0.8), 8, 10, "star")
	return {"success": true}
