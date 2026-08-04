class_name RenderSystem

const BG_IMG = preload("res://assets/bg_battlefield.png")
const SHIELD_IMG = preload("res://assets/fx_shield.png")
const FLAME_IMG = preload("res://assets/fx_flame.png")

## 入口：绘制整帧
static func draw_frame(game_node: CanvasItem):
	var cam_x = GameWorld.camera.x
	var cam_y = GameWorld.camera.y
	var font = ThemeDB.fallback_font

	# 1. 地图
	_draw_map(game_node, cam_x, cam_y)

	# 2. 角色实体
	var has_fullscreen_overlay = false
	for entry in GameWorld.active_overlays:
		if entry.get("position", {}).get("type") == "fullscreen":
			has_fullscreen_overlay = true
			break
	if not has_fullscreen_overlay:
		if is_instance_valid(GameWorld.player):
			_draw_fighter(game_node, GameWorld.player, cam_x, cam_y, true)
		if is_instance_valid(GameWorld.enemy):
			_draw_fighter(game_node, GameWorld.enemy, cam_x, cam_y, GameWorld.game_mode == "pvp")

	# 3. 投射物
	_draw_projectiles(game_node, cam_x, cam_y)

	# 4. 火焰区域
	_draw_flame_zones(game_node, cam_x, cam_y)

	# 5. 掉落物
	for p in GameWorld.pickups:
		p.draw(game_node, cam_x, cam_y)

	# 6. 蓄力条
	if is_instance_valid(GameWorld.player):
		HudSystem.draw_charge_bar(game_node, GameWorld.player, cam_x, cam_y)
	if GameWorld.game_mode == "pvp" and is_instance_valid(GameWorld.enemy):
		HudSystem.draw_charge_bar(game_node, GameWorld.enemy, cam_x, cam_y)

	# 7. 粒子
	for pt in GameWorld.particles:
		pt.draw(game_node, cam_x, cam_y)

	# 8. 爆炸特效
	for e in GameWorld.explosion_effects:
		var px = e.x - cam_x
		var py = e.y - cam_y
		var alpha = e.get("alpha", 0.8)
		game_node.draw_circle(Vector2(px + e.w / 2.0, py + e.h / 2.0), e.w / 2.0, Color(1.0, 0.533, 0.267, alpha))

	# 9. 角色注入的绘制回调
	for entry in GameWorld.draw_effect_callbacks:
		var cb: Callable = entry.get("cb")
		if not (cb and cb.is_valid()):
			continue
		var items: Array = cb.call(font, cam_x, cam_y)
		if items == null: continue
		for item in items:
			_exec_draw_item(game_node, item, font)

	# 10. Overlay 动画
	for entry in GameWorld.active_overlays:
		var overlay_anim: FrameAnimation = entry["anim"]
		if not overlay_anim or not overlay_anim.is_playing():
			continue
		var tex = overlay_anim.get_current_texture()
		if not tex:
			continue
		var pos = entry.get("position", {})
		match pos.get("type", ""):
			"fullscreen":
				game_node.draw_texture_rect(tex, Rect2(0, 0, Constants.W, Constants.H), false)
				var progress = overlay_anim.get_progress()
				var border_color = entry.get("border_color", Color(0.9, 0.15, 0.15))
				var border_alpha = 0.3 + sin(progress * PI * 6) * 0.2
				game_node.draw_rect(Rect2(0, 0, Constants.W, Constants.H), Color(border_color.r, border_color.g, border_color.b, border_alpha), false, 8)
			"fixed":
				var rect: Rect2 = pos.get("rect", Rect2())
				game_node.draw_texture_rect(tex, rect, false)
			"follow":
				var target = pos.get("target")
				if target and target is Fighter and target.hp > 0:
					var sx = target.pos_x - cam_x + target.w / 2.0 + pos.get("offset", Vector2.ZERO).x
					var sy = target.pos_y - cam_y + target.h / 2.0 + pos.get("offset", Vector2.ZERO).y
					var sc = pos.get("scale", Vector2.ONE)
					var tw = target.w * sc.x
					var th = target.h * sc.y
					if target.facing < 0:
						game_node.draw_set_transform(Vector2(sx, sy), 0.0, Vector2(-sc.x, sc.y))
						game_node.draw_texture_rect(tex, Rect2(-tw / 2.0, -th / 2.0, tw, th), false)
						game_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					else:
						game_node.draw_set_transform(Vector2(sx, sy), 0.0, Vector2(sc.x, sc.y))
						game_node.draw_texture_rect(tex, Rect2(-tw / 2.0, -th / 2.0, tw, th), false)
						game_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"world":
				var wx = pos.get("x", 0.0) - cam_x
				var wy = pos.get("y", 0.0) - cam_y
				var sc = pos.get("scale", Vector2.ONE)
				game_node.draw_texture_rect(tex, Rect2(wx, wy, tex.get_width() * sc.x, tex.get_height() * sc.y), false)

	# 11. 减速滤镜
	var dodge_slow = false
	for f in GameWorld.entities:
		if f.state_flags.get("dodge_slow", 0) > 0:
			dodge_slow = true
			break
	if dodge_slow or GameWorld.slow_mo_timer > 0:
		game_node.draw_rect(Rect2(0, 0, Constants.W, Constants.H), Color(0.471, 0.314, 0.784, 0.12))

	# 12. HUD
	HudSystem.draw(game_node, font)

	# 13. Debug
	game_node.draw_string(font, Vector2(10, Constants.H - 10), "frame:" + str(GameWorld.frame) + " particles:" + str(GameWorld.particles.size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.667, 0.667, 0.667))

