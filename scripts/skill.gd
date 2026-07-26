class_name Skill

var key: String
var skill_name: String
var cooldown: int
var energy_cost: int
var cd: int = 0
var can_use_func: Callable
var execute_func: Callable

func _init(p_key: String = "", p_name: String = "", p_cooldown: int = 0, p_energy_cost: int = 0, 
		   p_can_use: Callable = Callable(), p_execute: Callable = Callable()):
	key = p_key
	skill_name = p_name
	cooldown = p_cooldown
	energy_cost = p_energy_cost
	can_use_func = p_can_use
	execute_func = p_execute

func can_use(owner: Fighter) -> bool:
	if cd > 0:
		return false
	if owner.energy < energy_cost:
		return false
	if owner.charging_attack:
		return false
	if can_use_func.is_valid():
		return can_use_func.call(owner)
	return true

func try_use(owner: Fighter) -> Dictionary:
	if not can_use(owner):
		return {"success": false}
	owner.energy -= energy_cost
	cd = cooldown
	if execute_func.is_valid():
		var result = execute_func.call(owner)
		if result is Dictionary:
			return result
	return {"success": true}

func update():
	if cd > 0:
		cd -= 1
