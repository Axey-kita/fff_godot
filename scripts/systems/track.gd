class_name TrackSystem

# ===== Pure Tracking AI — 纯导航接口（无技能/攻击/闪避） =====

# ── 物理常量 ──
const GRAVITY := 0.22
const JUMP_VY := 10.0

# ── 有向可达图 ──
const BUILD_MOVE_SPEED := 2.0
static var _adj: Array = []
static var _graph_built: bool = false

# ── 跳跃状态 ──
static var _jump_commit: bool = false

# ── 路径状态 ──
static var _path: Array = []         # 当前完整路径 [plat0, plat1, ...]
static var _path_move_speed := 0.0   # 当前移动速度
static var _path_dir_to_target := 0  # 朝向目标的方向
static var _target_x := 0.0          # 目标 x 位置（同平台 desire 距离保持用）
static var _target_plat = null       # 目标平台
static var _desire_min := 0.0        # 同平台后的最小 desire 距离
static var _desire_max := 999999.0   # 同平台后的最大 desire 距离
static var _rush := false            # 是否使用 rush 模式（更快起跳）

# ── 辅助：维持速度（已内联到执行路径） ──
static var _last_vx := 0.0
static var _last_dir := 0

# ===== 新接口 =====

## 设置导航目标（由 AISystem 走位策略决定）
## navigate() 只设置内部状态，不直接操作 fighter 的 vx/vy
## from_plat/to_plat 为 null 时视为"无路径目标"
static func navigate(f, from_plat, to_plat, desire_min: float, desire_max: float, rush: bool = false):
	_desire_min = desire_min
	_desire_max = desire_max
	_rush = rush
	_target_plat = to_plat
	_target_x = _get_target_x(f, to_plat)
	
	# 设置移动速度
	var diff = Constants.AI_PRESETS.get(GameWorld.difficulty, Constants.AI_PRESETS["medium"])
	_path_move_speed = diff["move_speed"]
	
	# 设置路径
	if from_plat == null or to_plat == null:
		_path = []
		_jump_commit = false
		return
	
	# 方向（朝目标）
	var dx = _target_x - f.pos_x
	_path_dir_to_target = 1 if dx > 0 else -1
	
	if from_plat == to_plat:
		_path = [from_plat]  # 同平台，单元素路径
		_jump_commit = false
		return
	
	_path = _find_path(from_plat, to_plat)
	_need_think = false
	_jump_commit = false

## 每帧执行路径（同平台走向目标/不同平台图路径+边缘跳跃）
static func follow_path(f, ai_cx: float) -> void:
	var move_speed = _path_move_speed
	var dir_to_target = _path_dir_to_target

	# 跳跃承诺 coast
	if not f.grounded and _jump_commit:
		f.vx = 0
		_update_state(f, 0)
		_last_vx = 0; _last_dir = 0
		return

	# 落地清除承诺
	if f.grounded:
		_jump_commit = false

	# 穿透下落 → 维持水平速度直至落地
	if not f.grounded and f.passthrough_timer > 0:
		f.vx = dir_to_target * move_speed * 1.5
		_last_vx = f.vx; _last_dir = dir_to_target
		_update_state(f, dir_to_target)
		return

	# 识别 AI 当前所在平台
	var ai_feet_y = f.pos_y + f.h
	var ai_plat = null
	for p in GameWorld.platforms:
		if p.get("terrain_type", -1) == 3: continue
		if _is_on_platform(ai_cx, ai_feet_y, p):
			ai_plat = p
			break

	# 同平台 → desire 距离保持
	if ai_plat != null and _target_plat != null and ai_plat == _target_plat:
		var dx_target = _target_x - f.pos_x
		var dist = absf(dx_target)
		var dir_to_target_local = 1 if dx_target > 0 else -1
		
		if dist < _desire_min:
			# 太近 → 后退
			f.vx = -dir_to_target_local * move_speed
		elif dist > _desire_max:
			# 太远 → 前进
			f.vx = dir_to_target_local * move_speed
		else:
			# desire 范围内 → 停止
			f.vx = 0
		_last_vx = f.vx; _last_dir = dir_to_target_local
		_update_state(f, sign(f.vx))
		return

	# 不同平台 + 有路径 → 沿路径走
	if ai_plat != null and _target_plat != null and f.grounded and _path.size() >= 2:
		var next_plat = _path[1]
		_follow_path_step(f, ai_plat, next_plat, move_speed, dir_to_target, ai_cx)
		return

	# 无可达路径 → 朝目标方向走，到边缘起跳尝试
	if ai_plat != null and f.grounded:
		var dir_to_plat := 0
		var ai_cx_check = f.pos_x + f.w / 2
		if ai_cx_check < ai_plat["x"] + ai_plat["w"] / 2:
			dir_to_plat = 1
		else:
			dir_to_plat = -1
		f.vx = dir_to_plat * move_speed * 0.8
		var at_edge = false
		if dir_to_plat > 0:
			at_edge = absf(f.pos_x - (ai_plat["x"] + ai_plat["w"])) < 60
		else:
			at_edge = absf(f.pos_x - ai_plat["x"]) < 60
		if at_edge:
			f.vy = -JUMP_VY
			_jump_commit = true
		_last_vx = f.vx; _last_dir = dir_to_plat
		_update_state(f, dir_to_plat)
		return

	# 无有效路径 → 静止
	f.vx = 0
	_last_vx = 0; _last_dir = 0
	_update_state(f, 0)


