# 唤魔者 (evoker)
class_name EvokerCharacter

const PROJ_FIREBALL = preload("res://assets/fire.png")

static func get_config() -> Dictionary:
	return {
		"id": "evoker", "name": "唤魔者", "hp": 60, "max_energy": 140, "energy_regen": 0.083,
		"speed": 2.25, "attack_range": 44, "attack_damage": 4,
		"attack_cooldown": 0, "attack_delay": 8, "attack_duration": 68,
		"fields": {"last_summon_type":-1,"summon_dead1":false,"summon_dead2":false,"summon_dead3":false},
		"world_arrays": ["evoker_summons","void_rifts","evoker_fire_seas","gravity_balls","phantoms"],
		"images": {
			"idle": load("res://assets/evkid.png"),
			"walk": load("res://assets/evkid.png"),
			"jump": load("res://assets/evkid.png"),
			"attack": load("res://assets/evkid.png"),
			"ult": load("res://assets/evkid.png"),
		},
		"dex": {
			"icon": "🧙",
			"intro": "与深渊签订契约的唤魔者，操纵三种召唤物进行战斗。",
			"stats": [
				{"label": "生命", "value": "60"},
				{"label": "能量上限", "value": "140"},
				{"label": "能量恢复", "value": "5/秒"},
			],
			"skills": [
				{
					"name": "契约（特殊机制）",
					"desc": "与深渊签订契约，可操纵三种召唤物，场上最多同时存在 1 个。\n· 寂语之喉（1 号）：血量 60。\n· 哀恸枷锁（2 号）：血量 40。\n· 诅咒之眼（3 号）：血量 80。\n召唤物上场时以 3 点/秒缓慢恢复血量；除「随行」状态外可被敌人直接攻击，血量耗尽后死亡且无法再次召唤。\n唤魔者的普攻与技能2 会随当前召唤物而改变。\n\n召唤物被动：\n· 噤声（1 号）：当敌人与唤魔者处于 1 号的同一侧时，敌人造成的伤害减少 20%。\n· 摄魂（2 号）：处于 2 号附近的敌人能量以 5 点/秒的速度流失。\n· 凝视（3 号）：处于 3 号附近的敌人，技能1、技能2 的冷却时间增加 1 秒。",
					"meta": "被动 ｜ 召唤物上场回血 3/秒"
				},
				{
					"name": "冥炎弹 / 役使·随行 / 役使·猎杀（普攻）",
					"desc": "无召唤物 → 冥炎弹：抛出以抛物线飞行的冥炎弹，命中造成 4 伤害，附加减速 20%（持续 6 秒）与灼烧（每 2 秒 1 点，持续 6 秒）。消耗 10，冷却 2 秒。\n\n召唤物处于猎杀状态 → 役使·随行：召回召唤物回到身边并一同移动（移动速度与玩家一致），回归途中对沿途敌人造成 5 撞击伤害；随行期间唤魔者受到伤害的 60% 由召唤物承受。消耗 20，冷却 2 秒。\n\n召唤物处于随行状态 → 役使·猎杀：召唤物释放一次重击后进入猎杀状态（缓慢靠近敌人但不主动攻击）。消耗 20，冷却 3 秒。\n\n召唤物重击：\n· 1 号：以自身为中心释放蓝紫色空心圆冲击波，强力击飞周围敌人，伤害 10。\n· 2 号：向前突进用镰刀斩击敌人，伤害 10。\n· 3 号：发射一枚缓慢飞行的引力球，持续吸附敌人并造成 3 点/秒伤害。",
					"meta": "消耗 10~20 ｜ 冷却 2~3 秒"
				},
				{
					"name": "深渊召令（技能一）",
					"desc": "随机召唤一个召唤物生成在身前，默认为「随行」状态；若场上已有召唤物则将其替换。\n连续两次召唤的召唤物不会重复，已死亡的召唤物不能被召唤。",
					"meta": "消耗 20 ｜ 冷却 5 秒"
				},
				{
					"name": "幽蓝之境 / 魔令（技能二）",
					"desc": "无召唤物 → 幽蓝之境：在脚下生成大范围火海（持续 4 秒），持续灼烧范围内敌人（5 点/秒）并造成 40% 减速。消耗 20，冷却 13 秒。\n\n有召唤物 → 魔令：命令召唤物释放技能。消耗 20，冷却 13 秒。\n· 1 号：释放大范围水平冲击波，命中眩晕敌人 2 秒（无法进行任何操作），伤害 15。\n· 2 号：大范围挥镰斩击，命中造成流血（释放时受到 3 伤害）并持续 5 秒，伤害 15。\n· 3 号：向前突进撞击，命中剥夺敌人视力，失明 3 秒，伤害 20。",
					"meta": "消耗 20 ｜ 冷却 13 秒"
				},
				{
					"name": "虚空裂隙（大招）",
					"desc": "献祭场上的召唤物，召唤物立刻死亡，其剩余血量转移到唤魔者身上。\n召唤物死亡处出现虚空裂隙，持续 4 秒，吸附并对范围内敌人造成 10 点/秒的大量伤害。",
					"meta": "消耗 100 ｜ 冷却 60 秒"
				},
			]
		},
	}

