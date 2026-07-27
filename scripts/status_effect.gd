class_name StatusEffect

var id: String
var duration: int
var timer: int
var vfx_color: Color
var freeze: bool
var slow_factor: float
var tick_interval: int
var tick_damage: float
var ticks_since_last: int = 0

static var STATUS_DEFS := {
	"burn": {
		"id": "burn", "duration": 180, "vfx_color": Color.RED,
		"tick_damage": 0.5, "tick_interval": 60,
	},
	"slow": {
		"id": "slow", "duration": 180, "vfx_color": Color(0, 0.53, 1.0),
		"slow_factor": 0.8,
	},
	"frozen": {
		"id": "frozen", "duration": 240, "vfx_color": Color.WHITE,
		"freeze": true,
	},
	"gravity_debuff": {
		"id": "gravity_debuff", "duration": 120, "vfx_color": Color(0.67, 0.53, 1.0),
	},
	"evoker_gazed": {
		"id": "evoker_gazed", "duration": 600,
	},
}

func _init(p_id: String, p_duration: int = 0):
	id = p_id
	var def = STATUS_DEFS.get(p_id)
	if def:
		duration = def.get("duration", 60)
		timer = duration
		vfx_color = def.get("vfx_color", Color.WHITE)
		freeze = def.get("freeze", false)
		slow_factor = def.get("slow_factor", 1.0)
		tick_damage = def.get("tick_damage", 0.0)
		tick_interval = def.get("tick_interval", 60)
	else:
		duration = p_duration
		timer = p_duration
		vfx_color = Color.WHITE
		freeze = false
		slow_factor = 1.0
		tick_damage = 0.0
		tick_interval = 60

# Called once when the status is first applied to a target
func apply(target):
	match id:
		"frozen":
			target.ice_hit_count = 0
			target.emit_particles(target.pos_x + target.w / 2, target.pos_y + target.h / 2, 40, Color(0.53, 0.87, 1.0), 6, 8, "star", 1.5)
		"gravity_debuff":
			target.gravity_debuff = true
			target.jump_reduction = 0.8

# Called each tick when tick_damage > 0 and tick_interval matched
func _handle_tick(target: Fighter):
	match id:
		"burn":
			if target.hp <= 0:
				return
			target.hp = maxf(0, target.hp - 0.5)
			target.damage_flash = 10
			target.emit_particles(target.pos_x + target.w / 2, target.pos_y + target.h / 2, 10, Color(1.0, 0.27, 0.27), 2, 4, "circle", 0.5)

# Called when the status expires
func _handle_expire(target):
	match id:
		"frozen":
			target.ice_hit_count = 0
		"gravity_debuff":
			target.gravity_debuff = false
			target.jump_reduction = 1.0

func update(target: Fighter) -> bool:
	timer -= 1
	if timer <= 0:
		_handle_expire(target)
		return false
	if tick_damage > 0:
		ticks_since_last += 1
		if ticks_since_last >= tick_interval:
			ticks_since_last = 0
			_handle_tick(target)
	return true
