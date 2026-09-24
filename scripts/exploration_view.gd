extends Control
const Dungeon = preload("res://scripts/dungeon.gd")
const TERRAIN = preload("res://assets/art/dungeon-atlas.webp")
signal activated(index: int)
signal flagged(index: int)
signal inspected(description: String)
var session: RefCounted
var font: Font
var mode := "探索"
var previous_seen: Array = []
var origin := -1
var hover := -1
var elapsed := 0.0
var reveal_time := 0.0
var keyboard_index := 0

func _ready() -> void:
	custom_minimum_size = Vector2(420,300)
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	keyboard_index = session.map_position
	mouse_exited.connect(func(): hover=-1; inspected.emit("亮边房间可抵达 · 右键标记危险 · 数字统计周围八格"))

func _process(delta: float) -> void:
	elapsed += delta
	reveal_time = minf(1.0,reveal_time+delta*1.8)
	queue_redraw()

func center(index: int) -> Vector2:
	var step := Vector2((size.x-76)/6,(size.y-72)/4)
	return Vector2(38,36)+Vector2(index%7,index/7)*step

func radius() -> float:
	return minf(27,minf((size.x-76)/6,(size.y-72)/4)*0.37)

func hit(point: Vector2) -> int:
	for i in range(Dungeon.COUNT):
		if point.distance_to(center(i))<=radius()+8:
			return i
	return -1

func describe(index: int) -> String:
	if index<0:
		return "亮边房间可抵达 · 右键标记危险 · 数字统计周围八格"
	var tile: Dictionary = session.dungeon[index]
	var known: bool = tile.seen or tile.scouted
	var title: String = Dungeon.TITLES[tile.kind] if known else "未知房间"
	var state := "已清理" if tile.cleared else ("已侦察，进入才触发" if tile.scouted else "未探索")
	var route := "可抵达" if Dungeon.accessible(session.dungeon,index) else "先探索相邻通道"
	if tile.seen and tile.kind=="empty":
		state = "周围八格初始危险：%d" % Dungeon.danger(session.dungeon,index)
	return "%s · %s · %s%s" % [title,state,route," · 已标记" if tile.flag else ""]

func _get_tooltip(at_position: Vector2) -> String:
	return describe(hit(at_position))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover = hit(event.position)
		inspected.emit(describe(hover))
	if event is InputEventMouseButton and event.pressed:
		var index := hit(event.position)
		if index<0:
			return
		grab_focus()
		keyboard_index = index
		if event.button_index==MOUSE_BUTTON_LEFT:
			activated.emit(index)
		elif event.button_index==MOUSE_BUTTON_RIGHT:
			flagged.emit(index)
		accept_event()
	if event is InputEventKey and event.pressed:
		var next := keyboard_index
		match event.keycode:
			KEY_LEFT: next=maxi(0,next-1)
			KEY_RIGHT: next=mini(34,next+1)
			KEY_UP: next=maxi(0,next-7)
			KEY_DOWN: next=mini(34,next+7)
			KEY_ENTER, KEY_SPACE: activated.emit(next)
			_: return
		keyboard_index = next
		hover = next
		inspected.emit(describe(next))
		accept_event()

func _draw() -> void:
	draw_texture_rect(TERRAIN,Rect2(Vector2.ZERO,size),false)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.05,0.07,0.22))
	var cells: Array = session.dungeon
	for i in range(cells.size()):
		if not cells[i].seen or not cells[i].cleared:
			continue
		for next in Dungeon.neighbors(i):
			if next<i and cells[next].seen and cells[next].cleared:
				continue
			var revealed: bool = cells[next].seen and cells[next].cleared
			draw_line(center(i),center(next),Color("568f89") if revealed else Color("374d57"),2,true)
			if not revealed:
				draw_circle(center(i).lerp(center(next),0.7),2,Color("8dbeb1"))
	for i in range(cells.size()):
		var tile: Dictionary = cells[i]
		var known: bool = tile.seen or tile.scouted
		var reachable: bool = Dungeon.accessible(cells,i)
		var p := center(i)
		var r := radius()
		var is_new: bool = tile.seen and not previous_seen.is_empty() and i not in previous_seen
		var alpha := clampf(reveal_time*1.8-float(i%5)*0.1,0.0,1.0) if is_new else 1.0
		var color := Color("739eaa") if known else Color("344954")
		if known:
			match tile.kind:
				"combat","elite","boss","trap": color=Color("d89091")
				"chest": color=Color("e2bf79")
				"rest","entrance": color=Color("82d2b7")
				"event": color=Color("b4a0e5")
		if reachable and not tile.seen:
			draw_circle(p,r+5+2*sin(elapsed*2+i),Color(0.4,0.82,0.75,0.09))
			color = Color("76bdb3") if not known else color
		draw_circle(p,r+2,Color("071219"))
		draw_circle(p,r,Color(0.055,0.1,0.13,0.85))
		draw_arc(p,r,0,TAU,40,Color(color,alpha),2 if reachable else 1,true)
		if hover==i:
			draw_arc(p,r+6,0,TAU,40,Color("e8d4ab"),2,true)
		var symbol := "?"
		if known:
			symbol = {"entrance":"归","combat":"刃","elite":"危","boss":"核","trap":"!","chest":"宝","event":"谜","rest":"火","empty":"·"}[tile.kind]
			if tile.seen and tile.kind=="empty":
				symbol = str(Dungeon.danger(cells,i))
		if tile.flag:
			symbol = "!"
			color = Color("efbe72")
		var text_size := font.get_string_size(symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,21)
		draw_string(font,p+Vector2(-text_size.x/2,7),symbol,HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color(color,alpha))
		if tile.cleared and tile.kind!="empty":
			draw_circle(p+Vector2(r*0.76,-r*0.76),4,Color("83c2a6"))
		if tile.scouted and not tile.seen:
			draw_arc(p,r-5,0,PI,20,Color(color,0.5),1,true)
		if is_new and reveal_time<1:
			draw_arc(p,r+reveal_time*24,0,TAU,40,Color(color,(1-reveal_time)*0.65),2,true)
	var player := center(session.map_position)
	if origin>=0 and origin!=session.map_position:
		player = center(origin).lerp(player,1-pow(1-reveal_time,3))
	draw_arc(player,radius()+9,elapsed*0.5,elapsed*0.5+TAU*0.8,40,Color("9aead0"),2,true)
	var marker := player+Vector2(0,-radius()-14)
	draw_colored_polygon(PackedVector2Array([marker+Vector2(-5,-3),marker+Vector2(5,-3),marker+Vector2(0,4)]),Color("d0ffe6"))
