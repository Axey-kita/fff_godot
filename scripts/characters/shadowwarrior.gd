# 影武者 (shadowwarrior)
class_name ShadowwarriorCharacter

const ANI_DIR = "res://assets/char_ani/shadowwarrior/"

# ── 技能贴图（FrameAnimation 铁律） ──
static var _fa_cache := {}

static func _fa(path: String, dur: float = 999.0, loop: bool = true) -> FrameAnimation:
	if _fa_cache.has(path):
		return _fa_cache[path]
	var tex = load(path)
	if not tex or not tex is Texture2D:
		printerr("[shadowwarrior] _fa: failed to load ", path)
		return FrameAnimation.new()
	var a = FrameAnimation.new()
	a.add_frame(tex, dur)
	a.loop = loop
	_fa_cache[path] = a
	return a

const TRAP_A        = "res://assets/fx_shadow_trap_a.png"
const TRAP_B        = "res://assets/fx_shadow_trap_b.png"
const CLONE_REVEAL  = "res://assets/fx_shadow_clone_reveal.png"
const IAIDO_SLASH   = "res://assets/fx_shadow_iaido_slash.png"
const RETREAT       = "res://assets/fx_shadow_retreat.png"
const BREAK_STRIKE  = "res://assets/fx_shadow_break_strike.png"
const GRAB          = "res://assets/fx_shadow_grab.png"
const GRAB_BURST    = "res://assets/fx_shadow_grab_burst.png"

# 影武者 - Phantom 帧更新计数器（防同帧多次运行）
static var _last_phantom_frame: int = -1

static func get_config() -> Dictionary:
	return {
		"id": "shadowwarrior", "name": "影武者", "hp": 90, "max_energy": 100, "energy_regen": 0.05,
		"speed": 2.1, "attack_range": 44, "attack_damage": 5,
		"attack_cooldown": 60, "attack_delay": 8, "attack_duration": 68,
		"fields": {
			"stealth_active": false, "stealth_timer": 0,
			"last_skill_time": -999, "retreat_timer": 0, "retreat_dir": 1,
			"break_strike_timer": 0,
			"pending_trap": false, "shadow_trap_active": false, "shadow_trap": {},
			"pending_clones": false, "clone_reveal_timer": 0,
			"iaido_active": false, "iaido_timer": 0,
			"iaido_frozen": false, "iaido_dir": 1, "iaido_slash": {},
		},
		"world_arrays": ["phantoms"],
		"animations": {
			"idle":   FrameAnimation.load_from_frames(ANI_DIR + "idle/",   "shadowwarrior_idle_f_",   [{"index": 1, "duration": 999.0}], true),
			"walk":   FrameAnimation.load_from_frames(ANI_DIR + "walk/",   "shadowwarrior_walk_f_",   [{"index": 1, "duration": 999.0}], true),
			"jump":   FrameAnimation.load_from_frames(ANI_DIR + "jump/",   "shadowwarrior_jump_f_",   [{"index": 1, "duration": 999.0}], true),
			"attack": FrameAnimation.load_from_frames(ANI_DIR + "attack/", "shadowwarrior_attack_f_", [{"index": 1, "duration": 2.0}], false),
			"ult":    FrameAnimation.load_from_frames(ANI_DIR + "ult/",    "shadowwarrior_ult_f_",    [{"index": 1, "duration": 3.0}], false),
		},
		"dex": {
			"icon": "🥷",
			"intro": "影随身动，刃自暗生。他不与你正面相搏，只在你的呼吸之间往返穿梭——当你终于看清那道残影时，刀锋早已归鞘。\n\"你砍中的，从来都不是我。\"",
			"stats": [{"label": "生命", "value": "90"}, {"label": "能量上限", "value": "100"}],
			"skills": [
				{"name": "胧月·斩（普通攻击）", "desc": "挥刀劈砍，造成 5 点伤害。", "meta": "消耗：无 ｜ 冷却：1 秒"},
				{"name": "影缚·袭（技能一）", "desc": "在原地生成暗影替身陷阱（存在 5 秒）。敌人靠近时替身化为影球包裹并抓取敌人，包裹造成 5 点伤害，随后炸裂造成 10 点伤害。", "meta": "消耗：15 能量 ｜ 冷却：12 秒"},
				{"name": "幻影·舞（技能二）", "desc": "生成 2 个幻影分身（各 10 点血量）冲向敌人，仅能使用胧月·斩。敌方会优先攻击分身。", "meta": "消耗：25 能量 ｜ 冷却：20 秒"},
				{"name": "影舞流·居合（大招）", "desc": "向前快速位移并留下一道刀光，自身姿态定格。刀光命中造成 10 点伤害并抓取，1 秒后爆炸造成 30 点伤害。", "meta": "消耗：100 能量 ｜ 冷却：8 秒"},
				{"name": "夜樱·隐（特殊机制）", "desc": "使用技能1/2 后 1 秒内使用胧月·斩，改为后撤并隐身（对手视角消失），获得 1 秒无敌，最多维持 2.5 秒。隐身下胧月·斩变为破影一击（前冲，10 点伤害）。任意攻击/技能/大招都会解除隐身。", "meta": "—"},
			]
		},
	}

