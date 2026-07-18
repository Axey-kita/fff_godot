extends Control

@onready var char_select = $CharSelect
@onready var grid = $CharSelect/Grid
@onready var start_button = $CharSelect/StartButton
@onready var pve_button = $VBox/PVEButton
@onready var pvp_button = $VBox/PVPButton
@onready var vbox = $VBox

var selected_char := "knight"
var chars_initialized := false

func _ready():
	print("[MainMenu] _ready() start")
	_init_char_configs()
	print("[MainMenu] configs initialized, setting up UI...")
	pve_button.pressed.connect(_on_pve_pressed)
	pvp_button.pressed.connect(_on_pvp_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_populate_characters()

func _init_char_configs():
	if chars_initialized:
		return
	CharConfigs.ensure_init()
	chars_initialized = true

func _populate_characters():
	# Clear existing children
	for child in grid.get_children():
		child.queue_free()
	# Create buttons for each character
	var char_ids = ["knight","mage","archer","paladin","witch","assassin","shadowwarrior","evoker"]
	var char_names = ["骑士","法师","弓箭手","圣骑士","魔女","刺客","影武者","唤魔者"]
	var bg = ButtonGroup.new()
	for i in char_ids.size():
		var btn = Button.new()
		btn.text = char_names[i]
		btn.custom_minimum_size = Vector2(90, 36)
		btn.toggle_mode = true
		btn.button_group = bg
		btn.pressed.connect(_on_char_selected.bind(char_ids[i]))
		grid.add_child(btn)
	# Select first by default
	if grid.get_child_count() > 0:
		grid.get_child(0).button_pressed = true

func _on_pve_pressed():
	GameWorld.game_mode = "pve"
	vbox.visible = false
	char_select.visible = true

func _on_pvp_pressed():
	GameWorld.game_mode = "pvp"
	vbox.visible = false
	char_select.visible = true

func _on_char_selected(char_id: String):
	selected_char = char_id
	GameWorld.selected_char_id = char_id

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")
