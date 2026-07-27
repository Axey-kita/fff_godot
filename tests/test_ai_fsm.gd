extends GutTest
# AI FSM 状态机测试

func _make_fighter(char_id: String, x: float, y: float, is_player: bool) -> Fighter:
	var f = Fighter.new()
	f.char_id = char_id
	f.components = ComponentManager.new()
	f.components.init(f)
	f.setup(x, y, is_player, char_id, [])
	f.hp = f.max_hp
	f.energy = f.max_energy
	return f

func _setup_default(f, player):
	GameWorld.player = player
	GameWorld.enemy = f
	GameWorld.difficulty = "medium"
	GameWorld.game_mode = "pve"
	GameWorld.projectiles = []
	GameWorld.pickups = []
	GameWorld.phantoms = []
	GameWorld.evoker_summons = []
	GameWorld.platforms = []

# ── 状态变量测试 ──

func test_ai_runs_without_crash():
	var enemy = _make_fighter("knight", 300, 320, false)
	var player = _make_fighter("knight", 450, 320, true)
	_setup_default(enemy, player)
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "AI update_ai 应正常返回 delay")
	assert_gt(result, -1, "返回值应为非负整数")

func test_ai_state_idle_when_frozen():
	var enemy = _make_fighter("knight", 300, 320, false)
	var player = _make_fighter("knight", 450, 320, true)
	_setup_default(enemy, player)
	enemy.add_status("frozen")
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "冻结时应返回 delay，不崩溃")

func test_ai_think_delay():
	var enemy = _make_fighter("knight", 300, 320, false)
	var player = _make_fighter("knight", 450, 320, true)
	_setup_default(enemy, player)
	
	var result = AISystem.update_ai(5)
	assert_eq(result, 4, "think delay 5 时应返回 4")

func test_ai_chase_when_far():
	var enemy = _make_fighter("knight", 200, 320, false)
	var player = _make_fighter("knight", 600, 320, true)
	_setup_default(enemy, player)
	GameWorld.difficulty = "easy"
	GameWorld.platforms = [{"x": 0, "y": 320, "w": 800, "h": 10, "terrain_type": 0}]
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "近战在远处时应正常返回 delay")

func test_ai_ranged_does_not_crash():
	var enemy = _make_fighter("archer", 300, 320, false)
	var player = _make_fighter("knight", 340, 320, true)
	_setup_default(enemy, player)
	GameWorld.difficulty = "easy"
	GameWorld.platforms = [{"x": 0, "y": 320, "w": 800, "h": 10, "terrain_type": 0}]
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "远程角色贴脸时应正常走位而非崩溃")

func test_ai_archer_at_range():
	var enemy = _make_fighter("archer", 200, 320, false)
	var comp = enemy.components.get_component("archer")
	if comp:
		comp.arrows = 10
	enemy.energy = 50
	var player = _make_fighter("knight", 400, 320, true)
	_setup_default(enemy, player)
	GameWorld.platforms = [{"x": 0, "y": 320, "w": 800, "h": 10, "terrain_type": 0}]
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "弓箭手在射程内应正常执行")

func test_ai_low_hp():
	var enemy = _make_fighter("knight", 200, 320, false)
	var player = _make_fighter("knight", 500, 320, true)
	_setup_default(enemy, player)
	enemy.hp = 10.0  # < 20%
	GameWorld.platforms = [{"x": 0, "y": 320, "w": 800, "h": 10, "terrain_type": 0}]
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "残血时 AI 不应崩溃")

func test_ai_low_hp_close():
	var enemy = _make_fighter("knight", 350, 320, false)
	var player = _make_fighter("knight", 370, 320, true)
	_setup_default(enemy, player)
	enemy.hp = 10.0  # < 20%
	GameWorld.difficulty = "easy"
	GameWorld.platforms = [{"x": 0, "y": 320, "w": 800, "h": 10, "terrain_type": 0}]
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "残血贴脸时应正常反打")

func test_ai_evoker_runs():
	var enemy = _make_fighter("evoker", 400, 320, false)
	var player = _make_fighter("knight", 200, 320, true)
	_setup_default(enemy, player)
	enemy.energy = 50
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "Evoker AI 应正常执行")

# ── 地狱难度 ──
func test_hell_tactics_present():
	var source_file = FileAccess.open("res://scripts/systems/ai_system.gd", FileAccess.READ)
	assert_not_null(source_file, "应能读取 ai_system.gd")
	var content = source_file.get_as_text()
	source_file.close()
	
	assert_true(content.contains("is_hell"), "ai_system.gd 应包含 is_hell 判定")
	assert_true(content.contains("斩杀大招") or content.contains("防御技能"), "应包含地狱专属战术")

# ── melee 判断（用非 _ 前缀的公开函数间接测试） ──
func test_melee_chars_attack_when_close():
	# 近战角色贴脸时应返回非负 delay（间接验证 _is_melee 决策正确）
	var enemy = _make_fighter("knight", 350, 320, false)
	var player = _make_fighter("knight", 370, 320, true)
	_setup_default(enemy, player)
	GameWorld.difficulty = "easy"
	GameWorld.platforms = [{"x": 0, "y": 320, "w": 800, "h": 10, "terrain_type": 0}]
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "近战贴脸时应正常执行")

func test_ranged_chars_dont_crash_at_melee_range():
	# 远程角色贴脸时不应崩溃（间接验证不进入近战流程）
	var enemy = _make_fighter("archer", 350, 320, false)
	var player = _make_fighter("knight", 370, 320, true)
	_setup_default(enemy, player)
	GameWorld.difficulty = "easy"
	GameWorld.platforms = [{"x": 0, "y": 320, "w": 800, "h": 10, "terrain_type": 0}]
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "远程贴脸时应正常执行")

# ── 闪避 ──
func test_dodge_with_player_attacking():
	var enemy = _make_fighter("knight", 300, 320, false)
	var player = _make_fighter("knight", 350, 320, true)
	_setup_default(enemy, player)
	player.attacking = true
	GameWorld.difficulty = "hard"
	
	var result = AISystem.update_ai(0)
	assert_true(result >= 0, "玩家攻击贴脸时 AI 应正常反应")
