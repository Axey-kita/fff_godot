extends Node2D

# UI nodes (CanvasLayer)
@onready var ui_layer = $UILayer
@onready var pause_btn = $UILayer/PauseBtn
@onready var pause_menu = $UILayer/PauseMenu
@onready var continue_btn = $UILayer/PauseMenu/PausePanel/ContinueBtn
@onready var menu_btn = $UILayer/PauseMenu/PausePanel/MenuBtn
@onready var exit_btn = $UILayer/PauseMenu/PausePanel/ExitBtn
@onready var touch_controls = $TouchControls

var is_paused := false

# Input state
var keys := {
	"left": false, "right": false, "up": false, "down": false,
	"attack": false, "skill1": false, "skill2": false, "ult": false,
	"talent1": false, "talent2": false, "talent3": false,
}

# Fixed timestep
const FIXED_DT := 1000.0 / 60.0
var _last_time := 0.0
var _accumulator := 0.0

# AI
var ai_think_delay := 0

# 当前地图实例
var _current_map: Node2D = null

func _ready():
	print("[Game] _ready() start")
	_last_time = Time.get_ticks_msec()
	CharConfigs.ensure_init()
	TalentPool.init()
	print("[Game] configs OK, selected_char = ", GameWorld.selected_char_id)
	
	# Pause UI setup
	_style_pause_ui()
	pause_btn.pressed.connect(_toggle_pause)
	continue_btn.pressed.connect(_toggle_pause)
	menu_btn.pressed.connect(_back_to_menu)
	exit_btn.pressed.connect(_exit_game)
	
	call_deferred("_start_game")

func _start_game():
	var enemy_chars = ["knight","mage","archer","paladin","witch","assassin","shadowwarrior","evoker","rose"]
	var ai_char = enemy_chars[randi() % enemy_chars.size()]
	print("Starting game: player=", GameWorld.selected_char_id, " enemy=", ai_char)
	# ── 玩家天赋：使用主菜单选择（若无选择则用默认测试集）──
	if GameWorld.talent_pool.is_empty():
		GameWorld.player_talents = ["vitality", "blaze_rush"]
	else:
		GameWorld.player_talents = GameWorld.talent_pool.duplicate()
	GameWorld.enemy_talents = []
	init_game(GameWorld.selected_char_id, ai_char)

func init_game(player_char_id: String, enemy_char_id: String):
	CharConfigs.ensure_init()
	print("Configs available: ", CharConfigs.configs.keys())
	GameWorld.reset_world()
	CharacterFactory.reinject_draws()
	
	# 随机选图并加载平台
	_load_random_map()
	
	# 计算双方出生位置（站在最近的平台上）
	var spawns = _find_spawn_positions()
	
	var p_skills = CharacterFactory.create_skills(player_char_id)
	var e_skills = CharacterFactory.create_skills(enemy_char_id)
	print("Skills created: p=", p_skills.size(), " e=", e_skills.size())
	GameWorld.player = Fighter.new()
	GameWorld.player.setup(spawns.player_x, spawns.player_y, true, player_char_id, p_skills)
	add_child(GameWorld.player)
	GameWorld.enemy = Fighter.new()
	GameWorld.enemy.setup(spawns.enemy_x, spawns.enemy_y, false, enemy_char_id, e_skills)
	add_child(GameWorld.enemy)
	GameWorld.entities = [GameWorld.player, GameWorld.enemy]
	# ── 装配天赋 ──
	_assemble_talents(GameWorld.player, GameWorld.player_talents)
	_assemble_talents(GameWorld.enemy, GameWorld.enemy_talents)
	PickupSystem.init_pickups()
	GameWorld.game_running = true
	GameWorld.game_over = false
	GameWorld.frame = 0
	print("Game initialized! player.hp=", GameWorld.player.hp, " enemy.hp=", GameWorld.enemy.hp)

## 根据已加载的平台计算出生位置,确保角色站在地面/平台上
func _assemble_talents(fighter: Fighter, talent_ids: Array):
	if talent_ids.is_empty():
		return
	fighter.talent_manager = TalentManager.new()
	fighter.talent_manager.init(fighter, talent_ids)

