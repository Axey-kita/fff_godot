# 音频层 — 封装单个 AudioStreamPlayer，含 fade / 状态机 / ducking / 截断 / 分组音量
class_name AudioLayer
extends RefCounted

enum State { IDLE, FADING_IN, PLAYING, FADING_OUT, INTERRUPTED }

const VOLUME_FLOOR_DB := -60.0
const DUCK_DB := -12.0

var player: AudioStreamPlayer = null
var config: AudioConfig = null
var state: int = State.IDLE
var tween: Tween = null
var _cutoff_timer: Timer = null
var base_volume: float = 0.8          # config.volume * group_volume（未 ducking 前）
var ducked: bool = false
var ducked_by: Array = []              # AudioLayer 引用
var _group_volume: float = 1.0         # 当前分组音量
var _saved_config: AudioConfig = null  # 中断保存
var _saved_position: float = 0.0       # 中断时的播放位置（秒）
var _saved_cutoff_ms: int = 0          # 中断时的剩余截断时长
var _saved_group_vol: float = 1.0      # 中断时的分组音量
var _finish_callback: Callable = func(): pass

## 初始化
func init(p_player: AudioStreamPlayer):
	player = p_player
	player.volume_db = VOLUME_FLOOR_DB
	player.bus = "Master"

## 播放音频
func play(p_config: AudioConfig, group_vol: float, p_interrupt: bool = false):
	if not player:
		return
	if state == State.PLAYING and not p_interrupt:
		return

	# 中断当前
	if state != State.IDLE:
		_stop_tween()
		_cancel_cutoff()
		player.stop()

	config = p_config
	_group_volume = group_vol
	base_volume = config.volume * group_vol
	player.stream = _load_stream(config.path)
	if not player.stream:
		state = State.IDLE
		return

	# 淡入
	if config.fade_in_ms > 0:
		state = State.FADING_IN
		player.volume_db = VOLUME_FLOOR_DB
		player.play()
		_fade_to(linear2db(base_volume), config.fade_in_ms * 0.001, config.fade_curve)
		var t = player.get_tree().create_timer(config.fade_in_ms * 0.001)
		t.timeout.connect(func(): state = State.PLAYING if state == State.FADING_IN else state)
	else:
		state = State.PLAYING
		player.volume_db = linear2db(base_volume)
		player.play()

	# 截断定时
	if config.cutoff_ms > 0:
		_schedule_cutoff(config.cutoff_ms)

## 停止（淡出）
func stop(fade_out: bool = true):
	if state == State.IDLE:
		return
	_stop_tween()
	_cancel_cutoff()
	if fade_out and config and config.fade_out_ms > 0:
		state = State.FADING_OUT
		_fade_to(VOLUME_FLOOR_DB, config.fade_out_ms * 0.001, config.fade_curve)
		if not player.is_connected("finished", _on_fade_out_done):
			player.finished.connect(_on_fade_out_done, CONNECT_ONE_SHOT)
	else:
		_reset()

## 分组音量变化时调用：重新计算目标音量并 fade
func update_group_volume(new_group_vol: float):
	if state == State.IDLE or not config:
		return
	_group_volume = new_group_vol
	var target = config.volume * new_group_vol
	if ducked:
		target = maxf(target + DUCK_DB / 20.0, 0.0)  # ducking 降幅保持
	base_volume = target
	if state in [State.PLAYING, State.FADING_IN]:
		_fade_to(linear2db(target), 0.2, AudioConfig.FadeCurve.EASE_OUT)

## 中断前保存状态（断点重连）
func save_state():
	if state == State.IDLE or not config:
		return
	_saved_config = config
	_saved_position = player.get_playback_position() if player.playing else 0.0
	_saved_group_vol = _group_volume
	_saved_cutoff_ms = int(_cutoff_timer.time_left * 1000) if _cutoff_timer and not _cutoff_timer.is_stopped() else 0
	_cancel_cutoff()
	_stop_tween()
	player.stop()
	state = State.INTERRUPTED

## 从中断恢复（断点重连）
func resume():
	if state != State.INTERRUPTED or not _saved_config:
		return
	var cfg = _saved_config
	var pos = _saved_position
	var gv = _saved_group_vol
	var cutoff = _saved_cutoff_ms
	_saved_config = null; _saved_position = 0.0; _saved_cutoff_ms = 0; _saved_group_vol = 1.0

	config = cfg
	_group_volume = gv
	base_volume = config.volume * gv
	player.stream = _load_stream(config.path)
	if not player.stream:
		state = State.IDLE
		return

	# 从断点播放 + 短暂淡入
	state = State.FADING_IN
	player.volume_db = VOLUME_FLOOR_DB
	player.play(pos)
	_fade_to(linear2db(base_volume), 0.1, AudioConfig.FadeCurve.EASE_IN)
	var t = player.get_tree().create_timer(0.1)
	t.timeout.connect(func(): state = State.PLAYING if state == State.FADING_IN else state)

	# 恢复截断定时
	if cutoff > 0:
		_schedule_cutoff(cutoff)

## 清除中断保存（不恢复）
func clear_saved_state():
	_saved_config = null; _saved_position = 0.0; _saved_cutoff_ms = 0; _saved_group_vol = 1.0

func has_saved_state() -> bool:
	return _saved_config != null

func _on_fade_out_done():
	_reset()

## Ducking — 降低音量
func duck():
	if ducked or state == State.IDLE:
		return
	ducked = true
	var target = maxf(linear2db(base_volume) + DUCK_DB, VOLUME_FLOOR_DB)
	_fade_to(target, 0.15, AudioConfig.FadeCurve.LINEAR)

## Unduck — 恢复音量
func unduck():
	if not ducked:
		return
	ducked = false
	ducked_by.clear()
	if state in [State.PLAYING, State.FADING_IN]:
		_fade_to(linear2db(base_volume), 0.25, AudioConfig.FadeCurve.EASE_OUT)

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
	_cutoff_timer.timeout.connect(func(): stop(true))
	player.add_child(_cutoff_timer); _cutoff_timer.start()

func _cancel_cutoff():
	if _cutoff_timer: _cutoff_timer.stop(); _cutoff_timer.queue_free(); _cutoff_timer = null

func _stop_tween():
	if tween and tween.is_valid(): tween.kill()
	tween = null

func _reset():
	_stop_tween(); _cancel_cutoff(); clear_saved_state()
	player.stop(); player.stream = null
	state = State.IDLE; config = null
	ducked = false; ducked_by.clear()
	player.volume_db = VOLUME_FLOOR_DB
	_finish_callback.call()
	_finish_callback = func(): pass