# ===== 地图 =====
static func _draw_map(game_node: CanvasItem, cam_x: float, cam_y: float):
	var bg_tex = BG_IMG
	if GameWorld.astrologer_ult_end_frame > 0 and GameWorld.astrologer_ult_bg:
		bg_tex = GameWorld.astrologer_ult_bg
	if bg_tex:
		game_node.draw_texture_rect(bg_tex, Rect2(-cam_x * 0.2, -cam_y * 0.3, Constants.W + 200, Constants.H + 100), false)
	else:
		var from_color = Color(0.102, 0.102, 0.18)
		var to_color = Color(0.169, 0.137, 0.267)
		game_node.draw_rect(Rect2(0, -cam_y, Constants.W, Constants.H * 0.5), from_color)
		game_node.draw_rect(Rect2(0, Constants.H * 0.5 - cam_y, Constants.W, Constants.H * 0.5), to_color)

	for i in range(8):
		var mx = fmod(i * 280 - cam_x * 0.2, Constants.W + 200) - 100
		var my = Constants.GROUND_Y - 60 - sin(i * 1.5) * 30 - cam_y
		var pts = PackedVector2Array([
			Vector2(mx, Constants.GROUND_Y - cam_y),
			Vector2(mx + 120, my),
			Vector2(mx + 240, Constants.GROUND_Y - cam_y)
		])
		game_node.draw_polygon(pts, PackedColorArray([Color(0.267, 0.267, 0.424, 0.3)]))

	for pl in GameWorld.platforms:
		var sx = pl["x"] - cam_x
		var sy = pl["y"] - cam_y
		if sx < -pl["w"] - 20 or sx > Constants.W + 20:
			continue
		var ttype = pl.get("terrain_type", -1)
		if ttype == 0:
			game_node.draw_rect(Rect2(sx, sy, pl["w"], pl["h"]), Color(0.227, 0.227, 0.322))
			game_node.draw_rect(Rect2(sx, sy, pl["w"], 3), Color(0.31, 0.31, 0.435))
		elif ttype == 1:
			game_node.draw_rect(Rect2(sx, sy, pl["w"], pl["h"]), Color(0.18, 0.18, 0.28))
			game_node.draw_rect(Rect2(sx, sy, pl["w"], pl["h"]), Color(0.3, 0.22, 0.45, 0.3), false, 2)
		elif ttype == 2 or ttype == -1:
			game_node.draw_rect(Rect2(sx, sy, pl["w"], pl["h"]), Color(0.416, 0.298, 0.612))
			game_node.draw_rect(Rect2(sx + 4, sy - 2, pl["w"] - 8, 4), Color(0.541, 0.424, 0.737))
			game_node.draw_rect(Rect2(sx + 4, sy + pl["h"], pl["w"] - 8, 4), Color(0, 0, 0, 0.3))
		elif ttype == 3:
			game_node.draw_rect(Rect2(sx, sy, pl["w"], pl["h"]), Color(0.102, 0.039, 0.18))
			game_node.draw_rect(Rect2(sx, sy, pl["w"], 2), Color(0.416, 0.227, 0.667, 0.6))

	game_node.draw_rect(Rect2(0 - cam_x, Constants.GROUND_Y - cam_y - 10, 10, 10), Color(0.914, 0.271, 0.157))
	game_node.draw_rect(Rect2(Constants.MAP_W - 10 - cam_x, Constants.GROUND_Y - cam_y - 10, 10, 10), Color(0.914, 0.271, 0.157))

