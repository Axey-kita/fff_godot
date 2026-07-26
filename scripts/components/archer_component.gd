class_name ArcherComponent
extends CharComponent

var arrows: int = 10
var max_arrows: int = 10
var arrow_regen_timer: int = 0
var arrow_regen_rate: int = 480
var fire_arrow_buff: bool = false
var fire_arrow_timer: int = 0
var tracking_buff: bool = false
var tracking_timer: int = 0

func init(owner: Fighter):
	super.init(owner)
	arrows = max_arrows

func update():
	if arrows < max_arrows:
		arrow_regen_timer += 1
		if arrow_regen_timer >= arrow_regen_rate:
			arrow_regen_timer = 0
			arrows = min(max_arrows, arrows + 1)
	if fire_arrow_buff and fire_arrow_timer > 0:
		fire_arrow_timer -= 1
		if fire_arrow_timer <= 0:
			fire_arrow_buff = false
	if tracking_buff and tracking_timer > 0:
		tracking_timer -= 1
		if tracking_timer <= 0:
			tracking_buff = false