static func create_skills() -> Array:
	return [
		Skill.new("attack", "胧月·斩", 60, 0, func(owner: Fighter): return owner.attack_cooldown <= 0 and not owner.attacking, Callable(_attack)),
		Skill.new("skill1", "影缚·袭", 720, 15, func(owner: Fighter): return not owner.shadow_trap_active, Callable(_skill1)),
		Skill.new("skill2", "幻影·舞", 1200, 25, Callable(), Callable(_skill2)),
		Skill.new("ult", "影舞流·居合", 480, 100, func(owner: Fighter): return owner.energy >= 100 and not owner.iaido_active, Callable(_ult)),
	]

static func _attack(owner: Fighter) -> Dictionary:
	owner.attacking = true
	owner.attack_timer = 68
	owner.attack_delay = 8
	owner.attack_hit_dealt = false
	owner.attack_cooldown = 60
	owner.state = "attack"
	return {"success": true}

static func _skill1(owner: Fighter) -> Dictionary:
	owner.pending_trap = true
	owner.last_skill_time = GameWorld.frame
	Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 20, Color(0.4, 0.2, 0.67), 4, 6, "star")
	return {"success": true}

static func _skill2(owner: Fighter) -> Dictionary:
	owner.pending_clones = true
	owner.clone_reveal_timer = 30
	owner.last_skill_time = GameWorld.frame
	Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 30, Color(0.53, 0.27, 0.8), 5, 7, "star")
	return {"success": true}

static func _ult(owner: Fighter) -> Dictionary:
	if owner.iaido_active:
		return {"success": false}

	var dir = owner.facing
	owner.iaido_active = true
	owner.iaido_timer = 60      # 大招持续 1 秒（60 帧）
	owner.iaido_dir = dir
	owner.iaido_frozen = true
	owner.iaido_slash = {
		"x": owner.pos_x + (owner.w if dir == 1 else -360),
		"y": owner.pos_y - 4,
		"w": 360, "h": owner.h + 8,
		"dir": dir, "hit_dealt": false
	}

	Fighter.emit_particles(owner.pos_x + owner.w / 2.0, owner.pos_y + owner.h / 2.0, 40, Color(0.53, 0.27, 0.8), 8, 10, "star")
	return {"success": true}