# ===== 角色实体 =====
static func _draw_fighter(game_node: CanvasItem, f: Fighter, cam_x: float, cam_y: float, is_local: bool = false):
	if not f:
		return
	var px = f.pos_x - cam_x
	var py = f.pos_y - cam_y
	if px < -80 or px > 880:
		return

	if f.state_flags.get("skip_fighter_draw", false):
		return

	var alpha_mod = f.state_flags.get("draw_alpha_mod", 1.0)
	if f.damage_flash > 0 and f.damage_flash % 4 < 2:
		alpha_mod = 0.5

	var tex: Texture2D = f.state_flags.get("draw_texture_override") if f.state_flags.has("draw_texture_override") else null
	if not tex:
		var anim: FrameAnimation = f.current_anim
		if anim:
			tex = anim.get_current_texture()
	if not tex:
		var imgs = f.config.get("images", {})
		var tex_key = f.image_state if imgs.has(f.image_state) else "idle"
		tex = imgs.get(tex_key)
	if not tex:
		push_warning("FrameAnimation: No texture for " + f.char_id + " image_state=" + f.image_state)

	if tex is Texture2D:
		var tw: float = tex.get_width()
		var th: float = tex.get_height()
		var img_scale = f.config.get("image_scale", 1.0)
		# 普攻贴图独立缩放
		if f.attacking and f.config.has("attack_image_scale"):
			img_scale = f.config.get("attack_image_scale")
		var scale = minf(f.w / tw, f.h / th) * img_scale
		tw *= scale; th *= scale
		var tx = px + (f.w - tw) / 2.0
		var ty = py + f.h - th
		if f.facing < 0:
			game_node.draw_set_transform(Vector2(tx + tw, ty), 0.0, Vector2(-1, 1))
			game_node.draw_texture_rect(tex, Rect2(0, 0, tw, th), false, Color(1, 1, 1, alpha_mod))
			game_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			game_node.draw_texture_rect(tex, Rect2(tx, ty, tw, th), false, Color(1, 1, 1, alpha_mod))
	else:
		var c = Color(0.2, 0.6, 1.0, alpha_mod) if f.is_player else Color(1.0, 0.2, 0.2, alpha_mod)
		game_node.draw_rect(Rect2(px, py, f.w, f.h), c)

	# 护盾光环
	if f.shield_active and SHIELD_IMG:
		var sw: float = SHIELD_IMG.get_width()
		var sh: float = SHIELD_IMG.get_height()
		game_node.draw_texture_rect(SHIELD_IMG, Rect2(px + f.w / 2.0 - sw / 2.0, py + f.h / 2.0 - sh / 2.0, sw, sh), false, Color(1,1,1,0.6))

	# 角色注入的覆盖绘制
	for ov in f.draw_overrides:
		var ov_cb: Callable = ov.get("cb")
		if ov_cb and ov_cb.is_valid():
			ov_cb.call(px)

	# Paladin 神圣光环
	var pa = f.state_flags.get("paladin_aura")
	if pa:
		var cx = px + f.w / 2.0; var cy = py + f.h / 2.0; var r = maxf(f.w, f.h) * 0.75
		game_node.draw_arc(Vector2(cx, cy), r, 0, PI * 2, 32, Color(1.0, 0.843, 0.0, pa["shield_alpha"]), 4)
		if pa["holy_active"]:
			game_node.draw_circle(Vector2(cx, cy), maxf(f.w, f.h) * 1.18, Color(1.0, 0.843, 0.0, 0.12))

	# 状态效果
	for s in f.statuses:
		if s.timer <= 0:
			continue
		if s.freeze:
			game_node.draw_rect(Rect2(px, py, f.w, f.h), Color(1.0, 1.0, 1.0, 0.5))
		elif s.vfx_color:
			game_node.draw_rect(Rect2(px, py, f.w, f.h), Color(s.vfx_color.r, s.vfx_color.g, s.vfx_color.b, 0.4))

	# HP bar
	var hp_pct = f.hp / maxf(f.max_hp, 1.0)
	game_node.draw_rect(Rect2(px, py - 8, f.w, 4), Color(0.2, 0.2, 0.2))
	game_node.draw_rect(Rect2(px, py - 8, f.w * hp_pct, 4), Color(0.27, 0.67, 0.27))

	# Label
	var lbl = "P1" if f.is_player else ("P2" if is_local else "AI")
	var lbl_color = Color.WHITE if f.is_player else (Color(0.0, 0.667, 1.0) if is_local else Color.RED)
	var lbl_font = ThemeDB.fallback_font
	game_node.draw_string(lbl_font, Vector2(px, py - 12), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lbl_color)

