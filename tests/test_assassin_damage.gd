extends GutTest
# 刺客伤害与无敌状态自动化测试
# 验证修复：刺客「一瞬」无敌状态结束后能正常受到伤害
# 修复点：fighter.gd apply_physics 中递减 invincible_timer，归零时复位 is_invincible

var _attacker: Fighter
var _target: Fighter

func before_each():
	# 准备最小化的 Fighter 实例（不依赖场景与动画资源）
	_attacker = Fighter.new()
	_attacker.char_id = "knight"
	_attacker.is_player = true
	_attacker.pos_x = 100
	_attacker.pos_y = 320
	_attacker.facing = 1
	_attacker.hp = 100
	_attacker.max_hp = 100
	_attacker.w = 32
	_attacker.h = 56

	_target = Fighter.new()
	_target.char_id = "assassin"
	_target.is_player = false
	_target.pos_x = 140
	_target.pos_y = 320
	_target.facing = -1
	_target.hp = 90
	_target.max_hp = 90
	_target.w = 32
	_target.h = 56

	# 初始化 GameWorld 必要状态
	GameWorld.platforms = []
	GameWorld.particles = []
	GameWorld.player = _attacker
	GameWorld.enemy = _target
	GameWorld.game_running = true
	GameWorld.game_over = false

func after_each():
	GameWorld.platforms = []
	GameWorld.particles = []
	GameWorld.player = null
	GameWorld.enemy = null
	GameWorld.game_running = false
	GameWorld.game_over = false

# ===== apply_damage 在无敌期间应免疫伤害 =====

func test_apply_damage_blocked_when_invincible():
	# 模拟刺客「一瞬」技能生效期间
	_target.is_invincible = true
	_target.invincible_timer = 20
	var hp_before = _target.hp
	Fighter.apply_damage(_target, 10, _attacker)
	assert_eq(_target.hp, hp_before, "无敌期间目标不应受到伤害")
	assert_true(_target.is_invincible, "无敌期间 is_invincible 应保持为 true")

func test_apply_damage_works_when_not_invincible():
	# 普通状态下应正常受伤
	_target.is_invincible = false
	_target.invincible_timer = 0
	var hp_before = _target.hp
	Fighter.apply_damage(_target, 10, _attacker)
	assert_lt(_target.hp, hp_before, "非无敌状态目标应受到伤害")

# ===== apply_physics 应递减 invincible_timer 并复位 is_invincible =====

func test_apply_physics_decrements_invincible_timer():
	_target.is_invincible = true
	_target.invincible_timer = 5
	_target.grounded = true
	# 调用一次 apply_physics
	_target.apply_physics()
	assert_eq(_target.invincible_timer, 4, "apply_physics 后 invincible_timer 应递减 1")
	assert_true(_target.is_invincible, "timer 未归零时 is_invincible 应保持 true")

func test_apply_physics_resets_is_invincible_when_timer_zero():
	_target.is_invincible = true
	_target.invincible_timer = 1
	_target.grounded = true
	_target.apply_physics()
	assert_eq(_target.invincible_timer, 0, "invincible_timer 应归零")
	assert_false(_target.is_invincible, "timer 归零后 is_invincible 应复位为 false")

func test_apply_physics_resets_after_multiple_calls():
	# 模拟连续多帧调用 apply_physics 直到无敌结束
	_target.is_invincible = true
	_target.invincible_timer = 3
	_target.grounded = true
	for i in range(3):
		_target.apply_physics()
	assert_eq(_target.invincible_timer, 0, "3 帧后 invincible_timer 应归零")
	assert_false(_target.is_invincible, "3 帧后 is_invincible 应复位")

# ===== 刺客「一瞬」技能应正确设置无敌状态 =====

