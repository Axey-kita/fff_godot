class_name FrameAnimation
extends RefCounted

## 逐帧动画纯数据/计时层 — 不包含任何渲染位置信息
## 位置通过外部 position_spec 注入

class FrameData:
	var texture: Texture2D
	var duration_seconds: float
	
	func _init(p_tex: Texture2D, p_dur: float):
		texture = p_tex
		duration_seconds = p_dur

var frames: Array[FrameData] = []
var total_duration: float = 0.0
var loop: bool = false

# Runtime state
var _timer: float = 0.0
var _current_index: int = 0
var _playing: bool = false
var _finished: bool = false

## 从帧数据加载动画（不依赖外部 .txt 文件）
## frame_specs: Array[Dictionary] —— [{"index":1, "duration":999.0}, ...]
## 可选字段 "filename" 用于自定义文件名（省略时使用 prefix+index+.png）
static func load_from_frames(dir_path: String, prefix: String, frame_specs: Array, p_loop: bool = false) -> FrameAnimation:
	var anim = FrameAnimation.new()
	anim.loop = p_loop
	
	var loaded_count := 0
	for spec in frame_specs:
		var spec_d: Dictionary = spec as Dictionary
		if spec_d == null or spec_d.is_empty():
			continue
		var frame_num: int = spec_d["index"]
		var duration: float = spec_d["duration"]
		var custom_name: String = spec_d.get("filename", "")
		
		var file_name: String
		if not custom_name.is_empty():
			file_name = custom_name
		else:
			file_name = prefix + str(frame_num) + ".png"
		
		var full_path = dir_path + file_name
		
		# 直接 load()，不做存在性检查
		var tex: Texture2D = load(full_path)
		
		# 回退扩展名：png → jpg
		if not tex and file_name.ends_with(".png"):
			var jpg_path = dir_path + file_name.trim_suffix(".png") + ".jpg"
			tex = load(jpg_path)
		
		if tex and tex is Texture2D:
			anim.add_frame(tex, duration)
			loaded_count += 1
		else:
			push_error("[FrameAnimation] Failed to load frame: " + full_path)
	
	print("[FrameAnimation] Loaded ", loaded_count, "/", frame_specs.size(), " frames from ", dir_path)
	anim._calc_total_duration()
	return anim

func add_frame(texture: Texture2D, duration_seconds: float):
	frames.append(FrameData.new(texture, duration_seconds))

func _calc_total_duration():
	total_duration = 0.0
	for f in frames:
		total_duration += f.duration_seconds

func play():
	_playing = true
	_finished = false
	_timer = 0.0
	_current_index = 0

func stop():
	_playing = false
	_finished = true

func reset():
	_timer = 0.0
	_current_index = 0
	_finished = false

## 每帧更新 (frame_dt: 经过的帧数, 1 ≈ 1/60s)
func update(frame_dt: float = 1.0):
	if not _playing or _finished or frames.is_empty():
		return
	
	var dt_seconds = frame_dt / 60.0
	_timer += dt_seconds
	
	while _timer >= frames[_current_index].duration_seconds:
		if _current_index < frames.size() - 1:
			_timer -= frames[_current_index].duration_seconds
			_current_index += 1
		elif loop:
			_timer -= frames[_current_index].duration_seconds
			_current_index = 0
		else:
			_finished = true
			_playing = false
			_current_index = frames.size() - 1
			break

func get_current_texture() -> Texture2D:
	if frames.is_empty() or _current_index >= frames.size():
		return null
	return frames[_current_index].texture

func is_playing() -> bool:
	return _playing and not _finished

func is_finished() -> bool:
	return _finished

func get_progress() -> float:
	if total_duration <= 0:
		return 0.0
	var elapsed = 0.0
	for i in _current_index:
		elapsed += frames[i].duration_seconds
	elapsed += minf(_timer, frames[_current_index].duration_seconds)
	return clampf(elapsed / total_duration, 0.0, 1.0)
