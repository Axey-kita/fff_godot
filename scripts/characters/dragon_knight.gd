# 龙骑士 (dragon_knight)
class_name DragonKnightCharacter

const DK_ANI_DIR = "res://assets/char_ani/dragon_knight/"
const DK_FIRE_STAB = preload("res://assets/fx_dragon_knight_fire_stab.png")
const DK_SKY_SPLIT = preload("res://assets/fx_dragon_knight_sky_split.png")
const DK_UPPERCUT = preload("res://assets/fx_dragon_knight_uppercut.png")
const DK_AIR_STANCE = preload("res://assets/fx_dragon_knight_air_stance.png")
const DK_DIVE_STRIKE = preload("res://assets/fx_dragon_knight_dive_strike.png")
const DK_SHIELD = preload("res://assets/fx_dragon_knight_scale_counter.png")
const DK_FIREBALL_GROUND = preload("res://assets/fx_dragon_knight_fireball_ground.png")
const DK_FIREBALL_AIR = preload("res://assets/fx_dragon_knight_fireball_air.png")
const DK_DRAGON_IDLE = preload("res://assets/fx_dragon_knight_dragon_idle.png")
const DK_DRAGON_FLIGHT = preload("res://assets/fx_dragon_knight_dragon_flight.png")

## 从预加载贴图创建单帧 FrameAnimation
static func _make_anim(tex: Texture2D, dur: float, loop: bool = false) -> FrameAnimation:
	var a = FrameAnimation.new(); a.add_frame(tex, dur); a.loop = loop; return a

static func get_config() -> Dictionary:
	return {
		"id": "dragon_knight", "name": "龙骑士", "hp": 100, "max_energy": 100, "energy_regen": 0.05,
		"speed": 2.2, "attack_range": 44, "attack_damage": 5,
		"attack_cooldown": 60, "attack_delay": 8, "attack_duration": 30,
		"image_scale": 1.2,
		"fields": {
			"dragon_scales_active": false,
			"dragon_scales_timer": 0,
			"dragon_form_active": false,
			"dragon_form_timer": 0,
			"dk_burn_applied": false,
		},
		"world_arrays": [],
		"animations": {
			"idle": FrameAnimation.load_from_frames(DK_ANI_DIR + "idle/", "dragon_knight_idle_f_", [{"index": 1, "duration": 999.0}], true),
			"walk": FrameAnimation.load_from_frames(DK_ANI_DIR + "walk/", "dragon_knight_walk_f_", [{"index": 1, "duration": 999.0}], true),
			"jump": FrameAnimation.load_from_frames(DK_ANI_DIR + "jump/", "dragon_knight_jump_f_", [{"index": 1, "duration": 999.0}], true),
			"attack": _make_anim(DK_FIRE_STAB, 0.5),
			"attack_air": _make_anim(DK_SKY_SPLIT, 0.5),
			"skill1": _make_anim(DK_UPPERCUT, 0.5),
			"flight": _make_anim(DK_AIR_STANCE, 999.0, true),
			"skill1_phase2": _make_anim(DK_DIVE_STRIKE, 0.5),
			"skill2": _make_anim(DK_SHIELD, 999.0, true),
			"ult": _make_anim(DK_DRAGON_IDLE, 999.0, true),
			"ult_flight": _make_anim(DK_DRAGON_FLIGHT, 999.0, true),
		},
		"dex": {
			"icon": "🐉",
			"intro": "龙息灼烧天穹，长枪洞穿虚伪——他踏碎城墙而来，以龙之名，行使暴烈的正义。他化作火龙，用熔岩般的怒意将一切傲慢焚尽。他站在废墟之上，如同不可逾越的山岳，连神明都要侧目。\n\"蝼蚁……不配知晓我的名字。\"",
			"stats": [
				{"label": "生命", "value": "100"},
				{"label": "龙怒（能量）", "value": "100"},
			],
			"skills": [
				{"name": "烈焰（普通攻击）", "desc": "地面：将火焰缠绕长枪向前猛刺，造成 5 点伤害并附加灼烧。空中：裂空——向下猛击。", "meta": "消耗：无 ｜ 冷却：1 秒"},
				{"name": "凌空 / 寂灭（技能一）", "desc": "【凌空】举枪上挑，击飞敌人并造成 5 点伤害+灼烧，自身进入 3 秒凌空飞行状态。\n【寂灭】凌空期间再次释放，斜向下冲刺重击敌人，造成 10 点伤害+灼烧，结束凌空。", "meta": "消耗：15 能量 ｜ 冷却：15 秒"},
				{"name": "鳞反（技能二）", "desc": "举盾防御，免疫所有伤害并吸收伤害值。防御结束后释放红色冲击波击飞敌人，造成 10 + 吸收伤害。点按举盾1秒，长按最多3秒（松手结束）。", "meta": "消耗：15 能量 ｜ 冷却：15 秒"},
				{"name": "龙魂（大招）", "desc": "化身为巨龙，免疫击退击飞，自由飞行 10 秒。飞行中只能使用火球普攻：喷射火球造成 7 伤害+灼烧。空中火球斜向下攻击。", "meta": "消耗：40 能量 ｜ 冷却：20 秒"},
			]
		},
		"ai_profile": {"ideal_range": [0, 140], "kite": false},
	}

