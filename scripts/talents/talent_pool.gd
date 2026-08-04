# 天赋注册表 + 工厂
class_name TalentPool

static var _registry := {}
static var _metadata := {}

static func init():
	if not _registry.is_empty():
		return
	_register_all()

static func _register_all():
	# 每行四个字段：(talent_id, name, desc, is_skill)
	_metadata["vitality"]      = { "name": "生命强化",  "desc": "被动 · 可重复选取\n每次选取：最大生命 ×1.2\n选取 2 次：×1.4\n选取 3 次：×1.6", "is_skill": false }
	_metadata["thorns"]        = { "name": "荆棘护体",  "desc": "被动 · 可重复选取\n每次选取：反弹 3.0 伤害\n选取 2 次：4.5\n选取 3 次：6.0", "is_skill": false }
	_metadata["vampiric"]      = { "name": "鲜血汲取",  "desc": "被动 · 可重复选取\n每次选取：治疗 10%\n选取 2 次：15%\n选取 3 次：20%", "is_skill": false }
	_metadata["blaze_rush"]    = { "name": "烈焰冲刺",  "desc": "主动 · 不可叠加\n向前冲刺并留下火海\n冲刺伤害：6  火海：4/次\n冷却：600 帧（10 秒）", "is_skill": true }
	_metadata["void_affinity"] = { "name": "虚空亲和",  "desc": "被动 · 不可叠加\n触碰虚空时扣除当前生命 50%\n随机传送至地面", "is_skill": false }
	_metadata["arcane_surge"]  = { "name": "奥术涌流",  "desc": "主动 · 不可叠加\n被动：能量回复速度 +5%\n释放：瞬间回复 40 能量\n冷却：30 秒", "is_skill": true }
	_metadata["phase_blink"]   = { "name": "相位闪烁",  "desc": "主动 · 不可叠加\n向操控方向瞬移 500 像素\n无操控方向时默认向前瞬移\n冷却：10 秒", "is_skill": true }
	_metadata["regen_rune"]    = { "name": "再生符文",  "desc": "主动 · 不可叠加\n被动：所有血量回复量 +10%\n释放：以 5/秒 回复生命\n持续 4 秒  冷却：30 秒", "is_skill": true }
	_metadata["battle_frenzy"] = { "name": "战斗，爽！", "desc": "被动 · 不可叠加 · 占2格\n伤害 +5%  受伤 -10%\n技能1/2 冷却 -1 秒\n20% 概率免疫击退", "is_skill": false }
	_metadata["last_stand"]    = { "name": "背水一战",  "desc": "被动 · 不可叠加 · 整局1次\nHP < 20% 时自动触发\n无敌 10 秒 · 免疫击退\n免疫所有负面效果", "is_skill": false }
	_metadata["order_reforge"] = { "name": "秩序重铸",  "desc": "主动 · 不可叠加\n被动：技能一/二 冷却 -1 秒\n释放：所有冷却中的技能\n立即结束冷却\n冷却：40 秒", "is_skill": true }

	_registry["vitality"]      = { "factory": _make_vitality }
	_registry["thorns"]        = { "factory": _make_thorns }
	_registry["vampiric"]      = { "factory": _make_vampiric }
	_registry["blaze_rush"]    = { "factory": _make_blaze_rush }
	_registry["void_affinity"] = { "factory": _make_void_affinity }
	_registry["arcane_surge"]  = { "factory": _make_arcane_surge }
	_registry["phase_blink"]   = { "factory": _make_phase_blink }
	_registry["regen_rune"]    = { "factory": _make_regen_rune }
	_registry["battle_frenzy"] = { "factory": _make_battle_frenzy }
	_registry["last_stand"]    = { "factory": _make_last_stand }
	_registry["order_reforge"] = { "factory": _make_order_reforge }

static func create(talent_id: String, fighter) -> TalentInstance:
	var entry = _registry.get(talent_id)
	if not entry:
		return null
	var inst: TalentInstance = entry["factory"].call(fighter)
	inst.talent_id = talent_id
	return inst

static func get_all_ids() -> Array:
	return _registry.keys()

## 返回元数据：{name, desc, is_skill}，供 UI 使用（无需 fighter 上下文）
static func get_metadata(talent_id: String) -> Dictionary:
	return _metadata.get(talent_id, {})

