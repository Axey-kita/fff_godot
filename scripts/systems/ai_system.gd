class_name AISystem

# ===== AI System =====
static func update_ai(ai_think_delay: int) -> int:
	if GameWorld.game_mode == "pvp" or GameWorld.enemy.hp <= 0:
		return ai_think_delay
	var f = GameWorld.enemy
	
	# Frozen check (matches JS: if enemy.hasStatus('frozen') return)
	if f.has_status("frozen"):
		return ai_think_delay
	
	# Hit stun check (matches JS: if enemy.hitCooldown > 0 return)
	if f.hit_cooldown > 0:
		return ai_think_delay
	
	var diff = Constants.AI_PRESETS.get(GameWorld.difficulty, Constants.AI_PRESETS["medium"])
	
	# Phantom target selection — AI prefers nearest alive phantom
	var target = GameWorld.player
	if GameWorld.phantoms.size() > 0:
		var nearest = null
		var nd = INF
		for ph in GameWorld.phantoms:
			if not ph or ph.hp <= 0:
				continue
			var d = absf(f.pos_x - ph.x)
			if d < nd:
				nd = d
				nearest = ph
		if nearest:
			target = nearest
	
	var dx = (target["x"] if target is Dictionary else target.pos_x) - f.pos_x
	var dist = absf(dx)
	var dir_to_target = 1 if dx > 0 else -1
	
	# Think delay (matches JS: floor(react/16) + floor(random()*8))
	if ai_think_delay > 0:
		return ai_think_delay - 1
	var new_delay = int(diff["react"] / 16) + randi() % 8
	
	var rand = randf()
	
	# ---- Projectile defense: parry/block nearby projectiles ----
	var proj_near = false
	for p in GameWorld.projectiles:
		if p.get("owner") == GameWorld.player and absf(p.get("x", 0) - f.pos_x) < 200:
			proj_near = true
			break
	if proj_near and not f.blocking and f.grounded:
		var skill2 = f.get_skill("skill2")
		if skill2 and skill2.can_use(f):
			skill2.try_use(f)
			return new_delay
	
	# ---- Skill variables (used by both hell tactics and skill usage) ----
	var skill1 = f.get_skill("skill1")
	var skill2 = f.get_skill("skill2")
	var ult = f.get_skill("ult")

	# ---- Hell-specific tactics ----
	var is_hell = GameWorld.difficulty == "hell"
	if is_hell:
		# ① 反应闪避: 玩家攻击中+距离<150px → 后跳闪避, 70%概率
		var player = GameWorld.player
		if player and player.hp > 0 and player.attacking and dist < 150 and rand < 0.7:
			f.vx = -dir_to_target * diff["move_speed"] * 2.0
			if f.grounded: f.vy = -8
			_update_state(f, dir_to_target)
			return new_delay

		# ② 对空迎击: 玩家在空中+距离<120px → AI跳起迎击, 40%概率
		if player and not player.grounded and f.grounded and dist < 120 and rand < 0.4:
			f.vy = -9
			f.vx = dir_to_target * diff["move_speed"]
			_update_state(f, dir_to_target)
			return new_delay

		# ③ 防御技能: 玩家贴脸攻击中+距离<100px → AI开技二防御, 50%概率
		if skill2 and skill2.can_use(f) and dist < 100 and player and player.attacking and rand < 0.5:
			skill2.try_use(f)
			return new_delay

	# ---- Skill usage at distance ----
	var can_use_s1 = skill1 and skill1.can_use(f) and dist < 350
	var can_use_s2 = skill2 and skill2.can_use(f)
	var can_use_ult = ult and ult.can_use(f)
	
	if dist > 150 and dist < 350 and can_use_s1 and randf() < diff["skill_rate"] * 1.5:
		skill1.try_use(f)
		# hard/hell：延长 skill1 冷却以平衡高 skill_rate
		if Constants.difficulty_at_least(GameWorld.difficulty, "hard"):
			skill1.cd = maxi(skill1.cd, 300)
		return new_delay

	if dist < 200 and can_use_ult and randf() < diff["skill_rate"] * 0.8:
		ult.try_use(f)
		# hard/hell：延长 ult 冷却以平衡高 skill_rate
		if Constants.difficulty_at_least(GameWorld.difficulty, "hard"):
			ult.cd = maxi(ult.cd, 300)
		return new_delay
	
	# ---- Hell-specific tactics (cont.) ----
	if is_hell:
		var player = GameWorld.player
		# ④ 斩杀大招: 玩家血量<40%+距离<150px → 直接丢大招, 80%概率
		if can_use_ult and dist < 150 and player and player.hp < player.max_hp * 0.4 and rand < 0.8:
			ult.try_use(f); return new_delay

		# ⑤ 技能连招: 双技能可用+距离<200px → 技一→技二连发, 35%概率
		if can_use_s1 and can_use_s2 and dist < 200 and rand < 0.35:
			skill1.try_use(f)
			if skill2.can_use(f): skill2.try_use(f)
			return new_delay

	# ---- Archer: handle charging attack ----
	if f.char_id == "archer":
		if f.charging_attack:
			# Already charging → check if ready to fire
			var ct = (Time.get_ticks_msec() - f.charge_start_time) / 1000.0
			if ct >= 0.8:
				ArcherCharacter.ai_fire_arrow(f, ct)
			return new_delay
		elif dist < 350 and rand < diff["aggro"] * 1.5:
			# Start charging
			var comp = f.components.get_component("archer") if f.components else null
			if comp and comp.arrows > 0 and f.energy >= 5:
				f.charging_attack = true
				f.charge_start_time = Time.get_ticks_msec()
				f.attacking = true
				f.attack_timer = 9999
				f.state = "attack"
				return new_delay

	# ---- Evoker: summon management & ranged combat ----
	if f.char_id == "evoker":
		# Use ult when HP is low and has a summon
		if can_use_ult and f.hp < f.max_hp * 0.5 and dist < 250:
			ult.try_use(f)
			return new_delay

		# Check if evoker has a summon
		var has_summon = false
		var summon_state = ""
		for s in GameWorld.evoker_summons:
			if s.get("owner") == f:
				has_summon = true
				summon_state = s.get("state", "")
				break

		if not has_summon and can_use_s1:
			# No summon → summon one
			skill1.try_use(f)
			return new_delay

		# Has summon → manage summon state + ranged attack
		var atk_skill = f.get_skill("attack")

		# Use skill2 (魔令) to trigger summon special skill when it's off cooldown
		if has_summon and can_use_s2 and randf() < diff["skill_rate"]:
			skill2.try_use(f)
			return new_delay

		# Command summon: cycle 随行 ↔ 猎杀 via attack
		if has_summon and atk_skill and atk_skill.can_use(f):
			if summon_state == "随行":
				# 役使·猎杀 → send summon to attack
				atk_skill.try_use(f)
				return new_delay
			elif summon_state == "猎杀":
				# 役使·随行 → recall summon
				atk_skill.try_use(f)
				return new_delay

		# No summon → fire fireball at range
		if not has_summon and atk_skill and atk_skill.can_use(f) and dist < 400 and rand < diff["aggro"]:
			atk_skill.try_use(f)
			return new_delay

	# ---- Attack when close ----
	if dist < 80 and rand < diff["aggro"]:
		if f.char_id == "assassin":
			var atk_skill = f.get_skill("attack")
			if atk_skill and atk_skill.can_use(f):
				atk_skill.try_use(f)
		else:
			if f.attack_cooldown <= 0 and not f.attacking:
				f.attacking = true
				f.attack_timer = 68
				f.attack_delay = 8
				f.attack_hit_dealt = false
				f.attack_cooldown = 60
				f.state = "attack"
		return new_delay
	
	# ---- Platform-aware movement ----
	var move_speed = diff["move_speed"]
	var target_x = target.get("x", target.pos_x) if target is Dictionary else target.pos_x
	var target_y = target.get("y", target.pos_y) if target is Dictionary else target.pos_y
	
	# 找到 AI 和目标所在的平台
	var ai_cx = f.pos_x + f.w / 2.0
	var ai_feet_y = f.pos_y + f.h
	var target_feet_x = target_x
	var target_feet_y = target_y + (28.0 if target is Dictionary else target.h)
	
	var ai_plat = null
	var target_plat = null
	for p in GameWorld.platforms:
		if p.get("terrain_type", -1) == 3: continue
		if _is_on_platform(ai_cx, ai_feet_y, p):
			ai_plat = p
		if _is_on_platform(target_feet_x, target_feet_y, p):
			target_plat = p
	
	# 在同一平台上 → 直接走向目标
	if ai_plat != null and target_plat != null and ai_plat == target_plat:
		var dir = 1 if target_x > f.pos_x else -1
		f.vx = dir * move_speed
		_update_state(f, dir_to_target)
		return new_delay
	
	# 在不同平台上 → 使用有向图路径规划
	if ai_plat != null and target_plat != null and f.grounded:
		var path = _find_path(ai_plat, target_plat)
		if path.size() >= 2:
			var next_plat = path[1]  # 路径中下一个跳转目标平台
			var next_cx = next_plat["x"] + next_plat["w"] / 2.0
			var dir = 1 if next_cx > f.pos_x else -1
			f.vx = dir * move_speed * 1.5
			# 到达当前平台边缘时起跳
			var dist_to_edge = absf(f.pos_x - (ai_plat["x"] + ai_plat["w"] if dir > 0 else ai_plat["x"]))
			if dist_to_edge < 50 and f.grounded:
				f.vy = -JUMP_VY
				_jump_commit = true
		else:
			# 无可达路径 → 保持静止
			f.vx = 0
		_update_state(f, dir_to_target)
		return new_delay

	# ── 跳跃承诺期间，空中不施加水平输入（沿跳跃弧 coast） ──
	if not f.grounded:
		if _jump_commit:
			f.vx = 0
			_update_state(f, 0)
			return new_delay
	else:
		_jump_commit = false  # 落地后清除跳跃承诺

	# ⑥ 精确走位: 地狱专属 — 中距离拉扯
	if is_hell and dist < 300:
		var player = GameWorld.player
		var ideal_min = 120
		if player and player.attacking and dist > ideal_min:
			f.vx = dir_to_target * move_speed * 1.8
		elif dist < maxi(ideal_min, 60):
			f.vx = -dir_to_target * move_speed
		else:
			f.vx = dir_to_target * move_speed * 0.6
		_update_state(f, dir_to_target)
		return new_delay
	
	if dist > 200:
		f.vx = dir_to_target * move_speed
		if f.grounded and randf() < diff["jump_rate"]:
			f.vy = -8
		_update_state(f, dir_to_target)
		return new_delay
	
	if rand < diff["dodge"] and dist < 150:
		f.vx = -dir_to_target * move_speed * 1.5
		if f.grounded and randf() < 0.1:
			f.vy = -7
		_update_state(f, dir_to_target)
		return new_delay
	
	if dist > 80:
		f.vx = dir_to_target * move_speed * 0.8
	else:
		f.vx = 0
	
	_update_state(f, dir_to_target)
	return new_delay



