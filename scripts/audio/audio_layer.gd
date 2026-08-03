# 音频层 — 封装单个 AudioStreamPlayer，含 fade / 状态机 / ducking / 截断 / loop / pitch 随机化
class_name AudioLayer
extends RefCounted

enum State { IDLE, FADING_IN, PLAYING, FADING_OUT }

const VOLUME_FLOOR_DB := -60.0
const DUCK_LINEAR_MUL: float = 0.25           # -12 dB → 10^(-12/20) ≈ 0.25
const DUCK_DB: float = -12.0

var player: AudioStreamPlayer = null
var config: AudioConfig = null
var state: int = State.IDLE
var tween: Tween = null
var _cutoff_timer: Timer = null
var base_volume: float = 0.8                  # config.volume（未 ducking 前）
var ducked: bool = false
var ducked_by: Array = []                      # 压低自己的音效 ID 列表
var _finish_callback: Callable = func(): pass
var _fail_callback: Callable = func(_id, _reason): pass
var _loop_connected: bool = false

## 初始化（bus_name 由 AudioManager 传入）
func init(p_player: AudioStreamPlayer, bus_name: String = "SFX"):
	player = p_player
	player.volume_db = VOLUME_FLOOR_DB
	player.bus = bus_name

## 播放音频
func play(p_config: AudioConfig, p_interrupt: bool = false):
	if not player:
		return
	if state == State.PLAYING and not p_interrupt:
		return

	_reset_internal()

	config = p_config
	base_volume = config.volume

	player.stream = _load_stream(config.path)
	if not player.stream:
		state = State.IDLE
		config = null
		if _fail_callback.is_valid():
			_fail_callback.call(config.id if config else "", "load_failed")
		return

	# Bus 路由
	player.bus = config.get_bus_name()

	# Loop
	if config.loop and not _loop_connected:
		player.finished.connect(_on_loop_end)
		_loop_connected = true

	# Pitch 随机化
	if config.pitch_variation > 0.0:
		player.pitch_scale = 1.0 + randf_range(-config.pitch_variation, config.pitch_variation)

	# 淡入
	if config.fade_in_ms > 0:
		state = State.FADING_IN
		player.volume_db = VOLUME_FLOOR_DB
		player.play()
		_fade_to(linear_to_db(base_volume), config.fade_in_ms * 0.001, config.fade_curve)
		var t = player.get_tree().create_timer(config.fade_in_ms * 0.001)
		t.timeout.connect(func(): state = State.PLAYING if state == State.FADING_IN else state)
	else:
		state = State.PLAYING
		player.volume_db = linear_to_db(base_volume)
		player.play()

	# 截断定时
	if config.cutoff_ms > 0:
		_schedule_cutoff(config.cutoff_ms)

## 从指定位置播放（断点恢复用）
func play_from_position(p_config: AudioConfig, position: float, cutoff_remaining_ms: int = 0):
	if not player:
		return

	_reset_internal()

	config = p_config
	base_volume = config.volume

	player.stream = _load_stream(config.path)
	if not player.stream:
		state = State.IDLE
		config = null
		if _fail_callback.is_valid():
			_fail_callback.call("", "load_failed")
		return

	player.bus = config.get_bus_name()

	if config.loop and not _loop_connected:
		player.finished.connect(_on_loop_end)
		_loop_connected = true

	# 从断点 + 短暂 fade in
	state = State.FADING_IN
	player.volume_db = VOLUME_FLOOR_DB
	player.play(position)
	_fade_to(linear_to_db(base_volume), 0.1, AudioConfig.FadeCurve.EASE_IN)
	var t = player.get_tree().create_timer(0.1)
	t.timeout.connect(func(): state = State.PLAYING if state == State.FADING_IN else state)

	# 恢复截断
	if cutoff_remaining_ms > 0:
		_schedule_cutoff(cutoff_remaining_ms)

