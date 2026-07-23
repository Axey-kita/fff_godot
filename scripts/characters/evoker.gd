# 唤魔者 (evoker)
class_name EvokerCharacter

const PROJ_FIREBALL = preload("res://assets/fire.png")
const EVOKER_ANI_DIR = "res://assets/char_ani/evoker/"

static func get_config() -> Dictionary:
	return {
		"id": "evoker", "name": "唤魔者", "hp": 60, "max_energy": 140, "energy_regen": 0.083,
		"speed": 2.25, "attack_range": 44, "attack_damage": 4,
		"attack_cooldown": 0, "attack_delay": 8, "attack_duration": 68,
		"fields": {"last_summon_type":-1,"summon_dead1":false,"summon_dead2":false,"summon_dead3":false},
		"world_arrays": ["evoker_summons","void_rifts","evoker_fire_seas","gravity_balls","phantoms"],
		"animations": {
			"idle": FrameAnimation.load_from_dir(EVOKER_ANI_DIR + "idle/", "evoker_idle_f_", "timetable.txt", true),
			"walk": FrameAnimation.load_from_dir(EVOKER_ANI_DIR + "walk/", "evoker_walk_f_", "timetable.txt", true),
			"jump": FrameAnimation.load_from_dir(EVOKER_ANI_DIR + "jump/", "evoker_jump_f_", "timetable.txt", true),
			"attack": FrameAnimation.load_from_dir(EVOKER_ANI_DIR + "attack/", "evoker_attack_f_", "timetable.txt", false),
			"ult": FrameAnimation.load_from_dir(EVOKER_ANI_DIR + "ult/", "evoker_ult_f_", "timetable.txt", false),
		},
		"dex": {
			"icon": "🧙",
			"intro": "与深渊签订契约的唤魔者，操纵三种召唤物进行战斗。",
			"stats": [
				{"label": "生命", "value": "60"},
				{"label": "能量上限", "value": "140"},
				{"label": "能量恢复", "value": "5/秒"},
			],
			"skills": [
				{
					"name": "契约（特殊机制）",
					"desc": "与深渊签订契约，可操纵三种召唤物，场上最多同时存在 1 个。\n· 寂语之喉（1 号）：血量 60。\n· 哀恸枷锁（2 号）：血量 40。\n· 诅咒之眼（3 号）：血量 80。\n召唤物上场时以 3 点/秒缓慢恢复血量；除「随行」状态外可被敌人直接攻击，血量耗尽后死亡且无法再次召唤。\n唤魔者的普攻与技能2 会随当前召唤物而改变。\n\n召唤物被动：\n· 噤声（1 号）：当敌人与唤魔者处于 1 号的同一侧时，敌人造成的伤害减少 20%。\n· 摄魂（2 号）：处于 2 号附近的敌人能量以 5 点/秒的速度流失。\n· 凝视（3 号）：处于 3 号附近的敌人，技能1、技能2 的冷却时间增加 1 秒。",
					"meta": "被动 ｜ 召唤物上场回血 3/秒"
				},
				{
					"name": "冥炎弹 / 役使·随行 / 役使·猎杀（普攻）",
					"desc": "无召唤物 → 冥炎弹：抛出以抛物线飞行的冥炎弹，命中造成 4 伤害，附加减速 20%（持续 6 秒）与灼烧（每 2 秒 1 点，持续 6 秒）。消耗 10，冷却 2 秒。\n\n召唤物处于猎杀状态 → 役使·随行：召回召唤物回到身边并一同移动（移动速度与玩家一致），回归途中对沿途敌人造成 5 撞击伤害；随行期间唤魔者受到伤害的 60% 由召唤物承受。消耗 20，冷却 2 秒。\n\n召唤物处于随行状态 → 役使·猎杀：召唤物释放一次重击后进入猎杀状态（缓慢靠近敌人但不主动攻击）。消耗 20，冷却 3 秒。\n\n召唤物重击：\n· 1 号：以自身为中心释放蓝紫色空心圆冲击波，强力击飞周围敌人，伤害 10。\n· 2 号：向前突进用镰刀斩击敌人，伤害 10。\n· 3 号：发射一枚缓慢飞行的引力球，持续吸附敌人并造成 3 点/秒伤害。",
					"meta": "消耗 10~20 ｜ 冷却 2~3 秒"
				},
				{
					"name": "深渊召令（技能一）",
					"desc": "随机召唤一个召唤物生成在身前，默认为「随行」状态；若场上已有召唤物则将其替换。\n连续两次召唤的召唤物不会重复，已死亡的召唤物不能被召唤。",
					"meta": "消耗 20 ｜ 冷却 5 秒"
				},
				{
					"name": "幽蓝之境 / 魔令（技能二）",
					"desc": "无召唤物 → 幽蓝之境：在脚下生成大范围火海（持续 4 秒），持续灼烧范围内敌人（5 点/秒）并造成 40% 减速。消耗 20，冷却 13 秒。\n\n有召唤物 → 魔令：命令召唤物释放技能。消耗 20，冷却 13 秒。\n· 1 号：释放大范围水平冲击波，命中眩晕敌人 2 秒（无法进行任何操作），伤害 15。\n· 2 号：大范围挥镰斩击，命中造成流血（释放时受到 3 伤害）并持续 5 秒，伤害 15。\n· 3 号：向前突进撞击，命中剥夺敌人视力，失明 3 秒，伤害 20。",
					"meta": "消耗 20 ｜ 冷却 13 秒"
				},
				{
					"name": "虚空裂隙（大招）",
					"desc": "献祭场上的召唤物，召唤物立刻死亡，其剩余血量转移到唤魔者身上。\n召唤物死亡处出现虚空裂隙，持续 4 秒，吸附并对范围内敌人造成 10 点/秒的大量伤害。",
					"meta": "消耗 100 ｜ 冷却 60 秒"
				},
			]
		},
	}

