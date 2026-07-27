extends GutTest

# ── 跳跃曲线可达性测试 ──

func test_reachable_same_platform():
	# 同一平台 → 可达区间覆盖完整跳跃范围
	GameWorld.platforms = [{"x": 0, "y": 380, "w": 400, "h": 10, "terrain_type": 0}]
	var interval = TrackSystem._get_reachable_x_interval(GameWorld.platforms[0], 380, 1.0)
	assert_eq(interval.size(), 2, "Same height → interval should have 2 elements")
	# t_land = 2*9.5/0.22 ≈ 86.36, reach_l = 0 - 1*86.36, reach_r = 400 + 1*86.36
	assert_lt(interval[0], -80, "Left bound should be ~ -86 (jump range)")
	assert_gt(interval[1], 480, "Right bound should be ~ 486 (jump range)")

func test_reachable_horizontal():
	# 同高度平台，在跳跃范围内
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 200, "h": 10, "terrain_type": 0},
		{"x": 300, "y": 380, "w": 200, "h": 10, "terrain_type": 0},
	]
	# 从平台0跳到平台1：间隔100px，move_speed=1.0时 t2≈86.4，reach_r=0+1*86.4=86.4 < 300 → 不可达
	# 但 move_speed=3.0 时 reach_r=0+3*86.4=259.2 < 300，仍不可达
	# 用 move_speed=5.0: reach_r=0+5*86.4=432 > 300 → 可达
	var reachable = TrackSystem._is_platform_reachable(GameWorld.platforms[0], GameWorld.platforms[1], 5.0)
	assert_true(reachable, "High move_speed → should be reachable")

func test_reachable_vertical_up():
	# 可跳上高平台（高度差 < 205px）
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 200, "h": 10, "terrain_type": 0},
		{"x": 50, "y": 250, "w": 100, "h": 10, "terrain_type": 0},
	]
	var reachable = TrackSystem._is_platform_reachable(GameWorld.platforms[0], GameWorld.platforms[1], 3.0)
	assert_true(reachable, "130px height diff → reachable")

func test_reachable_vertical_down():
	# 可跳下低平台（下落）
	GameWorld.platforms = [
		{"x": 0, "y": 250, "w": 200, "h": 10, "terrain_type": 0},
		{"x": 50, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
	]
	var reachable = TrackSystem._is_platform_reachable(GameWorld.platforms[0], GameWorld.platforms[1], 3.0)
	assert_true(reachable, "Lower platform → reachable by falling")

func test_reachable_too_high():
	# 过高不可达（高度差 > 205px）
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 200, "h": 10, "terrain_type": 0},
		{"x": 50, "y": 130, "w": 100, "h": 10, "terrain_type": 0},
	]
	var reachable = TrackSystem._is_platform_reachable(GameWorld.platforms[0], GameWorld.platforms[1], 3.0)
	assert_false(reachable, "250px height diff → unreachable")

func test_reachable_too_far():
	# 过远不可达（跳跃距离不够）
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 50, "h": 10, "terrain_type": 0},
		{"x": 500, "y": 380, "w": 50, "h": 10, "terrain_type": 0},
	]
	# 间隔450px，move_speed=3.0时最远3*86.4=259 < 450
	var reachable = TrackSystem._is_platform_reachable(GameWorld.platforms[0], GameWorld.platforms[1], 3.0)
	assert_false(reachable, "450px gap → unreachable")

func test_reachable_is_on_platform():
	# 测试 _is_on_platform 辅助函数
	var plat = {"x": 100, "y": 200, "w": 300, "h": 10, "terrain_type": 0}
	assert_true(AISystem._is_on_platform(150, 200, plat), "Point inside platform")
	assert_true(AISystem._is_on_platform(100, 200, plat), "Point at left edge")
	assert_true(AISystem._is_on_platform(399, 200, plat), "Point near right edge")
	assert_false(AISystem._is_on_platform(50, 200, plat), "Point left of platform")
	assert_false(AISystem._is_on_platform(450, 200, plat), "Point right of platform")
	assert_false(AISystem._is_on_platform(150, 250, plat), "Point below platform (y diff > 20)")

func test_reachable_get_interval():
	# 测试 _get_reachable_x_interval 返回值
	var plat = {"x": 200, "y": 300, "w": 100, "h": 10, "terrain_type": 0}
	
	# 过高不可达
	var interval = TrackSystem._get_reachable_x_interval(plat, 50, 3.0)  # 250px diff > 205
	assert_eq(interval.size(), 0, "Too high → empty interval")


