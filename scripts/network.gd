class_name Network

# Message protocol constants
const MSG_INPUT = "input"
const MSG_READY = "ready"
const MSG_START = "start"
const MSG_STATE = "state"
const MSG_RESTART = "restart"
const MSG_RESULT_ACK = "result_ack"

# Serialize a Fighter to a Dictionary for network transmission
static func fighter_state(f) -> Dictionary:
	if not f:
		return {}
	return {
		"x": f.pos_x, "y": f.pos_y, "vx": f.vx, "vy": f.vy,
		"hp": f.hp, "max_hp": f.max_hp,
		"energy": f.energy, "max_energy": f.max_energy,
		"facing": f.facing, "grounded": f.grounded,
		"char_id": f.char_id, "is_player": f.is_player,
		"attacking": f.attacking, "attack_timer": f.attack_timer,
		"blocking": f.blocking, "shield_active": f.shield_active,
		"dashing": f.dashing, "dash_dir": f.dash_dir,
		"charging": f.charging, "charging_skill1": f.charging_skill1,
		"divine_shield_active": f.divine_shield_active,
		"holy_empower_active": f.holy_empower_active,
		"is_flying": f.is_flying, "is_casting_ult": f.is_casting_ult,
		"stealth_active": f.stealth_active, "shadow_stance": f.shadow_stance,
		"time_stop": f.time_stop,
		# Status effects simplified
		"frozen": f.has_status("frozen"),
		"status_count": f.statuses.size(),
	}

# Serialize full world state snapshot
static func make_state_snapshot() -> Dictionary:
	var snap := {}
	snap["player"] = fighter_state(GameWorld.player) if GameWorld.player else {}
	snap["enemy"] = fighter_state(GameWorld.enemy) if GameWorld.enemy else {}
	snap["frame"] = GameWorld.frame
	snap["game_over"] = GameWorld.game_over
	snap["camera_x"] = GameWorld.camera.x
	snap["slow_mo_timer"] = GameWorld.slow_mo_timer

	# Projectiles
	var projs := []
	for p in GameWorld.projectiles:
		projs.append({
			"x": p.get("x"), "y": p.get("y"), "vx": p.get("vx"), "vy": p.get("vy"),
			"w": p.get("w"), "h": p.get("h"), "life": p.get("life"),
			"damage": p.get("damage"), "type": p.get("type"), "color": p.get("color"),
		})
	snap["projectiles"] = projs

	return snap

# Apply a network state snapshot to the local world
static func apply_state_snapshot(snap: Dictionary):
	if snap.is_empty():
		return

	# Apply fighter states
	if GameWorld.player and snap.has("player"):
		_apply_fighter_snapshot(GameWorld.player, snap["player"])
	if GameWorld.enemy and snap.has("enemy"):
		_apply_fighter_snapshot(GameWorld.enemy, snap["enemy"])

	GameWorld.frame = snap.get("frame", GameWorld.frame)
	GameWorld.game_over = snap.get("game_over", GameWorld.game_over)
	GameWorld.camera.x = snap.get("camera_x", GameWorld.camera.x)
	GameWorld.slow_mo_timer = snap.get("slow_mo_timer", GameWorld.slow_mo_timer)

static func _apply_fighter_snapshot(f: Fighter, data: Dictionary):
	if data.is_empty():
		return
	f.pos_x = data.get("x", f.pos_x)
	f.pos_y = data.get("y", f.pos_y)
	f.vx = data.get("vx", f.vx)
	f.vy = data.get("vy", f.vy)
	f.hp = data.get("hp", f.hp)
	f.energy = data.get("energy", f.energy)
	f.facing = data.get("facing", f.facing)
	f.grounded = data.get("grounded", f.grounded)
	f.attacking = data.get("attacking", f.attacking)
	f.blocking = data.get("blocking", f.blocking)
	f.shield_active = data.get("shield_active", f.shield_active)
	f.dashing = data.get("dashing", f.dashing)
	f.dash_dir = data.get("dash_dir", f.dash_dir)
	f.charging = data.get("charging", f.charging)
	f.charging_skill1 = data.get("charging_skill1", f.charging_skill1)
	f.divine_shield_active = data.get("divine_shield_active", f.divine_shield_active)
	f.holy_empower_active = data.get("holy_empower_active", f.holy_empower_active)
	f.is_flying = data.get("is_flying", f.is_flying)
	f.is_casting_ult = data.get("is_casting_ult", f.is_casting_ult)
	f.stealth_active = data.get("stealth_active", f.stealth_active)
	f.shadow_stance = data.get("shadow_stance", f.shadow_stance)
	f.time_stop = data.get("time_stop", f.time_stop)

# Placeholder: Send PvP input to remote peer
static func send_pvp_input(input_data: Dictionary):
	print("[Network] send_pvp_input not implemented. Data: ", input_data)

# Placeholder: Send full PvP state to remote peer
static func send_pvp_state():
	print("[Network] send_pvp_state not implemented. Frame: ", GameWorld.frame)