static func _update_state(p: Fighter, mx: int):
	if p.grounded and mx == 0 and not p.attacking and not p.dashing:
		p.state = "idle"
	elif p.grounded and mx != 0 and not p.attacking and not p.dashing:
		p.state = "walk"
	if p.attacking and p.attack_timer <= 0:
		p.attacking = false; p.state = "idle"

# ── 物理常量 ──
const GRAVITY := 0.22
const JUMP_VY := 10.0     # 跳跃初速度（绝对值，与角色实际起跳 vy=-10 一致）

# ── 有向可达图（最低速度建图，欧氏距离边权）──
const BUILD_MOVE_SPEED := 2.0  # 建图水平速度

# _adj[i] = [{to: int, weight: float}, ...]  邻接表，i 为 GameWorld.platforms 下标
static var _adj: Array = []
static var _graph_built: bool = false

# 跳跃承诺标志：AI 作为路径一部分起跳后，在空中 coast（不施加水平输入）
static var _jump_commit: bool = false

## 判断点 (x, y) 是否站在平台 p 上
static func _is_on_platform(x: float, y: float, p: Dictionary) -> bool:
	if p.get("terrain_type", -1) == 3:
		return false
	return x >= p["x"] and x <= p["x"] + p["w"] and absf(y - p["y"]) < 20


