class_name ComponentManager

# Component preloads for type resolution
const CharComponent = preload("res://scripts/components/char_component.gd")
const ArcherComponent = preload("res://scripts/components/archer_component.gd")
const PaladinComponent = preload("res://scripts/components/paladin_component.gd")
const WitchComponent = preload("res://scripts/components/witch_component.gd")
const AssassinComponent = preload("res://scripts/components/assassin_component.gd")
const ShadowwarriorComponent = preload("res://scripts/components/shadowwarrior_component.gd")
const EvokerComponent = preload("res://scripts/components/evoker_component.gd")
const RoseComponent = preload("res://scripts/components/rose_component.gd")

var components: Dictionary = {}
var owner: Fighter = null

func init(owner: Fighter):
	self.owner = owner
	_setup_components()

func _setup_components():
	var comp = CharacterFactory.create_component(owner.char_id, owner)
	if comp:
		components[owner.char_id] = comp

func update():
	for comp in components.values():
		comp.update()

func on_damage_received(attacker: Fighter, dmg: float):
	for comp in components.values():
		comp.on_damage_received(attacker, dmg)

func on_attack_hit(target: Fighter, dmg: float):
	for comp in components.values():
		comp.on_attack_hit(target, dmg)

func get_component(key: Variant, default: Variant = null) -> Variant:
	return components.get(key, default)

func has_component(key: Variant) -> bool:
	return components.has(key)

func size() -> int:
	return components.size()

func keys() -> Array:
	return components.keys()

func values() -> Array:
	return components.values()