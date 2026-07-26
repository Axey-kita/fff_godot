class_name Constants

# Map dimensions
const W := 800
const H := 450
const MAP_W := 2400
const GROUND_Y := 380

# Physics
const GRAVITY := 0.22
const JUMP_SPEED := -10.0
const FRICTION := 0.88

# Fighter size
const FIGHTER_W := 32
const FIGHTER_H := 56

# AI difficulty presets
const AI_PRESETS := {
	"easy": {"react": 600, "aggro": 0.3, "dodge": 0.1, "skill_rate": 0.15, "move_speed": 0.75, "jump_rate": 0.0},
	"medium": {"react": 350, "aggro": 0.5, "dodge": 0.25, "skill_rate": 0.3, "move_speed": 0.9, "jump_rate": 0.02},
	"hard": {"react": 120, "aggro": 0.8, "dodge": 0.4, "skill_rate": 0.6, "move_speed": 1.1, "jump_rate": 0.05},
	"hell": {"react": 60, "aggro": 0.95, "dodge": 0.6, "skill_rate": 0.9, "move_speed": 1.3, "jump_rate": 0.08},
}

# 难度等级排序（用于比较和"不低于 hard"的判定）
const DIFFICULTY_LEVELS := ["easy", "medium", "hard", "hell"]

# 判断当前难度是否不低于指定难度
static func difficulty_at_least(diff: String, threshold: String) -> bool:
	var di = DIFFICULTY_LEVELS.find(diff)
	var ti = DIFFICULTY_LEVELS.find(threshold)
	if di < 0 or ti < 0:
		return false
	return di >= ti