func _find_spawn_positions() -> Dictionary:
	var player_x = 160
	var enemy_x = 600
	var player_y = Constants.GROUND_Y - Constants.FIGHTER_H
	var enemy_y = Constants.GROUND_Y - Constants.FIGHTER_H
	
	if GameWorld.platforms.is_empty():
		return {"player_x": player_x, "player_y": player_y, "enemy_x": enemy_x, "enemy_y": enemy_y}
	
	var best_player_plat = null
	var best_player_dist = INF
	var best_enemy_plat = null
	var best_enemy_dist = INF
	
	for p in GameWorld.platforms:
		if p.get("is_void", false):
			continue
		var plat_x = p["x"] + p["w"] / 2.0
		var plat_top = p["y"]
		
		# 左半场（玩家）
		if plat_x < Constants.MAP_W / 2.0:
			var dist_to_default = absf(plat_top - Constants.GROUND_Y)
			if dist_to_default < best_player_dist:
				# 确保角色宽度能站在平台上
				if p["w"] >= Constants.FIGHTER_W:
					best_player_dist = dist_to_default
					best_player_plat = p
		# 右半场（敌方）
		else:
			var dist_to_default = absf(plat_top - Constants.GROUND_Y)
			if dist_to_default < best_enemy_dist:
				if p["w"] >= Constants.FIGHTER_W:
					best_enemy_dist = dist_to_default
					best_enemy_plat = p
	
	if best_player_plat:
		player_y = best_player_plat["y"] - Constants.FIGHTER_H
		# 角色居中放在平台上
		player_x = best_player_plat["x"] + best_player_plat["w"] / 2.0 - Constants.FIGHTER_W / 2.0
	if best_enemy_plat:
		enemy_y = best_enemy_plat["y"] - Constants.FIGHTER_H
		enemy_x = best_enemy_plat["x"] + best_enemy_plat["w"] / 2.0 - Constants.FIGHTER_W / 2.0
	
	print("[Spawn] 玩家: (", player_x, ", ", player_y, ") 敌人: (", enemy_x, ", ", enemy_y, ")")
	return {"player_x": player_x, "player_y": player_y, "enemy_x": enemy_x, "enemy_y": enemy_y}

## 随机选一张地图,实例化并加载平台
func _load_random_map():
	# 清理旧地图
	if _current_map:
		_current_map.queue_free()
		_current_map = null
	GameWorld.platforms.clear()
	
	MapManager.ensure_init()
	var map_path = MapManager.pick_random()
	print("[Map] 选中地图: ", map_path)
	
	var map_scene = load(map_path)
	if not map_scene:
		push_error("[Map] 加载地图场景失败: ", map_path)
		GameWorld.init_platforms()
		return
	
	_current_map = map_scene.instantiate()
	add_child(_current_map)
	
	# 从 PlatformContainer 读取地形块
	var container = _current_map.get_node_or_null("PlatformContainer")
	if not container:
		push_error("[Map] 地图缺少 PlatformContainer 节点: ", map_path)
		GameWorld.init_platforms()
		return
	
	for child in container.get_children():
		var tile_script = child.get_script()
		if tile_script and tile_script.resource_path == "res://scripts/terrain_tile.gd":
			var tt = child
			var ttype = tt.tile_type
			var is_ground = ttype == 0
			var is_wall = ttype == 1
			GameWorld.platforms.append({
				"x": tt.position.x,
				"y": tt.position.y,
				"w": tt.block_w,
				"h": tt.block_h,
				"is_ground": is_ground,
				"is_wall": is_wall,
				"terrain_type": ttype,
			})
	
	# 隐藏地形块节点（_draw_map 已接管渲染，避免双重绘制）
	container.visible = false
	print("[Map] 加载 ", GameWorld.platforms.size(), " 个地形块, 地图=", MapManager.get_display_name(map_path))

func _process(_delta: float):
	if not GameWorld.game_running or GameWorld.game_over:
		queue_redraw()
		# Always show UI for game over
		return
	if is_paused:
		queue_redraw()
		return
	var now = Time.get_ticks_msec()
	if _last_time == 0:
		_last_time = now
	var dt = now - _last_time
	_last_time = now
	if dt > 250:
		dt = 250
	_accumulator += dt
	while _accumulator >= FIXED_DT:
		if GameWorld.slow_mo_timer > 0:
			GameWorld.slow_mo_timer -= 1
			GameWorld.slow_mo_tick += 1
			if GameWorld.slow_mo_tick >= GameWorld.SLOW_FACTOR:
				GameWorld.slow_mo_tick = 0
				_update()
		else:
			GameWorld.slow_mo_tick = 0
			_update()
		_accumulator -= FIXED_DT
	queue_redraw()