# ── 有向图 + Dijkstra 路径规划测试 ──

func before_each():
	TrackSystem._adj = []
	TrackSystem._graph_built = false
	TrackSystem._jump_commit = false
	TrackSystem._last_vx = 0
	TrackSystem._last_dir = 0
	TrackSystem._path = []
	TrackSystem._need_think = true

func test_graph_empty_platforms():
	GameWorld.platforms = []
	TrackSystem._build_graph()
	assert_eq(TrackSystem._adj.size(), 0, "Empty platforms → empty graph")

func test_graph_single_platform():
	GameWorld.platforms = [{"x": 0, "y": 380, "w": 400, "h": 10, "terrain_type": 0}]
	TrackSystem._build_graph()
	assert_eq(TrackSystem._adj.size(), 1, "One platform → one node")
	assert_eq(TrackSystem._adj[0].size(), 0, "One platform → no edges")

func test_find_path_same_platform():
	GameWorld.platforms = [{"x": 0, "y": 380, "w": 400, "h": 10, "terrain_type": 0}]
	var p = GameWorld.platforms[0]
	var path = TrackSystem._find_path(p, p)
	assert_eq(path.size(), 1, "Same platform → path of length 1")
	assert_eq(path[0], p, "Same platform → platform matches")

func test_graph_two_reachable():
	# 同高度近距离平台，BUILD_MOVE_SPEED=0.75 下可达
	# t_land≈90.9, reach_r=100+0.75*90.9≈168 > plat1.x+plat1.w 起点 120
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
		{"x": 120, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
	]
	TrackSystem._build_graph()
	var edges0 = TrackSystem._adj[0]
	var edges1 = TrackSystem._adj[1]
	assert_eq(edges0.size(), 1, "plat0→plat1 reachable")
	assert_eq(edges0[0]["to"], 1, "Edge target = plat1")
	assert_gt(edges0[0]["weight"], 0, "Edge weight > 0")
	# 对称：plat1→plat0 也应该可达
	assert_eq(edges1.size(), 1, "plat1→plat0 reachable")
	assert_eq(edges1[0]["to"], 0, "Edge target = plat0")

func test_find_path_two_platforms():
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
		{"x": 120, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
	]
	var path = TrackSystem._find_path(GameWorld.platforms[0], GameWorld.platforms[1])
	assert_eq(path.size(), 2, "Direct reachable → path length 2")
	assert_eq(path[0], GameWorld.platforms[0], "Path start = from_plat")
	assert_eq(path[1], GameWorld.platforms[1], "Path end = to_plat")

func test_find_path_unreachable():
	# 间距过大不可达
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 50, "h": 10, "terrain_type": 0},
		{"x": 500, "y": 380, "w": 50, "h": 10, "terrain_type": 0},
	]
	var path = TrackSystem._find_path(GameWorld.platforms[0], GameWorld.platforms[1])
	assert_eq(path.size(), 0, "Too far → empty path")

func test_find_path_multi_hop():
	# A→B→C 链式可达，A→C 不可达，需要经过 B
	# at BUILD_MOVE_SPEED=2.0: reach_r=100+2*90.9=281.8
	# C must start > 281.8
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
		{"x": 150, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
		{"x": 290, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
	]
	var path = TrackSystem._find_path(GameWorld.platforms[0], GameWorld.platforms[2])
	assert_eq(path.size(), 3, "Three platforms → path length 3")
	assert_eq(path[0], GameWorld.platforms[0], "Path[0] = A")
	assert_eq(path[1], GameWorld.platforms[1], "Path[1] = B")
	assert_eq(path[2], GameWorld.platforms[2], "Path[2] = C")

func test_find_path_directed():
	# 有向性：高平台→低平台可达（下落），低平台→高平台不可达（过高）
	# A(地面,y=380)→B(悬挂,y=150): 230px>205 不可达
	# B→A: 下落 230px，悬挂平台允许下落 → 可达
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},  # plat0: 地面
		{"x": 0, "y": 150, "w": 100, "h": 10, "terrain_type": 0},  # plat1: 悬挂
	]
	# A→B 不可达
	var path_up = TrackSystem._find_path(GameWorld.platforms[0], GameWorld.platforms[1])
	assert_eq(path_up.size(), 0, "Too high to reach → empty path")
	# B→A 可达（下落）
	var path_down = TrackSystem._find_path(GameWorld.platforms[1], GameWorld.platforms[0])
	assert_eq(path_down.size(), 2, "Falling down → reachable")
	assert_eq(path_down[0], GameWorld.platforms[1], "Path start = B")
	assert_eq(path_down[1], GameWorld.platforms[0], "Path end = A")

