class_name InputHandler

const PROJ_LIGHT_IMG = preload("res://assets/fx_lightning_projectile.png")

# ===== Player Input =====
static func update_player_input(world, keys: Dictionary):
	var p = world.player
	if p.hp > 0 and not p.has_status("frozen"):
		_handle_char_input(p, keys)

static func _handle_char_input(p: Fighter, keys: Dictionary):
	match p.char_id:
		"knight": CharacterFactory.handle_input("knight", p, keys)
		"mage": CharacterFactory.handle_input("mage", p, keys)
		"archer": CharacterFactory.handle_input("archer", p, keys)
		"paladin": CharacterFactory.handle_input("paladin", p, keys)
		"witch": CharacterFactory.handle_input("witch", p, keys)
		"assassin": CharacterFactory.handle_input("assassin", p, keys)
		"shadowwarrior": CharacterFactory.handle_input("shadowwarrior", p, keys)
		"evoker": CharacterFactory.handle_input("evoker", p, keys)
		"rose": CharacterFactory.handle_input("rose", p, keys)
