class_name RoseComponent
extends CharComponent

var blood_abyss: float = 0.0
var blood_heal_timer: int = 0
var rose_skill2_active: bool = false
var rose_skill2_damage_tick: int = 0
var rose_skill2_tick_damage: float = 3.0
var rose_skill2_enhanced: bool = false
var rose_skill2_fly_timer: int = 0
var rose_grab_center_x: float = -9999.0
var rose_skill1_enhanced_slashes: Array = []
var rose_skill1_slash_spawn_timer: int = 0
var rose_blood_abyss_suppressed: bool = false
var time_stop: bool = false
var time_stop_timer: int = 0

func update():
	if blood_abyss > 0 and owner.hp < owner.max_hp:
		blood_heal_timer += 1
		if blood_heal_timer >= 120:
			blood_heal_timer = 0
			blood_abyss -= 1
			owner.hp = minf(owner.max_hp, owner.hp + 1)
	# 全局效果写入黑板，使用信号驱动
	owner.set_state_flag("time_stop", time_stop)

func on_attack_hit(target: Fighter, dmg: float):
	if not rose_blood_abyss_suppressed:
		blood_abyss = minf(40.0, blood_abyss + dmg)
	if rose_blood_abyss_suppressed:
		rose_blood_abyss_suppressed = false