## 返回平台 plat 在目标高度 target_y 处的可达 x 区间 [l, r]
## 若目标高度超出跳跃范围（高于最高点）返回 null
## 物理常量：
##   GRAVITY = 0.22, JUMP_VY = 10.0
## 跳跃曲线：
##   x(t) = x0 + dir * move_speed * t
##   y(t) = y0 - JUMP_VY * t + 0.5 * GRAVITY * t^2
## 可达区间：从平台任意点起跳，在高度 target_y 处能到达的 x 范围
## 理论上界 = a_l - move_speed * t2 （左向外跳）
## 理论下界 = a_r + move_speed * t2 （右向外跳）
## 其中 t2 = (JUMP_VY + sqrt(JUMP_VY^2 - 2*GRAVITY*(a_y - target_y))) / GRAVITY
static func _get_reachable_x_interval(plat: Dictionary, target_y: float, move_speed: float) -> Array:
	var a_l = plat["x"]
	var a_r = plat["x"] + plat["w"]
	var a_y = plat["y"]
	
	# 目标在平台上方（y 坐标更小）
	if target_y < a_y:
		var dy = a_y - target_y
		var h_max = JUMP_VY * JUMP_VY / (2.0 * GRAVITY)  # ~205
		if dy > h_max:
			return []  # 过高不可达
		var disc = JUMP_VY * JUMP_VY - 2.0 * GRAVITY * dy
		if disc < 0:
			return []
		var t2 = (JUMP_VY + sqrt(disc)) / GRAVITY
		var reach_l = a_l - move_speed * t2
		var reach_r = a_r + move_speed * t2
		return [reach_l, reach_r]
	
	# 目标在平台下方（y 坐标更大）— 仅悬挂平台允许下落
	if target_y > a_y:
		if plat.get("is_ground", false):
			return []  # 地面阻挡下落，不可达
		var t_fall = sqrt(2.0 * (target_y - a_y) / GRAVITY)
		var reach_l = a_l - move_speed * t_fall
		var reach_r = a_r + move_speed * t_fall
		return [reach_l, reach_r]
	
	# 同一高度 — 可以跳跃落地，使用完整跳跃范围
	# Δy = 0, D = v_y0^2, t2 = 2*v_y0/g
	var t_land = 2.0 * JUMP_VY / GRAVITY
	return [a_l - move_speed * t_land, a_r + move_speed * t_land]


