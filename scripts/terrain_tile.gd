@tool
extends Sprite2D
class_name TerrainTile
## 地形块 — 在编辑器中可视化编辑地图,运行时生成纹理并标识地形类型

enum TileType {
	GROUND,    # 地面（平台 + 底部渲染）
	WALL,      # 墙壁（边界阻挡）
	PLATFORM,  # 平台（可站立）
	VOID,      # 虚空（掉落即死,未来效果）
	FIRE,      # 火焰（持续伤害区域,未来效果）
	WATER,     # 水域（减速/浮力,未来效果）
}

## 地形类型
@export var tile_type: TileType = TileType.PLATFORM:
	set(v):
		tile_type = v
		_generate_texture()

## 块宽度（像素）
@export var block_w: int = 32:
	set(v):
		block_w = maxi(8, v)
		_generate_texture()

## 块高度（像素）
@export var block_h: int = 32:
	set(v):
		block_h = maxi(8, v)
		_generate_texture()

# 每种地形的颜色方案
const _COLORS := {
	TileType.GROUND:    { "base": Color("3a3a52"), "light": Color("4a4a66"), "dark": Color("2a2a3e") },
	TileType.WALL:      { "base": Color("2e2e3e"), "light": Color("3e3e52"), "dark": Color("1e1e2e") },
	TileType.PLATFORM:  { "base": Color("6a4c9c"), "light": Color("8a6abc"), "dark": Color("4e3078") },
	TileType.VOID:      { "base": Color("1a0a2e"), "light": Color("2a1a4e"), "dark": Color("0e0520"), "glow": Color("6a3aaa") },
	TileType.FIRE:      { "base": Color("cc4400"), "light": Color("ee6622"), "dark": Color("882200") },
	TileType.WATER:     { "base": Color("1a5a8a"), "light": Color("2a7aaa"), "dark": Color("0e3a5e") },
}

func _ready():
	centered = false
	# 已从 .tscn 加载纹理则不重建，保持与编辑器一致
	if texture == null:
		_generate_texture()

func _generate_texture():
	var w = maxi(block_w, 8)
	var h = maxi(block_h, 8)
	centered = false
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var colors = _COLORS.get(tile_type, _COLORS[TileType.PLATFORM])
	
	# 逐像素绘制
	for y in range(h):
		for x in range(w):
			var c: Color
			# 边框（2px 暗边）
			if x < 2 or x >= w - 2 or y < 2 or y >= h - 2:
				c = colors["dark"]
			# 上/左边高光（模拟光照）
			elif x < 4 or y < 4:
				c = colors["light"]
			# 内部
			else:
				c = colors["base"]
				# 砖纹：每 16px 加一条细线
				if x % 16 < 1 or y % 16 < 1:
					c = c.darkened(0.15)
			# 特殊地形叠加效果
			if tile_type == TileType.VOID:
				# 虚空: 底部紫色光晕
				var glow_dist = float(y) / float(h)
				if glow_dist > 0.6:
					c = c.blend(Color(0.4, 0.2, 0.67, (glow_dist - 0.6) * 2.5))
			elif tile_type == TileType.FIRE:
				# 火焰: 顶部橙色脉冲（静态版）
				var pulse = float(h - y) / float(h)
				if pulse > 0.7:
					c = c.blend(Color(1.0, 0.6, 0.0, (pulse - 0.7) * 2.0))
			elif tile_type == TileType.WATER:
				# 水域: 顶部浅蓝透明感
				var water_top = float(h - y) / float(h)
				if water_top < 0.3:
					c = c.blend(Color(0.5, 0.8, 1.0, (0.3 - water_top) * 1.5))
			img.set_pixel(x, y, c)
	
	texture = ImageTexture.create_from_image(img)
	
	# 设置 Sprite2D 的缩放和区域以匹配 block_w/block_h
	var tex_w = texture.get_width()
	var tex_h = texture.get_height()
	scale = Vector2(1, 1)
	region_enabled = false
	# 用 scale 来适配实际显示大小
	if tex_w > 0 and tex_h > 0:
		scale = Vector2(float(w) / float(tex_w), float(h) / float(tex_h))
