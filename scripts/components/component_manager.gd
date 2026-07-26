class_name ComponentManager

var components: Dictionary = {}
var owner: Fighter = null

func init(owner: Fighter):
	self.owner = owner
	_setup_components()

func _setup_components():
	var char_id = owner.char_id
	match char_id:
		"archer":
			var comp = ArcherComponent.new()
			comp.init(owner)
			components["archer"] = comp
		"paladin":
			var comp = PaladinComponent.new()
			comp.init(owner)
			components["paladin"] = comp
		"witch":
			var comp = WitchComponent.new()
			comp.init(owner)
			components["witch"] = comp
		"assassin":
			var comp = AssassinComponent.new()
			comp.init(owner)
			components["assassin"] = comp
		"shadowwarrior":
			var comp = ShadowwarriorComponent.new()
			comp.init(owner)
			components["shadowwarrior"] = comp
		"evoker":
			var comp = EvokerComponent.new()
			comp.init(owner)
			components["evoker"] = comp
		"rose":
			var comp = RoseComponent.new()
			comp.init(owner)
			components["rose"] = comp

func update():
	for comp in components.values():
		comp.update()

func on_damage_received(attacker: Fighter, dmg: float):
	for comp in components.values():
		comp.on_damage_received(attacker, dmg)

func on_attack_hit(target: Fighter, dmg: float):
	for comp in components.values():
		comp.on_attack_hit(target, dmg)

func get(component_name: String) -> CharComponent:
	return components.get(component_name)

func has(component_name: String) -> bool:
	return components.has(component_name)