static func create_skills() -> Array:
	return [
		Skill.new("skill1", "凌空/寂灭", 900, 15, func(owner: Fighter): return true, Callable(_skill1)),
		Skill.new("skill2", "鳞反", 900, 15, Callable(_can_use_skill2), Callable(_skill2)),
		Skill.new("ult", "龙魂", 1200, 40, Callable(_can_use_ult), Callable(_ult)),
	]

# ===== 技能一：凌空（一段）/ 寂灭（二段） =====
static func _skill1(owner: Fighter) -> Dictionary:
	if owner.dk_sky_rise_active:
		return _skill1_phase2(owner)
	else:
		return _skill1_phase1(owner)

## 一段：凌空 — 上挑击飞 + 自身跳起 + 进入飞行
static func _skill1_phase1(owner: Fighter) -> Dictionary:
	owner.energy -= 15
	var dir = owner.facing
	var cx = owner.pos_x + owner.w / 2.0
	var cy = owner.pos_y + owner.h / 2.0

	# 攻击前方敌人
	var target = GameWorld.get_opponent(owner)
	if target and target.hp > 0:
		var dx = target.pos_x + target.w / 2.0 - cx
		var dy = target.pos_y + target.h / 2.0 - cy
		if absf(dx) < 80 and absf(dy) < 100:
			Fighter.apply_damage(target, 5, owner)
			target.vy = -14
			target.vx = dir * 4
			target.add_status("burn")
			var burn = target.statuses.back()
			if burn and burn.id == "burn":
				burn.duration = 240
				burn.timer = 240
				burn.tick_damage = 1.0
				burn.tick_interval = 120

	# 自身跳起 + 进入凌空状态
	owner.vy = -7  # 跳跃高度为普跳的2/3
	owner.grounded = false
	owner.dk_sky_rise_active = true
	owner.dk_sky_rise_anim_timer = 15
	owner.dk_flight_timer = 600  # 飞行倒计时（不占用技能cd，确保寂灭可释放）
	owner.set_animation_state("skill1")
	Fighter.emit_particles(cx, cy, 30, Color(1.0, 0.5, 0.1), 6, 10, "star")
	return {"success": true}

## 二段：寂灭 — 斜向下冲刺重击，10伤害+灼烧
static func _skill1_phase2(owner: Fighter) -> Dictionary:
	owner.dk_sky_rise_active = false
	owner.dk_crash_timer = 20  # 20帧斜下冲刺
	owner.dk_burn_applied = false
	owner.set_animation_state("skill1_phase2")
	# 初始速度：斜向下
	owner.vx = owner.facing * 6.0
	owner.vy = 8.0
	Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 25, Color(1.0, 0.2, 0.05), 8, 12, "star")
	return {"success": true}

# ===== 技能二：鳞反 =====
static func _can_use_skill2(owner: Fighter) -> bool:
	return not owner.dk_shield_active and not owner.dk_sky_rise_active and owner.dk_crash_timer <= 0 and not owner.dashing

static func _skill2(owner: Fighter) -> Dictionary:
	owner.energy -= 15
	owner.dk_shield_active = true
	owner.dk_shield_timer = 0
	owner.dk_shield_held = true
	owner.dk_shield_absorbed_damage = 0.0
	owner.set_animation_state("skill2")
	Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 15, Color(1.0, 0.3, 0.1), 5, 8, "circle")
	return {"success": true}