# Helper: find the owner's summon in GameWorld.evoker_summons
static func _get_summon(owner: Fighter) -> Dictionary:
	for s in GameWorld.evoker_summons:
		if s.get("owner") == owner:
			return s
	return {}

# canUse helpers (separate functions for clarity)
static func _can_attack(owner: Fighter) -> bool:
	if owner.attack_cooldown > 0 or owner.attacking:
		return false
	var s = _get_summon(owner)
	var cost: int = 20 if not s.is_empty() else 10
	return owner.energy >= cost

static func _can_skill1(owner: Fighter) -> bool:
	if owner.energy < 20:
		return false
	for i in 3:
		if not owner.get("summon_dead" + str(i + 1)):
			return true
	return false

static func _can_ult(owner: Fighter) -> bool:
	if owner.energy < 100:
		return false
	var s = _get_summon(owner)
	return not s.is_empty() and s.get("hp", 0) > 0

static func create_skills() -> Array:
	return [
		Skill.new("attack", "冥炎弹/役使", 0, 0, Callable(_can_attack), Callable(_attack)),
		Skill.new("skill1", "深渊召令", 300, 20, Callable(_can_skill1), Callable(_skill1)),
		Skill.new("skill2", "幽蓝之境/魔令", 780, 20, func(owner: Fighter): return owner.energy >= 20, Callable(_skill2)),
		Skill.new("ult", "虚空裂隙", 3600, 100, Callable(_can_ult), Callable(_ult)),
	]

# ===== 普攻：冥炎弹 / 役使·随行 / 役使·猎杀 =====
static func _attack(owner: Fighter) -> Dictionary:
	var summon = _get_summon(owner)

	if summon.is_empty():
		# ---- 冥炎弹 ----
		owner.energy -= 10
		owner.attack_cooldown = 120
		owner.attacking = true
		owner.attack_timer = 30
		var fire_x = owner.pos_x + (30.0 if owner.facing > 0 else -30.0)
		var fire_y = owner.pos_y + 20.0
		GameWorld.projectiles.append({
			"x": fire_x, "y": fire_y,
			"w": 24.0, "h": 24.0,
			"vx": 5.0 * owner.facing, "vy": -2.5,
			"life": 90,
			"damage": 4.0,
			"owner": owner,
			"type": "evoker_fireball",
			"color": Color(1.0, 0.533, 0.0),
			"reflected": false,
			"gravity": 0.15,
			"img": PROJ_FIREBALL,
			"slowDuration": 360,
			"burnDuration": 360,
		})
		Fighter.emit_particles(fire_x, fire_y, 10, Color(1.0, 0.533, 0.0), 3, 6)
		return {"success": true}

	# ---- 有召唤物 ----
	if summon["state"] == "猎杀":
		# 役使·随行
		owner.energy -= 20
		owner.attack_cooldown = 120
		summon["state"] = "回归"
		summon["hit_enemies"] = []
		Fighter.emit_particles(summon["x"], summon["y"], 8, Color(0.4, 0.8, 1.0), 2, 10)
		return {"success": true}

	if summon["state"] == "随行":
		# 役使·猎杀
		owner.energy -= 20
		owner.attack_cooldown = 180
		_perform_heavy_attack(summon)
		if summon["state"] == "随行":
			summon["state"] = "猎杀"
		return {"success": true}

	return {"success": false}

