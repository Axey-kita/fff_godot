# 影武者 (shadowwarrior)
class_name ShadowwarriorCharacter

const SHADOWWARRIOR_ANI_DIR = "res://assets/char_ani/shadowwarrior/"

static func get_config() -> Dictionary:
	return {
		"id": "shadowwarrior", "name": "影武者", "hp": 90, "max_energy": 100, "energy_regen": 0.05,
		"speed": 2.1, "attack_range": 44, "attack_damage": 5,
		"attack_cooldown": 60, "attack_delay": 8, "attack_duration": 68,
		"fields": {"stealth_active":false,"stealth_timer":0,"last_skill_time":-999,"retreat_timer":0,"retreat_dir":1,"break_strike_timer":0,"pending_trap":false,"shadow_trap_active":false,"shadow_trap":{},"pending_clones":false,"clone_reveal_timer":0,"iaido_active":false,"iaido_timer":0,"iaido_frozen":false,"iaido_dir":1,"iaido_slash":{}},
		"world_arrays": ["phantoms"],
		"animations": {
			"idle": FrameAnimation.load_from_frames(SHADOWWARRIOR_ANI_DIR + "idle/", "shadowwarrior_idle_f_", [{"index": 1, "duration": 999.0}], true),
			"walk": FrameAnimation.load_from_frames(SHADOWWARRIOR_ANI_DIR + "walk/", "shadowwarrior_walk_f_", [{"index": 1, "duration": 999.0}], true),
			"jump": FrameAnimation.load_from_frames(SHADOWWARRIOR_ANI_DIR + "jump/", "shadowwarrior_jump_f_", [{"index": 1, "duration": 999.0}], true),
			"attack": FrameAnimation.load_from_frames(SHADOWWARRIOR_ANI_DIR + "attack/", "shadowwarrior_attack_f_", [{"index": 1, "duration": 2.0}], false),
			"ult": FrameAnimation.load_from_frames(SHADOWWARRIOR_ANI_DIR + "ult/", "shadowwarrior_ult_f_", [{"index": 1, "duration": 3.0}], false),
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
	owner.last_skill_time = GameWorld.frame
	Fighter.emit_particles(owner.pos_x+owner.w/2, owner.pos_y+owner.h/2, 30, Color(0.53,0.27,0.8), 5, 7, "star")
	return {"success": true}

static func _ult(owner: Fighter) -> Dictionary:
	# 居合进行中则不能再放
	if owner.iaido_active:
		return {"success": false}

	var dir = owner.facing
	owner.iaido_active = true
	owner.iaido_timer = 150
	owner.iaido_dir = dir
	owner.iaido_frozen = true
	# 刀光：从角色当前位置起，沿 facing 方向延伸 360 像素
	owner.iaido_slash = {
		"x": owner.pos_x + (owner.w if dir == 1 else -360),
		"y": owner.pos_y - 4,
		"w": 360,
		"h": owner.h + 8,
		"dir": dir,
		"hit_dealt": false,
		"start_x": owner.pos_x,  # 姿态贴图平移起点
	}

	Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 40, Color(0.53, 0.27, 0.8), 8, 10, "star")
	return {"success": true}

## 影武者系统更新：技能1陷阱 + 技能2分身 + 大招居合
static func update_systems(f: Fighter):
	# === 技能1：影缚·袭 - 创建陷阱 ===
	if f.pending_trap:
		f.pending_trap = false
		f.shadow_trap_active = true
		f.shadow_trap = {
			"x": f.pos_x,
			"y": f.pos_y,
			"w": f.w,
			"h": f.h,
			"phase": "idle",
			"timer": 300,  # 5 秒存在时间
			"anim": 0,
			"captured": null,
		}

	# === 技能2：幻影·舞 - 创建分身 ===
	if f.pending_clones:
		f.pending_clones = false
		var opp = GameWorld.get_opponent(f)
		for i in range(2):
			var offset_x = (i - 0.5) * 30
			var ph = {
				"x": f.pos_x + offset_x,
				"y": f.pos_y,
				"w": f.w,
				"h": f.h,
				"hp": 5.0,
				"max_hp": 5.0,
				"facing": f.facing,
				"image_state": "walk",
				"attack_cooldown": 0,
				"attack_timer": 0,
				"attack_delay": 0,
				"attack_hit_dealt": false,
				"attacking": false,
				"owner": f,
				"vy": 0.0,
				"grounded": f.grounded,
			}
			GameWorld.phantoms.append(ph)

	# === 技能1：陷阱逻辑更新 ===
	if f.shadow_trap_active and not f.shadow_trap.is_empty():
		_update_shadow_trap(f)

	# === 技能2：分身逻辑更新 ===
	_update_phantoms(f)

	# === 大招：居合刀光命中 + 到期爆炸 ===
	if f.iaido_active:
		_update_iaido(f)

# 技能1：暗影替身陷阱更新
static func _update_shadow_trap(f: Fighter):
	var trap = f.shadow_trap
	trap["anim"] += 1
	trap["timer"] -= 1

	match trap["phase"]:
		"idle":
			# 检测敌人是否靠近
			var opp = GameWorld.get_opponent(f)
			if opp and opp.hp > 0:
				var dx = absf(opp.pos_x - trap["x"])
				if dx < 60:
					trap["phase"] = "capture"
					trap["timer"] = 60  # 包裹持续 1 秒
					trap["captured"] = opp
					Fighter.apply_damage(opp, 5.0, f)
		"capture":
			var cap = trap["captured"]
			if cap and cap.hp > 0:
				# 固定被抓取的敌人
				cap.pos_x = trap["x"] - cap.w / 2.0 + trap["w"] / 2.0
				cap.vx = 0
				cap.vy = 0
			if trap["timer"] <= 0:
				trap["phase"] = "burst"
				trap["timer"] = 20  # 爆炸动画 0.33 秒
				if cap and cap.hp > 0:
					Fighter.apply_damage(cap, 10.0, f)
					cap.vx = (1 if cap.pos_x > trap["x"] else -1) * 5
					cap.vy = -4
				Fighter.emit_particles(trap["x"] + trap["w"] / 2.0, trap["y"] + trap["h"] / 2.0, 30, Color(0.4, 0.2, 0.67), 6, 8, "star", 0.8)
		"burst":
			if trap["timer"] <= 0:
				f.shadow_trap_active = false
				f.shadow_trap = {}

	# 5 秒后陷阱消失
	if trap["timer"] <= 0 and trap["phase"] == "idle":
		f.shadow_trap_active = false
		f.shadow_trap = {}

# 技能2：幻影分身更新
static func _update_phantoms(f: Fighter):
	if GameWorld.phantoms.is_empty():
		return
	var opp = GameWorld.get_opponent(f)
	var to_remove = []
	for ph in GameWorld.phantoms:
		if ph.hp <= 0:
			to_remove.append(ph)
			continue
		# 重力 & 落地（空中释放的分身自动落地）
		if not ph.get("grounded", true):
			ph["vy"] += 0.22  # 与角色重力一致
			ph["y"] += ph["vy"]
			if ph["y"] + ph["h"] >= Constants.GROUND_Y:
				ph["y"] = Constants.GROUND_Y - ph["h"]
				ph["vy"] = 0.0
				ph["grounded"] = true
		# 落地后才能移动和攻击
		if ph.get("grounded", true):
			# 向敌人移动
			if opp and opp.hp > 0:
				var dx = opp.pos_x - ph["x"]
				var dist = absf(dx)
				var dir = 1 if dx > 0 else -1
				ph["facing"] = dir
				if not ph["attacking"]:
					if dist > 44:  # 攻击范围外
						ph["x"] += dir * 2.1 * 0.8  # 0.8 倍移速
						ph["image_state"] = "walk"
					else:
						# 攻击
						if ph["attack_cooldown"] <= 0:
							ph["attacking"] = true
							ph["attack_timer"] = 68
							ph["attack_delay"] = 8
							ph["attack_hit_dealt"] = false
							ph["attack_cooldown"] = 60
							ph["image_state"] = "attack"
			# 攻击命中判定
			if ph["attacking"]:
				ph["attack_timer"] -= 1
				if ph["attack_delay"] > 0:
					ph["attack_delay"] -= 1
					if ph["attack_delay"] <= 0 and not ph["attack_hit_dealt"]:
						ph["attack_hit_dealt"] = true
						if opp and opp.hp > 0:
							var box = Rect2(ph["x"] + (4 if ph["facing"] > 0 else -40), ph["y"] + 4, 44, ph["h"] - 8)
							if box.intersects(opp.get_hit_box()):
								Fighter.apply_damage(opp, 5.0, f)
				if ph["attack_timer"] <= 0:
					ph["attacking"] = false
					ph["image_state"] = "idle"
			if ph["attack_cooldown"] > 0:
				ph["attack_cooldown"] -= 1
	for ph in to_remove:
		GameWorld.phantoms.erase(ph)

# 大招：居合刀光命中 + 到期爆炸
static func _update_iaido(f: Fighter):
	var slash = f.iaido_slash
	if slash.is_empty():
		return

	# 刀光命中：造成 10 点伤害（仅一次）
	if not slash.get("hit_dealt", false):
		var target = GameWorld.get_opponent(f)
		if target and target.hp > 0:
			var slash_rect = Rect2(slash["x"], slash["y"], slash["w"], slash["h"])
			if slash_rect.intersects(target.get_hit_box()):
				Fighter.apply_damage(target, 10.0, f)
				slash["hit_dealt"] = true
				# 抓取效果：固定对手在刀光中心
				target.pos_x = slash["x"] + slash["w"] / 2.0 - target.w / 2.0
				target.vx = 0
				target.vy = 0
				slash["captured"] = target

	# 到期爆炸：iaido_timer 归零时造成 30 点伤害
	if f.iaido_timer <= 0:
		var cap = slash.get("captured")
		if cap and cap.hp > 0:
			Fighter.apply_damage(cap, 30.0, f)
			# 爆炸击退
			cap.vx = f.iaido_dir * 6
			cap.vy = -5
		# 爆炸特效
		var cx = slash["x"] + slash["w"] / 2.0
		var cy = slash["y"] + slash["h"] / 2.0
		Fighter.emit_particles(cx, cy, 50, Color(0.67, 0.2, 0.93), 10, 14, "star", 1.0)
		# 重置状态，角色停留在终点
		f.iaido_active = false
		f.iaido_frozen = false
		f.iaido_slash = {}
		# 将角色位置更新到刀光终点（大招结束后停留在终点）
		var end_x = slash.get("start_x", f.pos_x) + slash["dir"] * slash["w"]
		f.pos_x = clampf(end_x, 10, 2390 - f.w)
