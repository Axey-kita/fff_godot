extends CanvasLayer

const FONT_SIZE := 20
const FONT_SIZE_BIG := 24
const FONT_SIZE_SMALL_F := 15

const BTN_COLOR := Color(0.15, 0.15, 0.24, 0.6)
const BTN_COLOR_PRESSED := Color(0.4, 0.4, 0.6, 0.75)
const BTN_BORDER := Color(0.5, 0.5, 0.75, 0.5)
const FONT_COLOR := Color(0.92, 0.92, 0.97, 0.7)
const FONT_COLOR_STRONG := Color(0.95, 0.95, 0.98, 0.75)
const TALENT_COLOR := Color(0.25, 0.15, 0.05, 0.6)
const TALENT_COLOR_PRESSED := Color(0.6, 0.35, 0.1, 0.75)
const TALENT_BORDER := Color(0.8, 0.5, 0.15, 0.5)

# ── scene-defined Button children (drag to reposition in editor) ──
@onready var left_panel: ColorRect = $LeftPanel
@onready var right_panel: ColorRect = $RightPanel

@onready var btn_left: Button = $BtnLeft
@onready var btn_right: Button = $BtnRight
@onready var btn_up: Button = $BtnUp
@onready var btn_down: Button = $BtnDown
@onready var btn_skill1: Button = $BtnSkill1
@onready var btn_skill2: Button = $BtnSkill2
@onready var btn_attack: Button = $BtnAttack
@onready var btn_ult: Button = $BtnUlt
@onready var btn_talent1: Button = $BtnTalent1
@onready var btn_talent2: Button = $BtnTalent2
@onready var btn_talent3: Button = $BtnTalent3

var _game_node: Node = null
var _button_map: Dictionary = {}  # key_name → Button
var _talent_buttons: Array[Button] = []

func _ready():
	if not _is_mobile():
		hide()
		return
	_game_node = get_parent()
	_style_all()
	_connect_signals()
	# 天赋按钮默认隐藏，运行时由 update_talent_visibility 控制
	for b in _talent_buttons:
		b.hide()

func _is_mobile() -> bool:
	return OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("mobile")

# ── styling ─────────────────────────────────────────────────────

func _style_all():
	# Normal buttons
	var normal_map := {
		"left": [btn_left, FONT_SIZE_BIG, false],
		"right": [btn_right, FONT_SIZE_BIG, false],
		"up": [btn_up, FONT_SIZE, false],
		"down": [btn_down, FONT_SIZE, false],
		"skill1": [btn_skill1, FONT_SIZE, false],
		"skill2": [btn_skill2, FONT_SIZE, false],
		"attack": [btn_attack, FONT_SIZE_BIG, false],
		"ult": [btn_ult, FONT_SIZE_BIG, false],
		"talent1": [btn_talent1, FONT_SIZE_SMALL_F, true],
		"talent2": [btn_talent2, FONT_SIZE_SMALL_F, true],
		"talent3": [btn_talent3, FONT_SIZE_SMALL_F, true],
	}
	for key_name in normal_map:
		var entry = normal_map[key_name]
		var btn: Button = entry[0]
		var font_sz: int = entry[1]
		var is_talent: bool = entry[2]
		_style_btn(btn, font_sz, is_talent)
		_button_map[key_name] = btn

	_talent_buttons = [btn_talent1, btn_talent2, btn_talent3]

func _style_btn(btn: Button, font_sz: int, is_talent: bool):
	# Normal
	var normal := StyleBoxFlat.new()
	normal.bg_color = TALENT_COLOR if is_talent else BTN_COLOR
	normal.set_corner_radius_all(14)
	normal.border_width_left = 2; normal.border_width_right = 2
	normal.border_width_top = 2; normal.border_width_bottom = 2
	normal.border_color = TALENT_BORDER if is_talent else BTN_BORDER
	btn.add_theme_stylebox_override("normal", normal)

	# Pressed
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = TALENT_COLOR_PRESSED if is_talent else BTN_COLOR_PRESSED
	pressed.set_corner_radius_all(14)
	pressed.border_width_left = 2; pressed.border_width_right = 2
	pressed.border_width_top = 2; pressed.border_width_bottom = 2
	pressed.border_color = Color(0.9, 0.6, 0.2, 0.7) if is_talent else Color(0.75, 0.75, 0.95, 0.7)
	btn.add_theme_stylebox_override("pressed", pressed)

	# Hover
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.4, 0.25, 0.1, 0.65) if is_talent else Color(0.25, 0.25, 0.4, 0.65)
	hover.set_corner_radius_all(14)
	hover.border_width_left = 2; hover.border_width_right = 2
	hover.border_width_top = 2; hover.border_width_bottom = 2
	hover.border_color = Color(0.9, 0.55, 0.2, 0.6) if is_talent else Color(0.6, 0.6, 0.85, 0.6)
	btn.add_theme_stylebox_override("hover", hover)

	# Font — bold weight, pale color
	var sys_font := SystemFont.new()
	sys_font.font_weight = 700
	sys_font.font_names = PackedStringArray(["Noto Sans SC", "Arial", "sans-serif"])
	btn.add_theme_font_override("font", sys_font)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_color_override("font_color", FONT_COLOR_STRONG if font_sz >= FONT_SIZE_BIG else FONT_COLOR)

# ── signal connections ──────────────────────────────────────────

func _connect_signals():
	for key_name in _button_map:
		var btn: Button = _button_map[key_name]
		btn.button_down.connect(func(): _set_key(key_name, true))
		btn.button_up.connect(func(): _set_key(key_name, false))
		btn.mouse_exited.connect(func(): _set_key(key_name, false))

# ── direct key manipulation ─────────────────────────────────────

func _set_key(key_name: String, pressed: bool):
	if _game_node:
		_game_node.keys[key_name] = pressed

# ── talent button visibility ────────────────────────────────────

func update_talent_visibility():
	var p = GameWorld.player
	if not is_instance_valid(p) or not p.talent_manager:
		for b in _talent_buttons:
			b.hide()
		return
	for i in range(_talent_buttons.size()):
		if i < p.talent_slots.size():
			var t = p.talent_slots[i]
			_talent_buttons[i].text = t.talent_name
			_talent_buttons[i].show()
		else:
			_talent_buttons[i].hide()