# ===== 大招：龙魂 =====
static func _can_use_ult(owner: Fighter) -> bool:
	return not owner.dk_ult_active and not owner.dk_shield_active and not owner.dk_sky_rise_active and owner.dk_crash_timer <= 0 and not owner.dashing

static func _ult(owner: Fighter) -> Dictionary:
	owner.energy -= 40
	owner.dk_ult_active = true
	owner.dk_ult_timer = 600  # 10 秒
	owner.set_animation_state("ult")
	owner.config["image_scale"] = 6.0  # 巨龙 5 倍大小
	Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 60, Color(1.0, 0.15, 0.05), 14, 20, "star")
	return {"success": true}

# ===== 输入处理 =====
static func handle_input(owner: Fighter, keys: Dictionary) -> int:
	if owner.dk_crash_timer > 0:
		return 0
	if owner.dk_shield_active:
		owner.dk_shield_held = keys.skill2
		return 0
	if owner.dk_ult_active:
		return _input_ult(owner, keys)
	if owner.dk_sky_rise_active:
		return _input_sky_rise(owner, keys)

	var mx = 0
	if keys.left: mx = -1
	if keys.right: mx = 1
	if keys.up and owner.grounded: owner.vy = -10; owner.grounded = false
	if keys.attack and owner.attack_cooldown <= 0 and not owner.attacking:
		owner.attacking = true; owner.attack_timer = 30; owner.attack_delay = 8
		owner.attack_hit_dealt = false; owner.attack_cooldown = 60
		owner.dk_burn_applied = false
		owner.state = "attack"
		Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 15, Color(1.0, 0.4, 0.1), 4, 6, "star")
		keys.attack = false
	if keys.skill1:
		var s = owner.get_skill("skill1")
		if s: var r = s.try_use(owner); if r.get("success"): keys.skill1 = false
	if keys.skill2:
		var s2 = owner.get_skill("skill2")
		if s2: var r = s2.try_use(owner); if r.get("success"): keys.skill2 = false
	if keys.ult:
		var s3 = owner.get_skill("ult")
		if s3: var r = s3.try_use(owner); if r.get("success"): keys.ult = false
	Fighter.apply_movement(owner, mx, owner.config.get("speed", 2.2))
	Fighter.update_state(owner, mx)
	return mx

## 凌空状态输入：自由飞行 + 裂空普攻
static func _input_sky_rise(owner: Fighter, keys: Dictionary) -> int:
	# 起跳阶段：不干预飞行，让物理自然处理跳跃
	if owner.dk_sky_rise_anim_timer > 0:
		return 0

	owner.set_animation_state("flight")
	var fly_speed = 4.0
	var jx = 0.0; var jy = 0.0
	if keys.left: jx -= 1.0
	if keys.right: jx += 1.0
	if keys.up: jy -= 1.0
	if keys.down: jy += 1.0

	# 参考蔷薇强化二技能：直接修改坐标飞行
	owner.vx = 0; owner.vy = 0
	owner.pos_x = clampf(owner.pos_x + jx * fly_speed, 10, 2390 - owner.w)
	owner.pos_y = clampf(owner.pos_y + jy * fly_speed, 40, 380 - owner.h)
	if jx != 0: owner.facing = 1 if jx > 0 else -1

	# 普攻 → 裂空（独立计时器，绕过标准普攻流程）
	if keys.attack and owner.attack_cooldown <= 0 and not owner.attacking:
		owner.attacking = true; owner.attack_timer = 30
		owner.attack_delay = 999  # 阻止 fighter.gd 标准处理
		owner.attack_hit_dealt = true
		owner.attack_cooldown = 60
		owner.dk_burn_applied = false
		owner.dk_dive_attack_timer = 300  # 向下冲刺距离（参考圣骑士冲刺）
		owner.dk_crack_ends_flight = true  # 裂空结束后结束飞行
		owner.set_animation_state("attack_air")
		Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h, 12, Color(1.0, 0.5, 0.1), 4, 6, "circle")
		keys.attack = false

	# 技能一 → 通过 try_use 到 _skill1_phase2
	if keys.skill1:
		var s = owner.get_skill("skill1")
		if s: var r = s.try_use(owner); if r.get("success"): keys.skill1 = false

	return 0