# ============ 工厂函数（参数不标注 Fighter 类型，避免循环引用）============

## 生命强化 — 被动属性（可叠加）
static func _make_vitality(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "生命强化"
	inst.description = "被动 · 可叠加（最多 3 层）"
	inst.is_skill = false
	inst.on_attach = func():
		if not f.ad.has("vitality_stack"):
			f.ad["vitality_stack"] = 0
		f.ad["vitality_stack"] += 1
		var stack = f.ad["vitality_stack"]
		var mult = 1.0 + 0.2 * stack  # 1→1.2, 2→1.4, 3→1.6
		var base_hp = float(f.config.get("hp", 100))
		f.max_hp = base_hp * mult
		f.hp = minf(f.hp, f.max_hp)  # 同步当前血量
	return inst

## 荆棘 — 被动事件（可叠加，每秒最多触发 2 次）
static func _make_thorns(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "荆棘护体"
	inst.description = "被动 · 可叠加（最多 3 层）"
	inst.is_skill = false
	inst.on_attach = func():
		if not f.ad.has("thorns_stack"):
			f.ad["thorns_stack"] = 0
		f.ad["thorns_stack"] += 1
		if not f.ad.has("thorns_cd"):
			f.ad["thorns_cd"] = 0
	inst.on_damage_received = func(data: Dictionary):
		var attacker = data.get("attacker")
		var depth = data.get("recursion_depth", 0)
		if f.ad.get("thorns_cd", 0) > 0:
			return
		var stack = f.ad.get("thorns_stack", 1)
		var reflect = 3.0 + 1.5 * (stack - 1)  # 1层:3, 2层:4.5, 3层:6
		if attacker and attacker.hp > 0:
			f.ad["thorns_cd"] = 30  # 0.5 秒冷却
			f.apply_damage(attacker, reflect, f, false,
				Color.GREEN, "hit_enemy", "talent.thorns", depth + 1)
	inst.update = func():
		if f.ad.get("thorns_cd", 0) > 0:
			f.ad["thorns_cd"] -= 1
	return inst

## 嗜血 — 被动事件（可叠加）
static func _make_vampiric(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "鲜血汲取"
	inst.description = "被动 · 可叠加（最多 3 层）"
	inst.is_skill = false
	inst.on_attach = func():
		if not f.ad.has("vampiric_stack"):
			f.ad["vampiric_stack"] = 0
		f.ad["vampiric_stack"] += 1
	inst.on_damage_dealt = func(data: Dictionary):
		var dmg = data.get("damage", 0)
		var stack = f.ad.get("vampiric_stack", 1)
		var pct = 0.1 + 0.1 * (stack - 1)  # 1层:10%, 2层:20%, 3层:30%
		if dmg > 0:
			f.hp = minf(f.max_hp, f.hp + dmg * pct)
	return inst

## 烈焰冲刺 — 主动天赋（按 K/L/; 键激活）
static func _make_blaze_rush(f) -> TalentInstance:
	# ── 配置常量 ──
	const CD = 720          # 冷却帧数（12 秒）
	const DASH_DIST = 100   # 冲刺距离
	const DASH_SPD = 10.0   # 冲刺速度
	const HIT_DMG = 6.0    # 撞击伤害
	const FLAME_W = 10      # 火海宽
	const FLAME_H = 50      # 火海高
	const FLAME_LIFE = 90   # 火海持续帧
	const FLAME_DMG = 4     # 火海每次伤害
	const FLAME_TICK = 30   # 火海伤害间隔

	var inst = TalentInstance.new()
	inst.talent_name = "烈焰冲刺"
	inst.description = "主动 · 不可叠加"
	inst.is_skill = true
	# ── 状态命名空间 ──
	f.ad["blaze_rush"] = {"cd": 0, "flame_step": 0, "on": false}

	inst.on_dash_end = func():
		f.ad["blaze_rush"]["on"] = false

	inst.can_activate = func():
		return f.ad["blaze_rush"]["cd"] <= 0 and not f.dashing

	inst.activate = func():
		var state = f.ad["blaze_rush"]
		if state["cd"] > 0 or f.dashing:
			return {"success": false}

		state["cd"] = CD
		state["flame_step"] = 0
		state["on"] = true
		
		f.dashing = true
		f.dash_remaining = DASH_DIST
		f.dash_dir = f.facing
		f.dash_speed = DASH_SPD
		f.dash_damage_override = HIT_DMG
		f.dash_damage_dealt = false

		# 火海回调：每 1 帧（~10px）创建一个 10px 宽火海，避免重叠堆叠伤害
		const FLAME_INTERVAL = 1
		var blaze_cb
		blaze_cb = func(old_x, new_x):
			if not f.dashing or not f.ad["blaze_rush"]["on"]:
				f.dash_step_callbacks.erase(blaze_cb)
				f.dash_damage_override = 0.0
				return
			var state2 = f.ad["blaze_rush"]
			state2["flame_step"] += 1
			if state2["flame_step"] % FLAME_INTERVAL != 0:
				return
			var mid_x = (old_x + new_x) / 2.0
			GameWorld.flame_zones.append({
				"x": mid_x - FLAME_W / 2.0,
				"y": Constants.GROUND_Y - FLAME_H,
				"w": FLAME_W, "h": FLAME_H,
				"life": FLAME_LIFE, "timer": 0,
				"damage": FLAME_DMG, "tick_interval": FLAME_TICK,
				"owner": f,
			})
		f.dash_step_callbacks.append(blaze_cb)

		Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 25, Color(1.0, 0.4, 0.1), 6, 8, "star")
		return {"success": true}

	inst.update = func():
		var state = f.ad["blaze_rush"]
		if state["cd"] > 0:
			state["cd"] -= 1

	return inst

## 虚空亲和 — 被动（不可叠加）触碰虚空时扣50%HP并传送
static func _make_void_affinity(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "虚空亲和"
	inst.description = "被动 · 不可叠加"
	inst.is_skill = false
	inst.on_in_void = func(data: Dictionary):
		var fighter = data["fighter"]
		var pre_hp = data["pre_hp"]
		fighter.hp = maxf(1.0, pre_hp * 0.5)
		fighter._teleport_to_random_ground()
	return inst

## 奥术涌流 — 主动天赋（被动+5%能量回复，释放回复40能量，冷却30s）
static func _make_arcane_surge(f) -> TalentInstance:
	const CD := 1800        # 冷却帧数（30 秒）
	const BURST_ENERGY := 40  # 释放回复能量

	var inst = TalentInstance.new()
	inst.talent_name = "奥术涌流"
	inst.description = "主动 · 不可叠加"
	inst.is_skill = true

	# ── 被动：能量回复速度 +5% ──
	inst.on_attach = func():
		f.energy_regen *= 1.05

	# ── 主动状态 ──
	f.ad["arcane_surge"] = {"cd": 0}

	inst.can_activate = func():
		return f.ad["arcane_surge"]["cd"] <= 0

	inst.activate = func():
		var state = f.ad["arcane_surge"]
		if state["cd"] > 0:
			return {"success": false}

		state["cd"] = CD
		f.energy = minf(f.max_energy, f.energy + BURST_ENERGY)

		# 释放粒子特效（奥术蓝光）
		Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 20, Color(0.3, 0.5, 1.0), 6, 10, "star")
		return {"success": true}

	inst.update = func():
		var state = f.ad["arcane_surge"]
		if state["cd"] > 0:
			state["cd"] -= 1

	return inst

## 相位闪烁 — 主动天赋（向操控方向瞬移500px，冷却10s）
static func _make_phase_blink(f) -> TalentInstance:
	const CD = 600            # 冷却帧数（10 秒）
	const BLINK_DIST = 500    # 瞬移距离

	var inst = TalentInstance.new()
	inst.talent_name = "相位闪烁"
	inst.description = "主动 · 不可叠加"
	inst.is_skill = true

	# ── 状态命名空间 ──
	f.ad["phase_blink"] = {"cd": 0}

	inst.can_activate = func():
		return f.ad["phase_blink"]["cd"] <= 0

	inst.activate = func():
		var state = f.ad["phase_blink"]
		if state["cd"] > 0:
			return {"success": false}

		state["cd"] = CD

		# 方向判定：有操控输入则按输入方向，否则按朝向
		var dir: int
		if absf(f.vx) > 0.5:
			dir = 1 if f.vx > 0 else -1
		else:
			dir = f.facing

		# 瞬移入场粒子（瞬移前位置）
		Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 15, Color(0.5, 0.3, 1.0), 4, 6, "star")

		# 执行瞬移并钳制到地图边界
		f.pos_x += dir * BLINK_DIST
		f.pos_x = clampf(f.pos_x, 10, 2400 - 10 - f.w)

		# 瞬移出场粒子（瞬移后位置）
		Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 15, Color(0.5, 0.3, 1.0), 4, 6, "star")

		return {"success": true}

	inst.update = func():
		var state = f.ad["phase_blink"]
		if state["cd"] > 0:
			state["cd"] -= 1

	return inst

