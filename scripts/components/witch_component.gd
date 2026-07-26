class_name WitchComponent
extends CharComponent

var is_flying: bool = false
var fly_energy_drain: float = 8.0 / 60.0
var is_casting_ult: bool = false
var cast_ult_x: float = 0
var cast_ult_y: float = 0

func update():
	if is_flying:
		owner.energy -= fly_energy_drain
		if owner.energy <= 0:
			owner.energy = 0
			is_flying = false
	# 角色内部状态：只有角色脚本和物理系统需要，直接通过组件访问