## 龙魂大招输入：自由飞行 + 火球普攻
static func _input_ult(owner: Fighter, keys: Dictionary) -> int:
	var fly_speed = 3.5
	var jx = 0.0; var jy = 0.0
	if keys.left: jx -= 1.0
	if keys.right: jx += 1.0
	if keys.up: jy -= 1.0
	if keys.down: jy += 1.0

	owner.vx = jx * fly_speed
	owner.vy = jy * fly_speed
	if jx != 0: owner.facing = 1 if jx > 0 else -1

	owner.pos_x = clampf(owner.pos_x, 10, 2390 - owner.w)
	owner.pos_y = clampf(owner.pos_y, 20, 380 - owner.h)

	# 火球普攻（唯一可用攻击，巨龙贴图保持待机/飞行不变）
	if keys.attack and owner.attack_cooldown <= 0 and not owner.attacking:
		owner.attacking = true; owner.attack_timer = 20
		owner.attack_delay = 999  # 阻止 fighter.gd 标准攻击判定
		owner.attack_hit_dealt = true
		owner.attack_cooldown = 60
		owner.dk_burn_applied = false

		var px = owner.pos_x + (owner.w if owner.facing == 1 else 0)
		var py = owner.pos_y + 30
		if owner.grounded:
			# 地面火球从口部偏高位置发射
			py = owner.pos_y - 110
			GameWorld.projectiles.append({
				"x": px, "y": py, "w": 150, "h": 150,
				"vx": 5.0 * owner.facing, "vy": 0.0,
				"life": 120, "damage": 7, "owner": owner,
				"type": "dk_fireball", "color": Color(1.0, 0.3, 0.1),
				"img": DK_FIREBALL_GROUND, "burn": true,
				"reflected": false,
			})
		else:
			py = owner.pos_y - 110  # 空中火球从口部发射
			GameWorld.projectiles.append({
				"x": px, "y": py, "w": 150, "h": 150,
				"vx": 4.0 * owner.facing, "vy": 3.0,  # 斜向下（参考魔女）
				"life": 120, "damage": 7, "owner": owner,
				"type": "dk_fireball", "color": Color(1.0, 0.3, 0.1),
				"img": DK_FIREBALL_AIR, "burn": true,
				"reflected": false,
			})
		Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 10, Color(1.0, 0.4, 0.1), 4, 6, "circle")
		keys.attack = false

	return 0

