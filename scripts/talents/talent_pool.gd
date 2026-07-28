# 天赋注册表 + 工厂
class_name TalentPool

static var _registry := {}

static func init():
	if not _registry.is_empty():
		return
	_register_all()

static func _register_all():
	_registry["vitality"]   = { "factory": _make_vitality }
	_registry["thorns"]     = { "factory": _make_thorns }
	_registry["vampiric"]   = { "factory": _make_vampiric }
	_registry["blaze_rush"] = { "factory": _make_blaze_rush }

static func create(talent_id: String, fighter) -> TalentInstance:
	var entry = _registry.get(talent_id)
	if not entry:
		return null
	var inst: TalentInstance = entry["factory"].call(fighter)
	inst.talent_id = talent_id
	return inst

static func get_all_ids() -> Array:
	return _registry.keys()

# ============ 工厂函数（参数不标注 Fighter 类型，避免循环引用）============

## 生命强化 — 被动属性
static func _make_vitality(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "生命强化"
	inst.description = "最大生命值 +20%"
	inst.is_skill = false
	inst.on_attach = func():
		f.add_stat_mod("max_hp", "talent.vitality", 0.0, 1.2)
	return inst

## 荆棘 — 被动事件
static func _make_thorns(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "荆棘"
	inst.description = "受击时反弹 3.0 点伤害"
	inst.is_skill = false
	inst.on_damage_received = func(data: Dictionary):
		var attacker = data.get("attacker")
		var depth = data.get("recursion_depth", 0)
		if attacker and attacker.hp > 0:
			f.apply_damage(attacker, 3.0, f, false,
				Color.GREEN, "hit_enemy", "talent.thorns", depth + 1)
	return inst

## 嗜血 — 被动事件
static func _make_vampiric(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "嗜血"
	inst.description = "造成伤害的 10% 转化为生命值"
	inst.is_skill = false
	inst.on_damage_dealt = func(data: Dictionary):
		var dmg = data.get("damage", 0)
		if dmg > 0:
			f.hp = minf(f.max_hp, f.hp + dmg * 0.1)
	return inst

## 烈焰冲刺 — 主动天赋
static func _make_blaze_rush(f) -> TalentInstance:
	var inst = TalentInstance.new()
	inst.talent_name = "烈焰冲刺"
	inst.description = "激活后下次冲刺附带 10 点火焰伤害"
	inst.is_skill = true
	f.ad["blaze_rush"] = {"cd": 0}
	inst.can_activate = func(): return f.ad["blaze_rush"]["cd"] <= 0
	inst.activate = func():
		if f.ad["blaze_rush"]["cd"] > 0:
			return {"success": false}
		f.ad["blaze_rush"]["cd"] = 300
		f.ad["blaze_rush"]["ready"] = true
		return {"success": true}
	inst.update = func():
		if f.ad["blaze_rush"]["cd"] > 0:
			f.ad["blaze_rush"]["cd"] -= 1
	inst.on_damage_dealt = func(data: Dictionary):
		var target = data.get("target")
		var depth = data.get("recursion_depth", 0)
		var ad_data: Dictionary = f.ad.get("blaze_rush", {})
		if ad_data.get("ready", false) and target:
			f.ad["blaze_rush"]["ready"] = false
			f.apply_damage(target, 10, f, false,
				Color.ORANGE, "hit_enemy", "talent.blaze_rush", depth + 1)
	return inst
