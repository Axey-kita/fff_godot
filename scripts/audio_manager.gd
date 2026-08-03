extends Node

# ═══════════════════════════════════════════════════════════════
# AudioManager — 全局音频管理器 (Autoload)
# 基于 AudioLayer 池，支持 MP3/OGG/WAV，淡入淡出 / 截断 / 循环
# ═══════════════════════════════════════════════════════════════

const MAX_LAYERS := 16

var _sound_configs: Dictionary = {}       # id → AudioConfig
var _layers: Array = []
var _loop_configs: Dictionary = {}        # id → AudioLayer (循环音效追踪)

func _ready():
	for i in range(MAX_LAYERS):
		var player = AudioStreamPlayer.new()
		add_child(player)
		var layer = AudioLayer.new()
		layer.init(player, "SFX")
		_layers.append(layer)
	_register_all_sounds()

func _register_all_sounds():
	register_sound("bard_perform", "res://assets/char_ani/bard/BGM/Whisper of the Leaves.mp3",
		{"loop": true, "volume": 0.7, "fade_in_ms": 300, "fade_out_ms": 300, "category": AudioConfig.Category.MUSIC})

# ── 注册音效 ──

func register_sound(id: String, path: String, overrides: Dictionary = {}):
	"""注册一个音效配置。支持 .mp3 / .ogg / .wav。
	
	参数:
	  id       — 音效标识，如 "bard_perform"
	  path     — 资源路径，如 "res://assets/sfx/bard_perform.mp3"
	  overrides — 可选覆盖字段 (volume/loop/fade_in_ms/fade_out_ms/cutoff_ms 等)
	"""
	var cfg := AudioConfig.new(
		id,
		path,
		overrides.get("volume", 0.8),
		overrides.get("priority", AudioConfig.Priority.NORMAL),
		overrides.get("category", AudioConfig.Category.SFX_COMBAT),
		overrides.get("interrupt", AudioConfig.Interrupt.NONE),
		overrides.get("max_overlap", -1),
		overrides.get("fade_in_ms", 0),
		overrides.get("fade_out_ms", 0),
		overrides.get("cutoff_ms", 0),
		overrides.get("fade_curve", AudioConfig.FadeCurve.LINEAR),
		overrides.get("resumable", false),
		overrides.get("pitch_variation", 0.0),
		overrides.get("loop", false),
	)
	_sound_configs[id] = cfg
	print("[Audio] 注册音效: ", id, " → ", path)

# ── 播放 ──

func play_sound(id: String):
	"""播放已注册的音效（兼容旧接口）。
	未注册的音效仅打印提示，不会报错。"""
	if not _sound_configs.has(id):
		print("[Audio] ⚠ 未注册音效: ", id)
		return
	var layer := _find_idle_layer()
	if not layer:
		print("[Audio] ⚠ 无空闲音轨: ", id)
		return
	layer.play(_sound_configs[id])

func play_loop(id: String):
	"""循环播放音效（如 BGM / 演奏）。停止时用 stop_loop(id)。"""
	if _loop_configs.has(id):
		return  # 已在循环中
	if not _sound_configs.has(id):
		print("[Audio] ⚠ 未注册循环音效: ", id)
		return
	var cfg = _sound_configs[id]
	if not cfg.loop:
		cfg.loop = true  # 强制循环
	var layer := _find_idle_layer()
	if not layer:
		print("[Audio] ⚠ 无空闲音轨: ", id)
		return
	layer.play(cfg)
	_loop_configs[id] = layer

func stop_loop(id: String):
	"""停止循环音效。"""
	var layer: AudioLayer = _loop_configs.get(id)
	if layer:
		layer.stop(true)
		_loop_configs.erase(id)

func stop_all():
	"""停止所有音效。"""
	for layer in _layers:
		if layer.is_active():
			layer.stop(false)
	_loop_configs.clear()

# ── 内部 ──

func _find_idle_layer() -> AudioLayer:
	for layer in _layers:
		if layer.is_idle():
			return layer
	return null
