class_name ShadowwarriorComponent
extends CharComponent

var stealth_active: bool = false
var stealth_timer: int = 0
var last_skill_time: int = -999
var retreat_timer: int = 0
var retreat_dir: int = 1
var break_strike_timer: int = 0
var pending_trap: bool = false
var shadow_trap_active: bool = false
var shadow_trap: Dictionary = {}
var pending_clones: bool = false
var clone_reveal_timer: int = 0
var iaido_active: bool = false
var iaido_timer: int = 0
var iaido_frozen: bool = false
var iaido_dir: int = 1
var iaido_slash: Dictionary = {}

func update():
	if iaido_active and iaido_timer > 0:
		iaido_timer -= 1
	if stealth_active and stealth_timer > 0:
		stealth_timer -= 1
		if stealth_timer <= 0:
			stealth_active = false
			stealth_timer = 0
	if retreat_timer > 0:
		retreat_timer -= 1
	if break_strike_timer > 0:
		break_strike_timer -= 1
	# 写入黑板：系统只读，不查询组件
	owner.state_flags["iaido_active"] = iaido_active
	owner.state_flags["iaido_timer"] = iaido_timer
	owner.state_flags["stealth_active"] = stealth_active