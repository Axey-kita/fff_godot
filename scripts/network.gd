class_name Network

# Component preloads for type resolution
const PaladinComponent = preload("res://scripts/components/paladin_component.gd")
const WitchComponent = preload("res://scripts/components/witch_component.gd")
const ShadowwarriorComponent = preload("res://scripts/components/shadowwarrior_component.gd")
const AssassinComponent = preload("res://scripts/components/assassin_component.gd")
const RoseComponent = preload("res://scripts/components/rose_component.gd")

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
		# Character-specific fields via blackboard
		"time_stop": f.state_flags.get("time_stop", false),
		"divine_shield_active": f.state_flags.get("divine_shield", false),
		"holy_empower_active": f.state_flags.get("holy_empower", false),
		"is_flying": f.state_flags.get("is_flying", false),
		"is_casting_ult": f.state_flags.get("is_casting_ult", false),
		"stealth_active": f.state_flags.get("stealth_active", false),
		"shadow_stance": (f.components.get_component("assassin").shadow_stance if f.components and f.components.has_component("assassin") else false),
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
	# Character-specific fields via components
	if f.components:
		var p_comp: PaladinComponent = f.components.get_component("paladin")
		if p_comp:
			p_comp.divine_shield_active = data.get("divine_shield_active", p_comp.divine_shield_active)
			p_comp.holy_empower_active = data.get("holy_empower_active", p_comp.holy_empower_active)
		var w_comp: WitchComponent = f.components.get_component("witch")
		if w_comp:
			w_comp.is_flying = data.get("is_flying", w_comp.is_flying)
			w_comp.is_casting_ult = data.get("is_casting_ult", w_comp.is_casting_ult)
		var sw_comp: ShadowwarriorComponent = f.components.get_component("shadowwarrior")
		if sw_comp:
			sw_comp.stealth_active = data.get("stealth_active", sw_comp.stealth_active)
		var a_comp: AssassinComponent = f.components.get_component("assassin")
		if a_comp:
			a_comp.shadow_stance = data.get("shadow_stance", a_comp.shadow_stance)
			a_comp.time_stop = data.get("time_stop", a_comp.time_stop)
		var r_comp: RoseComponent = f.components.get_component("rose")
		if r_comp:
			r_comp.time_stop = data.get("time_stop", r_comp.time_stop)

# Placeholder: Send PvP input to remote peer
static func send_pvp_input(input_data: Dictionary):
	print("[Network] send_pvp_input not implemented. Data: ", input_data)

# Placeholder: Send full PvP state to remote peer
static func send_pvp_state():
	print("[Network] send_pvp_state not implemented. Frame: ", GameWorld.frame)
