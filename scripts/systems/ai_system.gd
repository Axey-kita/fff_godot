class_name AISystem

# ===== AI System =====
static func update_ai(ai_think_delay: int) -> int:
	if GameWorld.game_mode == "pvp" or GameWorld.enemy.hp <= 0:
		return ai_think_delay
	var f = GameWorld.enemy
	
	# Frozen check
	if f.has_status("frozen"):
		return ai_think_delay
	
	# Hit stun check
	if f.hit_cooldown > 0:
		return ai_think_delay
	
	var diff = Constants.AI_PRESETS.get(GameWorld.difficulty, Constants.AI_PRESETS["medium"])
	var is_hell = GameWorld.difficulty == "hell"
	
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
	
	var dx = (target["x"] if target is Dictionary else target.pos_x) - f.pos_x
	var dist = absf(dx)
	var dir_to_target = 1 if dx > 0 else -1
	
	# Think delay
	if ai_think_delay > 0:
		return ai_think_delay - 1
	var new_delay = int(diff["react"] / 16) + randi() % 8
	
	var rand = randf()
	var player = GameWorld.player
	
	# ═══════════════════════════════════════════════
	#  Hell mode: advanced tactical AI
	#FIXED BUG: 地狱模式之前仅有参数差异(hell=hard),AI无任何战术行为差异
	#修复:6项专属战术 — 反应闪避/对空迎击/防御技能/斩杀大招/技能连招/精确走位
	#FIXED BUG(新增#3): 地狱AI角色个性(V3) — 根据ai_profile动态选择策略
	# ═══════════════════════════════════════════════
	if is_hell:
		# ── Dodge player attacks reactively ──
		if player and player.hp > 0 and player.attacking and dist < 150 and rand < 0.7:
			# Jump backward to evade
			f.vx = -dir_to_target * diff["move_speed"] * 2.0
			if f.grounded:
				f.vy = -8
			_update_state(f, dir_to_target)
			return new_delay
		
		# ── Anti-air: jump to meet airborne player ──
		if player and not player.grounded and f.grounded and dist < 120 and rand < 0.4:
			f.vy = -9
			f.vx = dir_to_target * diff["move_speed"]
			_update_state(f, dir_to_target)
			return new_delay
		
		# ── Defensive skill2 when player is close and attacking ──
		var skill2 = f.get_skill("skill2")
		if skill2 and skill2.can_use(f) and dist < 100 and player and player.attacking and rand < 0.5:
			skill2.try_use(f)
			return new_delay
	#FIX END
	
	# ═══════════════════════════════════════════════
	#  Common projectile defense
	# ═══════════════════════════════════════════════
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
	
	# ═══════════════════════════════════════════════
	#  Skill usage
	# ═══════════════════════════════════════════════
	var skill1 = f.get_skill("skill1")
	var skill2 = f.get_skill("skill2")
	var ult = f.get_skill("ult")
	var can_use_s1 = skill1 and skill1.can_use(f) and dist < 350
	var can_use_s2 = skill2 and skill2.can_use(f)
	var can_use_ult = ult and ult.can_use(f)
	
	# Hell mode: ult when enemy is vulnerable (close range + low HP)
	if is_hell and can_use_ult and dist < 150 and player.hp < player.max_hp * 0.4 and rand < 0.8:
		ult.try_use(f)
		return new_delay
	
	# Skill1 at mid-range
	if dist > 150 and dist < 350 and can_use_s1 and randf() < diff["skill_rate"] * 1.5:
		skill1.try_use(f)
		if GameWorld.difficulty == "hard":
			skill1.cd = maxi(skill1.cd, 300)
		return new_delay
	
	# Ult at close range
	if dist < 200 and can_use_ult and randf() < diff["skill_rate"] * 0.8:
		ult.try_use(f)
		if GameWorld.difficulty == "hard":
			ult.cd = maxi(ult.cd, 300)
		return new_delay
	
	# Hell mode: combo skill1 → skill2 when close
	if is_hell and can_use_s1 and can_use_s2 and dist < 200 and rand < 0.35:
		skill1.try_use(f)
		if skill2.can_use(f):
			skill2.try_use(f)
		return new_delay
	
	# ═══════════════════════════════════════════════
	#  Attack when close
	# ═══════════════════════════════════════════════
	var attack_range = 80
	
	# Hell mode: chase into melee range more aggressively
	if is_hell and dist < 200 and rand < diff["aggro"]:
		f.vx = dir_to_target * diff["move_speed"] * 1.2
		_update_state(f, dir_to_target)
		if dist < attack_range:
			if f.char_id == "assassin":
				var atk_skill = f.get_skill("attack")
				if atk_skill and atk_skill.can_use(f):
					atk_skill.try_use(f)
			elif f.attack_cooldown <= 0 and not f.attacking:
				f.attacking = true; f.attack_timer = 68; f.attack_delay = 8
				f.attack_hit_dealt = false; f.attack_cooldown = 60; f.state = "attack"
		return new_delay
	
	if dist < attack_range and rand < diff["aggro"]:
		if f.char_id == "assassin":
			var atk_skill = f.get_skill("attack")
			if atk_skill and atk_skill.can_use(f):
				atk_skill.try_use(f)
		else:
			if f.attack_cooldown <= 0 and not f.attacking:
				f.attacking = true; f.attack_timer = 68; f.attack_delay = 8
				f.attack_hit_dealt = false; f.attack_cooldown = 60; f.state = "attack"
		return new_delay
	
	# ═══════════════════════════════════════════════
	#  Character profile: ideal_range / kite / prefer_air
	# ═══════════════════════════════════════════════
	var profile = f.config.get("ai_profile", {})
	var ideal_min = profile.get("ideal_range", [0, 80])[0]
	var ideal_max = profile.get("ideal_range", [0, 80])[1]
	var do_kite = profile.get("kite", false)
	var prefer_air = profile.get("prefer_air", false)
	
	# ═══════════════════════════════════════════════
	#  Charge handling (archer / mage / paladin)
	# ═══════════════════════════════════════════════
	if f.charging_attack or f.charging or f.charging_skill1:
		_ai_charge_tick(f)  #FIXED BUG: 之前传了2个参数(diff_movement),但函数只接受1个,导致Parse Error
		return new_delay
	if _should_start_charge(f):
		_ai_charge_start(f)
		return new_delay
	
	# Witch: prefer aerial flight
	if prefer_air and f.grounded and rand < 0.4 and f.energy > 30:
		f.vy = -10; f.grounded = false; f.is_flying = true
	
	# ═══════════════════════════════════════════════
	#  Movement: use ai_profile ideal_range + kite
	# ═══════════════════════════════════════════════
	var move_speed = diff["move_speed"]
	
	# Kite style: stay at range, retreat when too close
	if do_kite:
		if dist < ideal_min:
			f.vx = -dir_to_target * move_speed * 1.3
			if f.grounded and rand < 0.15: f.vy = -7
		elif dist > ideal_max:
			f.vx = dir_to_target * move_speed
		else:
			f.vx = dir_to_target * move_speed * (1.0 if rand > 0.5 else -0.5)
		_update_state(f, dir_to_target)
		return new_delay
	
	# Melee style: charge into ideal range
	if dist > ideal_max:
		f.vx = dir_to_target * move_speed
		if f.grounded and randf() < diff["jump_rate"]:
			f.vy = -8
		_update_state(f, dir_to_target)
		return new_delay
	
	# Hell: strafe/position
	if is_hell and dist < 300:
		if player.attacking and dist > 120:
			f.vx = dir_to_target * move_speed * 1.8
		elif dist < maxi(ideal_min, 60):
			f.vx = -dir_to_target * move_speed
		else:
			f.vx = dir_to_target * move_speed * 0.6
		_update_state(f, dir_to_target)
		return new_delay
	
	# Default dodge
	if rand < diff["dodge"] and dist < 150:
		f.vx = -dir_to_target * move_speed * 1.5
		if f.grounded and randf() < 0.1: f.vy = -7
		_update_state(f, dir_to_target)
		return new_delay
	
	# Close the gap
	if dist > ideal_max:
		f.vx = dir_to_target * move_speed * 0.8
	else:
		f.vx = 0
	
	_update_state(f, dir_to_target)
	return new_delay

