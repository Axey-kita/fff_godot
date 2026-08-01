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
		"dash_damage": 6,
		"cooldown": 600,
	},
	"vampiric": {
		"heal_pct": 0.1,
		"heal_per_stack": 0.05,
	},
	"void_affinity": {
		"hp_pct": 0.5,
	},
	"phase_blink": {
		"blink_distance": 500,
		"cooldown": 600,
	},
	"regen_rune": {
		"heal_per_sec": 5,
		"duration": 240,
		"heal_boost": 0.1,
		"cooldown": 1800,
	},
	"battle_frenzy": {
		"atk_boost": 0.05,
		"dmg_reduction": 0.1,
		"cd_reduction": 60,
		"knockback_resist": 0.2,
	},
	"last_stand": {
		"hp_threshold": 0.2,
		"invuln_duration": 600,
	},
	"order_reforge": {
		"cd_reduction": 60,
		"cooldown": 2400,
	},
}

static func get_talent(id: String) -> Dictionary:
	return data.get(id, {})