func _update():
	if GameWorld.hit_stop > 0:
		GameWorld.hit_stop -= 1
		return

	# 角色系统更新先行：让角色向中断器注册计时项
	# 双影武者对局时，双方的中断计时器同时递减
	FrameInterrupter.reset()
	CharacterSystems.update_characters()

	# 中断器判定：有活跃中断则 on_break 接管本帧执行权
	if FrameInterrupter.has_active():
		FrameInterrupter.run_breaks()
		GameWorld.frame += 1
		return

	GameWorld.frame += 1
	if GameWorld.player and GameWorld.player.dashing and GameWorld.player.image_state == "skill1":
		print("[ROSE-GRAB] === 帧开始 === frame=", GameWorld.frame, " rose.pos_x=", GameWorld.player.pos_x, " enemy.pos_x=", GameWorld.enemy.pos_x if GameWorld.enemy else "N/A", " enemy.vx=", GameWorld.enemy.vx if GameWorld.enemy else "N/A", " trails.size=", GameWorld.rose_slash_trails.size())
	# Cap particles to prevent performance leak
	if GameWorld.particles.size() > 300:
		GameWorld.particles = GameWorld.particles.slice(GameWorld.particles.size() - 300)
	# Update all skills (cooldowns)
	for f in GameWorld.entities:
		if not is_instance_valid(f):
			continue
		for sk in f.skills:
			sk.update()
	# Update status effects (burn, frozen, etc.) every frame
	for f in GameWorld.entities:
		if not is_instance_valid(f):
			continue
		f.update_statuses()
	# Update talent managers
	for f in GameWorld.entities:
		if not is_instance_valid(f):
			continue
		if f.talent_manager:
			f.talent_manager.update()
	# Input & AI (must happen BEFORE physics, so vx/vy from input take effect same frame)
	InputHandler.update_player_input(GameWorld, keys)
	InputRouter.handle_talent_keys(keys)
	ai_think_delay = AISystem.update_ai(ai_think_delay)
	# Apply physics (after input, matching JS order)
	_apply_physics_all()
	if GameWorld.player and GameWorld.player.dashing and GameWorld.player.image_state == "skill1":
		print("[ROSE-GRAB] physics后: frame=", GameWorld.frame, " rose.pos_x=", GameWorld.player.pos_x, " enemy.pos_x=", GameWorld.enemy.pos_x if GameWorld.enemy else "N/A", " enemy.vx=", GameWorld.enemy.vx if GameWorld.enemy else "N/A")
	# 作弊：无限蓝
	if GameWorld.infinite_energy and GameWorld.player:
		GameWorld.player.energy = GameWorld.player.max_energy
	# 闪避慢动作：刺客 dodge_slow_mo 期间，跳过敌方实体和投射物更新
	var dodge_slow_active = false
	for f in GameWorld.entities:
		if not is_instance_valid(f):
			continue
		if f.state_flags.get("dodge_slow", 0) > 0:
			dodge_slow_active = true
			break
	# Systems
	DashSystem.update_dash()
	if not dodge_slow_active:
		CharacterFactory.call_global_update("witch")
		ProjectileSystem.update_projectiles(self)
		FlameZoneSystem.update_flame_zones()
	SlowSystem.update_slow()
	PickupSystem.update_pickups_and_end()
	# CharacterSystems.update_characters() 已移至帧首，不再重复调用
	if GameWorld.enemy and GameWorld.player and GameWorld.player.dashing and GameWorld.player.image_state == "skill1":
		print("[ROSE-GRAB] 敌人位置(update_characters后): frame=", GameWorld.frame, " enemy.pos_x=", GameWorld.enemy.pos_x, " enemy.vx=", GameWorld.enemy.vx)
	CharacterSystems.update_active_overlays()
	# CharacterFactory.call_rose_trails() 已由 CharacterSystems.update_characters() 在帧首调用，不再重复
	CharacterFactory.call_global_update("evoker")
	# Camera
	var target_cam = GameWorld.player.pos_x - 400.0
	target_cam = clampf(target_cam, 0, 2400 - 800)
	GameWorld.camera.x += (target_cam - GameWorld.camera.x) * 0.1