# ===== 系统更新 =====
static func update_systems(owner: Fighter):
	# 鳞反：举盾吸收伤害
	if owner.dk_shield_active:
		owner.dk_shield_timer += 1
		owner.vx = 0
		owner.vy = 0
		# 结束条件：满3秒 或 松手且满1秒
		var should_end = false
		if owner.dk_shield_timer >= 180:
			should_end = true
		elif not owner.dk_shield_held and owner.dk_shield_timer >= 60:
			should_end = true
		if should_end:
			owner.dk_shield_active = false
			var total_dmg = 10.0 + owner.dk_shield_absorbed_damage
			var target = GameWorld.get_opponent(owner)
			if target and target.hp > 0:
				var dx = absf(target.pos_x + target.w / 2.0 - owner.pos_x - owner.w / 2.0)
				var dy = absf(target.pos_y + target.h / 2.0 - owner.pos_y - owner.h / 2.0)
				if dx < 250 and dy < 200:
					Fighter.apply_damage(target, total_dmg, owner)
					target.vy = -10
					target.vx = owner.facing * 6
			Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 40, Color(1.0, 0.15, 0.05), 12, 18, "circle")
			var s2 = owner.get_skill("skill2")
			if s2: s2.cd = s2.cooldown
		return

	# 龙魂大招：倒计时 + 飞行动画交替
	if owner.dk_ult_active:
		owner.dk_ult_timer -= 1
		# 攻击时不覆盖动画；否则每30帧切换 idle/flight
		if not owner.attacking:
			var frame_in_cycle = (600 - owner.dk_ult_timer) % 60
			if frame_in_cycle < 30:
				owner.set_animation_state("ult")
			else:
				owner.set_animation_state("ult_flight")
		if owner.dk_ult_timer <= 0:
			owner.dk_ult_active = false
			owner.config["image_scale"] = 1.2  # 恢复原始大小
			var s3 = owner.get_skill("ult")
			if s3: s3.cd = s3.cooldown
		return

	# 寂灭：斜下冲刺碰撞检测（优先于凌空飞行）
	if owner.dk_crash_timer > 0:
		owner.dk_crash_timer -= 1
		owner.vx = owner.facing * 8.0
		owner.vy = 6.0
		var target = GameWorld.get_opponent(owner)
		if target and target.hp > 0 and not owner.dk_burn_applied:
			var dx = absf(target.pos_x + target.w / 2.0 - owner.pos_x - owner.w / 2.0)
			var dy = target.pos_y + target.h / 2.0 - owner.pos_y - owner.h / 2.0
			if dx < 160 and dy > -40 and dy < 400:
				Fighter.apply_damage(target, 10, owner)
				target.add_status("burn")
				var burn = target.statuses.back()
				if burn and burn.id == "burn":
					burn.duration = 240; burn.timer = 240
					burn.tick_damage = 1.0; burn.tick_interval = 120
				owner.dk_burn_applied = true
		# 冲刺结束 → 落地，进入冷却
		if owner.dk_crash_timer <= 0:
			owner.dk_crash_timer = 0
			var s = owner.get_skill("skill1")
			if s: s.cd = s.cooldown
		return

	# 凌空飞行中
	if owner.dk_sky_rise_active:
		# 起跳动画：前 15 帧用 uppercut，之后切飞行
		if owner.dk_sky_rise_anim_timer > 0:
			owner.dk_sky_rise_anim_timer -= 1
			owner.set_animation_state("skill1")
		else:
			owner.set_animation_state("flight")
		# 飞行倒计时
		if owner.dk_flight_timer > 0:
			owner.dk_flight_timer -= 1
		if owner.dk_flight_timer <= 0 and owner.dk_sky_rise_active:
			owner.dk_sky_rise_active = false
			var s = owner.get_skill("skill1")
			if s: s.cd = s.cooldown
		# 裂空：向下冲刺（距离驱动，参考圣骑士冲刺）
		if owner.dk_dive_attack_timer > 0:
			var step = minf(18.0, owner.dk_dive_attack_timer)
			owner.pos_y += step
			owner.dk_dive_attack_timer -= step
			owner.vy = 0
			var target = GameWorld.get_opponent(owner)
			if target and target.hp > 0:
				var dx = absf(target.pos_x + target.w / 2.0 - owner.pos_x - owner.w / 2.0)
				var dy = target.pos_y + target.h / 2.0 - owner.pos_y - owner.h / 2.0
				if dx < 180 and dy > -60 and dy < 500:
					Fighter.apply_damage(target, 5, owner)
					target.add_status("burn")
					var burn = target.statuses.back()
					if burn and burn.id == "burn":
						burn.duration = 240; burn.timer = 240
						burn.tick_damage = 1.0; burn.tick_interval = 120
					owner.dk_dive_attack_timer = 0  # 命中后停止检查
		# 裂空结束后结束飞行
		if owner.dk_crack_ends_flight and owner.dk_dive_attack_timer <= 0:
			owner.dk_sky_rise_active = false
			owner.dk_crack_ends_flight = false
			var s2 = owner.get_skill("skill1")
			if s2: s2.cd = s2.cooldown
		return

	if not owner.attacking:
		owner.dk_burn_applied = false
		return

	# 凌空状态下由 _input_sky_rise 控制，跳过地面/空中位移逻辑
	if owner.dk_sky_rise_active:
		return

	# 空中攻击时强制覆盖贴图为裂空
	if not owner.grounded:
		owner.set_animation_state("attack_air")

	# 地面普攻：2 帧后向前突刺
	if not owner.dashing and owner.attack_timer == 28:
		if owner.grounded:
			owner.dashing = true
			owner.dash_remaining = 10
			owner.dash_dir = owner.facing
			owner.dash_speed = 4.0
			owner.dash_damage_dealt = true
		else:
			owner.vy = 16.0
			Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h, 12, Color(1.0, 0.5, 0.1), 4, 6, "circle")

	# 命中灼烧
	if owner.attack_delay <= 0 and not owner.dk_burn_applied:
		var target = GameWorld.get_opponent(owner)
		if target and target.hp > 0:
			if owner.get_attack_box().intersects(target.get_hit_box()):
				owner.dk_burn_applied = true
				target.add_status("burn")
				var burn = target.statuses.back()
				if burn and burn.id == "burn":
					burn.duration = 240
					burn.timer = 240
					burn.tick_damage = 1.0
					burn.tick_interval = 120
