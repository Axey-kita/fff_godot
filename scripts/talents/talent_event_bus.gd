# 天赋事件广播（字典化 + 递归深度控制）
class_name TalentEventBus

const MAX_RECURSION := 3

# 注意：参数不使用 Fighter 类型标注，避免与 fighter.gd 的循环引用
static func emit_damage_dealt(fighter, target, dmg: float,
		source: String, recursion_depth: int = 0):
	if recursion_depth >= MAX_RECURSION:
		return
	if not fighter or not fighter.talent_manager:
		return
	if source.begins_with("talent."):
		return  # 天赋来源的伤害不再触发事件
	fighter.talent_manager.on_damage_dealt({
		"fighter": fighter,
		"target": target,
		"damage": dmg,
		"source": source,
		"recursion_depth": recursion_depth,
	})

static func emit_damage_received(fighter, attacker, dmg: float,
		source: String, recursion_depth: int = 0):
	if recursion_depth >= MAX_RECURSION:
		return
	if not fighter or not fighter.talent_manager:
		return
	if source.begins_with("talent."):
		return
	fighter.talent_manager.on_damage_received({
		"fighter": fighter,
		"attacker": attacker,
		"damage": dmg,
		"source": source,
		"recursion_depth": recursion_depth,
	})

static func emit_kill(fighter, target):
	if fighter and fighter.talent_manager:
		fighter.talent_manager.on_kill({"fighter": fighter, "target": target})

static func emit_dash_end(fighter):
	if fighter and fighter.talent_manager:
		fighter.talent_manager.on_dash_end()