func test_assassin_skill1_sets_invincible():
	# 验证刺客一瞬技能会设置 is_invincible 和 invincible_timer
	var skills = AssassinCharacter.create_skills()
	var skill1 = null
	for s in skills:
		if s.key == "skill1":
			skill1 = s
			break
	assert_not_null(skill1, "应能找到 skill1（一瞬）")
	# 准备刺客 owner
	_target.energy = 30
	_target.facing = 1
	_target.grounded = true
	_target.attacking = false
	_target.dashing = false
	_target.ult_active = false
	var result = skill1.try_use(_target)
	assert_true(result.get("success", false), "skill1 应能成功释放")
	assert_true(_target.is_invincible, "skill1 释放后 is_invincible 应为 true")
	assert_eq(_target.invincible_timer, 20, "skill1 释放后 invincible_timer 应为 20")

# ===== 综合场景：无敌结束后能受到伤害 =====

func test_assassin_takes_damage_after_invincibility_expires():
	# 完整流程：触发一瞬 → 多帧 apply_physics → 无敌结束 → 受到伤害
	_target.is_invincible = true
	_target.invincible_timer = 3
	_target.grounded = true
	# 模拟 3 帧
	for i in range(3):
		_target.apply_physics()
	# 此时无敌应已结束
	assert_false(_target.is_invincible, "3 帧后无敌应结束")
	# 现在应能受到伤害
	var hp_before = _target.hp
	Fighter.apply_damage(_target, 15, _attacker)
	assert_lt(_target.hp, hp_before, "无敌结束后目标应能受到伤害")

# ===== 裂空斩（skill2）为飞行物，life=240（4 秒）持续飞行 =====

func test_assassin_skill2_life_is_240():
	# 验证裂空斩 life=240（4 秒）持续飞行
	GameWorld.projectiles.clear()
	_target.energy = 30
	_target.facing = 1
	_target.grounded = true
	_target.attacking = false
	_target.dashing = false
	_target.ult_active = false
	var skills = AssassinCharacter.create_skills()
	var skill2 = null
	for s in skills:
		if s.key == "skill2":
			skill2 = s
			break
	assert_not_null(skill2, "应能找到 skill2（裂空斩）")
	var result = skill2.try_use(_target)
	assert_true(result.get("success", false), "skill2 应能成功释放")
	assert_eq(GameWorld.projectiles.size(), 1, "应生成 1 个投射物")
	var proj = GameWorld.projectiles[0]
	assert_eq(proj["life"], 240, "裂空斩 life 应为 240（4 秒持续飞行）")
	assert_eq(proj["damage"], 15, "裂空斩伤害应为 15（与描述一致）")
	assert_true(proj["piercing"], "裂空斩应为穿透性")
	GameWorld.projectiles.clear()

# ===== 强化次元斩：伤害提升至 8 点，命中恢复 5 能量 =====

func test_enhanced_slash_deals_8_damage_and_restores_energy():
	# 准备刺客为攻击者，骑士为目标
	_attacker.char_id = "assassin"
	_attacker.facing = 1
	_attacker.pos_x = 100
	_attacker.w = 32
	_attacker.h = 56
	_attacker.energy = 30
	_attacker.max_energy = 100
	_attacker.enhanced_slash = true
	_attacker.enhanced_slash_timer = 30
	_attacker.attack_damage = 5  # 基础攻击力
	# 强化次元斩斩击出现在身后：slash_x = 100 - 40 + 16 - 50 = 26，范围 [26, 126]
	# 目标放在身后（pos_x=50，hit_box=[54, 78]），与斩击框相交
	_target.char_id = "knight"
	_target.pos_x = 50  # 在刺客身后，处于强化斩击范围内
	_target.w = 32
	_target.h = 56
	_target.facing = -1
	_target.hp = 100
	_target.max_hp = 100
	# 触发攻击（强化状态）
	AssassinCharacter._attack(_attacker)
	assert_true(_attacker.attacking, "攻击应已启动")
	assert_true(_attacker.enhanced_slash, "强化状态在攻击启动时应保留（等待命中判定）")
	# 推进 attack_delay（8 帧）使命中判定触发
	for i in range(8):
		_attacker.apply_physics()
	# 命中后：伤害应为 8 点（不是基础 5 点），允许浮点误差
	assert_almost_eq(_target.hp, 92.0, 0.01, "强化次元斩应造成 8 点伤害（100-8=92）")
	# 命中后应恢复 5 能量（加上 8 帧自然恢复约 0.66，允许误差 ±1.0）
	assert_almost_eq(_attacker.energy, 35.0, 1.0, "强化次元斩命中应恢复 5 能量")
	# 命中后强化状态应重置
	assert_false(_attacker.enhanced_slash, "命中后 enhanced_slash 应重置为 false")
	assert_eq(_attacker.enhanced_slash_timer, 0, "命中后 enhanced_slash_timer 应归零")

