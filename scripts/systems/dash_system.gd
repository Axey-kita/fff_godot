class_name DashSystem

# Component preloads for type resolution
const ShadowwarriorComponent = preload("res://scripts/components/shadowwarrior_component.gd")
const AssassinComponent = preload("res://scripts/components/assassin_component.gd")

# ===== Dash System =====
static func update_dash():
	for f in GameWorld.entities:
		if f.dashing and f.hp > 0:
			var step = f.dash_speed
			var old_x = f.pos_x
			var nx = f.pos_x + f.dash_dir * step
			if nx < 10 or nx + f.w > 2390:
				f.dashing = false; f.state = "idle"; f.vx = 0; continue
			f.pos_x = nx; f.dash_remaining -= step
			var t = GameWorld.get_opponent(f)
			if t and t.hp > 0 and f.get_hit_box().intersects(t.get_hit_box()):
				if not f.dash_damage_dealt:
					f.dash_damage_dealt = true
					# 影武者破影一击：10 点伤害（通过 break_strike_timer 字段判断）
					var shadow_comp: ShadowwarriorComponent = f.components.get_component("shadowwarrior") if f.components else null
					var dmg = 10.0 if (shadow_comp and shadow_comp.break_strike_timer > 0) else 15.0
					Fighter.apply_damage(t, dmg, f)
					t.vx = f.dash_dir * 7; t.vy = -4
			# 刺客「一瞬」闪避检测：使用连续碰撞检测（冲刺路径与投射物相交）
			if f.char_id == "assassin":
				var assassin_comp: AssassinComponent = f.components.get_component("assassin") if f.components else null
				if assassin_comp and assassin_comp.is_invincible:
					_check_assassin_dodge_through_projectiles(f, old_x, nx, assassin_comp)
			if f.dash_remaining <= 0:
				f.dashing = false; f.state = "idle"; f.vx = f.dash_dir * 2

# 刺客闪避：检测冲刺路径上是否有敌方投射物
static func _check_assassin_dodge_through_projectiles(f: Fighter, old_x: float, new_x: float, assassin_comp: AssassinComponent):
	var top = f.pos_y + 4
	var bottom = f.pos_y + f.h - 4
	var path_x = minf(old_x, new_x)
	var path_w = absf(new_x - old_x) + f.w
	var path_rect = Rect2(path_x, top, path_w, bottom - top)
	for p in GameWorld.projectiles:
		var owner = p.get("owner")
		if owner == null or owner == f:
			continue
		var opp = GameWorld.get_opponent(f)
		if owner != opp:
			continue
		var proj_rect = Rect2(p["x"], p["y"], p["w"], p["h"])
		if path_rect.intersects(proj_rect):
			if not assassin_comp.dodge_success:
				assassin_comp.dodge_success = true
				assassin_comp.dodge_slow_mo = 30
				assassin_comp.shadow_energy = minf(assassin_comp.shadow_energy_max, assassin_comp.shadow_energy + 1)
				if assassin_comp.shadow_energy >= assassin_comp.shadow_energy_max and not assassin_comp.shadow_stance:
					assassin_comp.shadow_stance = true
					assassin_comp.shadow_stance_timer = 480
				Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 15, Color(0.667, 0.533, 1.0), 3, 5, "star", 0.8)
				print("[DODGE-DEBUG] ★ 闪避触发（路径检测）！shadow_energy=", assassin_comp.shadow_energy, " dodge_slow_mo=", assassin_comp.dodge_slow_mo)
			break