# ══════════════════════════════════════════════════════════════════
#  handle_input — 玩家输入处理（从 input_handler.gd 迁移至此）
# ══════════════════════════════════════════════════════════════════
static func handle_input(p: Fighter, keys: Dictionary) -> int:
	# 居合定格期间冻结所有输入
	if p.iaido_active and p.iaido_frozen:
		p.vx = 0
		return 0

	var mx = 0
	if not p.dashing:
		if keys.left: mx = -1
		if keys.right: mx = 1
		if keys.up and p.grounded: p.vy = -10; p.grounded = false

	# 攻击键：破影一击 / 夜樱·隐 / 普通斩
	if keys.attack and not p.attacking:
		if p.stealth_active:
			# 隐身中：破影一击（前冲突进）
			p.dashing = true; p.dash_remaining = 60; p.dash_dir = p.facing
			p.dash_speed = 6.0; p.dash_damage_dealt = false
			p.break_strike_timer = 60
			p.stealth_active = false
			Fighter.emit_particles(p.pos_x + p.w / 2.0, p.pos_y + p.h / 2.0, 20, Color(0.53, 0.27, 0.8), 4, 6, "star")
			keys.attack = false
		elif GameWorld.frame - p.last_skill_time <= 60:
			# 夜樱·隐窗口：后撤隐身
			p.stealth_active = true; p.stealth_timer = 150   # 2.5 秒
			p.retreat_timer = 15; p.retreat_dir = p.facing
			p.is_invincible = true; p.invincible_timer = 60  # 1 秒无敌
			p.dashing = true; p.dash_remaining = 80
			p.dash_dir = -p.facing; p.dash_speed = 5.0
			p.dash_damage_dealt = true   # 后撤不造成突进伤害
			p.last_skill_time = -999     # 消耗窗口
			Fighter.emit_particles(p.pos_x + p.w / 2.0, p.pos_y + p.h / 2.0, 24, Color(0.4, 0.2, 0.67), 5, 7, "star")
			keys.attack = false
		else:
			var s = p.get_skill("attack")
			if s: var r = s.try_use(p); if r.get("success"): keys.attack = false

	# 技能/大招使用即解除隐身
	if keys.skill1:
		var s = p.get_skill("skill1")
		if s: var r = s.try_use(p); if r.get("success"): p.stealth_active = false; keys.skill1 = false
	if keys.skill2:
		var s = p.get_skill("skill2")
		if s: var r = s.try_use(p); if r.get("success"): p.stealth_active = false; keys.skill2 = false
	if keys.ult:
		var s = p.get_skill("ult")
		if s: var r = s.try_use(p); if r.get("success"): p.stealth_active = false; keys.ult = false

	# 水平移动（分身+1.1 倍速）
	if not p.has_status("frozen") and not p.dashing:
		var has_ph = GameWorld.phantoms.size() > 0
		var boost = 1.1 if has_ph else 1.0
		p.vx += mx * 0.25 * boost
		if absf(p.vx) > 2.25 * boost: p.vx = 2.25 * boost * signf(p.vx)

	Fighter.update_state(p, mx)
	return mx

