# 天赋运行时实例
class_name TalentInstance
extends RefCounted

var talent_id: String = ""
var talent_name: String = ""
var description: String = ""
var icon: String = ""
var is_skill: bool = false          # true=主动(需按键), false=被动
var compatible_chars: Array = []    # 空=所有角色可用, 非空=白名单

# 行为回调
var on_attach: Callable = func(): pass
var update: Callable = func(): pass
var can_activate: Callable = func(): return false
var activate: Callable = func(): return {"success": false}

# 事件回调（字典参数）
var on_damage_dealt: Callable = func(data: Dictionary): pass
var on_damage_received: Callable = func(data: Dictionary): pass
var on_skill_used: Callable = func(data: Dictionary): pass
var on_dodge: Callable = func(data: Dictionary): pass
var on_kill: Callable = func(data: Dictionary): pass
