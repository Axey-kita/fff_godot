class_name DashSystem

# ===== Dash System =====
static func update_dash():
	for f in GameWorld.entities:
		if f.dashing and f.hp > 0:
			var step = f.dash_speed
			var nx = f.pos_x + f.dash_dir * step
			if nx < 10 or nx + f.w > 2390:
				f.dashing = false; f.state = "idle"; f.vx = 0; continue
			f.pos_x = nx; f.dash_remaining -= step
			var t = GameWorld.get_opponent(f)
			if t and t.hp > 0 and f.get_hit_box().intersects(t.get_hit_box()):
				if not f.dash_damage_dealt:
					f.dash_damage_dealt = true
					Fighter.apply_damage(t, 15, f)
					t.vx = f.dash_dir * 7; t.vy = -4
			if f.dash_remaining <= 0:
				f.dashing = false; f.state = "idle"; f.vx = f.dash_dir * 2
