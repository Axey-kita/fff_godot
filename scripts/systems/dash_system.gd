class_name DashSystem

# ===== Dash System（数据驱动，不依赖任何角色/组件）=====
static func update_dash():
	for f in GameWorld.entities:
		if not (f.dashing and f.hp > 0):
			continue
		var step = f.dash_speed
		var old_x = f.pos_x
		var nx = f.pos_x + f.dash_dir * step
		if nx < 10 or nx + f.w > 2390:
			f.dashing = false; f.state = "idle"; f.vx = 0; continue
		f.pos_x = nx; f.dash_remaining -= step

		# 碰撞伤害（伤害值由角色注入覆盖）
		var t = GameWorld.get_opponent(f)
		if t and t.hp > 0 and f.get_hit_box().intersects(t.get_hit_box()):
			if not f.dash_damage_dealt:
				f.dash_damage_dealt = true
				var dmg = f.dash_damage_override if f.dash_damage_override > 0 else 15.0
				Fighter.apply_damage(t, dmg, f)
				t.vx = f.dash_dir * 7; t.vy = -4

		# 每帧回调（角色注入：刺客闪避、影武者特效等）
		for cb in f.dash_step_callbacks:
			if cb and cb.is_valid():
				cb.call(old_x, nx)

		if f.dash_remaining <= 0:
			f.dashing = false; f.state = "idle"; f.vx = f.dash_dir * 2
			# call on_dash_end
			TalentEventBus.emit_dash_end(f)
