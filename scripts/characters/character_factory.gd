class_name CharacterFactory

const Knight = preload("res://scripts/characters/knight.gd")
const Mage = preload("res://scripts/characters/mage.gd")
const Archer = preload("res://scripts/characters/archer.gd")
const Paladin = preload("res://scripts/characters/paladin.gd")
const Witch = preload("res://scripts/characters/witch.gd")
const Assassin = preload("res://scripts/characters/assassin.gd")
const Shadowwarrior = preload("res://scripts/characters/shadowwarrior.gd")
const Evoker = preload("res://scripts/characters/evoker.gd")
const Rose = preload("res://scripts/characters/rose.gd")
const DragonKnight = preload("res://scripts/characters/dragon_knight.gd")

# Component preloads
const COMP_ARCHER = preload("res://scripts/components/archer_component.gd")
const COMP_PALADIN = preload("res://scripts/components/paladin_component.gd")
const COMP_WITCH = preload("res://scripts/components/witch_component.gd")
const COMP_ASSASSIN = preload("res://scripts/components/assassin_component.gd")
const COMP_SHADOWWARRIOR = preload("res://scripts/components/shadowwarrior_component.gd")
const COMP_EVOKER = preload("res://scripts/components/evoker_component.gd")
const COMP_ROSE = preload("res://scripts/components/rose_component.gd")
const COMP_KNIGHT = preload("res://scripts/components/char_component.gd")  # fallback: no special component
const COMP_MAGE = preload("res://scripts/components/char_component.gd")    # fallback
const COMP_DRAGON_KNIGHT = preload("res://scripts/components/char_component.gd")  # fallback

static var _char_registry := {
	"knight": { "cls": Knight, "config": null, "comp": COMP_KNIGHT },
	"mage": { "cls": Mage, "config": null, "comp": COMP_MAGE },
	"archer": { "cls": Archer, "config": null, "comp": COMP_ARCHER },
	"paladin": { "cls": Paladin, "config": null, "comp": COMP_PALADIN },
	"witch": { "cls": Witch, "config": null, "comp": COMP_WITCH },
	"assassin": { "cls": Assassin, "config": null, "comp": COMP_ASSASSIN },
	"shadowwarrior": { "cls": Shadowwarrior, "config": null, "comp": COMP_SHADOWWARRIOR },
	"evoker": { "cls": Evoker, "config": null, "comp": COMP_EVOKER },
	"rose": { "cls": Rose, "config": null, "comp": COMP_ROSE },
	"dragon_knight": { "cls": DragonKnight, "config": null, "comp": COMP_DRAGON_KNIGHT },
}

static func get_config(char_id: String) -> Dictionary:
	var entry = _char_registry.get(char_id, {})
	if entry.is_empty():
		printerr("[CharacterFactory] get_config: unknown char_id=", char_id)
		return {}
	if entry.get("config") == null:
		print("[CharacterFactory] calling get_config() for: ", char_id)
		entry["config"] = entry["cls"].get_config()
		print("[CharacterFactory] get_config() returned for: ", char_id, " empty=", entry["config"].is_empty())
	return entry["config"]

static func create_skills(char_id: String) -> Array:
	var entry = _char_registry.get(char_id, {})
	if entry.is_empty():
		return []
	return entry["cls"].create_skills()

## 调度角色输入处理（替代 InputHandler 中的 match char_id）
static func handle_input(char_id: String, fighter: Fighter, keys: Dictionary) -> int:
	var entry = _char_registry.get(char_id, {})
	var cls = entry.get("cls")
	if cls and cls.has_method("handle_input"):
		return cls.handle_input(fighter, keys)
	return 0

## 调度角色专属系统更新（替代 CharacterSystems 中的硬编码函数）
static func update_char_systems(fighter: Fighter):
	var entry = _char_registry.get(fighter.char_id, {})
	var cls = entry.get("cls")
	if cls and cls.has_method("update_systems"):
		cls.update_systems(fighter)

## 调用 rose 的刀光拖尾更新（跨实体逻辑）
static func call_rose_trails():
	var entry = _char_registry.get("rose", {})
	var cls = entry.get("cls")
	if cls and cls.has_method("update_rose_trails"):
		cls.update_rose_trails()

## 创建角色组件（替代 ComponentManager 中的 match char_id）
static func create_component(char_id: String, owner: Fighter) -> CharComponent:
	var entry = _char_registry.get(char_id, {})
	var comp_cls = entry.get("comp")
	if comp_cls:
		var comp = comp_cls.new()
		comp.init(owner)
		return comp
	return null
