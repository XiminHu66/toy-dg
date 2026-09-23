extends Control
signal cell_clicked(point: Vector2i)
var session: RefCounted
var selected := ""
var mode := "move"
var font: Font
var cell := 72.0
var origin := Vector2(24,24)
var hover := Vector2i(-1,-1)
var flash_time := 0.0
var last_position := Vector2.ZERO
var token_position := Vector2.ZERO
var initialized := false

func _ready() -> void:
	custom_minimum_size = Vector2(624,410)
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if session == null or session.player.is_empty():
		return
	var destination := center(session.player.position)
	if not initialized:
		token_position = destination
		initialized = true
	token_position = token_position.lerp(destination,minf(1.0,delta*18.0))
	flash_time = maxf(0.0,flash_time-delta)
	queue_redraw()

func animate() -> void:
	flash_time = 0.55

func center(point: Vector2i) -> Vector2:
	return origin + Vector2(point)*cell + Vector2.ONE*cell*0.5

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = Vector2i((event.position-origin)/cell)
		if event.position.x < origin.x or event.position.y < origin.y:
			hover = Vector2i(-1,-1)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point := Vector2i((event.position-origin)/cell)
		if event.position.x >= origin.x and event.position.y >= origin.y and session.inside(point):
			cell_clicked.emit(point)

func _draw() -> void:
	if session == null:
		return
	cell = minf((size.x-48)/8.0,(size.y-48)/6.0)
	origin = Vector2((size.x-cell*8)/2.0,(size.y-cell*6)/2.0)
	for y in range(6):
		for x in range(8):
			var point := Vector2i(x,y)
			var rect := Rect2(origin+Vector2(point)*cell,Vector2.ONE*(cell-3))
			var color := Color("162532") if (x+y)%2 == 0 else Color("14212e")
			var route: Array = session.path(session.player.position,point)
			if session.player_turn and not route.is_empty() and route.size() <= session.movement:
				color = Color("193d43")
			if mode == "shadow" and session.player.shadowstep > 0 and not session.occupied(point) and session.distance(session.player.position,point) <= 3:
				color = Color("38304e")
			draw_style_box(tile_style(color),rect)
			if session.walls.has(point):
				draw_rect(rect.grow(-5),Color("344252"))
				draw_line(rect.position+Vector2(8,10),rect.end-Vector2(8,10),Color("566270"),2)
				draw_line(rect.position+Vector2(8,rect.size.y-10),rect.position+Vector2(rect.size.x-8,10),Color("566270"),2)
			if point == hover:
				draw_rect(rect,Color("68d9c4"),false,2)
	if session.inside(hover):
		var route: Array = session.path(session.player.position,hover)
		var previous := center(session.player.position)
		for point in route:
			draw_line(previous,center(point),Color(0.4,0.9,0.8,0.35),3)
			previous = center(point)
	for target in session.enemies:
		if target.hp <= 0:
			continue
		var position_value := center(target.position)
		if target.id == selected:
			draw_arc(position_value,cell*0.42,0,TAU,32,Color("f3c27a"),3)
		unit(position_value,target,false)
	unit(token_position,session.player,true)
	if flash_time > 0 and session.last_result.get("kind","") == "attack":
		var result: Dictionary = session.last_result
		var a := center(result.actor)
		var b := center(result.target)
		draw_line(a,b,Color(1,0.85,0.55,flash_time),5)
		var label := "-%d" % result.damage if result.hit else "闪避"
		if result.get("crit",false):
			label = "暴击 " + label
		draw_string(font,b+Vector2(-24,-35-(0.55-flash_time)*30),label,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("ffe0a1"))

func tile_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	return style

func unit(point: Vector2,stats: Dictionary,hero: bool) -> void:
	var scale_value := cell/72.0
	draw_set_transform(point,0,Vector2.ONE*scale_value)
	draw_circle(Vector2(0,15),22,Color(0,0,0,0.3))
	if hero:
		draw_colored_polygon(PackedVector2Array([Vector2(-12,-4),Vector2(12,-4),Vector2(20,18),Vector2(-18,18)]),Color("dde4ec"))
		draw_rect(Rect2(-15,1,9,18),Color("355c63"))
		draw_line(Vector2(-7,17),Vector2(-10,23),Color("788991"),5)
		draw_line(Vector2(7,17),Vector2(10,23),Color("788991"),5)
		draw_circle(Vector2(0,-13),12,Color("f3d6c4"))
		draw_colored_polygon(PackedVector2Array([Vector2(-13,-8),Vector2(-12,-24),Vector2(2,-28),Vector2(14,-19),Vector2(11,-8),Vector2(5,-18),Vector2(-3,-13),Vector2(-4,-20)]),Color("dfe9f6"))
		draw_line(Vector2(-6,-12),Vector2(-3,-12),Color("388fa3"),2)
		draw_line(Vector2(4,-12),Vector2(7,-12),Color("388fa3"),2)
		draw_line(Vector2(-8,-2),Vector2(13,5),Color("cb6169"),5)
		draw_line(Vector2(15,7),Vector2(25,-12),Color("9ddbcf"),4)
	else:
		var body := Color("b77364") if stats.id != "warden" else Color("b791d7")
		draw_colored_polygon(PackedVector2Array([Vector2(-17,-7),Vector2(-10,-22),Vector2(12,-22),Vector2(19,-3),Vector2(12,18),Vector2(-13,18)]),body)
		draw_rect(Rect2(-11,-10,22,8),Color("202a34"))
		draw_line(Vector2(-6,-6),Vector2(6,-6),Color("ffc384"),3)
		draw_line(Vector2(-14,16),Vector2(-21,23),body,5)
		draw_line(Vector2(14,16),Vector2(21,23),body,5)
	var facing: Vector2i = stats.facing
	var arrow := Vector2(facing)*29
	draw_line(arrow*0.75,arrow,Color("e3be79"),3)
	draw_circle(arrow,2,Color("e3be79"))
	draw_rect(Rect2(-25,28,50,5),Color("09121c"))
	draw_rect(Rect2(-25,28,50.0*stats.hp/maxf(1,stats.max_hp),5),Color("6bd2b6") if hero else Color("d58077"))
	if stats.bleeds.size() > 0:
		draw_string(font,Vector2(19,-17),"血%d" % stats.bleeds.size(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("ff8888"))
	draw_set_transform(Vector2.ZERO)
