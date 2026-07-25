class_name ProjectileSystem

# ===== Projectile System =====
static func update_projectiles(game_node: Node):
	for i in range(GameWorld.projectiles.size() - 1, -1, -1):
		var p = GameWorld.projectiles[i]
		# 1. Position & life update
		p["x"] += p["vx"]; p["y"] += p["vy"]; p["life"] -= 1

		# Gravity: parabolic projectiles
		if p.has("gravity"): p["vy"] += p["gravity"]

		# 2. Tracking (homing) effect
		if p.get("tracking") and p.has("owner") and p["owner"] and p.has("trackingTarget") and p["trackingTarget"] and p["trackingTarget"].hp > 0:
			var tt: Fighter = p["trackingTarget"]
			var dx = tt.pos_x + tt.w / 2.0 - (p["x"] + p["w"] / 2.0)
			var dy = tt.pos_y + tt.h / 2.0 - (p["y"] + p["h"] / 2.0)
			var dist = sqrt(dx * dx + dy * dy)
			if dist < 300:
				var angle = atan2(dy, dx)
				var current_angle = atan2(p["vy"], p["vx"])
				var diff = angle - current_angle
				while diff > PI: diff -= 2 * PI
				while diff < -PI: diff += 2 * PI
				var turn_speed = 0.03
				var new_angle = current_angle + clampf(diff, -turn_speed, turn_speed)
				var speed = sqrt(p["vx"] * p["vx"] + p["vy"] * p["vy"])
				p["vx"] = cos(new_angle) * speed
				p["vy"] = sin(new_angle) * speed

		# 3. Character hooks: onProjectileUpdate (e.g. witch meteor)
		if _run_projectile_update_hook(i, p, game_node):
			continue

		# 4. Out of bounds or life expired
		if p["x"] < -50 or p["x"] > Constants.MAP_W + 50 or p["y"] > Constants.GROUND_Y or p["life"] <= 0:
			# Character hooks: onProjectileUpdate (expiry handling)
			if _run_projectile_update_hook(i, p, game_node):
				continue
			_reset_casting(p)
			GameWorld.projectiles.remove_at(i)
			continue

		# 5. Collision detection
		var target = GameWorld.get_opponent(p["owner"])
		if not target or p["owner"] == target:
			GameWorld.projectiles.remove_at(i)
			continue

		# 6. Blocking / reflect
		if target.blocking and target != p["owner"]:
			if _reflect_projectile(p):
				continue

		if target.hp > 0:
			var proj_rect = Rect2(p["x"], p["y"], p["w"], p["h"])
			if target.get_hit_box().intersects(proj_rect):
				# Piercing: skip if already hit this target
				if p.get("piercing") and p.has("hitTargets") and p["hitTargets"].has(target):
					pass  # Already hit, don't deal damage again
				else:
					# Character hooks: onProjectileHit (e.g. evoker fireball, archer fire arrow, witch meteor)
					if _run_projectile_hit_hook(p, target, i, game_node):
						continue

					# Status effects on hit
					var ptype = str(p.get("type", ""))
					if ptype == "mage_ice":
						target.ice_hit_count += 1
						if target.ice_hit_count >= 2:
							target.add_status("frozen")
					# 冥炎弹命中效果
					if p.get("type") == "evoker_fireball":
						target.slow_timer = 360
						target.slow_percent = 0.2
						target.burn_timer = 360
					if p.get("isGravity"): target.add_status("gravity_debuff")
					if p.get("burn"): target.add_status("burn")
					if p.get("slow"): target.add_status("slow")
					if p.get("isFire") or p.get("is_fire"): target.add_status("burn")

					# 弓箭手火矢命中：生成火焰区域
					if p.get("is_fire") and (ptype == "arrow" or ptype == "arrow_ult"):
						GameWorld.flame_zones.append({
							"x": p["x"] - 20, "y": Constants.GROUND_Y - 20,
							"w": 120, "h": 60, "life": 240, "timer": 0,
							"damage": 2, "owner": p["owner"]
						})

					# Damage: mage projectiles have no knockback
					if ptype == "mage_fire" or ptype == "mage_ice" or ptype == "mage_light":
						Fighter.apply_damage(target, p["damage"], p["owner"], false)
					else:
						Fighter.apply_damage(target, p["damage"], p["owner"])

					# Hit particles
					Fighter.emit_particles(p["x"] + p["w"] / 2.0, p["y"] + p["h"] / 2.0, 30, Color(1.0, 0.67, 0.0), 6, 8, "star", 1.2)

					# Piercing support
				if p.get("piercing"):
					if not p.has("hitTargets"): p["hitTargets"] = []
					p["hitTargets"].append(target)
				else:
					_reset_casting(p)
					GameWorld.projectiles.remove_at(i)

# ===== Projectile Helpers =====
static func _reset_casting(p: Dictionary):
	if p.get("type") == "meteor":
		var owner: Fighter = p.get("owner")
		if owner:
			owner.is_casting_ult = false

static func _reflect_projectile(p: Dictionary) -> bool:
	var defender = GameWorld.get_opponent(p["owner"])
	if not defender.blocking:
		return false
	p["vx"] = -p["vx"] * 1.1
	p["owner"] = defender
	p["color"] = Color(1.0, 0.87, 0.27)  # gold / parry color
	defender.energy = minf(defender.max_energy, defender.energy + 20)
	Fighter.emit_particles(p["x"] + p["w"] / 2.0, p["y"] + p["h"] / 2.0, 25, Color(1.0, 0.87, 0.27), 5, 7, "star", 1.2)
	AudioManager.play_sound("parry")
	return true

static func _run_projectile_update_hook(i: int, p: Dictionary, game_node: Node) -> bool:
	var owner = p.get("owner")
	if not owner: return false
	var cfg = CharConfigs.configs.get(owner.char_id, {})
	var hooks = cfg.get("hooks")
	if not hooks is Dictionary: return false
	var func_name = hooks.get("onProjectileUpdate")
	if not func_name is String: return false
	return game_node.call(func_name, i, p)

static func _run_projectile_hit_hook(p: Dictionary, target: Fighter, i: int, game_node: Node) -> bool:
	var owner = p.get("owner")
	if not owner: return false
	var cfg = CharConfigs.configs.get(owner.char_id, {})
	var hooks = cfg.get("hooks")
	if not hooks is Dictionary: return false
	var func_name = hooks.get("onProjectileHit")
	if not func_name is String: return false
	return game_node.call(func_name, p, target, i)