func _apply_physics_all():
	# Time stop check — skip physics if any entity has time_stop active
	var time_stopped = false
	for f in GameWorld.entities:
		if not is_instance_valid(f):
			continue
		if f.state_flags.get("time_stop", false):
			time_stopped = true
			break
	if not time_stopped:
		for f in GameWorld.entities:
			if is_instance_valid(f):
				f.apply_physics()

# ===== Drawing =====
func _draw():
	RenderSystem.draw_frame(self)

func _unhandled_input(event: InputEvent):
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if GameWorld.game_over:
				get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
			else:
				_toggle_pause()
			return
		InputRouter.map_game_keys(event, keys)
		if event.pressed and event.keycode == KEY_R and GameWorld.game_over:
			_restart_game()

func _restart_game():
	# Clean up old fighters
	if GameWorld.player: GameWorld.player.queue_free()
	if GameWorld.enemy: GameWorld.enemy.queue_free()
	# 清理旧地图 (由 _load_random_map 负责清理)
	GameWorld.player = null
	GameWorld.enemy = null
	# 重置角色配置缓存（大招等修改的 config 字段需要还原）
	CharConfigs.reset()
	# 重新填充天赋
	if GameWorld.talent_pool.is_empty():
		GameWorld.player_talents = ["vitality", "blaze_rush"]
	else:
		GameWorld.player_talents = GameWorld.talent_pool.duplicate()
	GameWorld.enemy_talents = []
	var enemy_chars = ["knight","mage","archer","paladin","witch","assassin","shadowwarrior","evoker","rose"]
	var ai_char = enemy_chars[randi() % enemy_chars.size()]
	init_game(GameWorld.selected_char_id, ai_char)

# ===== Pause menu =====

func _toggle_pause():
	is_paused = not is_paused
	pause_menu.visible = is_paused
	# Hide/show touch controls with pause state
	if touch_controls:
		touch_controls.visible = not is_paused
	# Clear lingering keys so they don't trigger actions right after unpause
	if not is_paused:
		keys["attack"] = false
		keys["skill1"] = false
		keys["skill2"] = false
		keys["ult"] = false
		keys["up"] = false
		keys["talent1"] = false
		keys["talent2"] = false
		keys["talent3"] = false

func _back_to_menu():
	is_paused = false
	# 先解除所有角色注入（避免 lambda 持有已释放对象导致退出挂起）
	if GameWorld.player: GameWorld.player.detach_injections()
	if GameWorld.enemy: GameWorld.enemy.detach_injections()
	GameWorld.cleanup_draw_callbacks()
	# Stop game loop and clean up before changing scene
	GameWorld.game_running = false
	GameWorld.game_over = true
	if GameWorld.player:
		GameWorld.player.queue_free()
		GameWorld.player = null
	if GameWorld.enemy:
		GameWorld.enemy.queue_free()
		GameWorld.enemy = null
	CharConfigs.reset()
	if _current_map:
		_current_map.queue_free()
		_current_map = null
	GameWorld.reset_world()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _exit_game():
	if GameWorld.player: GameWorld.player.detach_injections()
	if GameWorld.enemy: GameWorld.enemy.detach_injections()
	GameWorld.cleanup_draw_callbacks()
	get_tree().quit()

func _style_pause_ui():
	# Pause button — small, subtle, top-right
	pause_btn.add_theme_font_size_override("font_size", 14)
	pause_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	pause_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	
	# Pause title
	var pause_title = $UILayer/PauseMenu/PausePanel/PauseTitle
	pause_title.add_theme_color_override("font_color", Color(1.0, 0.843, 0.0))
	
	# Style the three menu buttons
	_style_pause_button(continue_btn, Color(0.298, 0.686, 0.314))
	_style_pause_button(menu_btn, Color(1.0, 0.843, 0.0))
	_style_pause_button(exit_btn, Color(0.914, 0.271, 0.157))

func _style_pause_button(btn: Button, accent: Color):
	btn.add_theme_font_size_override("font_size", 16)
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(accent.r, accent.g, accent.b, 0.15)
	normal.set_corner_radius_all(10)
	normal.border_width_left = 2; normal.border_width_right = 2
	normal.border_width_top = 2; normal.border_width_bottom = 2
	normal.border_color = Color(accent.r, accent.g, accent.b, 0.5)
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = normal.duplicate()
	hover.bg_color = Color(accent.r, accent.g, accent.b, 0.35)
	hover.border_color = accent
	btn.add_theme_stylebox_override("hover", hover)
	
	btn.add_theme_color_override("font_color", accent)
