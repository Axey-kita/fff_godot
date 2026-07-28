# Fighter 上的天赋管理器
class_name TalentManager
extends RefCounted

var talents: Array = []
var owner = null  # Fighter 类型，避免循环引用不标注

func init(fighter, talent_ids: Array):
	owner = fighter
	for tid in talent_ids:
		var t = TalentPool.create(tid, fighter)
		if not t:
			continue
		# 兼容性检查
		if t.compatible_chars.size() > 0 and not fighter.char_id in t.compatible_chars:
			continue
		t.on_attach.call()
		talents.append(t)
		# 主动天赋填充槽位
		if t.is_skill:
			fighter.talent_slots.append(t)

func update():
	for t in talents:
		t.update.call()

# ── 事件分发 ──
func on_damage_dealt(data: Dictionary):
	for t in talents:
		if t.on_damage_dealt.is_valid():
			t.on_damage_dealt.call(data)

func on_damage_received(data: Dictionary):
	for t in talents:
		if t.on_damage_received.is_valid():
			t.on_damage_received.call(data)

func on_kill(data: Dictionary):
	for t in talents:
		if t.on_kill.is_valid():
			t.on_kill.call(data)

func on_in_void(data: Dictionary):
	for t in talents:
		if t.on_in_void.is_valid():
			t.on_in_void.call(data)

func on_dash_end():
	for t in talents:
		if t.on_dash_end.is_valid():
			t.on_dash_end.call()

# 主动天赋接口
func activate_slot(index: int) -> Dictionary:
	if not owner:
		return {"success": false}
	if index < 0 or index >= owner.talent_slots.size():
		return {"success": false}
	var t = owner.talent_slots[index]
	if not t.can_activate.call():
		return {"success": false}
	return t.activate.call()
