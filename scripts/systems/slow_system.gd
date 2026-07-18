class_name SlowSystem

# ===== Slow System =====
static func update_slow():
	for f in GameWorld.entities:
		if f.hp <= 0: continue
		var factor = f.get_slowed_factor()
		if factor < 1 and not f.has_status("frozen") and not f.dashing:
			f.vx *= factor
