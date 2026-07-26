class_name CharacterSystems

## 通用调度：遍历所有实体，调用各自的 update_systems
static func update_characters():
	for f in GameWorld.entities:
		if f.hp > 0:
			CharacterFactory.update_char_systems(f)
	CharacterFactory.call_rose_trails()

## 通用 overlay 动画管理器
static func update_active_overlays():
	var to_remove: Array = []
	for entry in GameWorld.active_overlays:
		var anim: FrameAnimation = entry["anim"]
		var should_remove = false
		if not anim or not anim.is_playing():
			should_remove = true
		else:
			anim.update(1)
			if anim.is_finished():
				should_remove = true
		if should_remove:
			to_remove.append(entry)
			var cb: Callable = entry.get("on_finish", Callable())
			if cb.is_valid():
				cb.call()
	for e in to_remove:
		GameWorld.active_overlays.erase(e)
