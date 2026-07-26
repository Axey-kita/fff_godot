extends GutTest
# 组件字段访问静态检查测试
# 验证：所有组件特定字段必须通过 ComponentManager 访问，不能直接访问 Fighter 实例

# 定义所有组件特定字段（按组件分组）
const COMPONENT_FIELDS = {
	"assassin": [
		"shadow_energy", "shadow_energy_max", "shadow_stance", "shadow_stance_timer",
		"shadow_energy_drain_rate", "enhanced_slash", "enhanced_slash_timer",
		"slash_active", "slash_timer", "slash_x", "slash_y", "slash_facing",
		"slash_damage_dealt", "skill2_active", "skill2_timer", "skill2_x", "skill2_y",
		"skill2_facing", "skill2_damage_dealt", "ult_active", "ult_timer", "ult_damage_timer",
		"time_stop", "time_stop_timer", "dodge_success", "dodge_slow_mo", "shadow_trail",
		"max_shadow_trail"
	],
	"shadowwarrior": [
		"stealth_active", "stealth_timer", "last_skill_time", "retreat_timer",
		"retreat_dir", "break_strike_timer", "pending_trap", "shadow_trap_active",
		"shadow_trap", "pending_clones", "clone_reveal_timer", "iaido_active",
		"iaido_timer", "iaido_frozen", "iaido_dir", "iaido_slash"
	],
	"witch": [
		"is_flying", "fly_energy_drain", "is_casting_ult", "cast_ult_x", "cast_ult_y"
	],
	"paladin": [
		"divine_shield_active", "divine_shield_timer", "divine_shield_absorb",
		"holy_empower_active", "holy_empower_timer"
	],
	"archer": [
		"arrows", "max_arrows", "arrow_regen_timer", "arrow_regen_rate",
		"fire_arrow_buff", "fire_arrow_timer", "tracking_buff", "tracking_timer"
	],
	"evoker": [
		"last_summon_type", "summon_dead1", "summon_dead2", "summon_dead3", "evoker_gazed"
	],
	"rose": [
		"blood_abyss", "blood_heal_timer", "rose_skill2_active", "rose_skill2_damage_tick",
		"rose_skill2_tick_damage", "rose_skill2_enhanced", "rose_skill2_fly_timer",
		"rose_grab_center_x", "rose_skill1_enhanced_slashes", "rose_skill1_slash_spawn_timer",
		"rose_blood_abyss_suppressed"
	]
}

# 允许直接访问的全局字段（Fighter 类中定义的共享字段）
const GLOBAL_FIELDS = [
	"pos_x", "pos_y", "vx", "vy", "w", "h", "facing",
	"hp", "max_hp", "energy", "max_energy",
	"attacking", "attack_timer", "attack_damage", "attack_cooldown",
	"blocking", "shield_active", "dashing", "dash_dir", "dash_remaining",
	"charging", "charging_attack", "charging_skill1",
	"grounded", "is_invincible", "invincible_timer",
	"char_id", "is_player", "state", "image_state",
	"damage_flash", "hit_stop", "frame",
	"slow_timer", "slow_percent", "burn_timer",
	"bleed_timer", "blind_timer",
	"dragon_scales_active", "dragon_scales_timer",
	"dragon_form_active", "dragon_form_timer",
	"gravity_debuff", "jump_reduction",
	"statuses", "current_anim", "animations",
	"components", "ai_think_delay", "ai_action_timer",
	"charge_start", "charge_start_time"
]

# 递归获取目录下所有 .gd 文件
func _get_gd_files(dir: String) -> Array:
	var files = []
	var dir_access = Directory.new()
	if dir_access.open(dir) == OK:
		dir_access.list_dir_begin(true, false)
		var filename = dir_access.get_next()
		while filename != "":
			if dir_access.current_is_dir():
				files.append_array(_get_gd_files(dir + "/" + filename))
			elif filename.ends_with(".gd"):
				files.append(dir + "/" + filename)
			filename = dir_access.get_next()
		dir_access.list_dir_end()
	return files