static func create_skills() -> Array:
	return [
		Skill.new("attack", "冥炎弹", 0, 0, func(owner: Fighter): return owner.attack_cooldown <= 0 and not owner.attacking and owner.energy >= 10, Callable(_attack)),
		Skill.new("skill1", "深渊召令", 300, 20, func(owner: Fighter): return owner.energy >= 20, Callable(_skill1)),
		Skill.new("skill2", "幽蓝之境", 780, 20, func(owner: Fighter): return owner.energy >= 20, Callable(_skill2)),
		Skill.new("ult", "虚空裂隙", 3600, 100, func(owner: Fighter): return owner.energy >= 100, Callable(_ult)),
	]

static func _attack(owner: Fighter) -> Dictionary:
	owner.energy -= 10
	owner.attack_cooldown = 120
	owner.attacking = true
	owner.attack_timer = 30
	var vx2 = 5.0 * owner.facing
	GameWorld.projectiles.append({"x":owner.pos_x+(30 if owner.facing>0 else -30),"y":owner.pos_y+20,"w":24,"h":24,"vx":vx2,"vy":-2.5,"life":90,"damage":4,"owner":owner,"type":"evoker_fireball","color":Color(1.0,0.53,0.0),"reflected":false,"gravity":0.15,"img":PROJ_FIREBALL})
	return {"success": true}

static func _skill1(owner: Fighter) -> Dictionary:
	var available = []
	for i in 3:
		if not owner.get("summon_dead" + str(i + 1)) and i != owner.last_summon_type:
			available.append(i)
	if available.is_empty():
		# If only the last type is available, allow re-summoning it
		for i in 3:
			if not owner.get("summon_dead" + str(i + 1)):
				available.append(i)
				break
	if available.is_empty():
		return {"success": false}
	var type_id = available[randi() % available.size()]
	var spawn_x = owner.pos_x + (60 if owner.facing > 0 else -60)
	var spawn_y = owner.pos_y + 10
	GameWorld.evoker_summons.append({"type":type_id,"owner":owner,"hp":float([60,40,80][type_id]),"max_hp":float([60,40,80][type_id]),"state":"随行","x":spawn_x,"y":spawn_y,"w":40,"h":40,"vx":0.0,"vy":0.0})
	owner.last_summon_type = type_id
	return {"success": true}

static func _skill2(owner: Fighter) -> Dictionary:
	GameWorld.evoker_fire_seas.append({"x":owner.pos_x-100,"y":owner.pos_y-40,"w":200,"h":80,"timer":0,"duration":240,"owner":owner})
	return {"success": true}

static func _ult(owner: Fighter) -> Dictionary:
	return {"success": true}