# ══════════════════════════════════════════════════════════════════
#  update_systems — 每帧逻辑（CharacterSystems 调度）
#FIXED BUG: 影武者之前缺少update_systems(),导致:
#  1)大招"居合"永久卡死(iaido_timer不递减,iaido_frozen永不解除)
#  2)隐身永不过期(stealth_timer不递减)
#  3)二技能分身闪退(用Fighter.new()创建,AI访问ph.x不存在)
#修复:补全完整状态机 — 无敌计时/隐身/破隐一击/居合命中检测+爆炸/暗影替身/分身生成
# ══════════════════════════════════════════════════════════════════
static func update_systems(f: Fighter):
	if f.char_id != "shadowwarrior" or f.hp <= 0:
		return

	# ── 无敌计时 ──
	if f.is_invincible:
		f.invincible_timer -= 1
		if f.invincible_timer <= 0: f.is_invincible = false

	# ── 后撤计时 ──
	if f.retreat_timer > 0: f.retreat_timer -= 1

	# ── 破影一击计时 ──
	if f.break_strike_timer > 0:
		if not f.dashing: f.break_strike_timer = 0
		else: f.break_strike_timer -= 1

	# ── 隐身计时 ──
	if f.stealth_active:
		f.stealth_timer -= 1
		if f.stealth_timer <= 0: f.stealth_active = false

	# ── 幻影·舞遮挡贴图计时 ──
	if f.clone_reveal_timer > 0: f.clone_reveal_timer -= 1

	# ── AI 夜樱·隐自动触发 ──
	if f != GameWorld.player and not f.stealth_active and not f.iaido_active:
		var delta = GameWorld.frame - f.last_skill_time
		if delta > 0 and delta <= 60:
			f.stealth_active = true; f.stealth_timer = 150
			f.retreat_timer = 15; f.retreat_dir = f.facing
			f.is_invincible = true; f.invincible_timer = 60
			f.dashing = true; f.dash_remaining = 80
			f.dash_dir = -f.facing; f.dash_speed = 5.0
			f.dash_damage_dealt = true
			f.last_skill_time = -999
			Fighter.emit_particles(f.pos_x + f.w / 2.0, f.pos_y + f.h / 2.0, 24, Color(0.4, 0.2, 0.67), 5, 7, "star")

	# ── 居合大招更新 ──
	if f.iaido_active:
		# 前 20 帧前冲（14 px/帧）
		if f.iaido_timer > 40:
			f.pos_x = clampf(f.pos_x + f.iaido_dir * 14, 10, 2400 - 10 - f.w)
		f.vx = 0; f.vy = 0

		var target = GameWorld.get_opponent(f)
		var slash = f.iaido_slash
		if not slash.is_empty() and target and target.hp > 0:
			var slash_rect = Rect2(slash["x"], slash["y"], slash["w"], slash["h"])
			if slash_rect.intersects(target.get_hit_box()):
				if not slash["hit_dealt"]:
					# 首次命中：斩击 10 点 + 标记
					Fighter.apply_damage(target, 10, f)
					slash["hit_dealt"] = true
					Fighter.emit_slash(target.pos_x + target.w / 2.0, target.pos_y + target.h / 2.0, f.iaido_dir if f.iaido_dir > 0 else PI, Color(0.53, 0.27, 0.8))
				# 抓取持续：每帧刷新 frozen
				target.add_status("frozen")

		f.iaido_timer -= 1
		if f.iaido_timer <= 0:
			# 刀光爆炸
			if not slash.is_empty() and target and target.hp > 0:
				var sr = Rect2(slash["x"], slash["y"], slash["w"], slash["h"])
				if sr.intersects(target.get_hit_box()):
					Fighter.apply_damage(target, 30, f)
			# 解除抓取
			if target:
				target.statuses = target.statuses.filter(func(s): return s.id != "frozen")
			if not slash.is_empty():
				Fighter.emit_explosion(slash["x"] + slash["w"] / 2.0, slash["y"] + slash["h"] / 2.0, Color(0.53, 0.27, 0.8), 60)
			f.iaido_active = false; f.iaido_frozen = false; f.iaido_slash = {}
			f.state = "idle"

	# ── 暗影替身（陷阱） ──
	if f.pending_trap:
		f.shadow_trap = {
			"x": f.pos_x, "y": f.pos_y, "w": 40, "h": 56,
			"timer": 300, "anim": 0, "phase": "idle",
			"capture_timer": 0, "captured": null, "burst_timer": 0
		}
		f.shadow_trap_active = true; f.pending_trap = false

	if f.shadow_trap_active and not f.shadow_trap.is_empty():
		# 直接操作 f.shadow_trap，不用本地引用避免 Godot Dict 赋值不可靠
		f.shadow_trap["anim"] = f.shadow_trap["anim"] + 1
		f.shadow_trap["timer"] = f.shadow_trap["timer"] - 1

		# 全局超时
		if f.shadow_trap["timer"] <= 0:
			f.shadow_trap_active = false; f.shadow_trap = {}
			return

		var target = GameWorld.get_opponent(f)

		match f.shadow_trap["phase"]:
			"idle":
				if target and target.hp > 0:
					var trap_rect = Rect2(f.shadow_trap["x"], f.shadow_trap["y"], f.shadow_trap["w"], f.shadow_trap["h"])
					if trap_rect.intersects(target.get_hit_box()):
						f.shadow_trap["phase"] = "capture"
						f.shadow_trap["capture_timer"] = 45
						f.shadow_trap["captured"] = target
						Fighter.apply_damage(target, 5, f)
						target.add_status("frozen")
						Fighter.emit_particles(target.pos_x + target.w / 2.0, target.pos_y + target.h / 2.0, 20, Color(0.4, 0.2, 0.67), 4, 6, "circle")

			"capture":
				var cap: Fighter = f.shadow_trap["captured"]
				if cap and cap is Fighter and cap.hp > 0:
					cap.add_status("frozen")
					f.shadow_trap["x"] = cap.pos_x - 4
					f.shadow_trap["y"] = cap.pos_y
				f.shadow_trap["capture_timer"] = f.shadow_trap["capture_timer"] - 1
				if f.shadow_trap["capture_timer"] <= 0:
					if target and target.hp > 0:
						Fighter.apply_damage(target, 10, f)
					if cap and cap is Fighter:
						cap.statuses = cap.statuses.filter(func(s): return s.id != "frozen")
					var cx = f.shadow_trap["x"] + f.shadow_trap["w"] / 2.0
					var cy = f.shadow_trap["y"] + f.shadow_trap["h"] / 2.0
					Fighter.emit_explosion(cx, cy, Color(0.53, 0.27, 0.8), 50)
					f.shadow_trap["phase"] = "burst"
					f.shadow_trap["burst_timer"] = 18

			"burst":
				f.shadow_trap["burst_timer"] = f.shadow_trap["burst_timer"] - 1
				if f.shadow_trap["burst_timer"] <= 0:
					f.shadow_trap_active = false; f.shadow_trap = {}

	# ── 幻影分身生成 ──
	if f.pending_clones:
		for i in 2:
			GameWorld.phantoms.append({
				"x": f.pos_x + (-40 if i == 0 else 40), "y": f.pos_y,
				"w": 32, "h": 56, "vx": 0.0, "vy": 0.0,
				"hp": 10.0, "max_hp": 10.0,
				"facing": f.facing, "grounded": true,
				"owner": f, "state": "idle", "image_state": "idle",
				"attacking": false, "attack_timer": 0, "attack_cooldown": 0,
				"attack_delay": 0, "attack_hit_dealt": false,
				"hit_cd": 0, "alive": true, "life": 600
			})
		f.pending_clones = false

		# ── 幻影分身全局更新（每帧仅执行一次） ──
	if _last_phantom_frame != GameWorld.frame:
		_last_phantom_frame = GameWorld.frame
		_update_phantoms()
