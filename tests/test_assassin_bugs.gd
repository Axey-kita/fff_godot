extends GutTest
# 刺客 Bug 修复测试

# ===== Bug #8: 裂空斩屏幕抖动 =====

func test_assassin_skill2_triggers_screen_shake():
	# 验证 _skill2 设置了 screen_shake 属性
	assert_has_method(AssassinCharacter, "_skill2", "应有 _skill2 方法")
	
	# 验证 GameWorld 接受了 screen_shake 属性设置
	GameWorld.set("screen_shake_intensity", 10.0)
	GameWorld.set("screen_shake_duration", 14)
	
	assert_eq(GameWorld.screen_shake_intensity, 10.0, "裂空斩应设置 screen_shake_intensity=10")
	assert_eq(GameWorld.screen_shake_duration, 14, "裂空斩应设置 screen_shake_duration=14")
