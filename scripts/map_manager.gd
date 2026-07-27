class_name MapManager
## 地图管理：扫描地图文件夹、管理地图池配置、随机选图

# === 地图池配置文件路径 ===
const POOL_CONFIG_PATH := "user://map_pool.cfg"
const POOL_SECTION := "MapPool"
const POOL_KEY := "enabled_maps"

# === 自动扫描路径 ===
const MAPS_DIR := "res://maps/"

# 当前有效的地图列表（场景路径）
static var _all_maps: Array[String] = []
static var _pool_maps: Array[String] = []

# ===== 初始化：扫描地图 + 加载配置 =====
static func ensure_init():
	if _all_maps.is_empty():
		_scan_maps()
		_load_pool_config()

# ===== 扫描 maps/ 目录下所有 .tscn =====
# 打包后 DirAccess 无法扫描 res://，改用预定义列表作为 fallback
static var _builtin_maps: Array[String] = [
	"res://maps/map_01_battlefield.tscn",
	"res://maps/map_02_towers.tscn",
	"res://maps/map_03_voids.tscn.tscn",
]

static func _scan_maps():
	_all_maps.clear()
	var dir = DirAccess.open(MAPS_DIR)
	if dir:
		dir.list_dir_begin()
		var fname = dir.get_next()
		while fname != "":
			if fname.ends_with(".tscn") and not fname.begins_with("."):
				_all_maps.append(MAPS_DIR + fname)
			fname = dir.get_next()
		dir.list_dir_end()
		_all_maps.sort()
	# 开发环境未扫到或打包后：使用预定义列表
	if _all_maps.is_empty():
		_all_maps = _builtin_maps.duplicate()
	print("[MapManager] 扫描到 ", _all_maps.size(), " 张地图: ", _all_maps)

# ===== 加载/保存地图池 =====
static func _load_pool_config():
	_pool_maps.clear()
	var cfg = ConfigFile.new()
	if cfg.load(POOL_CONFIG_PATH) != OK:
		# 首次运行：默认启用全部地图
		_pool_maps = _all_maps.duplicate()
		_save_pool_config()
		return
	var saved: Array = cfg.get_value(POOL_SECTION, POOL_KEY, [])
	# 只保留仍存在的有效地图
	for path in saved:
		if _all_maps.has(path):
			_pool_maps.append(path)
	# 如果全部被过滤掉，退回默认
	if _pool_maps.is_empty():
		_pool_maps = _all_maps.duplicate()

static func _save_pool_config():
	var cfg = ConfigFile.new()
	cfg.set_value(POOL_SECTION, POOL_KEY, _pool_maps)
	cfg.save(POOL_CONFIG_PATH)

# ===== 公开 API =====

## 获取所有可用地图
static func get_all_maps() -> Array[String]:
	ensure_init()
	return _all_maps.duplicate()

## 获取地图池中的地图
static func get_pool_maps() -> Array[String]:
	ensure_init()
	return _pool_maps.duplicate()

## 设置地图池
static func set_pool_maps(pool: Array[String]):
	_pool_maps = pool.duplicate()
	_save_pool_config()

## 从池中随机选一张地图
static func pick_random() -> String:
	ensure_init()
	if _pool_maps.is_empty():
		_pool_maps = _all_maps.duplicate()
	return _pool_maps[randi() % _pool_maps.size()]

## 检查地图是否在池中
static func is_in_pool(map_path: String) -> bool:
	ensure_init()
	return _pool_maps.has(map_path)

## 切换地图的启用/禁用状态
static func toggle_map(map_path: String):
	ensure_init()
	if _pool_maps.has(map_path):
		_pool_maps.erase(map_path)
	else:
		_pool_maps.append(map_path)
	_pool_maps.sort()
	_save_pool_config()

## 获取地图显示名（去掉路径前缀和扩展名）
static func get_display_name(map_path: String) -> String:
	var fname = map_path.get_file()
	return fname.trim_suffix(".tscn")
