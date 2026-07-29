# AudioManager — 全局音频管理 (Autoload)
extends Node

const POOL_SIZE := 8
const DUCK_DB := -12.0

# ── 运行时状态 ──
var _sfx_pool: Array[AudioLayer] = []
var _music_layer: AudioLayer = null
var _ui_layer: AudioLayer = null
var _sfx_volume: float = 1.0
var _music_volume: float = 1.0

# ── 音频配置注册表 ──
static var _configs: Dictionary = {}


# ═════════════════════════════════════════════════════════════════
# 生命周期
# ═════════════════════════════════════════════════════════════════

func _ready():
	_register_default_configs()
	_setup_pool()
	_setup_music_layer()
	_setup_ui_layer()

func _setup_pool():
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX_" + str(i)
		player.bus = "Master"
		add_child(player)
		var layer := AudioLayer.new()
		layer.init(player)
		layer._finish_callback = func(): _on_layer_finished(layer)
		_sfx_pool.append(layer)

func _setup_music_layer():
	var player := AudioStreamPlayer.new()
	player.name = "Music"
	player.bus = "Master"
	add_child(player)
	_music_layer = AudioLayer.new()
	_music_layer.init(player)

func _setup_ui_layer():
	var player := AudioStreamPlayer.new()
	player.name = "UI"
	player.bus = "Master"
	add_child(player)
	_ui_layer = AudioLayer.new()
	_ui_layer.init(player)


# ═════════════════════════════════════════════════════════════════
# 公共 API
# ═════════════════════════════════════════════════════════════════

## 播放 SFX（支持注册 ID 或内联结构体）
##   play_sfx("swing")           -- 预注册音效
##   play_sfx({"path": "res://...", "volume": 0.8, "priority": 2, "interrupt": 2, "fade_in_ms": 50, "cutoff_ms": 2000, "fade_curve": "ease_out"})
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
	instance._play_sfx_impl(config)

## 播放背景音乐
static func play_music(music_id: String):
	var instance = _get_instance()
	if not instance:
		return
	var config: AudioConfig = _configs.get(music_id)
	if not config:
		push_warning("[Audio] 未注册音效: " + music_id)
		return
	instance._music_layer.play(config, instance._music_volume)

## 停止背景音乐
static func stop_music(fade: bool = true):
	var instance = _get_instance()
	if not instance:
		return
	instance._music_layer.stop(fade)

## 停止所有 SFX
static func stop_all_sfx(fade: bool = true):
	var instance = _get_instance()
	if not instance:
		return
	for layer in instance._sfx_pool:
		layer.stop(fade)

## 全局音量（Master 总线 — 最后一层乘算）
static func set_master_volume(vol: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(clampf(vol, 0.0, 1.0)))

## SFX 分组音量：立即对所有活跃 SFX 层生效
static func set_sfx_volume(vol: float):
	var instance = _get_instance()
	if not instance: return
	instance._sfx_volume = clampf(vol, 0.0, 1.0)
	for layer in instance._sfx_pool:
		if layer.is_active():
			layer.update_group_volume(instance._sfx_volume)

## 音乐分组音量
static func set_music_volume(vol: float):
	var instance = _get_instance()
	if not instance: return
	instance._music_volume = clampf(vol, 0.0, 1.0)
	if instance._music_layer.is_active():
		instance._music_layer.update_group_volume(instance._music_volume)

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

