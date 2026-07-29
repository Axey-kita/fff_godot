# AudioManager — 全局音频管理 (Autoload)
extends Node

const UI_POOL_SIZE := 3
const MUSIC_LAYER_COUNT := 2  # 双缓冲支持交叉淡入淡出

# ── 运行时状态 ──
var _sfx_pool: Array[AudioLayer] = []
var _ui_pool: Array[AudioLayer] = []
var _music_layers: Array[AudioLayer] = []
var _music_index: int = 0
var _sfx_bus_idx: int = -1
var _music_bus_idx: int = -1
var _ui_bus_idx: int = -1
var _sfx_volume: float = 1.0
var _music_volume: float = 1.0
var _ui_volume: float = 1.0

# 中断恢复：{config, position, cutoff_remaining}
var _pending_resumes: Array[Dictionary] = []

# ── 音频配置注册表 ──
static var _configs: Dictionary = {}


# ═════════════════════════════════════════════════════════════════
# 生命周期
# ═════════════════════════════════════════════════════════════════

func _ready():
	# 注册 ProjectSettings 默认值
	if not ProjectSettings.has_setting("audio/sfx_pool_size"):
		ProjectSettings.set_setting("audio/sfx_pool_size", 8)

	_setup_buses()
	_register_default_configs()
	_setup_sfx_pool()
	_setup_ui_pool()
	_setup_music_layers()

## 建立 Audio Bus 层级：Master → SFX / Music / UI
func _setup_buses():
	# Godot 默认有 Master bus (index 0)，在此基础上增加子 bus
	const SFX_BUS := "SFX"
	const MUSIC_BUS := "Music"
	const UI_BUS := "UI"

	var master_idx := AudioServer.get_bus_index("Master")

	# 添加 bus 并发送到 Master
	_sfx_bus_idx = _ensure_bus(SFX_BUS, master_idx)
	_music_bus_idx = _ensure_bus(MUSIC_BUS, master_idx)
	_ui_bus_idx = _ensure_bus(UI_BUS, master_idx)

func _ensure_bus(bus_name: String, send_to_idx: int) -> int:
	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return i
	AudioServer.add_bus(AudioServer.bus_count)
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, AudioServer.get_bus_name(send_to_idx))
	return idx

func _setup_sfx_pool():
	var pool_size := ProjectSettings.get_setting("audio/sfx_pool_size", 8) as int
	for i in range(pool_size):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_" + str(i)
		player.bus = "SFX"
		add_child(player)
		var layer := AudioLayer.new()
		layer.init(player, "SFX")
		layer._finish_callback = func(): _on_layer_finished(layer)
		layer._fail_callback = func(id, reason): _on_play_failed(id, reason)
		_sfx_pool.append(layer)

