class_name GameParticle

var x: float
var y: float
var vx: float
var vy: float
var color: Color
var life: int
var max_life: int
var size: float
var type: String  # "circle", "rect", "star"
var alpha: float = 1.0

func _init(p_x: float, p_y: float, p_vx: float, p_vy: float, p_color: Color, 
		   p_life: int, p_size: float, p_type: String = "circle"):
	x = p_x
	y = p_y
	vx = p_vx
	vy = p_vy
	color = p_color
	life = p_life
	max_life = p_life
	size = p_size
	type = p_type

func update() -> bool:
	x += vx
	y += vy
	vy += 0.08
	life -= 1
	alpha = float(life) / float(max_life)
	size *= 0.97
	return life > 0 and size > 0.3

func draw(canvas: CanvasItem):
	var draw_color = Color(color.r, color.g, color.b, alpha * color.a)
	match type:
		"circle":
			canvas.draw_circle(Vector2(x, y), maxf(1.0, size), draw_color)
		"rect":
			canvas.draw_rect(Rect2(x - size/2, y - size/2, size, size), draw_color)
		"star":
			# Star is drawn as a small bright rectangle with glow
			canvas.draw_rect(Rect2(x - size/2, y - size/2, size, size), draw_color)