func _play_sfx_impl(config: AudioConfig):
	# 检查同音效重叠限制（仅对注册音效生效，inline 的 id 为 _inline 不受限）
	if config.id != "_inline" and config.max_overlap > 0:
		var active_count := 0
		for layer in _sfx_pool:
			if layer.current_config_id() == config.id and layer.is_active():
				active_count += 1
		if active_count >= config.max_overlap:
			return

	# 中断检查：找到可被中断的层，先保存状态
	var interrupted_layer: AudioLayer = null
	for layer in _sfx_pool:
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
	if interrupted_layer:
		if interrupted_layer.config.resumable:
			interrupted_layer.save_state()  # 长期音效断点保存
		else:
			interrupted_layer.clear_saved_state()

	# 找目标层（优先使用被中断的层）
	var target_layer: AudioLayer = null
	if interrupted_layer:
		target_layer = interrupted_layer
	else:
		# 优先空闲
		for layer in _sfx_pool:
			if layer.is_idle():
				target_layer = layer
				break
		# 其次 INTERRUPTED 层（放弃恢复）
		if not target_layer:
			for layer in _sfx_pool:
				if layer.state == AudioLayer.State.INTERRUPTED:
					layer.clear_saved_state()
					target_layer = layer
					break
		# 无空闲 → 替换最低优先级
		if not target_layer:
			var lowest_priority := 999
			for layer in _sfx_pool:
				if not layer.config:
					continue
				if layer.config.priority < lowest_priority:
					lowest_priority = layer.config.priority
					target_layer = layer
			if not target_layer:
				target_layer = _sfx_pool[0]

	if not target_layer:
		return

	# Ducking：压低低优先级层
	_apply_ducking(config)

	# 播放
	target_layer.play(config, _sfx_volume, interrupt_target != null)

## Ducking 逻辑
func _apply_ducking(new_config: AudioConfig):
	for layer in _sfx_pool:
		if not layer.is_active() or not layer.config:
			continue
		if layer.config.priority < new_config.priority:
			layer.ducked_by.append(new_config.id)
			layer.duck()
		elif layer.config.priority >= new_config.priority:
			# 新音效不压低同/高优先级
			pass

## 层结束回调：触发 unduck
func _on_layer_finished(layer: AudioLayer):
	# Unduck 检查
	var ducked_for_id := layer.current_config_id()
	for other in _sfx_pool:
		if not other.is_active():
			continue
		other.ducked_by.erase(ducked_for_id)
		if other.ducked_by.is_empty() and other.ducked:
			other.unduck()

	# 自动恢复被中断的层（断点重连）
	for other in _sfx_pool:
		if other.has_saved_state():
			other.resume()

## 获取 Autoload 实例
static func _get_instance() -> AudioManager:
	return Engine.get_main_loop().root.get_node_or_null("AudioManager") as AudioManager


# ═════════════════════════════════════════════════════════════════
# 默认音效注册（使用占位路径，替换为实际 MP3 后生效）
# ═════════════════════════════════════════════════════════════════

func _register_default_configs():
	_register("swing",       "res://assets/audio/sfx/swing.mp3",       0.8, AudioConfig.Priority.NORMAL, AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  0, 0,   50)
	_register("wave",        "res://assets/audio/sfx/wave.mp3",        0.75, AudioConfig.Priority.NORMAL, AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  2, 0,   80)
	_register("parry",       "res://assets/audio/sfx/parry.mp3",       0.7, AudioConfig.Priority.HIGH,   AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  0, 0,   50)
	_register("ult",         "res://assets/audio/sfx/ult.mp3",         1.0, AudioConfig.Priority.CRITICAL, AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.LOWER, 1, 50,  200)
	_register("hit_player",  "res://assets/audio/sfx/hit_player.mp3",  0.9, AudioConfig.Priority.HIGH,   AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  0, 0,   50)
	_register("hit_enemy",   "res://assets/audio/sfx/hit_enemy.mp3",   0.85, AudioConfig.Priority.HIGH,  AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  0, 0,   50)
	_register("pickup",      "res://assets/audio/sfx/pickup.mp3",      0.6, AudioConfig.Priority.NORMAL, AudioConfig.Category.SFX_UI,     AudioConfig.Interrupt.NONE,  0, 0,   30)
	_register("arrow",       "res://assets/audio/sfx/arrow.mp3",       0.6, AudioConfig.Priority.NORMAL, AudioConfig.Category.SFX_COMBAT, AudioConfig.Interrupt.NONE,  0, 0,   50)
	_register("bgm_battle",  "res://assets/audio/bgm/battle_01.mp3",   0.5, AudioConfig.Priority.LOW,    AudioConfig.Category.MUSIC,     AudioConfig.Interrupt.NONE,  1, 1000, 2000, true)  # resumable

func _register(id: String, path: String, vol: float, pri: int, cat: int, intr: int, max_ov: int, fade_in: int, fade_out: int, resumable: bool = false):
	var config := AudioConfig.new(id, path, vol, pri, cat, intr, max_ov, fade_in, fade_out, 0, AudioConfig.FadeCurve.LINEAR, resumable)
	_configs[id] = config