## 再生符文 — 主动天赋（被动+10%治疗量，释放后5hp/s持续4s，冷却30s）
static func _make_regen_rune(f) -> TalentInstance:
	const CD = 1800              # 冷却帧数（30 秒）
	const HEAL_PER_SEC := 5.0    # 每秒回复
	const DURATION := 240        # 持续帧数（4 秒）
	const HEAL_BOOST := 0.1      # 治疗加成 10%

	var inst = TalentInstance.new()
	inst.talent_name = "再生符文"
	inst.description = "主动 · 不可叠加"
	inst.is_skill = true

	# ── 状态命名空间 ──
	f.ad["regen_rune"] = {
		"cd": 0, "active": false, "timer": 0,
		"prev_hp": f.hp, "boosting": false,
	}

	inst.can_activate = func():
		return f.ad["regen_rune"]["cd"] <= 0

	inst.activate = func():
		var state = f.ad["regen_rune"]
		if state["cd"] > 0:
			return {"success": false}

		state["cd"] = CD
		state["active"] = true
		state["timer"] = DURATION

		# 释放特效（翠绿光芒）
		Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 20, Color(0.27, 1.0, 0.27), 5, 8, "star")
		return {"success": true}

	inst.update = func():
		var state = f.ad["regen_rune"]

		# 冷却递减
		if state["cd"] > 0:
			state["cd"] -= 1

		# 主动持续治疗：5hp/s = 5/60 每帧
		if state["active"] and f.hp > 0:
			state["timer"] -= 1
			if state["timer"] <= 0:
				state["active"] = false
			else:
				f.hp = minf(f.max_hp, f.hp + HEAL_PER_SEC / 60.0)

		# 被动：所有治疗量 +10%（通过监测 hp 增量实现）
		if f.hp > state["prev_hp"] and not state["boosting"]:
			var delta = f.hp - state["prev_hp"]
			state["boosting"] = true
			f.hp = minf(f.max_hp, f.hp + delta * HEAL_BOOST)
			state["boosting"] = false

		state["prev_hp"] = f.hp

	return inst