func test_normal_slash_deals_5_damage():
	# 非强化状态下应造成基础 5 点伤害
	_attacker.char_id = "assassin"
	_attacker.facing = 1
	_attacker.pos_x = 100
	_attacker.w = 32
	_attacker.h = 56
	_attacker.energy = 30
	_attacker.max_energy = 100
	_attacker.enhanced_slash = false
	_attacker.enhanced_slash_timer = 0
	_attacker.attack_damage = 5
	# 普通次元斩斩击在前方：slash_x = 100 + 32 + 10 = 142，范围 [142, 242]
	# 目标放在前方（pos_x=150，hit_box=[154, 178]），与斩击框相交
	_target.char_id = "knight"
	_target.pos_x = 150  # 在刺客前方，处于普通斩击范围内
	_target.w = 32
	_target.h = 56
	_target.facing = -1
	_target.hp = 100
	_target.max_hp = 100
	AssassinCharacter._attack(_attacker)
	for i in range(8):
		_attacker.apply_physics()
	assert_almost_eq(_target.hp, 95.0, 0.01, "普通次元斩应造成 5 点伤害（100-5=95）")

# ===== enhanced_slash_timer 应递减，超时后强化状态失效 =====

func test_enhanced_slash_timer_decrements():
	_target.enhanced_slash = true
	_target.enhanced_slash_timer = 5
	_target.grounded = true
	_target.apply_physics()
	assert_eq(_target.enhanced_slash_timer, 4, "apply_physics 后 enhanced_slash_timer 应递减 1")
	assert_true(_target.enhanced_slash, "timer 未归零时 enhanced_slash 应保持 true")

func test_enhanced_slash_resets_when_timer_expires():
	# 30 帧后强化状态应失效
	_target.enhanced_slash = true
	_target.enhanced_slash_timer = 3
	_target.grounded = true
	for i in range(3):
		_target.apply_physics()
	assert_eq(_target.enhanced_slash_timer, 0, "3 帧后 enhanced_slash_timer 应归零")
	assert_false(_target.enhanced_slash, "timer 归零后 enhanced_slash 应复位为 false")

# ===== 闪避慢动作计时器递减 =====

func test_dodge_slow_mo_decrements():
	_target.dodge_slow_mo = 10
	_target.grounded = true
	_target.apply_physics()
	assert_eq(_target.dodge_slow_mo, 9, "apply_physics 后 dodge_slow_mo 应递减 1")

func test_dodge_slow_mo_reaches_zero():
	_target.dodge_slow_mo = 3
	_target.grounded = true
	for i in range(5):  # 多递减几帧确保归零
		_target.apply_physics()
	assert_eq(_target.dodge_slow_mo, 0, "5 帧后 dodge_slow_mo 应归零（不会变负）")

# ===== 冲刺中释放普攻应能命中（使用 slash_x 固定位置） =====

