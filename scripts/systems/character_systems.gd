class_name CharacterSystems

# ===== Character-Specific Logic =====

static func update_assassin_logic():
	for f in GameWorld.entities:
		if f.char_id != "assassin" or f.hp <= 0: continue
		if f.is_invincible:
			f.invincible_timer -= 1
			if f.invincible_timer <= 0: f.is_invincible = false
		if f.enhanced_slash:
			f.enhanced_slash_timer -= 1
			if f.enhanced_slash_timer <= 0: f.enhanced_slash = false
		if f.slash_active:
			f.slash_timer -= 1
			if f.slash_timer <= 0:
				f.slash_active = false; f.attacking = false; f.state = "idle"
		if f.ult_active:
			f.ult_timer -= 1; f.ult_damage_timer += 1
			if f.ult_damage_timer >= 15:
				f.ult_damage_timer = 0
				var tgt = GameWorld.get_opponent(f)
				if tgt and tgt.hp > 0: Fighter.apply_damage(tgt, 2.5, f)
			if f.ult_timer <= 0:
				f.ult_active = false; f.time_stop = false; f.state = "idle"
		if f.shadow_stance:
			f.shadow_stance_timer -= 1
			f.shadow_energy = maxf(0, f.shadow_energy - f.shadow_energy_drain_rate)
			if f.shadow_stance_timer <= 0 or f.shadow_energy <= 0:
				f.shadow_stance = false; f.shadow_energy = 0; f.shadow_trail.clear()

static func update_shadowwarrior_logic():
	for f in GameWorld.entities:
		if f.char_id != "shadowwarrior" or f.hp <= 0: continue
		if f.is_invincible:
			f.invincible_timer -= 1
			if f.invincible_timer <= 0: f.is_invincible = false
		if f.retreat_timer > 0: f.retreat_timer -= 1
		if f.break_strike_timer > 0:
			if not f.dashing: f.break_strike_timer = 0
			else: f.break_strike_timer -= 1
		if f.stealth_active:
			f.stealth_timer -= 1
			if f.stealth_timer <= 0: f.stealth_active = false
		if f.iaido_active:
			if f.iaido_timer > 160:
				f.pos_x = clampf(f.pos_x + f.iaido_dir * 14, 10, 2390 - f.w)
			f.vx = 0; f.vy = 0
			f.iaido_timer -= 1
			if f.iaido_timer <= 0:
				f.iaido_active = false; f.iaido_frozen = false; f.state = "idle"
		if f.pending_trap:
			f.shadow_trap = {"x":f.pos_x,"y":f.pos_y,"w":40,"h":56,"timer":500}
			f.shadow_trap_active = true; f.pending_trap = false
		if f.shadow_trap_active and f.shadow_trap.has("timer"):
			f.shadow_trap["timer"] -= 1
			if f.shadow_trap["timer"] <= 0:
				f.shadow_trap_active = false; f.shadow_trap.clear()
		if f.pending_clones:
			for ci in 2:
				GameWorld.phantoms.append({
					"x":f.pos_x+(-40 if ci==0 else 40),"y":f.pos_y,
					"w":32,"h":56,"hp":5.0,"max_hp":5.0,
					"facing":f.facing,"owner":f,"state":"idle",
					"attacking":false,"attack_timer":0,"attack_cooldown":30,
					"attack_delay":0,"attack_hit_dealt":false,"life":300,
				})
			f.pending_clones = false