## 战斗，爽！— 被动天赋 · 占2格（伤害+5%，受伤-10%，技能12冷却-1s，20%免疫击退）
static func _make_battle_frenzy(f) -> TalentInstance:
	const ATK_BOOST := 0.05       # 伤害 +5%
	const DMG_REDUCTION := 0.1    # 受伤 -10%
	const CD_REDUCTION := 60      # 技能冷却 -1 秒（60 帧）
	const KNOCKBACK_RESIST := 0.2 # 击退免疫概率 20%

	var inst = TalentInstance.new()
	inst.talent_name = "战斗，爽！"
	inst.description = "被动 · 不可叠加 · 占2格"
	inst.is_skill = false

	# ── 装配时生效（占2格所以会被attach两次，用flag防叠加）──
	inst.on_attach = func():
		if f.ad.get("battle_frenzy_applied", false):
			return
		f.ad["battle_frenzy_applied"] = true
		# 伤害 +5%
		f.attack_boost += ATK_BOOST
		# 受伤 -10%
		f.damage_reduction += DMG_REDUCTION
		# 技能1/2 冷却 -1s
		var s1 = f.get_skill("skill1")
		if s1: s1.cooldown = maxi(1, s1.cooldown - CD_REDUCTION)
		var s2 = f.get_skill("skill2")
		if s2: s2.cooldown = maxi(1, s2.cooldown - CD_REDUCTION)

	# ── 20% 几率免疫击退 ──
	inst.on_damage_received = func(data: Dictionary):
		if randf() < KNOCKBACK_RESIST:
			f.vx = 0.0
			f.vy = maxf(0.0, f.vy)

	return inst

