extends CanvasLayer

const BTN_SIZE := Vector2(82, 70)
const BTN_SIZE_SMALL := Vector2(78, 60)
const FONT_SIZE := 20
const FONT_SIZE_BIG := 24

const PANEL_COLOR := Color(0.08, 0.08, 0.14, 0.45)
const BTN_COLOR := Color(0.15, 0.15, 0.24, 0.6)
const BTN_COLOR_PRESSED := Color(0.4, 0.4, 0.6, 0.75)
const BTN_BORDER := Color(0.5, 0.5, 0.75, 0.5)
const FONT_COLOR := Color(0.88, 0.88, 0.96, 0.9)

var _game_node: Node = null

func _ready():
	if not _is_mobile():
		hide()
		return
	_game_node = get_parent()
	_create_panels()
	_create_buttons()

func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")

# ── semi-transparent background panels ──────────────────────────

func _create_panels():
	# Left panel ─ D-pad area
	var left_panel := ColorRect.new()
	left_panel.color = PANEL_COLOR
	left_panel.position = Vector2(4, 276)
	left_panel.size = Vector2(260, 170)
	add_child(left_panel)

	# Right panel ─ action buttons area
	var right_panel := ColorRect.new()
	right_panel.color = PANEL_COLOR
	right_panel.position = Vector2(540, 272)
	right_panel.size = Vector2(270, 174)
	add_child(right_panel)

# ── buttons ─────────────────────────────────────────────────────

func _create_buttons():
	# Left side ─ D-pad (horizontal only)
	_create_btn("←", "left",  Vector2(12,  350), BTN_SIZE)
	_create_btn("→", "right", Vector2(164, 350), BTN_SIZE)

	# Right side ─ vertical + action buttons
	_create_btn("↑",   "up",      Vector2(710, 284), BTN_SIZE_SMALL)
	_create_btn("↓",   "down",    Vector2(710, 352), BTN_SIZE_SMALL)
	_create_btn("技1", "skill1",  Vector2(546, 284), BTN_SIZE_SMALL)
	_create_btn("技2", "skill2",  Vector2(628, 284), BTN_SIZE_SMALL)
	_create_btn("攻击", "attack", Vector2(548, 352), BTN_SIZE)
	_create_btn("大招", "ult",    Vector2(630, 352), BTN_SIZE)

func _create_btn(text: String, key_name: String, pos: Vector2, size: Vector2):
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.flat = true
	btn.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	btn.expand_icon = true

	# Style ─ normal
	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_COLOR
	normal.set_corner_radius_all(14)
	normal.border_width_left = 2
	normal.border_width_right = 2
	normal.border_width_top = 2
	normal.border_width_bottom = 2
	normal.border_color = BTN_BORDER
	btn.add_theme_stylebox_override("normal", normal)

	# Style ─ pressed
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = BTN_COLOR_PRESSED
	pressed.set_corner_radius_all(14)
	pressed.border_width_left = 2
	pressed.border_width_right = 2
	pressed.border_width_top = 2
	pressed.border_width_bottom = 2
	pressed.border_color = Color(0.75, 0.75, 0.95, 0.7)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Style ─ hover
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.25, 0.25, 0.4, 0.65)
	hover.set_corner_radius_all(14)
	hover.border_width_left = 2
	hover.border_width_right = 2
	hover.border_width_top = 2
	hover.border_width_bottom = 2
	hover.border_color = Color(0.6, 0.6, 0.85, 0.6)
	btn.add_theme_stylebox_override("hover", hover)

	# Font
	var font_sz = FONT_SIZE_BIG if key_name == "attack" or key_name == "ult" else FONT_SIZE
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", FONT_COLOR)

	# ── Critical: connect button_down, button_up AND mouse_exited ──
	# mouse_exited prevents stuck-key when finger slides off button
	btn.button_down.connect(func(): _set_key(key_name, true))
	btn.button_up.connect(func(): _set_key(key_name, false))
	btn.mouse_exited.connect(func(): _set_key(key_name, false))

	add_child(btn)

# ── direct key manipulation ─────────────────────────────────────

func _set_key(key_name: String, pressed: bool):
	if _game_node:
		_game_node.keys[key_name] = pressed
