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
	# Pickup spawn timer (difficulty-based)
	var interval = _pickup_interval()
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

static func _pickup_interval() -> int:
	# hard=720 帧（12 秒），hell=900 帧（15 秒），其余=420 帧（7 秒）
	if Constants.difficulty_at_least(GameWorld.difficulty, "hell"):
		return 900
	if Constants.difficulty_at_least(GameWorld.difficulty, "hard"):
		return 720
	return 420

static func _initial_pickup_count() -> int:
	# hard/hell 初始 4 个，其余 6 个
	if Constants.difficulty_at_least(GameWorld.difficulty, "hard"):
		return 4
	return 6

static func _max_pickups() -> int:
	# hard/hell 上限 6 个，其余 10 个
	if Constants.difficulty_at_least(GameWorld.difficulty, "hard"):
		return 6
	return 10

static func init_pickups():
	GameWorld.pickups.clear()
	var count = _initial_pickup_count()
	for i in count:
		_spawn_pickup()

static func _spawn_pickup():
	var max_pickups = _max_pickups()
	if GameWorld.pickups.size() >= max_pickups:
		return
	var px = 100 + randf() * 2200
	var py = 380 - 30 - randf() * 120
	# Weight-based type selection — hell 沿用 hard_weight（更少 attack/cooldown）
	var keys = Pickup.PICKUP_DEFS.keys()
	var total: float = 0.0
	var weight_key = "hard_weight" if Constants.difficulty_at_least(GameWorld.difficulty, "hard") else "weight"
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