## 背水一战 — 被动天赋 · 整局1次（HP<20%触发无敌10s，免疫击退+负面效果）
static func _make_last_stand(f) -> TalentInstance:
	const HP_THRESHOLD := 0.2     # 触发阈值：20% 最大生命
	const INVULN_DURATION := 600  # 无敌持续帧数（10 秒）

	var inst = TalentInstance.new()
	inst.talent_name = "背水一战"
	inst.description = "被动 · 不可叠加 · 整局1次"
	inst.is_skill = false

	# ── 状态命名空间 ──
	f.ad["last_stand"] = {"triggered": false, "active": false, "timer": 0}

	# ── hp_changed 监听：HP 首次低于 20% 时触发 ──
	inst.on_attach = func():
		f.hp_changed.connect(func(_old: float, new_hp: float):
			var state = f.ad["last_stand"]
			if state["triggered"]:
				return
			if new_hp <= 0:
				return
			if new_hp < f.max_hp * HP_THRESHOLD:
				state["triggered"] = true
				state["active"] = true
				state["timer"] = INVULN_DURATION

				# 无敌：伤害减免拉满 → 每击只受 1 点伤害
				f.damage_reduction += 1.0

				# 防止触发的那一击直接致死
				f.hp = maxf(new_hp, f.max_hp * HP_THRESHOLD)

				# 清除已有负面效果
				_clear_debuffs(f)

				# 释放粒子特效（金色光芒）
				Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 40, Color(1.0, 0.843, 0.0), 8, 12, "star", 1.5)
		)

	# ── 受击时：补回那 1 点强制伤害 → 真正无敌 + 免疫击退 ──
	inst.on_damage_received = func(_data: Dictionary):
		var state = f.ad["last_stand"]
		if not state["active"]:
			return
		# 补回每击强制扣的 1 点伤害
		f.hp = minf(f.max_hp, f.hp + 1)
		# 免疫击退
		f.vx = 0.0
		f.vy = maxf(0.0, f.vy)

	# ── 每帧：递减计时 + 持续清除负面效果 ──
	inst.update = func():
		var state = f.ad["last_stand"]
		if not state["active"]:
			return
		state["timer"] -= 1
		# 持续清除新施加的负面效果
		_clear_debuffs(f)
		if state["timer"] <= 0:
			state["active"] = false
			f.damage_reduction -= 1.0  # 恢复正常受伤

	return inst

## 清除所有负面效果（debuff）
static func _clear_debuffs(f):
	f.statuses.clear()
	f.gravity_debuff = false
	f.jump_reduction = 1.0
	f.slow_timer = 0
	f.slow_percent = 0.0
	f.burn_timer = 0

## 秩序重铸 — 主动天赋（被动技能12冷却-1s，释放重置所有技能冷却，冷却40s）
static func _make_order_reforge(f) -> TalentInstance:
	const CD := 2400             # 冷却帧数（40 秒）
	const CD_REDUCTION := 60      # 技能冷却 -1 秒

	var inst = TalentInstance.new()
	inst.talent_name = "秩序重铸"
	inst.description = "主动 · 不可叠加"
	inst.is_skill = true

	# ── 被动：技能1/2 冷却 -1s（仅首次）──
	if not f.ad.get("order_reforge_applied", false):
		f.ad["order_reforge_applied"] = true
		var s1 = f.get_skill("skill1")
		if s1: s1.cooldown = maxi(1, s1.cooldown - CD_REDUCTION)
		var s2 = f.get_skill("skill2")
		if s2: s2.cooldown = maxi(1, s2.cooldown - CD_REDUCTION)

	# ── 主动状态 ──
	f.ad["order_reforge"] = {"cd": 0}

	inst.can_activate = func():
		return f.ad["order_reforge"]["cd"] <= 0

	inst.activate = func():
		var state = f.ad["order_reforge"]
		if state["cd"] > 0:
			return {"success": false}

		state["cd"] = CD

		# 重置技能冷却（大招只重置50%）
		for sk in f.skills:
			if sk.key == "ult" and sk.cd > 0:
				sk.cd = floori(sk.cd * 0.5)
			else:
				sk.cd = 0

		# 金色重置特效
		Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 30, Color(1.0, 0.84, 0.0), 6, 9, "star", 1.2)
		return {"success": true}

	inst.update = func():
		var state = f.ad["order_reforge"]
		if state["cd"] > 0:
			state["cd"] -= 1

	return inst
