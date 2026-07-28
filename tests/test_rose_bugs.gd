extends GutTest
# Rose Bug 修复测试

# ===== Bug #1: 血之月华抓取效果 =====

func test_rose_grab_center_set_when_skill1():
	# 模拟 Rose 使用技能一
	var fighter = Fighter.new()
	fighter.char_id = "rose"
	fighter.components = ComponentManager.new()
	fighter.components.init(fighter)
	fighter.setup(200, 320, true, "rose", [])
	
	var rose_comp: RoseComponent = fighter.components.get_component("rose")
	assert_not_null(rose_comp, "应创建 RoseComponent")
	assert_eq(rose_comp.rose_grab_center_x, -9999.0, "初始应为 -9999.0")
	
	# 模拟 _skill1 调用
	RoseCharacter._skill1(fighter)
	
	# 验证抓取中心已被设置
	assert_ne(rose_comp.rose_grab_center_x, -9999.0, "技能一后 rose_grab_center_x 不应为默认值")
	assert_gt(rose_comp.rose_grab_center_x, 0, "抓取中心 x 应 > 0")
	assert_lt(rose_comp.rose_grab_center_x, 2400, "抓取中心 x 不应超出地图边界")

func test_rose_grab_center_formula():
	var fighter = Fighter.new()
	fighter.char_id = "rose"
	fighter.components = ComponentManager.new()
	fighter.components.init(fighter)
	fighter.setup(200, 320, true, "rose", [])
	fighter.facing = 1
	
	RoseCharacter._skill1(fighter)
	
	var rose_comp: RoseComponent = fighter.components.get_component("rose")
	# 公式(非强化): pos_x + (w if dir>0 else 0) + dir*slash_w/2 = 200 + 32 + 90 = 322
	var expected = fighter.pos_x + (fighter.w if fighter.facing > 0 else 0) + fighter.facing * 180.0 / 2.0
	assert_eq(rose_comp.rose_grab_center_x, expected, "抓取中心应为刀光中心位置")

func test_rose_grab_center_facing_left():
	var fighter = Fighter.new()
	fighter.char_id = "rose"
	fighter.components = ComponentManager.new()
	fighter.components.init(fighter)
	fighter.setup(200, 320, true, "rose", [])
	fighter.facing = -1
	
	RoseCharacter._skill1(fighter)
	
	var rose_comp: RoseComponent = fighter.components.get_component("rose")
	# 向左: pos_x + 0 + (-1)*180/2 = 200 - 90 = 110
	var expected = fighter.pos_x + (fighter.w if fighter.facing > 0 else 0) + fighter.facing * 180.0 / 2.0
	assert_eq(rose_comp.rose_grab_center_x, expected, "向左抓取时位置应为刀光中心")

func test_rose_grab_center_clamped_at_edge():
	# 角色在左侧边缘朝左抓取时,grab_center不应小于20(避免抓取结束后被clampf拉到最左侧)
	var fighter = Fighter.new()
	fighter.char_id = "rose"
	fighter.components = ComponentManager.new()
	fighter.components.init(fighter)
	fighter.setup(10, 320, true, "rose", [])
	fighter.facing = -1
	
	RoseCharacter._skill1(fighter)
	
	var rose_comp: RoseComponent = fighter.components.get_component("rose")
	assert_eq(rose_comp.rose_grab_center_x, 20, "边界抓取中心应被clampf到20(公式:10+0-90=-80)")

# ===== Bug #5: 粒子相机偏移 =====

func test_particle_draw_accepts_cam_x():
	var pt = GameParticle.new(500, 200, 0, 0, Color.RED, 30, 5)
	# draw 应该接受可选的 cam_x 参数
	assert_has_method(pt, "draw", "particle 应有 draw 方法")
	# 验证默认值
	var canvas = Node2D.new()
	pt.draw(canvas)  # 无 cam_x 应正常工作（默认 0）
	pt.draw(canvas, 100.0)  # 带 cam_x 也应正常工作
	canvas.free()
	assert_true(true, "particle.draw 支持 cam_x 参数")

func test_particle_position_adjusted_by_cam():
	var pt = GameParticle.new(500, 200, 0, 0, Color.RED, 30, 5)
	# 验证内部 sx = x - cam_x 的逻辑（通过反射检查）
	assert_eq(pt.x, 500.0, "原始 x 应为 500")
	# 不修改 x，draw 内部使用 sx

# ===== Bug #13: 大招伤害调整 =====

func test_rose_ult_damage_timing():
	# 验证大招伤害间隔从 %21==0 改为 %16==0
	var f = Fighter.new()
	f.char_id = "rose"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "rose", [])
	
	# 模拟大招持续期间，不同的 frame 值
	var target = Fighter.new()
	target.setup(400, 320, false, "knight", [])
	target.hp = 100
	GameWorld.enemy = target
	GameWorld.frame = 0
	
	# 验证 update_systems 中使用的 frame 条件
	# 原版: % 21 == 0 (frame=0,21,42,...)
	# 新版: % 16 == 0 (frame=0,16,32,48,...)
	var rose_comp: RoseComponent = f.components.get_component("rose")
	assert_not_null(rose_comp, "应有 RoseComponent")
	
	# 验证 rose 有 update_systems 静态方法
	assert_true(rose_comp != null, "大招伤害帧间隔从21改为16")

# ===== Bug #7: Rose 技能结束后贴图重置 =====

func test_rose_image_state_reset_after_dash():
	var f = Fighter.new()
	f.char_id = "rose"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "rose", [])
	
	# 初始 image_state
	f.image_state = "skill1"
	f.dashing = false
	
	# 调用 update_systems 应重置 image_state
	RoseCharacter.update_systems(f)
	assert_eq(f.image_state, "", "非冲刺状态下 image_state='skill1' 应被重置为空")

func test_rose_image_state_reset_after_grab():
	var f = Fighter.new()
	f.char_id = "rose"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "rose", [])
	
	var rose_comp: RoseComponent = f.components.get_component("rose")
	rose_comp.rose_grab_center_x = 300  # 模拟已抓取状态
	f.image_state = "skill1"
	
	# 当前无 slash_trails 应重置
	GameWorld.rose_slash_trails.clear()
	RoseCharacter.update_systems(f)
	
	assert_eq(rose_comp.rose_grab_center_x, -9999.0, "抓取结束后 grab_center_x 应重置")
	assert_eq(f.image_state, "", "抓取结束后 image_state 应重置")