# ---- Heavy attack by summon type (triggered by 役使·猎杀) ----
static func _perform_heavy_attack(summon: Dictionary):
	var owner: Fighter = summon["owner"]
	var enemy: Fighter = GameWorld.get_opponent(owner)
	if not enemy:
		return

	summon["action_type"] = "heavy"
	var st: int = summon["type"]
	var cx: float = summon["x"] + summon["w"] / 2.0
	var cy: float = summon["y"] + summon["h"] / 2.0

	match st:
		0:
			# 1号：蓝紫色空心圆形冲击波
			var dx = enemy.pos_x + enemy.w / 2.0 - cx
			var dy = enemy.pos_y + enemy.h / 2.0 - cy
			var dist = sqrt(dx * dx + dy * dy)
			if dist < 100.0:
				var angle = atan2(dy, dx)
				Fighter.apply_damage(enemy, 10, owner, false)
				enemy.vx = cos(angle) * 12.0
				enemy.vy = -6.0
				Fighter.emit_particles(cx, cy, 30, Color(0.667, 0.533, 1.0), 6, 20, "star")
			summon["action_timer"] = 20
			summon["state"] = "猎杀"

		1:
			# 2号：向前突进斩（跨帧动画，由 onUpdate 推进）
			summon["state"] = "突进"
			var dir_to_enemy: float = signf(enemy.pos_x - summon["x"])
			summon["dash_dir"] = int(dir_to_enemy) if dir_to_enemy != 0 else owner.facing
			summon["dash_timer"] = 16
			summon["dash_hit"] = false
			summon["vx"] = 0.0
			summon["vy"] = 0.0
			summon["action_timer"] = 20

		2:
			# 3号：发射引力球
			var dir: float = signf(enemy.pos_x - summon["x"])
			if dir == 0:
				dir = float(owner.facing)
			GameWorld.gravity_balls.append({
				"x": summon["x"] + (summon["w"] if dir > 0 else -20.0),
				"y": summon["y"] + 10.0,
				"w": 30.0, "h": 30.0,
				"vx": 1.5 * dir,
				"vy": 0.0,
				"life": 180,
				"owner": owner,
				"attract_radius": 120.0,
				"damage_timer": 0,
			})
			summon["action_timer"] = 20
			summon["state"] = "猎杀"

# ===== 技能1：深渊召令 =====
static func _skill1(owner: Fighter) -> Dictionary:
	# Find available types (not dead)
	var available = []
	for i in 3:
		if not owner.get("summon_dead" + str(i + 1)):
			available.append(i)
	if available.is_empty():
		return {"success": false}

	# Exclude last summoned type if possible
	var exclude = owner.last_summon_type
	var filtered = []
	for t in available:
		if t != exclude:
			filtered.append(t)
	if filtered.is_empty():
		filtered = available  # only the last type is available, allow re-summon

	var type_id: int = filtered[randi() % filtered.size()]

	# Remove existing summon (not marking dead) — iterate backwards
	for i in range(GameWorld.evoker_summons.size() - 1, -1, -1):
		if GameWorld.evoker_summons[i].get("owner") == owner:
			GameWorld.evoker_summons.remove_at(i)

	# Spawn new summon in front of owner
	var spawn_x: float = owner.pos_x + (60.0 if owner.facing > 0 else -60.0)
	var spawn_y: float = owner.pos_y + 10.0
	var max_hps = [60.0, 40.0, 80.0]
	GameWorld.evoker_summons.append({
		"type": type_id,
		"owner": owner,
		"hp": float(max_hps[type_id]),
		"max_hp": float(max_hps[type_id]),
		"state": "随行",
		"x": spawn_x, "y": spawn_y,
		"w": 40.0, "h": 40.0,
		"vx": 0.0, "vy": 0.0,
		"hit_enemies": [],
		"action_timer": 0,
		"action_type": "",
		"flash_timer": 0,
		"hit_cd": 0,
		"dash_dir": 1,
		"dash_timer": 0,
		"dash_hit": false,
	})

	owner.last_summon_type = type_id

	var summon_colors = [
		Color(0.541, 0.169, 0.886),
		Color(1.0, 0.271, 0.0),
		Color(0.196, 0.804, 0.196),
	]
	Fighter.emit_particles(spawn_x, spawn_y, 20, summon_colors[type_id], 4, 15)
	return {"success": true}