func test_graph_skip_void_platforms():
	# 虚空平台（terrain_type=3）应跳过
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 3},
		{"x": 0, "y": 250, "w": 100, "h": 10, "terrain_type": 0},
	]
	TrackSystem._build_graph()
	assert_eq(TrackSystem._adj.size(), 2, "Two platforms total")
	assert_eq(TrackSystem._adj[0].size(), 0, "Void platform → no outgoing edges")
	assert_eq(TrackSystem._adj[1].size(), 0, "Only one non-void platform → no edges (no target)")

func test_plat_index():
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
		{"x": 200, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
	]
	assert_eq(AISystem._plat_index(GameWorld.platforms[0]), 0, "First platform index = 0")
	assert_eq(AISystem._plat_index(GameWorld.platforms[1]), 1, "Second platform index = 1")
	# 不存在的平台
	assert_eq(AISystem._plat_index({"x": 999, "y": 999, "w": 1, "h": 1}), -1, "Unknown platform → -1")


# ── 跳跃承诺 + 中间平台测试 ──

## 构造最小 AI 状态，使得 update_ai 能到达 mid-air coasting 检查
func _make_ai(mid_air: bool) -> Fighter:
	var f = Fighter.new()
	f.setup(300, 320, false, "knight", [])
	f.grounded = not mid_air
	f.hit_cooldown = 0
	f.hp = 50
	f.vx = 3.0
	return f

func _make_player() -> Fighter:
	var p = Fighter.new()
	p.setup(460, 320, true, "knight", [])
	p.hp = 50
	return p

func _setup_game_world(enemy: Fighter, player: Fighter):
	GameWorld.player = player
	GameWorld.enemy = enemy
	GameWorld.difficulty = "easy"
	GameWorld.platforms = []
	GameWorld.evoker_summons = []
	GameWorld.phantoms = []
	GameWorld.projectiles = []
	GameWorld.game_mode = "pve"

func test_jump_commit_coasts_in_air():
	# AI 跳跃承诺期间在空中 → 停止水平输入，让跳跃弧自然飞行
	var f = _make_ai(true)   # mid-air
	var p = _make_player()
	_setup_game_world(f, p)
	# 跳跃承诺现在由 TrackSystem 管理
	TrackSystem._jump_commit = true
	# 设置必要的 TrackSystem 状态
	TrackSystem._path_move_speed = 1.0
	TrackSystem._path_dir_to_target = 1
	TrackSystem._target_plat = null

	var ai_cx = f.pos_x + f.w / 2.0
	TrackSystem.follow_path(f, ai_cx)

	assert_eq(f.vx, 0.0, "Jump commit + mid-air → vx = 0 (coast)")

func test_jump_commit_cleared_on_ground():
	# AI 落地后清除跳跃承诺
	var f = _make_ai(false)  # grounded
	var p = _make_player()
	_setup_game_world(f, p)
	TrackSystem._jump_commit = true

	var ai_cx = f.pos_x + f.w / 2.0
	TrackSystem.follow_path(f, ai_cx)

	assert_false(TrackSystem._jump_commit, "Grounded AI → _jump_commit cleared")

func test_jump_commit_not_set_without_jump():
	# 没有跳跃时 _jump_commit 默认 false
	var f = _make_ai(false)
	var p = _make_player()
	_setup_game_world(f, p)

	var ai_cx = f.pos_x + f.w / 2.0
	TrackSystem.follow_path(f, ai_cx)

	assert_false(TrackSystem._jump_commit, "No platform navigation → _jump_commit remains false")

