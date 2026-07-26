class_name AssassinComponent
extends CharComponent

var shadow_energy: float = 0
var shadow_energy_max: float = 5
var shadow_stance: bool = false
var shadow_stance_timer: int = 0
var shadow_energy_drain_rate: float = 5.0 / 480.0
var is_invincible: bool = false
var invincible_timer: int = 0
var enhanced_slash: bool = false
var enhanced_slash_timer: int = 0
var slash_active: bool = false
var slash_timer: int = 0
var slash_x: float = 0
var slash_y: float = 0
var slash_facing: int = 1
var slash_damage_dealt: bool = false
var skill2_active: bool = false
var skill2_timer: int = 0
var skill2_x: float = 0
var skill2_y: float = 0
var skill2_facing: int = 1
var skill2_damage_dealt: bool = false
var ult_active: bool = false
var ult_timer: int = 0
var ult_damage_timer: int = 0
var time_stop: bool = false
var time_stop_timer: int = 0
var dodge_success: bool = false
var dodge_slow_mo: int = 0
var shadow_trail: Array = []
var max_shadow_trail: int = 12

func update():
	if is_invincible and invincible_timer > 0:
		invincible_timer -= 1
		if invincible_timer <= 0:
			is_invincible = false
	if enhanced_slash_timer > 0:
		enhanced_slash_timer -= 1
		if enhanced_slash_timer <= 0:
			enhanced_slash = false
	if slash_active and slash_timer > 0:
		slash_timer -= 1
		if slash_timer <= 0:
			slash_active = false
	if dodge_slow_mo > 0:
		dodge_slow_mo -= 1
	if shadow_stance:
		shadow_energy -= shadow_energy_drain_rate
		if shadow_energy <= 0:
			shadow_energy = 0
			shadow_stance = false
			shadow_stance_timer = 0
			shadow_trail.clear()
		else:
			shadow_stance_timer -= 1
			if shadow_stance_timer <= 0:
				shadow_stance = false
				shadow_stance_timer = 0
				shadow_trail.clear()
			else:
				if absf(owner.vx) > 0.5 or owner.dashing:
					shadow_trail.append({"x": owner.pos_x, "y": owner.pos_y, "facing": owner.facing, "life": 12})
					if shadow_trail.size() > max_shadow_trail:
						shadow_trail.pop_front()
				for i in range(shadow_trail.size() - 1, -1, -1):
					shadow_trail[i]["life"] -= 1
					if shadow_trail[i]["life"] <= 0:
						shadow_trail.remove_at(i)

func on_damage_received(attacker: Fighter, dmg: float):
	if owner.dashing and is_invincible and not dodge_success:
		dodge_success = true
		dodge_slow_mo = 30
		shadow_energy = minf(shadow_energy_max, shadow_energy + 1)
		if shadow_energy >= shadow_energy_max and not shadow_stance:
			shadow_stance = true
			shadow_stance_timer = 480
		Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 15, Color(0.667, 0.533, 1.0), 3, 5, "star", 0.8)