# ===== 技能2：幽蓝之境 / 魔令 =====
static func _skill2(owner: Fighter) -> Dictionary:
	var summon = _get_summon(owner)

	if summon.is_empty():
		# ---- 幽蓝之境：在脚下生成大范围火海 ----
		GameWorld.evoker_fire_seas.append({
			"x": owner.pos_x - 100.0,
			"y": owner.pos_y - 40.0,
			"w": 200.0, "h": 80.0,
			"timer": 0,
			"duration": 240,
			"owner": owner,
		})
		Fighter.emit_particles(owner.pos_x, owner.pos_y, 30, Color(0.267, 0.533, 1.0), 5, 20)
		return {"success": true}
	else:
		# ---- 魔令：命令召唤物释放技能 ----
		_perform_summon_skill(summon)
		return {"success": true}

# ---- Summon skill by type (triggered by 魔令) ----
static func _perform_summon_skill(summon: Dictionary):
	var owner: Fighter = summon["owner"]
	var enemy: Fighter = GameWorld.get_opponent(owner)
	if not enemy:
		return

	summon["action_type"] = "skill"
	var st: int = summon["type"]
	var cx: float = summon["x"] + summon["w"] / 2.0
	var cy: float = summon["y"] + summon["h"] / 2.0

	match st:
		0:
			# 1号：水平冲击波，伤害15，眩晕2秒（frozen 120帧）
			var dx = enemy.pos_x + enemy.w / 2.0 - cx
			var dy = enemy.pos_y + enemy.h / 2.0 - cy
			if abs(dy) < 40.0 and abs(dx) < 120.0:
				Fighter.apply_damage(enemy, 15, owner, true)
				enemy.add_status("frozen")
				for s in enemy.statuses:
					if s.id == "frozen":
						s.timer = 120
				Fighter.emit_particles(cx, cy, 25, Color(0.4, 0.267, 1.0), 5, 20)
			summon["action_timer"] = 20

		1:
			# 2号：大范围斩击，伤害15+3，流血5秒
			var dx2 = enemy.pos_x + enemy.w / 2.0 - cx
			var dy2 = enemy.pos_y + enemy.h / 2.0 - cy
			var dist2 = sqrt(dx2 * dx2 + dy2 * dy2)
			if dist2 < 90.0:
				Fighter.apply_damage(enemy, 15, owner, true)
				Fighter.apply_damage(enemy, 3, owner, false)
				enemy.bleed_timer = 300
				Fighter.emit_particles(cx, cy, 30, Color(1.0, 0.2, 0.2), 6, 20)
			summon["action_timer"] = 20

		2:
			# 3号：突进撞击（瞬移），伤害20，失明3秒
			var dx3 = enemy.pos_x + enemy.w / 2.0 - cx
			var dy3 = enemy.pos_y + enemy.h / 2.0 - cy
			var dist3 = sqrt(dx3 * dx3 + dy3 * dy3)
			if dist3 < 120.0:
				var target_x = enemy.pos_x + enemy.w / 2.0 - summon["w"] / 2.0
				var target_y = enemy.pos_y + enemy.h / 2.0 - summon["h"] / 2.0
				summon["x"] = target_x
				summon["y"] = target_y
				Fighter.apply_damage(enemy, 20, owner, true)
				enemy.blind_timer = 180
				Fighter.emit_particles(target_x + summon["w"] / 2.0, target_y + summon["h"] / 2.0, 30, Color(0.533, 1.0, 0.533), 5, 20)
			summon["action_timer"] = 20

# ===== 大招：虚空裂隙 =====
static func _ult(owner: Fighter) -> Dictionary:
	var summon = _get_summon(owner)
	if summon.is_empty() or summon.get("hp", 0) <= 0:
		return {"success": false}

	# Transfer summon's remaining HP to owner
	var transferred: int = int(summon["hp"])
	var heal: float = minf(float(transferred), owner.max_hp - owner.hp)
	owner.hp += heal
	owner.hp = minf(owner.hp, owner.max_hp)

	# Mark summon type as dead
	owner.set("summon_dead" + str(summon["type"] + 1), true)

	# Create void rift at summon position
	GameWorld.void_rifts.append({
		"x": summon["x"] - 80.0,
		"y": summon["y"] - 60.0,
		"w": 160.0, "h": 120.0,
		"duration": 240,
		"timer": 0,
		"owner": owner,
	})

	# Store summon position for particles before removing
	var fx: float = summon["x"] + summon["w"] / 2.0
	var fy: float = summon["y"] + summon["h"] / 2.0

	# Remove summon from world
	for i in range(GameWorld.evoker_summons.size() - 1, -1, -1):
		if GameWorld.evoker_summons[i].get("owner") == owner:
			GameWorld.evoker_summons.remove_at(i)

	Fighter.emit_particles(fx, fy, 50, Color(0.667, 0.267, 1.0), 8, 10, "star")
	return {"success": true}
