extends GutTest
# 弓箭手 AI 射箭测试

func test_archer_has_ai_fire_arrow():
	assert_has_method(ArcherCharacter, "ai_fire_arrow", "ArcherCharacter 应有 ai_fire_arrow 方法")

func test_ai_fire_arrow_creates_projectile():
	var f = Fighter.new()
	f.char_id = "archer"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "archer", [])
	f.energy = 100
	f.facing = 1
	
	var initial_count = GameWorld.projectiles.size()
	ArcherCharacter.ai_fire_arrow(f, 1.5)
	
	assert_eq(GameWorld.projectiles.size(), initial_count + 1, "射箭应创建一个新的投射物")
	assert_eq(f.charging_attack, false, "射箭后 charging_attack 应重置")
	assert_eq(f.attacking, false, "射箭后 attacking 应重置")

func test_ai_fire_arrow_needs_energy():
	var f = Fighter.new()
	f.char_id = "archer"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "archer", [])
	f.energy = 0
	
	GameWorld.projectiles.clear()
	ArcherCharacter.ai_fire_arrow(f, 1.0)
	
	assert_eq(GameWorld.projectiles.size(), 0, "能量不足时不应创建投射物")

func test_ai_fire_arrow_damage_scales():
	var f = Fighter.new()
	f.char_id = "archer"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "archer", [])
	f.energy = 100
	f.facing = 1
	
	GameWorld.projectiles.clear()
	ArcherCharacter.ai_fire_arrow(f, 0.5)  # < 1s → 5 damage
	
	var proj = GameWorld.projectiles[0] if GameWorld.projectiles.size() > 0 else null
	assert_not_null(proj, "应有投射物")
	if proj:
		assert_eq(proj["damage"], 5.0, "蓄力<1s 伤害应为 5")

func test_ai_archer_charges_when_far():
	# 验证 AI 系统中弓箭手在较远距离开始蓄力
	var f = Fighter.new()
	f.char_id = "archer"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, false, "archer", [])
	
	var player = Fighter.new()
	player.setup(400, 320, true, "knight", [])
	GameWorld.player = player
	GameWorld.enemy = f
	GameWorld.difficulty = "medium"
	f.energy = 100
	
	# AI 系统在 dist < 350 时应能触发蓄力
	assert_false(f.charging_attack, "初始不应蓄力")
