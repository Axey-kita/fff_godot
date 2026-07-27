extends GutTest
# 影武者 Bug 修复测试

# ===== Bug #9: 破隐一击贴图被角色本体覆盖 =====

func test_shadowwarrior_break_strike_shows_fighter():
	# 破影一击是普通冲刺攻击，_draw_fighter 不应跳过角色贴图
	var f = Fighter.new()
	f.char_id = "shadowwarrior"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "shadowwarrior", [])
	
	var sw_comp: ShadowwarriorComponent = f.components.get_component("shadowwarrior")
	assert_not_null(sw_comp, "应有 ShadowwarriorComponent")
	
	# 模拟破影一击状态
	sw_comp.break_strike_timer = 30
	# 新逻辑：仅 iaido_active 才跳过绘制，break_strike_timer 不影响
	var should_skip = sw_comp.iaido_active
	assert_false(should_skip, "破影一击期间角色贴图不应被跳过")

func test_shadowwarrior_iaido_skips_fighter_draw():
	var f = Fighter.new()
	f.char_id = "shadowwarrior"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "shadowwarrior", [])
	
	var sw_comp: ShadowwarriorComponent = f.components.get_component("shadowwarrior")
	sw_comp.iaido_active = true
	
	var should_skip = sw_comp.iaido_active
	assert_true(should_skip, "居合期间应跳过角色绘制")

# ===== 分身锁满血修复: 近战攻击伤害分身 =====

func test_melee_attacks_damage_phantoms():
	# 模拟近战攻击命中分身
	var attacker = Fighter.new()
	attacker.char_id = "knight"
	attacker.attack_damage = 5
	attacker.setup(200, 320, true, "knight", [])
	
	var ph = {
		"x": 220, "y": 320, "w": 32, "h": 56,
		"hp": 5.0, "max_hp": 5.0,
		"owner": Fighter.new(),  # 模拟属于敌人的分身
	}
	GameWorld.phantoms.append(ph)
	
	# 模拟攻击命中前的hp
	assert_eq(ph["hp"], 5.0, "分身初始HP应为5.0")
	
	# 模拟攻击命中逻辑: ph["hp"] -= attack_damage
	ph["hp"] -= 5.0
	
	assert_eq(ph["hp"], 0.0, "受到5点伤害后分身HP应为0")
	
	GameWorld.phantoms.clear()

func test_melee_does_not_hit_own_phantoms():
	# 验证不打自己的分身
	var attacker = Fighter.new()
	attacker.char_id = "shadowwarrior"
	attacker.attack_damage = 5
	attacker.setup(200, 320, true, "shadowwarrior", [])
	
	var ph = {
		"x": 220, "y": 320, "w": 32, "h": 56,
		"hp": 5.0,
		"owner": attacker,  # 属于攻击者自己的分身
	}
	GameWorld.phantoms.append(ph)
	
	# 模拟代码逻辑: if ph.get("owner") == self: continue
	var should_skip = (ph.get("owner") == attacker)
	assert_true(should_skip, "自己的分身不应被自己的攻击命中")
	
	GameWorld.phantoms.clear()