## 停止（淡出）
func stop(fade_out: bool = true):
	if state == State.IDLE:
		return
	_stop_tween()
	_cancel_cutoff()
	if fade_out and config and config.fade_out_ms > 0:
		state = State.FADING_OUT
		_fade_to(VOLUME_FLOOR_DB, config.fade_out_ms * 0.001, config.fade_curve)
		var timer = player.get_tree().create_timer(config.fade_out_ms * 0.001)
		timer.timeout.connect(func(): _reset())
	else:
		_reset()

## Ducking — 降低音量 (-12 dB)
func duck():
	if ducked or state == State.IDLE:
		return
	ducked = true
	var target_db = linear_to_db(base_volume) + DUCK_DB
	_fade_to(maxf(target_db, VOLUME_FLOOR_DB), 0.15, AudioConfig.FadeCurve.LINEAR)

## Unduck — 恢复音量
func unduck():
	if not ducked:
		return
	ducked = false
	ducked_by.clear()
	if state in [State.PLAYING, State.FADING_IN]:
		_fade_to(linear_to_db(base_volume), 0.25, AudioConfig.FadeCurve.EASE_OUT)

## 获取当前播放位置（秒），用于断点保存
func get_playback_position() -> float:
	return player.get_playback_position() if player and player.playing else 0.0

## 获取剩余截断时长（ms）
func get_cutoff_remaining_ms() -> int:
	if _cutoff_timer and not _cutoff_timer.is_stopped():
		return int(_cutoff_timer.time_left * 1000)
	return 0

## 状态查询
func is_idle() -> bool:     return state == State.IDLE
func is_active() -> bool:   return state != State.IDLE
func current_config_id() -> String: return config.id if config else ""


# ── 内部 ──

func _load_stream(path: String) -> AudioStream:
	if path.is_empty(): return null
	var res = load(path)
	if res and res is AudioStream: return res
	if path.ends_with(".mp3"):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var bytes = file.get_buffer(file.get_length())
			file.close()
			var mp3 = AudioStreamMP3.new(); mp3.data = bytes
			return mp3
	return null

## 统一音量 Tween（确保同一时刻仅一个 Tween 操作 volume_db）
func _fade_to(target_db: float, duration: float, curve: int):
	_stop_tween()
	tween = player.create_tween()
	var tw = tween.tween_property(player, "volume_db", target_db, duration)
	match curve:
		AudioConfig.FadeCurve.EASE_IN:      tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		AudioConfig.FadeCurve.EASE_OUT:     tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		AudioConfig.FadeCurve.EASE_IN_OUT:   tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_:                                   tw.set_trans(Tween.TRANS_LINEAR)

func _schedule_cutoff(ms: int):
	_cancel_cutoff()
	_cutoff_timer = Timer.new(); _cutoff_timer.one_shot = true
	_cutoff_timer.wait_time = ms * 0.001
	_cutoff_timer.timeout.connect(_on_cutoff)
	player.add_child(_cutoff_timer); _cutoff_timer.start()

func _on_cutoff():
	# 检查音效是否已经自然结束
	if not player.playing:
		_reset()
		return
	stop(true)

func _on_loop_end():
	# Loop: 重新从头播放
	if config and config.loop and player:
		player.seek(0.0)
		player.play()

func _cancel_cutoff():
	if _cutoff_timer: _cutoff_timer.stop(); _cutoff_timer.queue_free(); _cutoff_timer = null

func _stop_tween():
	if tween and tween.is_valid(): tween.kill()
	tween = null

func _reset():
	_stop_tween(); _cancel_cutoff()
	player.stop(); player.stream = null
	state = State.IDLE; config = null
	ducked = false; ducked_by.clear()
	player.volume_db = VOLUME_FLOOR_DB
	player.pitch_scale = 1.0
	if _loop_connected and player.finished.is_connected(_on_loop_end):
		player.finished.disconnect(_on_loop_end)
	_loop_connected = false
	_finish_callback.call()
	_finish_callback = func(): pass

func _reset_internal():
	_stop_tween(); _cancel_cutoff()
	player.stop()
	ducked = false; ducked_by.clear()
	player.pitch_scale = 1.0
	if _loop_connected and player.finished.is_connected(_on_loop_end):
		player.finished.disconnect(_on_loop_end)
	_loop_connected = false