# ══════════════════════════════════════════════════
#  Charge helpers
# ══════════════════════════════════════════════════
static func _should_start_charge(f: Fighter) -> bool:
	if f.char_id == "archer":
		return f.arrows > 0 and f.energy >= 5 and not f.charging_attack
	if f.char_id == "mage":
		var ult = f.get_skill("ult")
		return (not ult or ult.cd <= 0) and f.energy >= 40 and not f.charging and not f.attacking
	return false

static func _ai_charge_start(f: Fighter):
	f.forced_skill_timer = randi_range(2, 8)
	f.charge_start_time = Time.get_ticks_msec()
	match f.char_id:
		"archer":
			f.charging_attack = true; f.attacking = true; f.attack_timer = 9999; f.state = "attack"
		"mage":
			f.charging = true

static func _ai_charge_tick(f: Fighter):
	f.forced_skill_timer -= 1
	var should_release := f.forced_skill_timer <= 0
	if f.char_id == "archer" and (f.energy < 5 or f.arrows <= 0): should_release = true
	if f.char_id == "mage" and f.energy < 40: should_release = true
	if not should_release: return
	
	f.forced_skill_timer = 0
	var ct = (Time.get_ticks_msec() - f.charge_start_time) / 1000.0
	match f.char_id:
		"archer": _release_archer_charge(f, ct)
		"mage": _release_mage_charge(f, ct)

