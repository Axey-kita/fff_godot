class_name CharConfigs

## Each character is now self-contained in scripts/characters/xxx.gd.
## This class delegates to CharacterFactory for all config queries.

static var configs := {}

static func ensure_init():
	if configs.is_empty():
		_init_all()

## 重置配置缓存（重开游戏时调用，避免大招等修改的 config 残留）
static func reset():
	configs.clear()
	CharacterFactory.reset_configs()
	_init_all()

static func get_all_ids() -> Array:
	return configs.keys()

static func get_char_name(char_id: String) -> String:
	var cfg = configs.get(char_id, {})
	if cfg.is_empty():
		return char_id
	return cfg.get("name", char_id)

static func _init_all():
	var ids = CharacterFactory._char_registry.keys()
	print("[CharConfigs] _init_all() start, loading ", ids.size(), " characters...")
	for cid in ids:
		print("[CharConfigs] loading config for: ", cid)
		configs[cid] = CharacterFactory.get_config(cid)
		if configs[cid].is_empty():
			printerr("[CharConfigs] FAILED to load config for: ", cid)
		else:
			var anims = configs[cid].get("animations", {})
			print("[CharConfigs] ", cid, " loaded OK. animations keys=", anims.keys(), " idle valid=", anims.get("idle") != null)
	print("[CharConfigs] _init_all() done")
