class_name InputHandler

const PROJ_LIGHT_IMG = preload("res://assets/fx_lightning_projectile.png")

# ===== Player Input =====
static func update_player_input(world, keys: Dictionary):
	var p = world.player
	if p.hp > 0 and not p.has_status("frozen"):
		# 悬挂平台下落：S/↓ 键 + 站在非地面平台上
		if keys["down"] and p.grounded and p.on_platform != null \
			and not p.on_platform.get("is_ground", false):
			p.passthrough_platform = p.on_platform
			p.passthrough_timer = 10
			p.grounded = false
			p.vy = 1
		_handle_char_input(p, keys)

static func _handle_char_input(p: Fighter, keys: Dictionary):
	CharacterFactory.handle_input(p.char_id, p, keys)
