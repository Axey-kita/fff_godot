extends GutTest
# 圣骑士 Bug 修复测试

# ===== Bug #7: 圣骑士技能结束后贴图不重置 =====

func test_paladin_has_update_systems():
	assert_has_method(PaladinCharacter, "update_systems", "圣骑士应添加 update_systems 方法")

func test_paladin_image_state_reset_after_charge():
	var f = Fighter.new()
	f.char_id = "paladin"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "paladin", [])
	
	# 模拟冲刺和蓄力都已结束，但 image_state 仍为 "charge"
	f.image_state = "charge"
	f.dashing = false
	f.charging_skill1 = false
	
	PaladinCharacter.update_systems(f)
	
	assert_eq(f.image_state, "", "冲刺和蓄力都结束后 charge 贴图应被重置")

func test_paladin_image_state_kept_during_charge():
	var f = Fighter.new()
	f.char_id = "paladin"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "paladin", [])
	
	# 冲刺或蓄力进行中时，不应重置
	f.image_state = "charge"
	f.dashing = true
	f.charging_skill1 = false
	
	PaladinCharacter.update_systems(f)
	
	assert_eq(f.image_state, "charge", "冲刺进行中不应重置 charge 贴图")

func test_paladin_image_state_kept_if_not_charge():
	var f = Fighter.new()
	f.char_id = "paladin"
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(200, 320, true, "paladin", [])
	
	f.image_state = "walk"
	f.dashing = false
	f.charging_skill1 = false
	
	PaladinCharacter.update_systems(f)
	
	assert_eq(f.image_state, "walk", "非 charge 状态不应受影响")