## 判断从 from_plat 是否可以到达 to_plat
## 判定逻辑：
## 1. 高度差检查：若 from_plat.y - to_plat.y > h_max → 不可达
## 2. 计算 from_plat 在 to_plat.y 高度处的可达 x 区间
## 3. 若 to_plat 的 x 区间与可达 x 区间有重叠 → 可达
static func _is_platform_reachable(from_plat: Dictionary, to_plat: Dictionary, move_speed: float) -> bool:
	if from_plat.get("terrain_type", -1) == 3 or to_plat.get("terrain_type", -1) == 3:
		return false
	var from_y = from_plat["y"]
	var to_y = to_plat["y"]
	var h_max = JUMP_VY * JUMP_VY / (2.0 * GRAVITY)
	if from_y - to_y > h_max:
		return false  # 目标过高
	var interval = _get_reachable_x_interval(from_plat, to_y, move_speed)
	if interval.size() < 2:
		return false
	var reach_l = interval[0]
	var reach_r = interval[1]
	var to_l = to_plat["x"]
	var to_r = to_plat["x"] + to_plat["w"]
	# 区间重叠检查
	return not (to_r < reach_l or to_l > reach_r)


## 检查从 from_plat 到 to_plat 的跳跃轨迹是否会被其他平台拦截
## 方法：沿抛物线采样，检查是否有中间平台在轨迹上
## 若被拦截，AI 会落在中间平台上而非目标平台，应阻止该边加入图
static func _trajectory_obstructed(from_plat: Dictionary, to_plat: Dictionary) -> bool:
	var from_y = from_plat["y"]
	var from_l = from_plat["x"]
	var from_r = from_plat["x"] + from_plat["w"]
	var from_cx = from_plat["x"] + from_plat["w"] / 2.0
	var to_cx = to_plat["x"] + to_plat["w"] / 2.0
	
	# 跳跃方向
	var dir = 1 if to_cx > from_cx else -1
	
	# 起跳位置：朝向目标的那一侧边缘
	var takeoff_x = from_r if dir > 0 else from_l
	var takeoff_y = from_y
	
	# 估算抛物线落地时间（用目标高度处的下降段时间，或完整跳跃时间）
	var target_y = to_plat["y"]
	var t_total := 0.0
	if target_y < from_y:
		# 向上跳：计算到达目标高度的时间
		var dy = from_y - target_y
		var disc = JUMP_VY * JUMP_VY - 2.0 * GRAVITY * dy
		if disc < 0:
			return false  # 数学上已不可达，不应走到这里
		t_total = (JUMP_VY + sqrt(disc)) / GRAVITY
	else:
		# 同高或向下：用完整跳跃时间
		t_total = 2.0 * JUMP_VY / GRAVITY
	
	# 每 4 帧采样一次，从第 6 帧开始（跳过起跳位置附近）
	var dt := 4.0
	var t := dt + 2.0
	while t < t_total:
		var x = takeoff_x + dir * BUILD_MOVE_SPEED * t
		var y = takeoff_y - JUMP_VY * t + 0.5 * GRAVITY * t * t
		
		# 检查每个非起点/终点的平台
		for plat in GameWorld.platforms:
			if plat == from_plat or plat == to_plat:
				continue
			if plat.get("terrain_type", -1) == 3:
				continue
			# 只检查垂直方向在起止高度之间的平台
			var plat_y = plat["y"]
			var y_min = mini(from_y, target_y)
			var y_max = maxi(from_y, target_y)
			if plat_y < y_min or plat_y > y_max:
				continue
			if _is_on_platform(x, y, plat):
				return true  # 被拦截
		t += dt
	
	return false