# ===== 旧接口保留 =====
# 注：update_track() 已删除，改为 navigate() + follow_path()

# ── 需要重新规划路径标志 ──
static var _need_think: bool = true

# ── 沿路径走一步（边缘检测 + 起跳） ──
static func _follow_path_step(f, ai_plat, next_plat, move_speed: float, dir_to_target: int, ai_cx: float):
	var is_above = next_plat["y"] < ai_plat["y"]

	# 悬挂平台下落
	if not is_above and not ai_plat.get("is_ground", false) and f.grounded:
		f.passthrough_platform = ai_plat
		f.passthrough_timer = 10
		f.grounded = false
		f.vy = 1
		f.vx = dir_to_target * move_speed * 1.5
		_last_vx = f.vx; _last_dir = dir_to_target
		_update_state(f, dir_to_target)
		return

	# 方向：走向 next_plat 的 x 范围
	var next_l = next_plat["x"]
	var next_r = next_plat["x"] + next_plat["w"]
	var dir := 0
	if ai_cx < next_l:
		dir = 1
	elif ai_cx > next_r:
		dir = -1
	else:
		# 已在目标 x 范围内 → 直上跳
		if is_above and f.grounded:
			f.vx = 0
			f.vy = -JUMP_VY
			_jump_commit = true
			_last_vx = 0; _last_dir = 0
			_update_state(f, 0)
			return
		dir = dir_to_target

	# 速度：rush 模式 1.5x，否则 1.0x
	var speed_mult = 1.5 if _rush else 1.0
	f.vx = dir * move_speed * speed_mult

	# 起跳检测（到边缘起跳）
	var edge_threshold = 40 if _rush else 60
	var at_edge = absf(f.pos_x - (ai_plat["x"] + ai_plat["w"] if dir > 0 else ai_plat["x"])) < edge_threshold
	if is_above and at_edge and f.grounded:
		var target_cx = (next_l + next_r) / 2.0
		var jump_dir = 1 if target_cx > f.pos_x else -1
		f.vx = jump_dir * move_speed * speed_mult
		f.vy = -JUMP_VY
		_jump_commit = true

	_last_vx = f.vx; _last_dir = dir
	_update_state(f, dir)

# ── 辅助：获取目标 x 位置 ──
static func _get_target_x(f, target_plat) -> float:
	if target_plat != null:
		return target_plat["x"] + target_plat["w"] / 2.0
	return GameWorld.player.pos_x + GameWorld.player.w / 2.0


# ===== 状态更新 =====
static func _update_state(p, mx: int):
	if p.grounded and mx == 0 and not p.attacking and not p.dashing:
		p.state = "idle"
	elif p.grounded and mx != 0 and not p.attacking and not p.dashing:
		p.state = "walk"
	if p.attacking and p.attack_timer <= 0:
		p.attacking = false; p.state = "idle"

# ===== 平台辅助函数 =====
static func _is_on_platform(x: float, y: float, p: Dictionary) -> bool:
	if p.get("terrain_type", -1) == 3: return false
	return x >= p["x"] and x <= p["x"] + p["w"] and absf(y - p["y"]) < 20

static func _get_reachable_x_interval(plat: Dictionary, target_y: float, move_speed: float) -> Array:
	var a_l = plat["x"]; var a_r = plat["x"] + plat["w"]; var a_y = plat["y"]
	if target_y < a_y:
		var dy = a_y - target_y
		var h_max = JUMP_VY * JUMP_VY / (2.0 * GRAVITY)
		if dy > h_max: return []
		var disc = JUMP_VY * JUMP_VY - 2.0 * GRAVITY * dy
		if disc < 0: return []
		var t2 = (JUMP_VY + sqrt(disc)) / GRAVITY
		return [a_l - move_speed * t2, a_r + move_speed * t2]
	if target_y > a_y:
		if plat.get("is_ground", false): return []
		var t_fall = sqrt(2.0 * (target_y - a_y) / GRAVITY)
		return [a_l - move_speed * t_fall, a_r + move_speed * t_fall]
	var t_land = 2.0 * JUMP_VY / GRAVITY
	return [a_l - move_speed * t_land, a_r + move_speed * t_land]