func _setup_ui_pool():
	for i in range(UI_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "UI_" + str(i)
		player.bus = "UI"
		add_child(player)
		var layer := AudioLayer.new()
		layer.init(player, "UI")
		layer._finish_callback = func(): _on_layer_finished(layer)
		layer._fail_callback = func(id, reason): _on_play_failed(id, reason)
		_ui_pool.append(layer)

func _setup_music_layers():
	for i in range(MUSIC_LAYER_COUNT):
		var player := AudioStreamPlayer.new()
		player.name = "Music_" + str(i)
		player.bus = "Music"
		add_child(player)
		var layer := AudioLayer.new()
		layer.init(player, "Music")
		layer._finish_callback = func(): _on_layer_finished(layer)
		layer._fail_callback = func(id, reason): _on_play_failed(id, reason)
		_music_layers.append(layer)


# ═════════════════════════════════════════════════════════════════
# 公共 API
# ═════════════════════════════════════════════════════════════════

## 播放 SFX（支持注册 ID 或内联 dict）
##   play_sfx("swing")
##   play_sfx({"path": "res://...", "volume": 0.8, "priority": "high", "interrupt": "lower"})
static func play_sfx(sfx):
	var instance = _get_instance()
	if not instance:
		return
	var config: AudioConfig
	if sfx is String:
		config = _configs.get(sfx)
		if not config:
			push_warning("[Audio] 未注册音效: " + sfx)
			return
	elif sfx is Dictionary:
		config = AudioConfig.from_dict(sfx, "_inline")
	else:
		push_warning("[Audio] 无效参数类型: " + typeof(sfx))
		return

	# 按 category 路由
	match config.category:
		AudioConfig.Category.MUSIC:
			instance._play_music_impl(config)
		_:
			instance._play_sfx_impl(config)

## 播放背景音乐（自动交叉淡入淡出）
static func play_music(music_id: String):
	var instance = _get_instance()
	if not instance:
		return
	var config: AudioConfig = _configs.get(music_id)
	if not config:
		push_warning("[Audio] 未注册音效: " + music_id)
		return
	config.category = AudioConfig.Category.MUSIC
	instance._play_music_impl(config)

## 停止背景音乐
static func stop_music(fade: bool = true):
	var instance = _get_instance()
	if not instance:
		return
	for layer in instance._music_layers:
		layer.stop(fade)

## 停止所有 SFX
static func stop_all_sfx(fade: bool = true):
	var instance = _get_instance()
	if not instance:
		return
	for layer in instance._sfx_pool:
		layer.stop(fade)

## 全局音量（Master 总线）
static func set_master_volume(vol: float):
	var idx := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(idx, linear2db(clampf(vol, 0.0, 1.0)))

## SFX 分组音量（SFX Bus）
static func set_sfx_volume(vol: float):
	var instance = _get_instance()
	if not instance: return
	instance._sfx_volume = clampf(vol, 0.0, 1.0)
	if instance._sfx_bus_idx >= 0:
		AudioServer.set_bus_volume_db(instance._sfx_bus_idx, linear2db(instance._sfx_volume))

## 音乐分组音量（Music Bus）
static func set_music_volume(vol: float):
	var instance = _get_instance()
	if not instance: return
	instance._music_volume = clampf(vol, 0.0, 1.0)
	if instance._music_bus_idx >= 0:
		AudioServer.set_bus_volume_db(instance._music_bus_idx, linear2db(instance._music_volume))

## UI 分组音量（UI Bus）
static func set_ui_volume(vol: float):
	var instance = _get_instance()
	if not instance: return
	instance._ui_volume = clampf(vol, 0.0, 1.0)
	if instance._ui_bus_idx >= 0:
		AudioServer.set_bus_volume_db(instance._ui_bus_idx, linear2db(instance._ui_volume))

## 兼容旧 API
static func play_sound(type: String):
	play_sfx(type)

## 注册音效配置
static func register_config(config: AudioConfig):
	_configs[config.id] = config

## 获取已注册的 config id 列表
static func get_registered_ids() -> Array:
	return _configs.keys()


# ═════════════════════════════════════════════════════════════════
# 内部实现
# ═════════════════════════════════════════════════════════════════

## SFX / UI 播放（走池）
func _play_sfx_impl(config: AudioConfig):
	# 选择池
	var pool := _sfx_pool
	if config.category == AudioConfig.Category.SFX_UI:
		pool = _ui_pool

	# 重叠限制（内联 dict 不受限）
	if config.id != "_inline" and config.max_overlap >= 0:
		var active_count := 0
		for layer in pool:
			if layer.current_config_id() == config.id and layer.is_active():
				active_count += 1
		if active_count >= config.max_overlap:
			return

	# 中断检查
	var interrupted_layer: AudioLayer = null
	for layer in pool:
		if not layer.is_active():
			continue
		var layer_config = layer.config
		if not layer_config:
			continue
		match config.interrupt:
			AudioConfig.Interrupt.SELF:
				if layer_config.id == config.id:
					interrupted_layer = layer
					break
			AudioConfig.Interrupt.LOWER:
				if layer_config.priority <= config.priority:
					interrupted_layer = layer
					break
			AudioConfig.Interrupt.ALL:
				interrupted_layer = layer
				break

	# 保存中断状态
	if interrupted_layer and interrupted_layer.config:
		if interrupted_layer.config.resumable:
			_save_resume_state(interrupted_layer)
		interrupted_layer.stop(false)

	# 找目标层
	var target_layer := _find_target_layer(pool, config, interrupted_layer)
	if not target_layer:
		return

	# Ducking
	_apply_ducking(pool, config)

	# 播放
	target_layer.play(config, interrupted_layer != null)

## 背景音乐播放（双缓冲交叉淡入淡出）
func _play_music_impl(config: AudioConfig):
	# 如果已有同 ID 音乐在播放，跳过
	for layer in _music_layers:
		if layer.current_config_id() == config.id and layer.state == AudioLayer.State.PLAYING:
			return

	# 停止当前音乐层的上一首
	var prev_layer := _music_layers[_music_index] if _music_layers.size() > 0 else null
	if prev_layer and prev_layer.is_active():
		prev_layer.stop(false)

	# 轮转到下一层
	_music_index = (_music_index + 1) % _music_layers.size()
	var layer := _music_layers[_music_index]
	layer.stop(false)  # 确保干净
	layer.play(config)

## 层结束回调：触发 unduck + 恢复被中断的音效
func _on_layer_finished(layer: AudioLayer):
	# Unduck 检查
	var ducked_for_id := layer.current_config_id()
	for pool in [_sfx_pool, _ui_pool]:
		for other in pool:
			if not other.is_active():
				continue
			other.ducked_by.erase(ducked_for_id)
			if other.ducked_by.is_empty() and other.ducked:
				other.unduck()

	# 自动恢复被中断的 resumable 音效（按优先级降序）
	_try_resume_pending()

## 播放失败回调
func _on_play_failed(config_id: String, reason: String):
	push_warning("[Audio] 播放失败: %s (reason: %s)" % [config_id, reason])


# ── 中断恢复 ──

func _save_resume_state(layer: AudioLayer):
	if not layer.config:
		return
	_pending_resumes.append({
		"config": layer.config,
		"position": layer.get_playback_position(),
		"cutoff_remaining": layer.get_cutoff_remaining_ms(),
	})

func _try_resume_pending():
	if _pending_resumes.is_empty():
		return

	# 按优先级降序排列（高优先级先恢复）
	_pending_resumes.sort_custom(func(a, b): return a.config.priority > b.config.priority)

	for resume_data in _pending_resumes:
		var cfg: AudioConfig = resume_data.config
		var pos: float = resume_data.position
		var cutoff: int = resume_data.cutoff_remaining

		# 选择一个空闲层恢复
		var pool := _sfx_pool if cfg.category != AudioConfig.Category.SFX_UI else _ui_pool
		var target_layer: AudioLayer = null
		for layer in pool:
			if layer.is_idle():
				target_layer = layer
				break
		if not target_layer:
			# 无空闲层 → 替换最低优先级
			var lowest_priority := 999
			for layer in pool:
				if not layer.config:
					continue
				if layer.config.priority < lowest_priority:
					lowest_priority = layer.config.priority
					target_layer = layer
		if not target_layer:
			if pool.size() > 0:
				target_layer = pool[0]

		if target_layer:
			target_layer.stop(false)
			target_layer.play_from_position(cfg, pos, cutoff)

	_pending_resumes.clear()


# ── 层分配 ──

func _find_target_layer(pool: Array, config: AudioConfig, interrupted_layer: AudioLayer) -> AudioLayer:
	# 优先使用被中断的层
	if interrupted_layer:
		return interrupted_layer

	# 找空闲层
	for layer in pool:
		if layer.is_idle():
			return layer

	# 回收 pending resume（仅当新音效优先级严格高于被中断音效）
	var best_resume_idx := -1
	var best_resume_prio := -1
	for i in range(_pending_resumes.size()):
		var rc: AudioConfig = _pending_resumes[i].config
		if rc.priority < config.priority and rc.priority > best_resume_prio:
			best_resume_idx = i
			best_resume_prio = rc.priority
	if best_resume_idx >= 0:
		_pending_resumes.remove_at(best_resume_idx)
		# 找空闲层（此时应该有了，因为 freeing a resume 释放了一个 slot）
		for layer in pool:
			if layer.is_idle():
				return layer

	# 替换最低优先级
	var lowest_priority := 999
	var target_layer: AudioLayer = null
	for layer in pool:
		if not layer.config:
			continue
		if layer.config.priority < lowest_priority:
			lowest_priority = layer.config.priority
			target_layer = layer
	if not target_layer and pool.size() > 0:
		target_layer = pool[0]
	return target_layer


# ── Ducking ──

func _apply_ducking(pool: Array, new_config: AudioConfig):
	for layer in pool:
		if not layer.is_active() or not layer.config:
			continue
		if layer.config.priority < new_config.priority:
			layer.ducked_by.append(new_config.id)
			layer.duck()


# ── 辅助 ──

static func _get_instance() -> AudioManager:
	return Engine.get_main_loop().root.get_node_or_null("AudioManager") as AudioManager


# ═════════════════════════════════════════════════════════════════
# 默认音效注册
# ═════════════════════════════════════════════════════════════════

func _register_default_configs():
	#                          id            path                                   vol   priority            category               interrupt            overlap  fade_in  fade_out  resumable
	_register("swing",       "res://assets/audio/sfx/swing.mp3",       0.8,  AudioConfig.Priority.NORMAL,   AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  -1, 0,   50)
	_register("wave",        "res://assets/audio/sfx/wave.mp3",        0.75, AudioConfig.Priority.NORMAL,   AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,   2, 0,   80)
	_register("parry",       "res://assets/audio/sfx/parry.mp3",       0.7,  AudioConfig.Priority.HIGH,     AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  -1, 0,   50)
	_register("ult",         "res://assets/audio/sfx/ult.mp3",         1.0,  AudioConfig.Priority.CRITICAL, AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.LOWER,  1, 50,  200)
	_register("hit_player",  "res://assets/audio/sfx/hit_player.mp3",  0.9,  AudioConfig.Priority.HIGH,     AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  -1, 0,   50)
	_register("hit_enemy",   "res://assets/audio/sfx/hit_enemy.mp3",   0.85, AudioConfig.Priority.HIGH,     AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  -1, 0,   50)
	_register("pickup",      "res://assets/audio/sfx/pickup.mp3",      0.6,  AudioConfig.Priority.NORMAL,   AudioConfig.Category.SFX_UI,     AudioConfig.Interrupt.NONE,  -1, 0,   30)
	_register("arrow",       "res://assets/audio/sfx/arrow.mp3",       0.6,  AudioConfig.Priority.NORMAL,   AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  -1, 0,   50)
	_register("bgm_battle",  "res://assets/audio/bgm/battle_01.mp3",   0.5,  AudioConfig.Priority.LOW,      AudioConfig.Category.MUSIC,      AudioConfig.Interrupt.NONE,  -1, 1000, 2000, true)

func _register(id: String, path: String, vol: float, pri: int, cat: int, intr: int, max_ov: int, fade_in: int, fade_out: int, resumable: bool = false):
	var config := AudioConfig.new(id, path, vol, pri, cat, intr, max_ov, fade_in, fade_out, 0, AudioConfig.FadeCurve.LINEAR, resumable)
	_configs[id] = config
