class_name AISystem

# ===== AI System =====
static func update_ai(ai_think_delay: int) -> int:
	if GameWorld.game_mode == "pvp" or GameWorld.enemy.hp <= 0:
		return ai_think_delay
	var f = GameWorld.enemy
	
	# Frozen check (matches JS: if enemy.hasStatus('frozen') return)
	if f.has_status("frozen"):
		return ai_think_delay
	
	# Hit stun check (matches JS: if enemy.hitCooldown > 0 return)
	if f.hit_cooldown > 0:
		return ai_think_delay
	
	var diff = Constants.AI_PRESETS.get(GameWorld.difficulty, Constants.AI_PRESETS["medium"])
	
	# Phantom target selection — AI prefers nearest alive phantom
	var target = GameWorld.player
	if GameWorld.phantoms.size() > 0:
		var nearest = null
		var nd = INF
		for ph in GameWorld.phantoms:
			if not ph or ph.hp <= 0:
				continue
			var d = absf(f.pos_x - ph.x)
			if d < nd:
				nd = d
				nearest = ph
		if nearest:
			target = nearest
	
	var dx = target.pos_x - f.pos_x
	var dist = absf(dx)
	var dir_to_target = 1 if dx > 0 else -1
	
	# Think delay (matches JS: floor(react/16) + floor(random()*8))
	if ai_think_delay > 0:
		return ai_think_delay - 1
	var new_delay = int(diff["react"] / 16) + randi() % 8
	
	var rand = randf()
	
	# ---- Projectile defense: parry/block nearby projectiles ----
	var proj_near = false
	for p in GameWorld.projectiles:
		if p.get("owner") == GameWorld.player and absf(p.get("x", 0) - f.pos_x) < 200:
			proj_near = true
			break
	if proj_near and not f.blocking and f.grounded:
		var skill2 = f.get_skill("skill2")
		if skill2 and skill2.can_use(f):
			skill2.try_use(f)
			return new_delay
	
	# ---- Skill usage at distance ----
	var skill1 = f.get_skill("skill1")
	var skill2 = f.get_skill("skill2")
	var ult = f.get_skill("ult")
	var can_use_s1 = skill1 and skill1.can_use(f) and dist < 350
	var can_use_s2 = skill2 and skill2.can_use(f)
	var can_use_ult = ult and ult.can_use(f)
	
	if dist > 150 and dist < 350 and can_use_s1 and randf() < diff["skill_rate"] * 1.5:
		skill1.try_use(f)
		if GameWorld.difficulty == "hard":
			skill1.cd = maxi(skill1.cd, 300)
		return new_delay
	
	if dist < 200 and can_use_ult and randf() < diff["skill_rate"] * 0.8:
		ult.try_use(f)
		if GameWorld.difficulty == "hard":
			ult.cd = maxi(ult.cd, 300)
		return new_delay
	
	# ---- Attack when close ----
	if dist < 80 and rand < diff["aggro"]:
		if f.char_id == "assassin":
			var atk_skill = f.get_skill("attack")
			if atk_skill and atk_skill.can_use(f):
				atk_skill.try_use(f)
		else:
			if f.attack_cooldown <= 0 and not f.attacking:
				f.attacking = true
				f.attack_timer = 68
				f.attack_delay = 8
				f.attack_hit_dealt = false
				f.attack_cooldown = 60
				f.state = "attack"
		return new_delay
	
	# ---- Movement ----
	var move_speed = diff["move_speed"]
	if dist > 200:
		f.vx = dir_to_target * move_speed
		if f.grounded and randf() < diff["jump_rate"]:
			f.vy = -8
		_update_state(f, dir_to_target)
		return new_delay
	
	if rand < diff["dodge"] and dist < 150:
		f.vx = -dir_to_target * move_speed * 1.5
		if f.grounded and randf() < 0.1:
			f.vy = -7
		_update_state(f, dir_to_target)
		return new_delay
	
	if dist > 80:
		f.vx = dir_to_target * move_speed * 0.8
	else:
		f.vx = 0
	
	_update_state(f, dir_to_target)
	return new_delay

static func _update_state(p: Fighter, mx: int):
	if p.grounded and mx == 0 and not p.attacking and not p.dashing:
		p.state = "idle"
	elif p.grounded and mx != 0 and not p.attacking and not p.dashing:
		p.state = "walk"
	if p.attacking and p.attack_timer <= 0:
		p.attacking = false; p.state = "idle"
