# 天赋数值配置
class_name TalentConfigs

static var data := {
	"vitality": {
		"hp_mult": 1.2,
		"max_stack": 3,
		"stack_add": 0.2,
	},
	"thorns": {
		"reflect_dmg": 3.0,
		"reflect_per_stack": 1.5,
	},
	"blaze_rush": {
		"dash_damage": 10,
		"cooldown": 300,
	},
	"vampiric": {
		"heal_pct": 0.1,
		"heal_per_stack": 0.05,
	},
}

static func get(id: String) -> Dictionary:
	return data.get(id, {})
