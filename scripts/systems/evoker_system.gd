class_name EvokerSystem

# ===== Evoker Runtime System =====
# Handles all per-frame updates for evoker entities: status effects, fire seas,
# gravity balls, void rifts, and the summon state machine.

static func update() -> void:
	_update_evoker_statuses()
	_update_fire_seas()
	_update_gravity_balls()
	_update_void_rifts()
	_update_summons()

# ===== B1: Evoker-specific entity state updates =====
static func _update_evoker_statuses() -> void:
	for f in GameWorld.entities:
		if f.char_id != "evoker" or f.hp <= 0.0:
			continue

		# Slow timer
		if f.slow_timer > 0:
			f.slow_timer -= 1
			if f.slow_percent > 0.0:
				var max_spd: float = 2.25 * (1.0 - f.slow_percent)
				if absf(f.vx) > max_spd:
					f.vx = max_spd * signf(f.vx)

		# Burn timer — damage every 120 frames (2 seconds)
		if f.burn_timer > 0:
			f.burn_timer -= 1
			if f.burn_timer % 120 == 0:
				f.hp -= 1.0
				if f.hp < 0.0:
					f.hp = 0.0

		# Bleed timer
		if f.bleed_timer > 0:
			f.bleed_timer -= 1

		# Blind timer — disable attacking, slow to 50%
		if f.blind_timer > 0:
			f.blind_timer -= 1
			f.attacking = false
			var blind_max_spd: float = 2.25 * 0.5
			if absf(f.vx) > blind_max_spd:
				f.vx = blind_max_spd * signf(f.vx)

# ===== B2: Fire sea updates =====
static func _update_fire_seas() -> void:
	for i in range(GameWorld.evoker_fire_seas.size() - 1, -1, -1):
		var fs: Dictionary = GameWorld.evoker_fire_seas[i]
		fs["timer"] = fs.get("timer", 0) + 1
		if fs["timer"] >= fs.get("duration", 240):
			GameWorld.evoker_fire_seas.remove_at(i)
			continue

		# Damage every 12 frames
		if fs["timer"] % 12 == 0:
			var owner: Fighter = fs.get("owner") as Fighter
			if owner:
				var enemy: Fighter = GameWorld.get_opponent(owner)
				if enemy and enemy.hp > 0.0:
					var fs_x: float = fs.get("x", 0.0)
					var fs_y: float = fs.get("y", 0.0)
					var fs_w: float = fs.get("w", 0.0)
					var fs_h: float = fs.get("h", 0.0)
					if _rect_collision(enemy.pos_x, enemy.pos_y, enemy.w, enemy.h, fs_x, fs_y, fs_w, fs_h):
						Fighter.apply_damage(enemy, 1.0, owner, false)
						enemy.slow_timer = 12
						enemy.slow_percent = 0.4

# ===== B3: Gravity ball updates =====
static func _update_gravity_balls() -> void:
	for i in range(GameWorld.gravity_balls.size() - 1, -1, -1):
		var b: Dictionary = GameWorld.gravity_balls[i]
		b["x"] = b.get("x", 0.0) + b.get("vx", 0.0)
		b["y"] = b.get("y", 0.0) + b.get("vy", 0.0)
		b["life"] = b.get("life", 0) - 1

		if b["life"] <= 0:
			GameWorld.gravity_balls.remove_at(i)
			continue

		var owner: Fighter = b.get("owner") as Fighter
		if not owner:
			continue

		var enemy: Fighter = GameWorld.get_opponent(owner)
		if not enemy or enemy.hp <= 0.0:
			continue

		var b_x: float = b.get("x", 0.0)
		var b_y: float = b.get("y", 0.0)
		var b_w: float = b.get("w", 30.0)
		var b_h: float = b.get("h", 30.0)
		var att_rad: float = b.get("attract_radius", 120.0)

		# Attract: pull enemy toward ball center
		var cx: float = b_x + b_w / 2.0
		var cy: float = b_y + b_h / 2.0
		var ex_cx: float = enemy.pos_x + enemy.w / 2.0
		var ex_cy: float = enemy.pos_y + enemy.h / 2.0
		var dx: float = cx - ex_cx
		var dy: float = cy - ex_cy
		var dist: float = sqrt(dx * dx + dy * dy)

		if dist < att_rad and dist > 0.1:
			enemy.vx += (dx / dist) * 0.5
			enemy.vy += (dy / dist) * 0.5

		# Damage every 20 frames
		var dmg_timer: int = b.get("damage_timer", 0) + 1
		b["damage_timer"] = dmg_timer
		if dmg_timer % 20 == 0:
			var ball_rect := Rect2(b_x, b_y, b_w, b_h)
			if enemy.get_hit_box().intersects(ball_rect):
				Fighter.apply_damage(enemy, 1.0, owner, false)