static func _is_platform_reachable(from_plat: Dictionary, to_plat: Dictionary, move_speed: float) -> bool:
	if from_plat.get("terrain_type", -1) == 3 or to_plat.get("terrain_type", -1) == 3: return false
	var from_y = from_plat["y"]; var to_y = to_plat["y"]
	var h_max = JUMP_VY * JUMP_VY / (2.0 * GRAVITY)
	if from_y - to_y > h_max: return false
	var interval = _get_reachable_x_interval(from_plat, to_y, move_speed)
	return interval.size() >= 2 and not (to_plat["x"] + to_plat["w"] < interval[0] or to_plat["x"] > interval[1])

static func _trajectory_obstructed(from_plat: Dictionary, to_plat: Dictionary) -> bool:
	var from_y = from_plat["y"]; var from_l = from_plat["x"]; var from_r = from_plat["x"] + from_plat["w"]
	var from_cx = from_plat["x"] + from_plat["w"] / 2.0; var to_cx = to_plat["x"] + to_plat["w"] / 2.0
	var dir = 1 if to_cx > from_cx else -1
	var takeoff_x = from_r if dir > 0 else from_l; var takeoff_y = from_y; var target_y = to_plat["y"]
	var t_total := 0.0
	if target_y < from_y:
		var dy = from_y - target_y; var disc = JUMP_VY * JUMP_VY - 2.0 * GRAVITY * dy
		if disc < 0: return false
		t_total = (JUMP_VY + sqrt(disc)) / GRAVITY
	else: t_total = 2.0 * JUMP_VY / GRAVITY
	var t := 6.0
	while t < t_total:
		var x = takeoff_x + dir * BUILD_MOVE_SPEED * t
		var y = takeoff_y - JUMP_VY * t + 0.5 * GRAVITY * t * t
		for plat in GameWorld.platforms:
			if plat == from_plat or plat == to_plat: continue
			if plat.get("terrain_type", -1) == 3: continue
			var plat_y = plat["y"]
			if plat_y < mini(from_y, target_y) or plat_y > maxi(from_y, target_y): continue
			if _is_on_platform(x, y, plat): return true
		t += 4.0
	return false

static func _build_graph() -> void:
	var n = GameWorld.platforms.size()
	_adj = []; _adj.resize(n)
	for i in range(n):
		_adj[i] = []
		var from_plat = GameWorld.platforms[i]
		if from_plat.get("terrain_type", -1) == 3: continue
		for j in range(n):
			if i == j: continue
			var to_plat = GameWorld.platforms[j]
			if to_plat.get("terrain_type", -1) == 3: continue
			if _is_platform_reachable(from_plat, to_plat, BUILD_MOVE_SPEED) and not _trajectory_obstructed(from_plat, to_plat):
				var from_cx = from_plat["x"] + from_plat["w"] / 2.0; var to_cx = to_plat["x"] + to_plat["w"] / 2.0
				_adj[i].append({"to": j, "weight": sqrt((to_cx - from_cx) * (to_cx - from_cx) + (to_plat["y"] - from_plat["y"]) * (to_plat["y"] - from_plat["y"]))})
	_graph_built = true

static func _dijkstra(start_idx: int, goal_idx: int) -> Array:
	if not _graph_built or _adj.size() != GameWorld.platforms.size(): _build_graph()
	var n = GameWorld.platforms.size()
	if start_idx < 0 or start_idx >= n or goal_idx < 0 or goal_idx >= n: return []
	var dist = []; var prev = []; var visited = []
	dist.resize(n); prev.resize(n); visited.resize(n)
	for i in range(n): dist[i] = INF; prev[i] = -1; visited[i] = false
	dist[start_idx] = 0.0
	while true:
		var u = -1; var min_d = INF
		for i in range(n):
			if not visited[i] and dist[i] < min_d: min_d = dist[i]; u = i
		if u == -1 or u == goal_idx: break
		visited[u] = true
		for edge in _adj[u]:
			var v = edge["to"]; var nd = dist[u] + edge["weight"]
			if nd < dist[v]: dist[v] = nd; prev[v] = u
	if prev[goal_idx] == -1 and start_idx != goal_idx: return []
	var path = []; var cur = goal_idx
	while cur != -1: path.push_front(cur); cur = prev[cur]
	return path

static func _plat_index(plat: Dictionary) -> int:
	for i in range(GameWorld.platforms.size()):
		if GameWorld.platforms[i] == plat: return i
	return -1

static func _find_path(from_plat: Dictionary, to_plat: Dictionary) -> Array:
	if GameWorld.platforms.size() == 0: return []
	var si = _plat_index(from_plat); var ti = _plat_index(to_plat)
	if si < 0 or ti < 0: return []
	var idx_path = _dijkstra(si, ti)
	if idx_path.size() == 0: return []
	var result = []
	for idx in idx_path: result.append(GameWorld.platforms[idx])
	return result