func test_intermediate_platform_path_recalculates():
	# AI 从 A 跳到中间平台 B 后，路径重算为 B→C
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},  # A
		{"x": 150, "y": 380, "w": 100, "h": 10, "terrain_type": 0},  # B
		{"x": 290, "y": 380, "w": 100, "h": 10, "terrain_type": 0},  # C
	]
	# AI 在 A，目标在 C → 路径 A→B→C
	var path_from_a = TrackSystem._find_path(GameWorld.platforms[0], GameWorld.platforms[2])
	assert_eq(path_from_a.size(), 3, "From A to C → path length 3 (A→B→C)")

	# 模拟 AI 落地到 B（路径自动重算）
	var path_from_b = TrackSystem._find_path(GameWorld.platforms[1], GameWorld.platforms[2])
	assert_eq(path_from_b.size(), 2, "From B to C → path length 2 (B→C)")
	assert_eq(path_from_b[0], GameWorld.platforms[1], "Path start = B")
	assert_eq(path_from_b[1], GameWorld.platforms[2], "Path end = C")


# ── 轨迹拦截检测测试 ──

func test_trajectory_not_obstructed_no_other_platform():
	# 只有两个平台 → 无拦截
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
		{"x": 120, "y": 380, "w": 100, "h": 10, "terrain_type": 0},
	]
	var obstructed = TrackSystem._trajectory_obstructed(GameWorld.platforms[0], GameWorld.platforms[1])
	assert_false(obstructed, "No other platform → not obstructed")

func test_trajectory_obstructed_by_intermediate():
	# A→C 的抛物线会被 B 拦截
	# A(y=380) → B(y=300) → C(y=250)
	# A→C 经过 B 所在区域 → 应被拦截
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},   # A
		{"x": 80, "y": 300, "w": 60, "h": 10, "terrain_type": 0},  # B：拦截者
		{"x": 120, "y": 250, "w": 60, "h": 10, "terrain_type": 0}, # C
	]
	var obstructed = TrackSystem._trajectory_obstructed(GameWorld.platforms[0], GameWorld.platforms[2])
	assert_true(obstructed, "A→C parbola should pass through B → obstructed")

func test_trajectory_not_obstructed_by_bystander():
	# 旁观平台 D 在跳跃区域外 → 不应被拦截
	# A(y=380) → C(y=250)，D 在远侧
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},  # A
		{"x": 300, "y": 250, "w": 80, "h": 10, "terrain_type": 0}, # D：远离轨迹
		{"x": 120, "y": 250, "w": 60, "h": 10, "terrain_type": 0}, # C
	]
	var obstructed = TrackSystem._trajectory_obstructed(GameWorld.platforms[0], GameWorld.platforms[2])
	assert_false(obstructed, "D is far from trajectory → not obstructed")

func test_graph_skips_obstructed_edge():
	# A→C 被 B 拦截 → 不应有 A→C 边
	# 但 A→B 和 B→C 应存在
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},   # A
		{"x": 80, "y": 300, "w": 60, "h": 10, "terrain_type": 0},  # B
		{"x": 120, "y": 250, "w": 60, "h": 10, "terrain_type": 0}, # C
	]
	TrackSystem._build_graph()
	# A→C 被拦截
	var ac_edge = null
	for e in TrackSystem._adj[0]:
		if e["to"] == 2: ac_edge = e
	assert_null(ac_edge, "A→C blocked by B → no edge")
	# A→B 应存在
	var ab_edge = null
	for e in TrackSystem._adj[0]:
		if e["to"] == 1: ab_edge = e
	assert_not_null(ab_edge, "A→B should exist")
	# B→C 应存在
	var bc_edge = null
	for e in TrackSystem._adj[1]:
		if e["to"] == 2: bc_edge = e
	assert_not_null(bc_edge, "B→C should exist")

func test_obstructed_path_finds_alt_route():
	# A→C 被 B 拦截，路径应走 A→B→C 而非直接 A→C
	GameWorld.platforms = [
		{"x": 0, "y": 380, "w": 100, "h": 10, "terrain_type": 0},   # A
		{"x": 80, "y": 300, "w": 60, "h": 10, "terrain_type": 0},  # B
		{"x": 120, "y": 250, "w": 60, "h": 10, "terrain_type": 0}, # C
	]
	var path = TrackSystem._find_path(GameWorld.platforms[0], GameWorld.platforms[2])
	assert_eq(path.size(), 3, "Obstructed → should find A→B→C")
	assert_eq(path[0], GameWorld.platforms[0], "Path[0] = A")
	assert_eq(path[1], GameWorld.platforms[1], "Path[1] = B")
	assert_eq(path[2], GameWorld.platforms[2], "Path[2] = C")
