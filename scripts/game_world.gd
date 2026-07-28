extends Node

# Explicit preloads for cold cache autoload compilation
const Fighter = preload("res://scripts/fighter.gd")
const Constants = preload("res://data/constants.gd")

# Game state
var game_running := false
var game_over := false
var game_result := ""  # "win" or "lose"
var game_mode := "pve" # "pve" or "pvp"
var difficulty := "medium"
var frame := 0
var hit_stop := 0

# Talent system
const MAX_TALENT_SLOTS := 3
var player_talents: Array = []
var enemy_talents: Array = []
var talent_pool: Array = []  # 主菜单中已选择的天赋 ID 列表

# Slow motion
var slow_mo_timer := 0
var slow_mo_tick := 0
const SLOW_FACTOR := 3
const SLOW_DURATION := 90
const SLOW_MAX := 300

# Entities
var player = null
var enemy = null
var entities: Array = []

# World arrays
var projectiles: Array = []
var particles: Array = []
var pickups: Array = []
var flame_zones: Array = []
var explosion_effects: Array = []
var tornadoes: Array = []
var vortexes: Array = []
var phantoms: Array = []
var evoker_summons: Array = []
var void_rifts: Array = []
var evoker_fire_seas: Array = []
var gravity_balls: Array = []
var rose_slash_trails: Array = []
var rose_joystick_dir: Vector2 = Vector2.ZERO
var active_overlays: Array = []  # [{anim, position, owner, overlay_id, on_finish}]

# 角色注入的绘制回调 { "key": unique_key, "cb": Callable, "z": int }
# 角色在 skill 激活时注册，用完自行注销；game.gd 只遍历调用，不关心来源
static var draw_effect_callbacks: Array = []

## 注册绘制回调（角色调用）
static func register_draw_effect(key: String, cb: Callable, z: int = 0):
	# 同名 key 先移除旧注册
	unregister_draw_effect(key)
	draw_effect_callbacks.append({"key": key, "cb": cb, "z": z})
	draw_effect_callbacks.sort_custom(_sort_by_z)

static func unregister_draw_effect(key: String):
	for i in range(draw_effect_callbacks.size() - 1, -1, -1):
		if draw_effect_callbacks[i].get("key") == key:
			draw_effect_callbacks.remove_at(i)

static func _sort_by_z(a: Dictionary, b: Dictionary) -> bool:
	return a.get("z", 0) < b.get("z", 0)

# 清理绘制回调（切场景/退出时调用，避免 lambda 持有已释放对象导致挂起）
static func cleanup_draw_callbacks():
	draw_effect_callbacks.clear()

# Platforms
var platforms: Array = []

# Camera
var camera := {"x": 0.0}
var screen_shake_intensity: float = 0.0
var screen_shake_duration: int = 0

# Pickup timer
var pickup_timer := 0.0

# Selected character
var selected_char_id := "knight"

# Cheats
var infinite_energy := false

func _ready():
	init_platforms()

func init_platforms():
	platforms = [
		{"x": 0, "y": Constants.GROUND_Y, "w": Constants.MAP_W, "h": 10, "is_ground": true},
		{"x": 400, "y": Constants.GROUND_Y - 120, "w": 120, "h": 12},
		{"x": 1000, "y": Constants.GROUND_Y - 160, "w": 140, "h": 12},
		{"x": 1600, "y": Constants.GROUND_Y - 110, "w": 130, "h": 12},
	]

func reset_world():
	FrameInterrupter.reset()
	projectiles.clear()
	particles.clear()
	pickups.clear()
	flame_zones.clear()
	explosion_effects.clear()
	tornadoes.clear()
	vortexes.clear()
	phantoms.clear()
	evoker_summons.clear()
	void_rifts.clear()
	evoker_fire_seas.clear()
	gravity_balls.clear()
	rose_slash_trails.clear()
	active_overlays.clear()
	draw_effect_callbacks.clear()
	entities.clear()
	camera.x = 0
	pickup_timer = 0
	slow_mo_timer = 0
	slow_mo_tick = 0

func get_opponent(fighter):
	if fighter == player:
		return enemy
	return player

func trigger_slow_motion(duration: int = SLOW_DURATION):
	if game_mode == "pvp":
		return
	slow_mo_timer = min(SLOW_MAX, slow_mo_timer + duration)
