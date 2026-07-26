class_name CharComponent

var owner: Fighter = null

func init(owner: Fighter):
	self.owner = owner

func update():
	pass

func on_damage_received(attacker: Fighter, dmg: float):
	pass

func on_attack_hit(target: Fighter, dmg: float):
	pass