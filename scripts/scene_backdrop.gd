extends Control
var texture: Texture2D = preload("res://assets/art/camp-observatory.webp")
var elapsed := 0.0
var dim := 0.42
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()
func _draw() -> void:
	if size.x<=0 or size.y<=0:
		return
	var factor := maxf(size.x/texture.get_width(),size.y/texture.get_height())
	var extent := texture.get_size()*factor*1.035
	var drift := Vector2(sin(elapsed*0.07)*5,cos(elapsed*0.09)*3)
	draw_texture_rect(texture,Rect2((size-extent)/2+drift,extent),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.045,0.07,dim))
	for i in range(22):
		var point := Vector2(fposmod(i*137.3+sin(elapsed*0.3+i)*15,size.x),fposmod(i*83.7-elapsed*(5+i%4),size.y))
		draw_circle(point,1.0+i%2,Color(0.55,0.9,0.83,0.15+0.12*sin(elapsed+i)))