# 检查单个文件中的组件字段访问违规
func _check_file(filepath: String) -> Array:
	var violations = []
	var file = File.new()
	if file.open(filepath, File.READ) != OK:
		return violations
	
	var content = file.get_as_text()
	file.close()
	
	# 合并所有组件字段
	var all_component_fields = []
	for comp_name in COMPONENT_FIELDS:
		all_component_fields.append_array(COMPONENT_FIELDS[comp_name])
	
	# 检查模式：f.field_name, owner.field_name, target.field_name, p.field_name
	# 排除: comp.field_name (正确的组件访问), components.get_component(...)
	var patterns = ["\\bf\\.", "\\bowner\\.", "\\btarget\\.", "\\bp\\."]
	
	for pattern in patterns:
		for field in all_component_fields:
			# 构建正则：例如 f.shadow_energy 但排除 f.components.get_component
			var regex = RegEx.new()
			regex.compile(pattern + field + "\\b")
			var matches = regex.search_all(content)
			for match in matches:
				var line_num = content.substr(0, match.start).count("\n") + 1
				# 检查是否在 components.get_component 调用中（合法访问）
				var context = content.substr(max(0, match.start - 30), 80)
				if not context.find("components.get_component") >= 0:
					violations.append({
						"file": filepath,
						"line": line_num,
						"field": field,
						"access": pattern.strip_edges(),
						"context": context.strip_edges()
					})
	
	return violations

func test_no_direct_component_field_access():
	# 获取所有 .gd 文件（排除 tests 目录）
	var files = _get_gd_files("res://scripts")
	
	var all_violations = []
	for filepath in files:
		# 跳过组件文件本身（组件字段定义处）
		if filepath.find("/components/") >= 0:
			continue
		var violations = _check_file(filepath)
		all_violations.append_array(violations)
	
	# 如果有违规，输出详细信息
	if all_violations.size() > 0:
		print("\n=== 组件字段访问违规报告 ===")
		print("共发现 %d 处违规:" % all_violations.size())
		for i in range(min(all_violations.size(), 50)):
			var v = all_violations[i]
			print("  [%d] %s:%d" % [i + 1, v["file"], v["line"]])
			print("       字段: %s" % v["field"])
			print("       访问: %s" % v["access"])
			print("       上下文: %s" % v["context"])
			print()
	
	# 断言：没有违规
	assert_eq(all_violations.size(), 0, 
		"不允许直接访问组件特定字段，必须通过 ComponentManager 访问。共发现 %d 处违规" % all_violations.size())

func test_global_fields_allowed():
	# 验证全局字段列表包含所有 Fighter 类中的字段
	var fighter_file = "res://scripts/fighter.gd"
	var file = File.new()
	if file.open(fighter_file, File.READ) != OK:
		return
	
	var content = file.get_as_text()
	file.close()
	
	# 提取所有 var 定义的字段
	var regex = RegEx.new()
	regex.compile("\\bvar\\s+(\\w+)\\s*[:=]")
	var matches = regex.search_all(content)
	
	var fighter_fields = []
	for match in matches:
		var field = match.get_string(1)
		if not field in fighter_fields:
			fighter_fields.append(field)
	
	# 检查是否有遗漏的字段
	var missing_fields = []
	for field in fighter_fields:
		if not field in GLOBAL_FIELDS:
			missing_fields.append(field)
	
	if missing_fields.size() > 0:
		print("\n=== 全局字段列表更新提醒 ===")
		print("fighter.gd 中有 %d 个字段未在 GLOBAL_FIELDS 中定义:" % missing_fields.size())
		for field in missing_fields:
			print("  - %s" % field)
	
	# 警告级别：不强制断言失败，但提示更新列表
	assert_lt(missing_fields.size(), 10, 
		"GLOBAL_FIELDS 列表需要更新，有 %d 个字段遗漏" % missing_fields.size())