# ===== 投射物 =====
static func _draw_projectiles(game_node: CanvasItem, cam_x: float, cam_y: float):
	for p in GameWorld.projectiles:
		var px = p["x"] - cam_x
		var py = p["y"] - cam_y
		if px < -50 or px > Constants.W + 50:
			continue
		var pc = p.get("color", Color(0.533, 0.867, 1.0))
		var pimg = p.get("img")
		if pimg is Texture2D:
			if p.get("vx", 0) < 0:
				game_node.draw_set_transform(Vector2(px + p["w"], py), 0.0, Vector2(-1, 1))
				game_node.draw_texture_rect(pimg, Rect2(0, 0, p["w"], p["h"]), false, Color(1,1,1,0.8))
				game_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				game_node.draw_texture_rect(pimg, Rect2(px, py, p["w"], p["h"]), false, Color(1,1,1,0.8))
		else:
			game_node.draw_rect(Rect2(px, py, p["w"], p["h"]), pc)
			game_node.draw_rect(Rect2(px + 4, py + 4, p["w"] - 8, p["h"] - 8), Color.WHITE)
		if GameWorld.frame % 2 == 0:
			Fighter.emit_particles(p["x"] + p["w"] / 2.0, p["y"] + p["h"] / 2.0, 3, pc, 2, 4, "circle")

# ===== 火焰区域 =====
static func _draw_flame_zones(game_node: CanvasItem, cam_x: float, cam_y: float):
	for fz in GameWorld.flame_zones:
		var px = fz["x"] - cam_x
		var py = fz["y"] - cam_y
		if px < -50 or px > Constants.W + 50:
			continue
		if FLAME_IMG:
			game_node.draw_texture_rect(FLAME_IMG, Rect2(px, py, fz["w"], fz["h"]), false, Color(1,1,1,0.8))
		else:
			game_node.draw_rect(Rect2(px, py, fz["w"], fz["h"]), Color(1.0, 0.267, 0.0, 0.8))

# ===== 绘制指令执行器 =====
static func _exec_draw_item(game_node: CanvasItem, item: Dictionary, font: Font):
	match item.get("type"):
		"set_transform":
			game_node.draw_set_transform(item["pos"], item.get("rot", 0.0), item["scale"])
		"tex":
			game_node.draw_texture_rect(item["tex"], item["rect"], false, item.get("color", Color.WHITE))
		"rect":
			game_node.draw_rect(item["rect"], item["color"], item.get("filled", true), item.get("border_width", -1.0))
		"circle":
			game_node.draw_circle(item["pos"], item["radius"], item["color"])
		"arc":
			game_node.draw_arc(item["pos"], item["radius"], item["start"], item["end"], item["segments"], item["color"], item.get("width", 1.0))
		"string":
			game_node.draw_string(font, item["pos"], item["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, item.get("size", 10), item.get("color", Color.WHITE))
		"reset_transform":
			game_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
