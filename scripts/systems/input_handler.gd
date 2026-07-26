class_name InputHandler

const PROJ_LIGHT_IMG = preload("res://assets/fx_lightning_projectile.png")

# ===== Player Input =====
static func update_player_input(world, keys: Dictionary):
	var p = world.player
	if p.hp > 0 and not p.has_status("frozen"):
		_handle_char_input(p, keys)

static func _handle_char_input(p: Fighter, keys: Dictionary):
	CharacterFactory.handle_input(p.char_id, p, keys)
