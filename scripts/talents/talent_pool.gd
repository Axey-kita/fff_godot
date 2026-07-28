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

	_registry["vitality"]      = { "factory": _make_vitality }
	_registry["thorns"]        = { "factory": _make_thorns }
	_registry["vampiric"]      = { "factory": _make_vampiric }
	_registry["blaze_rush"]    = { "factory": _make_blaze_rush }
	_registry["void_affinity"] = { "factory": _make_void_affinity }

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