static func _release_archer_charge(f: Fighter, ct: float):
	var dmg: float; var cost: float
	if ct < 1: dmg = 5; cost = 5
	elif ct < 2: dmg = 8; cost = 10
	else: dmg = 12; cost = 15
	if f.energy >= cost:
		f.energy -= cost; f.arrows -= 1
		var d = f.facing; var px2 = f.pos_x + (f.w if d == 1 else 0); var py2 = f.pos_y + 30
		var spd = minf(4 + ct * 2, 10)
		var arr_img = ArcherCharacter.PROJ_ARROW_FIRE if f.fire_arrow_buff else ArcherCharacter.PROJ_ARROW
		GameWorld.projectiles.append({"x":px2-16,"y":py2-10,"w":32,"h":20,"vx":spd*d,"vy":0,"life":120,"damage":dmg,"owner":f,"type":"arrow","color":Color(0.67,0.67,0.67),"reflected":false,"is_fire":f.fire_arrow_buff,"tracking":f.tracking_buff,"trackingTarget":GameWorld.get_opponent(f),"img":arr_img})
	f.charging_attack = false; f.attacking = false; f.state = "idle"

static func _release_mage_charge(f: Fighter, ct: float):
	var dmg = 20; var cost = 40
	if ct > 3: dmg = 60; cost = 120
	elif ct > 1: dmg = 40; cost = 80
	if f.energy < cost: f.charging = false; return
	f.energy -= cost
	var d = f.facing; var px2 = f.pos_x + (f.w if d == 1 else 0); var py2 = f.pos_y + 30
	GameWorld.projectiles.append({"x":px2-20,"y":py2-15,"w":40,"h":30,"vx":4*d,"vy":0,"life":200,"damage":dmg,"owner":f,"type":"mage_light","color":Color(1,1,0.27),"reflected":false,"img":null})
	var ult = f.get_skill("ult"); if ult: ult.cd = ult.cooldown
	f.charging = false

static func _update_state(p: Fighter, mx: int):
	if p.grounded and mx == 0 and not p.attacking and not p.dashing:
		p.state = "idle"
	elif p.grounded and mx != 0 and not p.attacking and not p.dashing:
		p.state = "walk"
	if p.attacking and p.attack_timer <= 0:
		p.attacking = false; p.state = "idle"