func test_attack_during_dash_hits_target():
	# 模拟冲刺中释放普攻：刺客在 pos_x=100 启动攻击，然后冲刺移动到 pos_x=200
	# 命中判定应使用 slash_x（启动时固定），而非 pos_x（冲刺中偏移）
	_attacker.char_id = "assassin"
	_attacker.facing = 1
	_attacker.pos_x = 100
	_attacker.w = 32
	_attacker.h = 56
	_attacker.energy = 30
	_attacker.max_energy = 100
	_attacker.enhanced_slash = false
	_attacker.enhanced_slash_timer = 0
	_attacker.attack_damage = 5
	# 目标在刺客启动攻击时的前方
	_target.char_id = "knight"
	_target.pos_x = 150  # 在 slash_x=142 范围内
	_target.w = 32
	_target.h = 56
	_target.facing = -1
	_target.hp = 100
	_target.max_hp = 100
	# 启动攻击
	AssassinCharacter._attack(_attacker)
	# 模拟冲刺：每帧 pos_x 增加 5（dash_speed=5），共 8 帧
	# 8 帧后 pos_x = 100 + 40 = 140，如果用 pos_x 计算攻击框会错过目标
	for i in range(8):
		_attacker.pos_x += 5  # 模拟冲刺移动
		_attacker.apply_physics()
	# 命中应成功（因为使用 slash_x=142，目标在 150）
	assert_almost_eq(_target.hp, 95.0, 0.01, "冲刺中释放普攻应使用 slash_x 命中目标")

# ===== 闪避触发暗影能量积攒 =====

func test_dodge_accumulates_shadow_energy():
	# 模拟刺客闪避：冲刺+无敌时被投射物命中应积攒暗影能量
	_target.char_id = "assassin"
	_target.dashing = true
	_target.is_invincible = true
	_target.dodge_success = false
	_target.shadow_energy = 0
	_target.shadow_energy_max = 5
	_target.shadow_stance = false
	_target.hp = 100
	_target.pos_x = 100
	_target.w = 32
	_target.h = 56
	# 创建一个投射物，位置与刺客重叠
	_attacker.char_id = "knight"
	_attacker.pos_x = 50
	GameWorld.projectiles.clear()
	GameWorld.projectiles.append({
		"x": 100, "y": _target.pos_y, "w": 40, "h": 40,
		"vx": 0, "vy": 0, "life": 60, "damage": 10,
		"owner": _attacker, "type": "test_proj",
		"piercing": false, "hitTargets": []
	})
	ProjectileSystem.update_projectiles(null)
	# 闪避应触发
	assert_true(_target.dodge_success, "闪避应触发 dodge_success=true")
	assert_eq(_target.dodge_slow_mo, 30, "闪避应设置 dodge_slow_mo=30")
	assert_eq(_target.shadow_energy, 1, "闪避应积攒 1 格暗影能量")
	assert_false(_target.shadow_stance, "1 格能量不应触发暗影游走")
	GameWorld.projectiles.clear()

func test_dodge_full_energy_triggers_shadow_stance():
	# 4 格能量时再闪避一次，应满格触发暗影游走
	_target.char_id = "assassin"
	_target.dashing = true
	_target.is_invincible = true
	_target.dodge_success = false
	_target.shadow_energy = 4
	_target.shadow_energy_max = 5
	_target.shadow_stance = false
	_target.hp = 100
	_target.pos_x = 100
	_target.w = 32
	_target.h = 56
	_attacker.char_id = "knight"
	_attacker.pos_x = 50
	GameWorld.projectiles.clear()
	GameWorld.projectiles.append({
		"x": 100, "y": _target.pos_y, "w": 40, "h": 40,
		"vx": 0, "vy": 0, "life": 60, "damage": 10,
		"owner": _attacker, "type": "test_proj",
		"piercing": false, "hitTargets": []
	})
	ProjectileSystem.update_projectiles(null)
	assert_eq(_target.shadow_energy, 5, "闪避后应满 5 格能量")
	assert_true(_target.shadow_stance, "满格应触发暗影游走状态")
	assert_eq(_target.shadow_stance_timer, 480, "暗影游走持续 480 帧（8 秒）")
	GameWorld.projectiles.clear()

