class_name CharConfigs

## Each character is now self-contained in scripts/characters/xxx.gd.
## This class delegates to CharacterFactory for all config queries.

static var configs := {}

static func ensure_init():
	if configs.is_empty():
		_init_all()

static func _init_all():
	var ids = ["knight", "mage", "archer", "paladin", "witch", "assassin", "shadowwarrior", "evoker", "rose"]
	print("[CharConfigs] _init_all() start, loading ", ids.size(), " characters...")
	for cid in ids:
		print("[CharConfigs] loading config for: ", cid)
		configs[cid] = CharacterFactory.get_config(cid)
		if configs[cid].is_empty():
			printerr("[CharConfigs] FAILED to load config for: ", cid)
		else:
			var imgs = configs[cid].get("images", {})
			print("[CharConfigs] ", cid, " loaded OK. images keys=", imgs.keys(), " idle valid=", imgs.get("idle") != null)
	print("[CharConfigs] _init_all() done")
