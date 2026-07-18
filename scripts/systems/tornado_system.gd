class_name TornadoSystem

# ===== Tornado & Vortex System =====
static func update_tornadoes():
	for i in range(GameWorld.tornadoes.size() - 1, -1, -1):
		var t = GameWorld.tornadoes[i]
		t["life"] -= 1
		if t["life"] <= 0: GameWorld.tornadoes.remove_at(i); continue
		var target = GameWorld.get_opponent(t["owner"])
		if target and target.hp > 0:
			var dx2 = (t["x"]+t["w"]/2)-(target.pos_x+target.w/2)
			var dy2 = (t["y"]+t["h"]/2)-(target.pos_y+target.h/2)
			var d2 = sqrt(dx2*dx2+dy2*dy2)
			if d2 < 150:
				var pull = t.get("pull_strength", 0.3)
				var ang = atan2(dy2, dx2)
				target.vx += cos(ang)*pull; target.vy += sin(ang)*pull*0.5
			# Periodic damage when target overlaps tornado rect
			if target.get_hit_box().intersects(Rect2(t["x"], t["y"], t["w"], t["h"])):
				t["timer"] = t.get("timer", 0) + 1
				var ti = t.get("tick_interval", 60)
				if t["timer"] >= ti:
					t["timer"] = 0
					Fighter.apply_damage(target, t["damage"], t["owner"], false)
	for i in range(GameWorld.vortexes.size()-1,-1,-1):
		var v = GameWorld.vortexes[i]
		v["life"] -= 1
		if v["life"] <= 0: GameWorld.vortexes.remove_at(i); continue
		var target = GameWorld.get_opponent(v["owner"])
		if target and target.hp > 0:
			var dx2 = (v["x"]+v["w"]/2)-(target.pos_x+target.w/2)
			var dy2 = (v["y"]+v["h"]/2)-(target.pos_y+target.h/2)
			var d2 = sqrt(dx2*dx2+dy2*dy2)
			if d2 < 130:
				var pull = v.get("pull_strength", 0.4)
				var ang = atan2(dy2, dx2)
				target.vx += cos(ang)*pull; target.vy += sin(ang)*pull*0.4
			# Periodic damage when target overlaps vortex rect
			if target.get_hit_box().intersects(Rect2(v["x"], v["y"], v["w"], v["h"])):
				v["timer"] = v.get("timer", 0) + 1
				var ti = v.get("tick_interval", 30)
				if v["timer"] >= ti:
					v["timer"] = 0
					Fighter.apply_damage(target, v["damage"], v["owner"], false)