func test_shadow_stance_drains_energy_and_expires():
	# 暗影游走期间每帧消耗能量，能量耗尽后退出
	_target.char_id = "assassin"
	_target.shadow_stance = true
	_target.shadow_stance_timer = 480
	_target.shadow_energy = 0.5  # 很少能量
	_target.shadow_energy_max = 5
	_target.shadow_energy_drain_rate = 5.0 / 480.0
	_target.grounded = true
	_target.vx = 0
	# 推进几帧，能量应耗尽
	for i in range(60):
		_target.apply_physics()
	assert_false(_target.shadow_stance, "能量耗尽后暗影游走应退出")
	assert_eq(_target.shadow_energy, 0, "能量应归零")
	assert_eq(_target.shadow_stance_timer, 0, "timer 应归零")

func test_shadow_stance_leaves_trail_when_moving():
	# 暗影游走状态移动时应留下残影
	_target.char_id = "assassin"
	_target.shadow_stance = true
	_target.shadow_stance_timer = 480
	_target.shadow_energy = 5
	_target.shadow_energy_max = 5
	_target.shadow_energy_drain_rate = 5.0 / 480.0
	_target.shadow_trail.clear()
	_target.grounded = true
	_target.vx = 3  # 移动中
	_target.facing = 1
	_target.apply_physics()
	assert_gt(_target.shadow_trail.size(), 0, "移动中应留下残影")

# ===== 闪避期间完全免疫伤害和状态效果 =====

func test_dodge_completely_immune_to_damage():
	# 冲刺+无敌期间被投射物命中，应完全免疫伤害
	_target.char_id = "assassin"
	_target.dashing = true
	_target.is_invincible = true
	_target.dodge_success = false
	_target.shadow_energy = 0
	_target.shadow_energy_max = 5
	_target.shadow_stance = false
	_target.hp = 100
	_target.max_hp = 100
	_target.pos_x = 100
	_target.pos_y = 320
	_target.w = 32
	_target.h = 56
	_attacker.char_id = "knight"
	_attacker.pos_x = 50
	GameWorld.projectiles.clear()
	GameWorld.projectiles.append({
		"x": 100, "y": _target.pos_y, "w": 40, "h": 40,
		"vx": 0, "vy": 0, "life": 60, "damage": 50,
		"owner": _attacker, "type": "test_proj",
		"piercing": false, "hitTargets": [],
		"burn": true, "slow": true  # 带状态效果
	})
	ProjectileSystem.update_projectiles(null)
	# HP 应完全不变
	assert_eq(_target.hp, 100, "闪避期间应完全免疫伤害，HP 不变")
	# 不应被附加 burn/slow 状态
	assert_false(_target.has_status("burn"), "闪避期间应免疫 burn 状态")
	assert_false(_target.has_status("slow"), "闪避期间应免疫 slow 状态")
	GameWorld.projectiles.clear()

func test_dodge_does_not_consume_projectile():
	# 闪避时非穿透性投射物不应被消耗（应继续飞行）
	_target.char_id = "assassin"
	_target.dashing = true
	_target.is_invincible = true
	_target.dodge_success = false
	_target.shadow_energy = 0
	_target.shadow_energy_max = 5
	_target.shadow_stance = false
	_target.hp = 100
	_target.pos_x = 100
	_target.pos_y = 320
	_target.w = 32
	_target.h = 56
	_attacker.char_id = "knight"
	_attacker.pos_x = 50
	GameWorld.projectiles.clear()
	GameWorld.projectiles.append({
		"x": 100, "y": _target.pos_y, "w": 40, "h": 40,
		"vx": 5, "vy": 0, "life": 60, "damage": 10,
		"owner": _attacker, "type": "test_proj",
		"piercing": false, "hitTargets": []
	})
	ProjectileSystem.update_projectiles(null)
	# 投射物不应被移除（闪避不消耗投射物）
	assert_eq(GameWorld.projectiles.size(), 1, "闪避不应消耗投射物，应继续飞行")
	GameWorld.projectiles.clear()
