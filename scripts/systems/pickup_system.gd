class_name PickupSystem

# ===== Pickup & End System =====
static func update_pickups_and_end():
	# Pickup collection
	for i in range(GameWorld.pickups.size()-1,-1,-1):
		var item = GameWorld.pickups[i]
		if not item.active: GameWorld.pickups.remove_at(i); continue
		item.update()
		for t in [GameWorld.player, GameWorld.enemy]:
			if t.hp <= 0: continue
			var d = sqrt(pow(t.pos_x+t.w/2-item.x-item.w/2,2)+pow(t.pos_y+t.h/2-item.y-item.h/2,2))
			if d < 35:
				item.apply_effect(t); item.active = false
				GameWorld.pickups.remove_at(i); break
	# Pickup spawn timer (difficulty-based: hard=720 frames, else=420 frames)
	var interval = 720 if GameWorld.difficulty == "hard" else 420
	if GameWorld.pickup_timer <= 0:
		_spawn_pickup()
		GameWorld.pickup_timer = interval
	else:
		GameWorld.pickup_timer -= 1
	# Particle lifecycle
	GameWorld.particles = GameWorld.particles.filter(func(p): return p.update())
	# Explosion effects fade out
	for i2 in range(GameWorld.explosion_effects.size() - 1, -1, -1):
		var e = GameWorld.explosion_effects[i2]
		e["life"] -= 1
		e["alpha"] = float(e["life"]) / float(e["max_life"])
		if e["life"] <= 0:
			GameWorld.explosion_effects.remove_at(i2)
	# Game over check
	if GameWorld.player.hp <= 0:
		GameWorld.game_over = true
		GameWorld.game_result = "lose"
	elif GameWorld.enemy.hp <= 0:
		GameWorld.game_over = true
		GameWorld.game_result = "win"

static func init_pickups():
	GameWorld.pickups.clear()
	var count = 4 if GameWorld.difficulty == "hard" else 6
	for i in count:
		_spawn_pickup()

static func _spawn_pickup():
	var max_pickups = 6 if GameWorld.difficulty == "hard" else 10
	if GameWorld.pickups.size() >= max_pickups:
		return
	var px = 100 + randf() * 2200
	var py = 380 - 30 - randf() * 120
	# Weight-based type selection (matches JS PICKUP_DEFS)
	var keys = Pickup.PICKUP_DEFS.keys()
	var total: float = 0.0
	var weight_key = "hard_weight" if GameWorld.difficulty == "hard" else "weight"
	for k in keys:
		total += Pickup.PICKUP_DEFS[k][weight_key]
	var r = randf() * total
	var chosen = keys[0]
	for k in keys:
		r -= Pickup.PICKUP_DEFS[k][weight_key]
		if r <= 0:
			chosen = k
			break
	GameWorld.pickups.append(Pickup.new(px, py, chosen))
