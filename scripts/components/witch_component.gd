class_name WitchComponent
extends CharComponent

var is_flying: bool = false
var fly_energy_drain: float = 8.0 / 60.0
var is_casting_ult: bool = false
var ult_lock_timer: int = 0  # 大招前摇锁定帧数（期间不可移动）
var cast_ult_x: float = 0
var cast_ult_y: float = 0

func update():
	if is_flying:
		owner.energy -= fly_energy_drain
		if owner.energy <= 0:
			owner.energy = 0
			is_flying = false
	if ult_lock_timer > 0:
		ult_lock_timer -= 1
		if ult_lock_timer <= 0 and is_casting_ult:
			is_casting_ult = false