#FIX END

# ── 幻影分身更新逻辑 ──
static func _update_phantoms():
	var phantoms = GameWorld.phantoms
	var to_remove: Array = []

	for ph in phantoms:
		var owner: Fighter = ph.get("owner")
		if not owner or owner.hp <= 0 or ph["hp"] <= 0:
			Fighter.emit_particles(ph["x"] + ph["w"] / 2.0, ph["y"] + ph["h"] / 2.0, 20, Color(0.53, 0.27, 0.8), 4, 6, "star")
			to_remove.append(ph)
			continue

		ph["life"] -= 1
		if ph["life"] <= 0:
			Fighter.emit_particles(ph["x"] + ph["w"] / 2.0, ph["y"] + ph["h"] / 2.0, 20, Color(0.53, 0.27, 0.8), 4, 6, "star")
			to_remove.append(ph)
			continue

		if ph.get("hit_cd", 0) > 0: ph["hit_cd"] -= 1

		var target = GameWorld.get_opponent(owner)
		var px: float = ph["x"]; var py: float = ph["y"]

		# 简单 AI：朝敌人移动
		if target and target.hp > 0:
			var dx = target.pos_x - px
			var dist = absf(dx)
			ph["facing"] = 1 if dx > 0 else -1
			if dist > 46:
				ph["x"] += signf(dx) * 2.2
				ph["state"] = "walk"
			else:
				ph["state"] = "idle"
				# 到达攻击距离：胧月·斩
				if ph["attack_cooldown"] <= 0 and not ph["attacking"]:
					ph["attacking"] = true
					ph["attack_timer"] = 30
					ph["attack_delay"] = 8
					ph["attack_hit_dealt"] = false
					ph["attack_cooldown"] = 60
					ph["state"] = "attack"

		# 落地
		ph["y"] = 380 - ph["h"]  # GROUND_Y
		ph["grounded"] = true

		# 攻击命中判定
		if ph["attacking"]:
			ph["attack_timer"] -= 1
			if ph["attack_delay"] > 0:
				ph["attack_delay"] -= 1
				if ph["attack_delay"] <= 0 and not ph["attack_hit_dealt"]:
					ph["attack_hit_dealt"] = true
					if target and target.hp > 0:
						var ox = ph["w"] if ph["facing"] == 1 else -44
						var box = Rect2(ph["x"] + ox, ph["y"] + 6, 44, ph["h"] - 16)
						if box.intersects(target.get_hit_box()):
							Fighter.apply_damage(target, 5, owner)
							Fighter.emit_slash(target.pos_x + target.w / 2.0, target.pos_y + target.h / 2.0, 0 if ph["facing"] > 0 else PI, Color(0.53, 0.27, 0.8))
			if ph["attack_timer"] <= 0:
				ph["attacking"] = false; ph["state"] = "idle"; ph["image_state"] = "idle"
		if ph["attack_cooldown"] > 0: ph["attack_cooldown"] -= 1

		# 分身姿态
		ph["image_state"] = "attack" if ph["attacking"] else ("walk" if ph["state"] == "walk" else "idle")

		# 分身受击
		var foe = GameWorld.get_opponent(owner)
		if foe and foe.hp > 0:
			# 敌方近战攻击
			if foe.attacking and foe.attack_hit_dealt and ph.get("hit_cd", 0) <= 0:
				if foe.get_attack_box().intersects(Rect2(ph["x"] + 4, ph["y"] + 4, ph["w"] - 8, ph["h"] - 8)):
					ph["hp"] -= (foe.config.get("attack_damage", 5) if foe.config else 5)
					ph["hit_cd"] = 30
					Fighter.emit_particles(ph["x"] + ph["w"] / 2.0, ph["y"] + ph["h"] / 2.0, 12, Color(1, 0.53, 0.27), 3, 5, "star")
			# 敌方投射物
			var pj_to_remove: Array = []
			for pj in GameWorld.projectiles:
				var pj_owner: Fighter = pj.get("owner")
				if pj_owner == owner: continue  # 不受友方投射物影响
				var pr: Rect2 = Rect2(pj["x"], pj["y"], pj["w"], pj["h"])
				if pr.intersects(Rect2(ph["x"] + 4, ph["y"] + 4, ph["w"] - 8, ph["h"] - 8)):
					ph["hp"] -= (pj.get("damage", 5) as float)
					Fighter.emit_particles(ph["x"] + ph["w"] / 2.0, ph["y"] + ph["h"] / 2.0, 12, Color(1, 0.53, 0.27), 3, 5, "star")
					if not pj.get("piercing", false):
						pj_to_remove.append(pj)
			for pj in pj_to_remove:
				GameWorld.projectiles.erase(pj)

	# 清理死亡/超时分身
	for ph in to_remove:
		GameWorld.phantoms.erase(ph)
