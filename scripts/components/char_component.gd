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

# 统一 HUD 数据接口：game.gd 遍历组件即可，无需 match char_id
# 返回 Dict，key 为 hud 类型，如 "blood_abyss", "shadow_energy", "arrows"
func get_hud_data() -> Dictionary:
	return {}