# ── 有向图构建（最低速建图） ──

## 使用 BUILD_MOVE_SPEED 遍历所有平台对，构建有向图邻接表
## 边权 = 平台中心点之间的欧氏距离
static func _build_graph() -> void:
	var n = GameWorld.platforms.size()
	_adj = []
	_adj.resize(n)
	for i in range(n):
		_adj[i] = []
		var from_plat = GameWorld.platforms[i]
		if from_plat.get("terrain_type", -1) == 3:
			continue
		for j in range(n):
			if i == j: continue
			var to_plat = GameWorld.platforms[j]
			if to_plat.get("terrain_type", -1) == 3:
				continue
			if _is_platform_reachable(from_plat, to_plat, BUILD_MOVE_SPEED) \
				and not _trajectory_obstructed(from_plat, to_plat):
				var from_cx = from_plat["x"] + from_plat["w"] / 2.0
				var to_cx = to_plat["x"] + to_plat["w"] / 2.0
				var dx = to_cx - from_cx
				var dy = to_plat["y"] - from_plat["y"]
				var w = sqrt(dx * dx + dy * dy)
				_adj[i].append({"to": j, "weight": w})
	_graph_built = true


## Dijkstra 最短路（邻接表版本）
## 返回从 start_idx 到 goal_idx 的平台下标路径 [start, ..., goal]
## 若不可达返回空数组
static func _dijkstra(start_idx: int, goal_idx: int) -> Array:
	if not _graph_built or _adj.size() != GameWorld.platforms.size():
		_build_graph()
	var n = GameWorld.platforms.size()
	if start_idx < 0 or start_idx >= n or goal_idx < 0 or goal_idx >= n:
		return []

	var dist = []
	var prev = []
	var visited = []
	dist.resize(n)
	prev.resize(n)
	visited.resize(n)
	for i in range(n):
		dist[i] = INF
		prev[i] = -1
		visited[i] = false
	dist[start_idx] = 0.0

	while true:
		# 找未访问的最小 dist 节点
		var u = -1
		var min_d = INF
		for i in range(n):
			if not visited[i] and dist[i] < min_d:
				min_d = dist[i]
				u = i
		if u == -1 or u == goal_idx:
			break

		visited[u] = true
		for edge in _adj[u]:
			var v = edge["to"]
			var nd = dist[u] + edge["weight"]
			if nd < dist[v]:
				dist[v] = nd
				prev[v] = u

	if prev[goal_idx] == -1 and start_idx != goal_idx:
		return []

	# 重构路径
	var path = []
	var cur = goal_idx
	while cur != -1:
		path.push_front(cur)
		cur = prev[cur]
	return path


## 在 GameWorld.platforms 中查找平台下标
static func _plat_index(plat: Dictionary) -> int:
	for i in range(GameWorld.platforms.size()):
		if GameWorld.platforms[i] == plat:
			return i
	return -1


## 查找从 from_plat 到 to_plat 的最短平台路径
## 返回平台字典数组 [from_plat, ..., to_plat]（含两端），不可达返回 []
static func _find_path(from_plat: Dictionary, to_plat: Dictionary) -> Array:
	if GameWorld.platforms.size() == 0:
		return []
	var si = _plat_index(from_plat)
	var ti = _plat_index(to_plat)
	if si < 0 or ti < 0:
		return []
	var idx_path = _dijkstra(si, ti)
	if idx_path.size() == 0:
		return []
	var result = []
	for idx in idx_path:
		result.append(GameWorld.platforms[idx])
	return result