# ===== B4: Void rift updates =====
static func _update_void_rifts() -> void:
	for i in range(GameWorld.void_rifts.size() - 1, -1, -1):
		var rift: Dictionary = GameWorld.void_rifts[i]
		rift["timer"] = rift.get("timer", 0) + 1
		if rift["timer"] >= rift.get("duration", 240):
			GameWorld.void_rifts.remove_at(i)
			continue

		# Damage every 6 frames
		if rift["timer"] % 6 == 0:
			var owner: Fighter = rift.get("owner") as Fighter
			if owner:
				var enemy: Fighter = GameWorld.get_opponent(owner)
				if enemy and enemy.hp > 0.0:
					var r_x: float = rift.get("x", 0.0)
					var r_y: float = rift.get("y", 0.0)
					var r_w: float = rift.get("w", 0.0)
					var r_h: float = rift.get("h", 0.0)
					if _rect_collision(enemy.pos_x, enemy.pos_y, enemy.w, enemy.h, r_x, r_y, r_w, r_h):
						Fighter.apply_damage(enemy, 1.0, owner, false)

# ===== B5: Summon state machine =====
static func _update_summons() -> void:
	for i in range(GameWorld.evoker_summons.size() - 1, -1, -1):
		var summon: Dictionary = GameWorld.evoker_summons[i]
		var owner: Fighter = summon.get("owner") as Fighter

		# Owner null or dead — remove summon
		if not owner or owner.hp <= 0.0:
			GameWorld.evoker_summons.remove_at(i)
			continue

		# Summon hp <= 0 — mark type as dead, remove
		if summon.get("hp", 0.0) <= 0.0:
			var st: int = summon.get("type", -1)
			if st >= 0:
				owner.set("summon_dead" + str(st + 1), true)
			GameWorld.evoker_summons.remove_at(i)
			continue

		# HP regen
		var mhp: float = summon.get("max_hp", 0.0)
		if summon["hp"] < mhp:
			summon["hp"] = minf(mhp, summon["hp"] + 0.05)

		# Action timer
		if summon.get("action_timer", 0) > 0:
			summon["action_timer"] = summon["action_timer"] - 1

		# Flash timer
		if summon.get("flash_timer", 0) > 0:
			summon["flash_timer"] = summon["flash_timer"] - 1

		var enemy: Fighter = GameWorld.get_opponent(owner)

		# === State machine ===
		var state: String = summon.get("state", "随行")
		var sx: float = summon.get("x", 0.0)
		var sy: float = summon.get("y", 0.0)
		var sw: float = summon.get("w", 40.0)
		var sh: float = summon.get("h", 40.0)

		match state:
			"随行":
				# Smoothly follow owner (offset -50, +10)
				var target_x: float = owner.pos_x - 50.0
				var target_y: float = owner.pos_y + 10.0
				summon["vx"] = summon.get("vx", 0.0) + (target_x - sx) * 0.08
				summon["vy"] = summon.get("vy", 0.0) + (target_y - sy) * 0.08
				var speed: float = sqrt(summon["vx"] * summon["vx"] + summon["vy"] * summon["vy"])
				if speed > 3.5:
					summon["vx"] = (summon["vx"] / speed) * 3.5
					summon["vy"] = (summon["vy"] / speed) * 3.5

			"猎杀":
				if enemy and enemy.hp > 0.0:
					# Slowly move toward enemy at 1.5 speed
					var edx: float = enemy.pos_x - sx
					var edy: float = enemy.pos_y - sy
					var edist: float = sqrt(edx * edx + edy * edy)
					if edist > 0.1:
						summon["vx"] = (edx / edist) * 1.5
						summon["vy"] = (edy / edist) * 1.5
					# Clamp speed to 2.0
					var spd2: float = sqrt(summon["vx"] * summon["vx"] + summon["vy"] * summon["vy"])
					if spd2 > 2.0:
						summon["vx"] = (summon["vx"] / spd2) * 2.0
						summon["vy"] = (summon["vy"] / spd2) * 2.0

			"回归":
				# Move toward owner at 6.0 speed
				var ret_tx: float = owner.pos_x - 50.0
				var ret_ty: float = owner.pos_y + 10.0
				var ret_dx: float = ret_tx - sx
				var ret_dy: float = ret_ty - sy
				var ret_dist: float = sqrt(ret_dx * ret_dx + ret_dy * ret_dy)
				if ret_dist > 0.1:
					summon["vx"] = (ret_dx / ret_dist) * 6.0
					summon["vy"] = (ret_dy / ret_dist) * 6.0
				else:
					summon["vx"] = 0.0
					summon["vy"] = 0.0

				# If within 10px of owner, switch to 随行
				if ret_dist < 10.0:
					summon["state"] = "随行"

				# Along the way, if colliding with enemy, deal 5 damage (track in hit_enemies array)
				if enemy and enemy.hp > 0.0:
					var hit_ens: Array = summon.get("hit_enemies", [])
					if not hit_ens.has(enemy):
						if _rect_collision(sx, sy, sw, sh, enemy.pos_x, enemy.pos_y, enemy.w, enemy.h):
							Fighter.apply_damage(enemy, 5.0, owner, false)
							hit_ens.append(enemy)
							summon["hit_enemies"] = hit_ens

			"突进":
				# Move by dash_dir * 8 per frame
				var dash_d: int = summon.get("dash_dir", 1)
				summon["vx"] = dash_d * 8.0
				summon["vy"] = 0.0

				var dash_t: int = summon.get("dash_timer", 0) - 1
				summon["dash_timer"] = dash_t

				# If colliding with enemy, deal 10 damage (dash_hit flag)
				if enemy and enemy.hp > 0.0:
					var dash_h: bool = summon.get("dash_hit", false)
					if not dash_h:
						if _rect_collision(sx, sy, sw, sh, enemy.pos_x, enemy.pos_y, enemy.w, enemy.h):
							Fighter.apply_damage(enemy, 10.0, owner, false)
							summon["dash_hit"] = true

				# When dash_timer <= 0, switch to 猎杀
				if dash_t <= 0:
					summon["state"] = "猎杀"

		# Apply velocity to position
		summon["x"] = summon.get("x", 0.0) + summon.get("vx", 0.0)
		summon["y"] = summon.get("y", 0.0) + summon.get("vy", 0.0)
		# Update local refs after position change
		sx = summon["x"]
		sy = summon["y"]

		# === Passive auras ===
		var s_type: int = summon.get("type", -1)
		if enemy and enemy.hp > 0.0:
			var ecx: float = enemy.pos_x + enemy.w / 2.0
			var ecy: float = enemy.pos_y + enemy.h / 2.0
			var scx: float = sx + sw / 2.0
			var scy: float = sy + sh / 2.0
			var aura_dx: float = ecx - scx
			var aura_dy: float = ecy - scy
			var aura_dist: float = sqrt(aura_dx * aura_dx + aura_dy * aura_dy)

			match s_type:
				1:
					# 摄魂：if enemy within 150px, every 60 frames drain 5 energy
					if aura_dist < 150.0 and GameWorld.frame % 60 == 0:
						enemy.energy = maxf(0.0, enemy.energy - 5.0)
				2:
					# 凝视：enemy within 150px → skill cd +1s (debuff, removed on leaving)
					if aura_dist < 150.0:
						if not enemy.evoker_gazed:
							var es1 = enemy.get_skill("skill1")
							if es1: es1.cd += 60
							var es2 = enemy.get_skill("skill2")
							if es2: es2.cd += 60
							enemy.evoker_gazed = true
					elif enemy.evoker_gazed:
						var es1 = enemy.get_skill("skill1")
						if es1: es1.cd = maxi(0, es1.cd - 60)
						var es2 = enemy.get_skill("skill2")
						if es2: es2.cd = maxi(0, es2.cd - 60)
						enemy.evoker_gazed = false

		# === Hit detection (non-随行 state only) ===
		if state != "随行":
			# Hit CD
			var hit_cd: int = summon.get("hit_cd", 0)
			if hit_cd > 0:
				summon["hit_cd"] = hit_cd - 1

			# Enemy melee attack on summon
			if enemy and enemy.hp > 0.0 and hit_cd <= 0:
				if enemy.attacking and enemy.attack_hit_dealt:
					if _rect_collision(sx, sy, sw, sh, enemy.pos_x, enemy.pos_y, enemy.w, enemy.h):
						summon["hp"] = summon.get("hp", 0.0) - enemy.attack_damage
						summon["hit_cd"] = 30
						var fsx: float = sx + sw / 2.0
						var fsy: float = sy + sh / 2.0
						Fighter.emit_particles(fsx, fsy, 8, Color(1.0, 0.0, 0.0), 2, 10)

			# Enemy projectiles hitting summon
			if enemy:
				for pi in range(GameWorld.projectiles.size() - 1, -1, -1):
					var proj: Dictionary = GameWorld.projectiles[pi]
					var p_owner: Fighter = proj.get("owner") as Fighter
					if p_owner != enemy:
						continue
					var pr_x: float = proj.get("x", 0.0)
					var pr_y: float = proj.get("y", 0.0)
					var pr_w: float = proj.get("w", 32.0)
					var pr_h: float = proj.get("h", 20.0)
					if _rect_collision(sx, sy, sw, sh, pr_x, pr_y, pr_w, pr_h):
						summon["hp"] = summon.get("hp", 0.0) - proj.get("damage", 0.0)
						if not proj.get("piercing", false):
							GameWorld.projectiles.remove_at(pi)


# ===== Utility: rectangle collision check =====
static func _rect_collision(a_x: float, a_y: float, a_w: float, a_h: float, b_x: float, b_y: float, b_w: float, b_h: float) -> bool:
	return a_x + a_w > b_x and a_x < b_x + b_w and a_y + a_h > b_y and a_y < b_y + b_h
