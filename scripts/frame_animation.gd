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

## 从目录加载动画序列
## 时间表格式: frameN::Xs[::optional_filename]
static func load_from_dir(dir_path: String, prefix: String, timetable_path: String, p_loop: bool = false) -> FrameAnimation:
	var anim = FrameAnimation.new()
	anim.loop = p_loop
	
	# 如果 timetable_path 不是完整路径，拼上 dir_path
	var full_timetable_path = timetable_path
	if not timetable_path.begins_with("res://"):
		full_timetable_path = dir_path + timetable_path
	
	print("[FrameAnimation] Loading animation from: ", dir_path)
	
	var timetable = _parse_timetable(full_timetable_path)
	if timetable.is_empty():
		push_error("[FrameAnimation] Failed to parse timetable: " + full_timetable_path)
		return anim
	
	var loaded_count := 0
	for entry in timetable:
		var frame_num = entry["index"]
		var duration = entry["duration"]
		var custom_name = entry.get("filename", "")
		
		var file_name: String
		if not custom_name.is_empty():
			file_name = custom_name
		else:
			file_name = prefix + str(frame_num) + ".png"
		
		var full_path = dir_path + file_name
		
		# 直接 load()，不做事先存在性检查。
		# 安卓导出时贴图被压缩为 .ctex，FileAccess/ResourceLoader.exists 可能误判。
		var tex: Texture2D = load(full_path)
		
		# 回退扩展名：png → jpg
		if not tex and file_name.ends_with(".png"):
			var jpg_path = dir_path + file_name.trim_suffix(".png") + ".jpg"
			tex = load(jpg_path)
			if tex:
				print("[FrameAnimation] Loaded JPG fallback: ", jpg_path)
		
		if tex and tex is Texture2D:
			anim.add_frame(tex, duration)
			loaded_count += 1
		else:
			push_error("[FrameAnimation] Failed to load frame: " + full_path)
	
	print("[FrameAnimation] Loaded ", loaded_count, "/", timetable.size(), " frames from ", dir_path)
	anim._calc_total_duration()
	return anim

## 解析时间表: frameN::Xs[::filename]
static func _parse_timetable(path: String) -> Array:
	var result: Array = []
	
	# 在导出包中，.txt 文件应可通过 FileAccess 读取
	if not FileAccess.file_exists(path):
		# 回退：尝试 ResourceLoader 加载
		var res = load(path)
		if res:
			push_warning("[FrameAnimation] Timetable loaded via ResourceLoader: " + path)
		else:
			push_error("[FrameAnimation] Timetable file not found: " + path)
			return result
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[FrameAnimation] Cannot open timetable: " + path)
		return result
	
	var lines = file.get_as_text().split("\n")
	for line in lines:
		var stripped = line.strip_edges()
		if stripped.is_empty() or stripped.begins_with("end"):
			break
		var parts = stripped.split("::")
		if parts.size() < 2:
			continue
		var frame_num_str = parts[0].trim_prefix("frame")
		if not frame_num_str.is_valid_int():
			continue
		var frame_index = frame_num_str.to_int()
		var dur_str = parts[1].trim_suffix("s").strip_edges()
		if not dur_str.is_valid_float():
			continue
		var duration = dur_str.to_float()
		
		var entry = {"index": frame_index, "duration": duration}
		# 可选第三列：自定义文件名（用于帧复用）
		if parts.size() >= 3 and not parts[2].strip_edges().is_empty():
			entry["filename"] = parts[2].strip_edges()
		
		result.append(entry)
	
	return result

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
